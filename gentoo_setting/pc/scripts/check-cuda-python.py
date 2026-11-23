#!/usr/bin/env python3
"""Small synthetic GPU checks; run inside cuda-python.sh, never the musl host."""
import argparse
import ctypes
import importlib.metadata
import json
import os
from pathlib import Path
import sys
import time

import torch
import torch.nn.functional as functional


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seconds", type=int, default=0)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if not 0 <= args.seconds <= 600:
        parser.error("--seconds must be between 0 and 600")
    assert torch.cuda.is_available(), "CUDA device unavailable"
    torch.manual_seed(2026)
    torch.set_num_threads(2)
    torch.backends.cuda.matmul.allow_tf32 = False
    torch.backends.cudnn.allow_tf32 = False
    torch.backends.cudnn.benchmark = False
    checks = []

    def close(name, actual, reference, **tolerance):
        torch.testing.assert_close(actual.cpu(), reference, **tolerance)
        checks.append(name)

    a, b = torch.randn(256, 256), torch.randn(256, 256)
    close("matrix/cublas", a.cuda() @ b.cuda(), a @ b, rtol=1e-4, atol=2e-4)
    vector = torch.randn(4096)
    close("fft/cufft", torch.fft.fft(vector.cuda()), torch.fft.fft(vector),
          rtol=1e-4, atol=5e-5)
    positive = a @ a.T + torch.eye(256) * 256
    rhs = torch.randn(256, 8)
    close("solve/cusolver", torch.linalg.solve(positive.cuda(), rhs.cuda()),
          torch.linalg.solve(positive, rhs), rtol=1e-4, atol=1e-6)
    image, weight = torch.randn(2, 4, 32, 32), torch.randn(8, 4, 3, 3)
    gpu_image = image.cuda().requires_grad_()
    convolution = functional.conv2d(gpu_image, weight.cuda(), padding=1)
    close("convolution/cudnn", convolution, functional.conv2d(image, weight, padding=1),
          rtol=1e-4, atol=5e-5)
    convolution.square().mean().backward()
    assert torch.isfinite(gpu_image.grad).all().item()
    checks.append("autograd")
    sparse = torch.eye(256).to_sparse_csr()
    close("sparse/cusparse", torch.sparse.mm(sparse.cuda(), b.cuda()), b,
          rtol=1e-5, atol=1e-6)

    # Torch 的随机数不一定调用 cuRAND，单独测试官方库及真实设备输出。
    distribution = importlib.metadata.distribution("nvidia-curand")
    candidates = [Path(distribution.locate_file(item)).resolve()
                  for item in distribution.files or []
                  if item.name.startswith("libcurand.so.")]
    assert len(candidates) == 1, "Inspect changed cuRAND wheel layout"
    assert candidates[0].is_relative_to(Path(sys.prefix).resolve())
    curand = ctypes.CDLL(str(candidates[0]))
    generator = ctypes.c_void_p()
    curand.curandCreateGenerator.argtypes = [ctypes.POINTER(ctypes.c_void_p), ctypes.c_int]
    curand.curandSetPseudoRandomGeneratorSeed.argtypes = [ctypes.c_void_p, ctypes.c_ulonglong]
    curand.curandGenerateUniform.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t]
    curand.curandDestroyGenerator.argtypes = [ctypes.c_void_p]
    assert curand.curandCreateGenerator(ctypes.byref(generator), 100) == 0
    try:
        assert curand.curandSetPseudoRandomGeneratorSeed(generator, 2026) == 0
        samples = torch.empty(4096, device="cuda")
        assert curand.curandGenerateUniform(generator, samples.data_ptr(), samples.numel()) == 0
        torch.cuda.synchronize()
        assert ((samples > 0) & (samples <= 1) & torch.isfinite(samples)).all().item()
        assert abs(samples.mean().item() - 0.5) < 0.05
    finally:
        assert curand.curandDestroyGenerator(generator) == 0
    checks.append("curand/device-readback")
    assert samples.cpu().numpy().shape == (4096,)
    checks.append("numpy/readback")

    nvml = ctypes.CDLL("libnvidia-ml.so.1")
    assert nvml.nvmlInit_v2() == 0
    device = ctypes.c_void_p()
    nvml.nvmlDeviceGetHandleByIndex_v2.argtypes = [ctypes.c_uint, ctypes.POINTER(ctypes.c_void_p)]
    nvml.nvmlDeviceGetTemperature.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.POINTER(ctypes.c_uint)]
    assert nvml.nvmlDeviceGetHandleByIndex_v2(0, ctypes.byref(device)) == 0
    temperature = ctypes.c_uint()
    max_temperature, iterations = 0, 0
    started = time.monotonic()
    x = torch.randn(1024, 1024, device="cuda")
    try:
        while time.monotonic() - started < args.seconds:
            assert nvml.nvmlDeviceGetTemperature(device, 0, ctypes.byref(temperature)) == 0
            max_temperature = max(max_temperature, temperature.value)
            assert temperature.value < 80, "GPU thermal guard reached; load stopped"
            result = x @ x.T
            assert torch.isfinite(result).all().item()
            iterations += 1
            time.sleep(0.05)
    finally:
        nvml.nvmlShutdown()
    torch.cuda.synchronize()
    maps = Path("/proc/self/maps").read_text()
    toolkit = os.environ.get("CUDA_HOME")
    assert not toolkit or toolkit + "/lib" not in maps, "Mixed core toolkit and wheel libraries"
    report = {
        "torch": torch.__version__, "cuda_build": torch.version.cuda,
        "cudnn": torch.backends.cudnn.version(),
        "gpu": torch.cuda.get_device_name(), "checks": checks,
        "load_seconds": round(time.monotonic() - started, 2), "load_iterations": iterations,
        "maximum_temperature_c": max_temperature if iterations else None,
        "peak_allocated_mib": round(torch.cuda.max_memory_allocated() / 1024**2, 1),
        "core_toolkit_libraries_mixed": False,
    }
    text = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.write_text(text)
    print(text, end="")


if __name__ == "__main__":
    main()
