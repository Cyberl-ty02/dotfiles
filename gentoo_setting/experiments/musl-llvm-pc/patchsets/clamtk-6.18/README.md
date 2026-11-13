# ClamTk 6.18

目标为 Gentoo `app-antivirus/clamtk-6.18-r2`。程序设置了 gettext domain，
但没有明确绑定翻译目录；在本轮 musl 根中，即使中文翻译文件存在、
`LANG=zh_CN.UTF-8`，界面仍显示英文。独立 Perl 检查中，明确绑定目录后可读到中文。

源码补丁增加一行 `bindtextdomain`，不改全局 locale、Perl 编码或 libc。
按版本安装为：

```text
/etc/portage/patches/app-antivirus/clamtk-6.18-r2/0001-bind-gettext-domain-directory.patch
```

独立副本的应用与反向撤回检查、版本限定用户补丁重建，以及私有显示中的中文界面
均已通过；日志确认补丁实际应用，标题、配置、扫描和更新控件已显示中文。
安装补丁后须重建该包，单独复制补丁不会更新已安装程序。
上游显式绑定正确目录后，核对目标版本，移除这一个用户补丁。
