# Gentoo development mirrors

本目录保存 PC 与 WSL 共用的用户级开发工具国内镜像配置。内部沿用
`dot_*` 路径命名，但它不是仓库根目录的通用配置；部署时去掉 `dot_` 前缀并
写入 Gentoo 用户家目录。

| 仓库文件 | 用户路径 | 用途 |
| --- | --- | --- |
| `dot_bunfig.toml` | `~/.bunfig.toml` | Bun npm registry |
| `dot_cargo/config.toml` | `~/.cargo/config.toml` | Cargo sparse index |
| `dot_config/go/env` | `~/.config/go/env` | Go module proxy chain |
| `dot_config/pip/pip.conf` | `~/.config/pip/pip.conf` | pip index |
| `dot_config/uv/uv.toml` | `~/.config/uv/uv.toml` | uv default index |
| `dot_npmrc` | `~/.npmrc` | npm registry |
| `dot_pixi/config.toml` | `~/.pixi/config.toml` | Pixi Conda and PyPI mirrors |

配置优先使用 CERNET 高校联合镜像。Go Proxy 因 CERNET 当前未提供兼容
端点，按华为、阿里、官方和源码直连的顺序回退。这里只能存放公开 URL，
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
