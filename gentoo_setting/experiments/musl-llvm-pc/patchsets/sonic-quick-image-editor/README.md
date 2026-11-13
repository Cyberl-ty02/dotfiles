# Sonic 图像编辑 0.7.0.1

问题：源码要求 Highway，但 SonicDE 配方未声明依赖；源码又查找 `HWY`，而
Highway 提供的是 `hwy` CMake Config 包及 `hwy::hwy` 目标。
参考 [Highway 上游](https://github.com/google/highway/blob/1.3.0/CMakeLists.txt) 和
[SonicDE 配方基线](https://github.com/sonicde-gentoo/portage/tree/a5e6600f3dbd67b02ca61a095e036c8a908fe0cc/sonicde-base/sonic-quick-image-editor)。

- `repository/0001-declare-highway-dependency.patch`：只补 `DEPEND`，运行依赖随原配方的 `${DEPEND}` 继承。
- `source/0001-use-hwy-cmake-config.patch`：只改 CMake 包发现方式。

等效修正已通过 musl、Clang 22、libc++、Highway 1.4.0 源码编译安装。
补丁组应用路径先在独立工作副本检查，不把当前运行中的构建切换到新来源。

在目标 Gentoo/chroot 内，以仓库克隆在 `/root/dotfiles` 为例：

```bash
group=/root/dotfiles/gentoo_setting/experiments/musl-llvm-pc/patchsets/sonic-quick-image-editor
git -C /var/db/repos/sonicde diff -- sonicde-base/sonic-quick-image-editor
git -C /var/db/repos/sonicde apply --check "$group/repository/0001-declare-highway-dependency.patch"
# 检查通过且确认该路径没有自己的未保存修改后再执行
git -C /var/db/repos/sonicde apply "$group/repository/0001-declare-highway-dependency.patch"
```

源码补丁通过 Portage 版本限定的用户补丁目录应用：

```bash
target=/etc/portage/patches/sonicde-base/sonic-quick-image-editor-0.7.0.1
install -d "$target"
# 同名文件已存在时先比较内容，不直接覆盖
test ! -e "$target/0001-use-hwy-cmake-config.patch" &&
    install -m 0644 "$group/source/0001-use-hwy-cmake-config.patch" "$target/"
emerge --pretend --verbose --update --newuse sonicde-base/sonicde-meta
```

这要求上游配方正常执行 `eapply_user`，本轮 ECM 准备流程满足此条件。
不能同时启用旧的 `musl-pc-lab` 修复配方和这份用户源码补丁，否则会重复应用。
首次迁入补丁组时，应核对计划确实采用 SonicDE 原仓库配方；已有本地 `-r1`
安装的实验根暂不按这段直接切换。

上游修复后，分别检查两层是否仍需要。源码补丁仅删除上述明确文件；配方补丁只在
它仍是自己的未提交差异时撤回，可先用 `git apply --reverse --check` 检查。
若修正已成为上游提交，不要反向应用去撤销上游。遇到新版本或上下文变化时先重审，
不要用强制应用跳过检查。
