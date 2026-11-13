# gcompat 1.1.0 加载器路径草案

`repository/0001-amd64-loader-path.patch` 修改的是 GURU ebuild，不是 gcompat C
源码，因此不应放到 `/etc/portage/patches/`。保留原补丁内容及零上下文格式。
目标为本轮 GURU `949a279b16d2b63b3ca54e717b6e181eac3ac347` 的
`sys-libs/gcompat/gcompat-1.1.0.ebuild`。

它限定 amd64/musl，调整 EAPI 和默认选项，并补充 `/lib64/ld-linux-x86-64.so.2`
相对符号链接。对应的手工加载器路径已验证，但这份完整配方尚未单独安装验收，
因此不纳入默认新机安装。

可在目标仓库的独立工作副本中检查：

```bash
# guru_copy 指向 GURU 的独立工作副本
group=/root/dotfiles/gentoo_setting/experiments/musl-llvm-pc/patchsets/gcompat-1.1.0
git -C "$guru_copy" apply --check --unidiff-zero --directory=sys-libs/gcompat \
    "$group/repository/0001-amd64-loader-path.patch"
```

这里的 `--unidiff-zero` 是原补丁格式要求，不是允许跨版本强制套用。应用前仍须
确认提交、目标文件及内容。后续若采用更新的 gcompat 或上游已经处理加载器路径，
先重新评估，本草案不能替代完整 glibc，也不是 NVIDIA 图形兼容方案。
