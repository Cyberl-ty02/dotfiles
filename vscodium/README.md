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
.\vscodium\sync-extensions.ps1
.\vscodium\sync-extensions.ps1 -Apply
```

同步先处理已排除项，再补回期望功能。卸载一个包可能连带卸载成员，因此脚本会
重新读取有效索引，不用过时列表判断“已经安装”。安装只依照明确清单，禁止包
自动带回其他成员／依赖，最后核验清单完整且排除项未回流。新增组件前仍需检查
硬依赖与运行时，不能靠强制卸载压过依赖错误。默认预览不修改编辑器。

Windows 的 `bootstrap.ps1 -InstallEditorExtensions` 调用同一入口，`-DryRun`
在该扩展步骤只预览。Windows 实机安装仍需在 Windows 执行和验收；Linux 不离线改写
Windows 系统盘。共享清单不包含账号、授权或插件内部状态。

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
