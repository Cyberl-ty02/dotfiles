# Gentoo development mirrors

PC 与 WSL 共用的用户级开发工具国内镜像已经迁入仓库根目录，由 chezmoi
直接部署。本目录只保留使用说明，不再保存第二份配置。

| 仓库文件 | 用户路径 | 用途 |
| --- | --- | --- |
| `../../dot_bunfig.toml` | `~/.bunfig.toml` | Bun npm registry |
| `../../dot_cargo/config.toml` | `~/.cargo/config.toml` | Cargo sparse index |
| `../../dot_config/go/env` | `~/.config/go/env` | Go module proxy chain |
| `../../dot_config/pip/pip.conf` | `~/.config/pip/pip.conf` | pip index |
| `../../dot_config/uv/uv.toml` | `~/.config/uv/uv.toml` | uv default index |
| `../../dot_npmrc` | `~/.npmrc` | npm registry |
| `../../dot_pixi/config.toml` | `~/.pixi/config.toml` | Pixi Conda and PyPI mirrors |

开发工具配置优先使用 CERNET 高校联合镜像。Portage distfiles 采用 USTC、
TUNA、华为、阿里和官方源；CERNET 当前会把部分请求转至连接超时的参与镜像，
因此只保留为 Portage Git 备用。Go Proxy 因 CERNET 当前未提供兼容端点，
按华为、阿里、官方和源码直连的顺序回退。这里只能存放公开 URL，
不得加入 registry token、密码或私有源凭据。

临时绕过镜像时，优先使用工具自己的命令行参数或环境变量：

```sh
BUN_CONFIG_REGISTRY=https://registry.npmjs.org bun install
npm --registry=https://registry.npmjs.org install
UV_DEFAULT_INDEX=https://pypi.org/simple uv sync
GOPROXY=https://proxy.golang.org,direct go mod download
```

Cargo 可同时传入：

```sh
cargo --config 'source.crates-io.replace-with="crates-io-direct"' \
  --config 'source.crates-io-direct.registry="sparse+https://index.crates.io/"' \
  build
```

长期恢复 Cargo 官方源时，移除 `~/.cargo/config.toml` 中的
`[source.crates-io] replace-with`。项目级配置可以覆盖这些用户级默认值。
Cargo 的搜索 API 与依赖下载源分开处理，镜像搜索使用
`cargo search --registry cernet <关键词>`。
