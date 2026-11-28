# VSCodium 多端同步

插件与可迁移设置由 Git 管理；账号令牌、钱包、运行状态、工作区历史、machine ID、
本机 JDK 路径不进入仓库。共用设置在 `../dot_config/private_VSCodium/User/settings.json`，
Windows 设置在 `../windows_setting/AppData/Roaming/VSCodium/User/settings.json`。

## 唯一插件清单

- `extensions-common.txt`：两端共用的有效插件 ID，不锁发布版本。
- `extensions-linux.txt`、`extensions-windows.txt`：平台专属功能；Remote WSL 仅在 Windows。
- `extensions-excluded.txt`：已替换的旧组合、重复后端及与 Java21 策略冲突的插件。

保留 IDE 功能，按语言整理实际组件，避免通过大包反复装回冲突依赖：

| 功能 | 当前组合与边界 |
| --- | --- |
| Java／JVM 项目 | Oracle Java + Maven for Java + Gradle for Java + Spring Initializr；所有 JVM 保持 Dragonwell Standard21 |
| 项目模板 | `Maven: Generate from Maven Archetype`、`Gradle: Create a Gradle Java Project...`／Advanced、`Spring Initializr: Create a Spring Boot Project...`，不局限于 Oracle 自带模板 |
| Python | Python、Pyright、Ruff、Black、debugpy、原生环境管理与 Jupyter；保留 Django/Jinja、docstring 与缩进功能 |
| Rust | rust-analyzer 原生测试视图、补全与运行入口，保留 TOML 支持；移除旧测试适配器／转换器组合 |
| C/C++、构建与文档 | 保留现有 Clice、CMake／xmake、Typst、Markdown、Office 等组件；不因名称相似删除有独立功能的插件 |

Red Hat Java 1.58 语言服务器要求并自带 JDK25，与本机策略冲突，因此排除其 Java
大包及 JDT 专用调试／测试后端，使用 Oracle 的编译、调试、测试功能。Kotlin 本轮暂缓。
Python 的独立 Flake8／isort 功能由 Ruff 覆盖；格式化继续使用 Black。
Jupyter 子组件和各语言必要依赖仍保留，不将扩展包成员简单视为重复插件。

## 执行同步

Linux 默认仅预览：

```sh
gentoo_setting/scripts/sync-vscodium.sh
gentoo_setting/scripts/sync-vscodium.sh --apply
```

Windows 在更新本仓库后，用 PowerShell 执行；不需要运行完整系统 bootstrap：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\vscodium\sync-extensions.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\vscodium\sync-extensions.ps1 -Apply
```

上述命令仅为该进程允许执行仓库脚本，适用于未签名脚本被 RemoteSigned 拦截的情况，
不会修改系统执行策略。Windows 的 `extensions.autoUpdate` 使用当前编辑器要求的
字符串 `"on"`，而不是旧版布尔值。

同步先处理已排除项，再补回期望功能。卸载一个包可能连带卸载成员，因此脚本会
重新读取有效索引，不用过时列表判断“已经安装”。安装只依照明确清单，禁止包
自动带回其他成员／依赖，最后核验清单完整且排除项未回流。新增组件前仍需检查
硬依赖与运行时，不能靠强制卸载压过依赖错误。默认预览不修改编辑器。

Windows 的 `bootstrap.ps1 -InstallEditorExtensions` 调用同一入口，`-DryRun`
在该扩展步骤只预览。用户已于2026-11-23人工确认 Windows 配置同步完成；以后新机
仍需在 Windows 执行和验收，Linux 不离线改写 Windows 系统盘。共享清单不包含
账号、授权或插件内部状态，不据此声称每个扩展的全部功能均已测试。

Windows 已在 VSCodium 1.143.17232 上执行安装同步并通过清单复核，用户设置的
chezmoi 差异为空；Oracle Java 27.0.1 已安装，`JAVA_HOME` 对应的 Dragonwell
Standard 21 已核验。此项仅确认安装与配置，重载后的 Java 编译、调试、测试及
其他语言 GUI 功能仍需分别验收。

## Java21 与 Flatpak 边界

Windows 可安装 Scoop 的 `dragonwell21-jdk` 与 `maven`，然后核验 `java -version`
与 `mvn -version`；不跟随 Maven 的通用 OpenJDK 建议安装另一套 JVM。
Maven／Gradle 优先使用项目自己的 wrapper，升级由项目管理。

Gentoo 原生 Maven 由 Portage 管理。Flatpak 专用设置由
`../gentoo_setting/pc/scripts/configure-postboot-user.py` 合并：Maven 桥接脚本只在
SDK 中通过包内 `host-spawn` 调用宿主 `/usr/bin/mvn`，在宿主终端直接调用原生
Maven，不固定扩展版本路径，不混用 SDK 与宿主库。不要将该本机路径复制到 Windows。
本机已通过 Maven archetype 项目生成及 SDK→宿主的 Java21 编译／JUnit 测试。
Maven 不自动读取 shell 的 HTTP_PROXY；需要下载依赖时，在本机私有
`~/.m2/settings.xml` 配置 Maven 标准代理。国内镜像可放入激活 profile 的
repositories／pluginRepositories，保留 Central 回退；本机已核对阿里云 Central
镜像的样本 POM 与官方一致，并以默认 settings、独立空缓存通过合成项目测试。
实际代理地址、凭据和用户 settings 不进入仓库，也不直接复制到 Windows。

Flatpak 的原生 Zsh 终端也使用包内 `/app/bin/host-spawn`，保持 PTY／作业控制与
宿主登录环境；原有 SDK sh 会话不强制关闭。代理由 `codium` 启动器按调用环境同时
传给 Chromium 和 Node；已有实例需完整退出后重开才继承新环境，不关闭 TLS 校验。

保留工作区信任、关闭遥测，不新增自动上传源代码的 AI 插件。模板生成器可能在
用户主动调用时向服务提交项目选项，不自动提交真实项目、身份或私有源码。

## Gentoo Codex：共享配置与可选 Magpie 路由

Magpie 的 Linux 图形版在 musl PC 上使用用户级 Flatpak `local.yetone.Magpie`，
以 GNOME 运行时提供 GTK／WebKitGTK。使用时保持 Magpie 在运行，网关仅监听
`127.0.0.1:3425`。Magpie 的出站代理在它自己的 Settings 中填写；VSCodium 按
现有 `proxy` → `codium` 流程启动。启动器和插件入口将回环地址补入
`NO_PROXY`／`no_proxy`，同时保留原有排除项，让编辑器直连本机网关。

### 一份用户配置，只切插件路由

- 原生 CLI 与 VSCodium Codex 始终使用同一个 `~/.codex`：共用主配置、登录、
  会话数据库、插件、skills 和缓存，不随 Magpie 是否在线切换整个用户目录。
- `~/.codex/config.toml` 保持普通 Codex 的默认配置。Magpie 仍将模型选择写入自己
  的 `codex-staging/config.toml`；这里仅作为路由来源，不再作为编辑器的 `CODEX_HOME`。
- 插件启动后端时，`codex-runtime.py`
  检查本机网关及已选模型，仅向本次进程叠加模型、provider、网关、可选目录与推理参数。
  模型目录优先使用 Magpie 已生成的文件；否则从本机网关获取，放入只读封存的 Linux
  内存文件。每个新后端读自己的快照，不生成另一份磁盘缓存，也不污染普通模型列表。
  Magpie 缺失、配置不适用、网关离线、模型或模型目录不可用时，直接使用普通主配置。
- 不从 Magpie 导入沙箱、审批、工作区信任或其他行为配置，不覆盖主配置或登录文件。
  网关令牌及认证头通过子进程环境传递，不写入命令行或仓库。
- 原生 `codex`／`musl-codex-resume` 保持原来的默认行为，不自动切换模型。
  两个入口的共享不等于可以同时写同一个活动会话。

启用此适配并选择 Magpie 时，**本机网关会收到现有 ChatGPT 访问授权**，因而能够
使用该登录；这不是认证隔离方案。只有信任本机 Magpie 并明确同意这一点才部署。
读取模型目录时，令牌仅用于固定的 `127.0.0.1:3425`，不跟随重定向、不打印或另存。
当前已验证文件式 ChatGPT 凭据；仅存在系统钥匙环中的凭据不能由适配器直接读取，
模型目录不可用时保持普通模式。不要为此关闭密钥环保护或导出令牌到 shell。

模型路由使用已安装扩展自带的后端，不固定扩展版本、不另装第二套 Codex。
本地适配通过 `chatgpt.cliExecutable` 接入；这是上游标为开发用途的入口，不代表
上游保证所有扩展版本兼容。升级扩展后需要复验；不修改扩展文件或关闭安全限制。

### 日常启动

先打开 FlClash 和 Magpie。在 Magpie 的 Providers 添加供应商，随后从
**Agents → Codex** 选择模型。日常从终端启动同一个 VSCodium：

```sh
proxy
codium
```

`codium` 调用 [Linux 启动器](../gentoo_setting/pc/scripts/launch-codium.py)，保持
日常的 VSCodium 设置，不需要单独的 **VSCodium (Magpie)** 菜单项。
首次从旧的独立目录方案切换时，先结束任务，正常退出所有 VSCodium 窗口后再运行
`codium`，使扩展自身也读到共享目录。以后在 Magpie 改模型、启动或退出 Magpie 后，
先结束任务，再执行 VSCodium 的 **Developer: Reload Window**，由新后端重新选择。

这里的“自适应”发生在插件后端启动时，不是在正在生成的请求中途切换。Magpie 运行中
退出导致请求失败时，不自动把同一请求重发给另一供应商，避免重复计费或意外转发历史。
不同 provider 的已有会话可能无法直接续聊；保持原 provider，或人工确认后另开／
派生会话，不改写旧会话的 provider 来绕过限制。

### 重建本机配置

Magpie 的 **Codex** 行对应 OpenAI 扩展。沙箱只读访问扩展目录以检测扩展，
模型配置仍写入 Magpie 自己的应用数据；不要把 Magpie 的 `CODEX_HOME` 也改成
`~/.codex`，否则它会直接改变普通 CLI 的默认模型。

```sh
magpie_codex="$HOME/.var/app/local.yetone.Magpie/data/codex-staging"
install -d -m 0700 "$magpie_codex"
flatpak override --user --filesystem="$HOME/.vscode-oss/extensions:ro" \
  --env="CODEX_HOME=$magpie_codex" --env=MAGPIE_ADDR=127.0.0.1:3425 \
  local.yetone.Magpie
```

上面是可独立复用的 Flatpak 设置。当前真机另有本地的插件路由适配脚本
`configure-codex.py` 和 `codex-runtime.py`，以及配套的 `codium` 启动器。
这次发布只同步文档，脚本还在本机工作树中。仅克隆仓库或执行上面的 Flatpak
命令不会安装该适配。已经部署的本机设置与入口有备份，位于
`~/.local/state/codex-runtime-backup/`。

旧 `codex-staging` 中已经产生的会话和重复缓存保持原样，尤其不能在仍有进程使用时
直接替换或删除。新插件进程统一在 `~/.codex` 写入；旧历史的离线迁移与缓存清理
单独验收，不能把切换新入口说成历史数据库已经合并或磁盘空间已经回收。

撤回适配时，恢复部署备份中的编辑器设置和入口，或移除本机设置中的
`chatgpt.cliExecutable` 后重启编辑器；共享主配置、登录和会话没有被路由器改写。
重开 Magpie 后在 Settings 填入 FlClash 的 HTTP/mixed 监听地址。
真实供应商的密钥、模型元数据和会话都留在本机，不提交仓库。

### 验证边界

2026-11-28 使用 `openai.chatgpt` 26.1120.50957 自带的
`codex-cli 0.171.0-alpha.13.2`，在隔离共享目录与本地模拟 Responses 服务上验证：
同一份主配置下，两种 Magpie 模型均完成请求，普通模式仍读取原默认值，主配置
字节内容未变，既有 provider 和审批／沙箱设置保持；网关令牌和认证头也按预期传递。
合成 ChatGPT 登录下按普通→Magpie A→Magpie B→普通顺序启动，模型列表分别正确，
Magpie 的内存目录没有改写普通磁盘模型缓存。共13项临时回归测试通过，包括部署
预览／幂等、缺失／错误配置、离线回退、回环代理排除、显式模型参数与旧扩展索引回退。
经用户明确授权，真实本机网关的只读模型目录获取也通过；没有发起付费模型请求。
用户级入口与本机单项编辑器设置已部署，目标 VSCodium Flatpak 内的入口自检和
重复部署预览通过。部署前的活动后端保持运行；首次退出旧窗口并重开的 GUI 验收待做。
这不是当前活动窗口已经切换，也不代替真实付费供应商、全部 GUI 模型列表、
已有会话跨 provider 续聊或旧历史迁移验收。

参考：[Magpie 的 Codex 模型配置](https://usemagpie.ai/docs/codex-models)、
[Codex App Server](https://developers.openai.com/codex/app-server)、
[配置优先级与进程参数](https://developers.openai.com/codex/config-advanced)、
[IDE 设置与自定义后端限制](https://developers.openai.com/codex/ide/settings)。
