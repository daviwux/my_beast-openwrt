# My Beast OpenWrt 2.0 (x86_64)

纯 nftables + Docker + PassWall2 一键安装 + Argon 美化主题 + 万兆优化固件

## 主要特点
- OpenWrt 24.10.5
- 纯 nftables / fw4（完全移除 iptables 相关包）
- Docker + luci-app-dockerman 完整支持
- PassWall2 一键安装脚本（sh /etc/passwall2-setup.sh）
- Argon 主题（登录页可自定义背景图、视频、模糊、暗黑模式）
- BBR + 16MB TCP 缓冲 + 高 conntrack + IPv6 优化

## 下载固件
→ [Releases](https://github.com/你的用户名/my-beast-openwrt/releases)

## 安装 PassWall2
刷机后 SSH 登录路由器执行：
```bash
sh /etc/passwall2-setup.sh


自定义 LuCI 界面
登录 https://10.0.0.1 后：

System → Argon Config
可设置登录背景图、视频 URL、模糊度、透明度、光暗模式等
保存应用后刷新登录页即可看到效果

编译自己的版本

Fork 本仓库
修改 config/custom-config.sh 或 config/feeds.conf.custom
push 到 main 分支 → GitHub Actions 自动编译
下载 artifact 中的 .img.gz 刷机

版本迭代

2.0.0：纯 nftables + Argon 主题 + PassWall2 一键 + Docker 优化
后续版本：根据需要添加监控、cgroup v2、自动升级等


### 10. docs/CHANGELOG.md

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-01-xx

### Added
- 纯 nftables / fw4 完整支持（firewall4 + kmod-nft-nat 等）
- Docker + luci-app-dockerman 完整集成
- PassWall2 一键安装脚本（/etc/passwall2-setup.sh）
- Argon 主题 + luci-app-argon-config（登录页自定义背景/视频/暗黑模式）
- IPv6 accept_ra=2 + proxy_ndp 优化
- 高 conntrack + BBR + 16MB TCP 缓冲

### Changed
- 移除所有 iptables / iptables-nft / ip6tables 相关包，实现纯 nftables
- 移除 flow offload（x86_64 上无实际收益且有潜在冲突）

### Fixed
- feeds 警告（exim、python-zope 等）不影响编译
- fw4 开机自启保险机制
