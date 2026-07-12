{ pkgs, ... }:

{
  # CUDA redistributables use NVIDIA's non-free license.
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    clinfo
    cudaPackages.cuda_cccl
    cudaPackages.cuda_cudart
    cudaPackages.cuda_nvcc
    cudaPackages.cuda_nvrtc
    vulkan-tools
  ];
}
