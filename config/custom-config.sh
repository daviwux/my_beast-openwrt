#!/bin/bash
TARGET_DIR=${1:-$(pwd)/openwrt}
cd "$TARGET_DIR"

# 1. 修改默认后台 IP 为 10.0.0.1
sed -i 's/192.168.1.1/10.0.0.1/g' package/base-files/files/bin/config_generate

# 2. 注入 .config（核心包选择）
cat >> .config <<EOF
# --- 平台与分区 ---
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
CONFIG_TARGET_x86_64_DEVICE_generic=y
CONFIG_TARGET_KERNEL_PARTSIZE=256
CONFIG_TARGET_ROOTFS_PARTSIZE=2048

# --- LuCI 与中文 + Argon 主题 ---
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-compat=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
CONFIG_PACKAGE_luci-theme-bootstrap=y
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-argon-config=y
CONFIG_PACKAGE_luci-lib-ipkg=y

# --- 防火墙（纯 nftables / fw4） ---
CONFIG_PACKAGE_firewall4=y
CONFIG_PACKAGE_kmod-nft-nat=y
CONFIG_PACKAGE_kmod-nft-queue=y
CONFIG_PACKAGE_nftables=y

# --- Docker 支持 ---
CONFIG_PACKAGE_luci-app-dockerman=y
CONFIG_PACKAGE_luci-i18n-dockerman-zh-cn=y
CONFIG_PACKAGE_docker=y
CONFIG_PACKAGE_dockerd=y
CONFIG_PACKAGE_docker-compose=y
CONFIG_PACKAGE_containerd=y
CONFIG_PACKAGE_runc=y
CONFIG_PACKAGE_tini=y
CONFIG_PACKAGE_kmod-veth=y
CONFIG_PACKAGE_kmod-br-netfilter=y
CONFIG_PACKAGE_kmod-nf-conntrack-netlink=y

# --- PassWall2 纯 nft 依赖 ---
CONFIG_PACKAGE_kmod-nft-tproxy=y
CONFIG_PACKAGE_kmod-nft-socket=y
CONFIG_PACKAGE_kmod-nft-xfrm=y
CONFIG_PACKAGE_kmod-nft-nat6=y
CONFIG_PACKAGE_ipset=y
CONFIG_PACKAGE_resolveip=y

# --- 性能与驱动 ---
CONFIG_PACKAGE_irqbalance=y
CONFIG_PACKAGE_intel-microcode=y
CONFIG_PACKAGE_iucode-tool=y
CONFIG_PACKAGE_kmod-ixgbe=y
CONFIG_PACKAGE_kmod-i40e=y
CONFIG_PACKAGE_kmod-r8125=y
CONFIG_PACKAGE_kmod-r8126=y
CONFIG_PACKAGE_kmod-ath12k=y

# --- IPv6 支持 ---
CONFIG_PACKAGE_odhcp6c=y
CONFIG_PACKAGE_odhcpd-ipv6only=y

# --- 系统工具 ---
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_ttyd=y
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_autocore=y

# --- 禁用 iptables 相关包（保持纯 nft） ---
CONFIG_PACKAGE_iptables=n
CONFIG_PACKAGE_iptables-nft=n
CONFIG_PACKAGE_ip6tables=n
CONFIG_PACKAGE_ip6tables-nft=n
EOF

# 3. sysctl 性能调优
mkdir -p package/base-files/files/etc
cat >> package/base-files/files/etc/sysctl.conf <<EOF
# BBR + 高性能缓冲
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216

# 高并发连接追踪
net.netfilter.nf_conntrack_max=1048576
net.netfilter.nf_conntrack_tcp_timeout_established=1200
net.netfilter.nf_conntrack_ipv6_max=524288

# IPv6 + Docker 兼容
net.ipv6.conf.all.accept_ra=2
net.ipv6.conf.default.accept_ra=2
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.all.autoconf=1
net.ipv6.conf.default.autoconf=1
net.ipv6.conf.all.dad_transmits=1
net.ipv6.conf.default.dad_transmits=1
net.ipv6.conf.docker0.proxy_ndp=1

# Docker 桥接 nft 转发
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-arptables=1
EOF

# 4. 防火墙 fw4 开机自启保险
cat >> package/base-files/files/etc/rc.local <<'EOF'
if [ -x /etc/init.d/firewall ]; then
    /etc/init.d/firewall enable
    /etc/init.d/firewall restart
    logger -t fw4 "防火墙已启用（nftables 模式）"
fi
exit 0
EOF

# 5. PassWall2 一键安装脚本
mkdir -p package/base-files/files/etc
cat >> package/base-files/files/etc/passwall2-setup.sh <<'EOF'
#!/bin/sh
# 添加 PassWall 公钥
wget -O /tmp/passwall.pub https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub
opkg-key add /tmp/passwall.pub
rm -f /tmp/passwall.pub

# 检测版本和架构
. /etc/openwrt_release
release="${DISTRIB_RELEASE%.*}"
arch="$DISTRIB_ARCH"

# 添加 feeds
cat >> /etc/opkg/customfeeds.conf << EOT
src/gz passwall_luci https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/passwall_luci
src/gz passwall_packages https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/passwall_packages
src/gz passwall2 https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/passwall2
EOT

opkg update

# 安装核心包（纯 nft 依赖）
opkg install luci-app-passwall2 luci-i18n-passwall2-zh-cn sing-box chinadns-ng kmod-nft-tproxy kmod-nft-socket nftables

# 修复 fw4 reload 选项不兼容问题
uci -q delete firewall.passwall2.reload
uci -q delete firewall.passwall2_server.reload
uci commit firewall
/etc/init.d/firewall reload

# 启用服务
/etc/init.d/passwall2 enable
/etc/init.d/passwall2 restart

echo "PassWall2 已安装完成（纯 nftables 模式）"
echo "请访问 LuCI -> Services -> PassWall 2 配置节点"
echo "建议优先使用 TPROXY 或 Redir（nft）模式"
EOF
chmod +x package/base-files/files/etc/passwall2-setup.sh

# 6. 默认使用 Argon 主题
mkdir -p package/base-files/files/etc/config
cat >> package/base-files/files/etc/config/luci <<EOF
config luci
	option lang 'auto'
	option mediaurlbase '/luci-static/argon'
EOF

# 结束提示
echo "2.0 配置应用完成：纯 nftables + Docker + Argon 主题 + PassWall2 一键安装"
echo "登录 LuCI 后：System → Argon Config 可自定义登录背景、视频、暗黑模式等"
