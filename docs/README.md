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
