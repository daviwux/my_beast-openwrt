#!/bin/bash
# ==================================================
# OpenWrt 定制脚本 - 完美防报错 + 通用极致性能优化版 3.9 (2026)
# 关键调整：nf_conntrack_max = 524288（安全值，防 OOM，适合 4–8GB 内存）
# 其他：Cake + BBR + nftables Docker 兼容 + 全预编译 PassWall2/SmartDNS/Docker
# 网页管理 IP：192.168.1.2
# ==================================================

TARGET_DIR=${1:-$(pwd)/openwrt}
cd "$TARGET_DIR" || { echo "目录错误"; exit 1; }

# 固定管理 IP 为 192.168.1.2（网页 LuCI 直接访问）
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# .config：核心包 + 依赖（全预编译）
cat > .config <<EOF
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
CONFIG_TARGET_x86_64_DEVICE_generic=y
CONFIG_TARGET_KERNEL_PARTSIZE=256
CONFIG_TARGET_ROOTFS_PARTSIZE=2048

# LuCI + Argon + 中文
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-compat=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-argon-config=y

# 纯 nftables
CONFIG_PACKAGE_iptables=n
CONFIG_PACKAGE_iptables-nft=n
CONFIG_PACKAGE_ip6tables=n
CONFIG_PACKAGE_ip6tables-nft=n
CONFIG_PACKAGE_kmod-ipt-offload=n
CONFIG_PACKAGE_firewall4=y
CONFIG_PACKAGE_kmod-nft-nat=y
CONFIG_PACKAGE_kmod-nft-queue=y
CONFIG_PACKAGE_nftables=y

# PassWall2 全预装
CONFIG_PACKAGE_luci-app-passwall2=y
CONFIG_PACKAGE_luci-i18n-passwall2-zh-cn=y
CONFIG_PACKAGE_sing-box=y
CONFIG_PACKAGE_chinadns-ng=y
CONFIG_PACKAGE_v2ray-geoip=y
CONFIG_PACKAGE_v2ray-geosite=y
CONFIG_PACKAGE_kmod-nft-tproxy=y
CONFIG_PACKAGE_kmod-nft-socket=y
CONFIG_PACKAGE_kmod-nft-xfrm=y
CONFIG_PACKAGE_kmod-nft-nat6=y
CONFIG_PACKAGE_ipset=y
CONFIG_PACKAGE_resolveip=y
CONFIG_PACKAGE_kmod-tun=y
CONFIG_PACKAGE_kmod-inet-diag=y
CONFIG_PACKAGE_kmod-netlink-diag=y

# Docker 全预装（nft 桥接兼容）
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

# SmartDNS 全预装
CONFIG_PACKAGE_luci-app-smartdns=y
CONFIG_PACKAGE_luci-i18n-smartdns-zh-cn=y
CONFIG_PACKAGE_smartdns=y

# Cake SQM + 高性能组件
CONFIG_PACKAGE_luci-app-sqm=y
CONFIG_PACKAGE_kmod-sched-cake=y
CONFIG_PACKAGE_kmod-ifb=y
CONFIG_PACKAGE_irqbalance=y
CONFIG_PACKAGE_intel-microcode=y
CONFIG_PACKAGE_iucode-tool=y

# 万兆/2.5G 网卡驱动
CONFIG_PACKAGE_kmod-ixgbe=y
CONFIG_PACKAGE_kmod-i40e=y
CONFIG_PACKAGE_kmod-r8125=y
CONFIG_PACKAGE_kmod-r8126=y
CONFIG_PACKAGE_kmod-ath12k=y

# IPv6 + 系统工具
CONFIG_PACKAGE_odhcp6c=y
CONFIG_PACKAGE_odhcpd-ipv6only=y
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_ttyd=y
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_autocore=y
EOF

# 性能调优 sysctl（通用优化 + nf_conntrack_max = 524288）
mkdir -p package/base-files/files/etc
cat > package/base-files/files/etc/sysctl.conf <<EOF
# 队列 + 拥塞控制（Cake + BBR 黄金组合）
net.core.default_qdisc=cake
net.ipv4.tcp_congestion_control=bbr

# IPv6 转发 + 优化
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
net.ipv6.conf.all.accept_ra=2
net.ipv6.conf.default.accept_ra=2
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.all.autoconf=1
net.ipv6.conf.default.autoconf=1

# 缓冲区（适中偏大，适合大多数软路由）
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_rmem=4096 131072 67108864
net.ipv4.tcp_wmem=4096 131072 67108864

# Conntrack + Docker nft 桥接（关键兼容 + 安全值）
net.netfilter.nf_conntrack_max=524288           # 安全值，防 OOM，适合 4–8GB 内存
net.netfilter.nf_conntrack_tcp_timeout_established=600
net.netfilter.nf_conntrack_udp_timeout=60
net.netfilter.nf_conntrack_udp_timeout_stream=180
net.bridge.bridge-nf-call-nftables=1

# 高性能 TCP（低延迟 + 高并发）
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_low_latency=1
net.ipv4.tcp_no_metrics_save=1
net.core.somaxconn=65535
net.core.netdev_max_backlog=100000
net.ipv4.tcp_max_syn_backlog=16384
net.ipv4.ip_local_port_range=1024 65535

# ARP 表优化（防高并发溢出）
net.ipv4.neigh.default.gc_thresh1=2048
net.ipv4.neigh.default.gc_thresh2=8192
net.ipv4.neigh.default.gc_thresh3=16384
net.ipv6.neigh.default.gc_thresh1=2048
net.ipv6.neigh.default.gc_thresh2=8192
net.ipv6.neigh.default.gc_thresh3=16384

# 文件描述符 + vm 脏页/内存优化（减少 I/O 等待）
fs.file-max=2097152
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.swappiness=10
vm.overcommit_memory=1
vm.overcommit_ratio=80
vm.vfs_cache_pressure=50

# MTU probing + TCP 窗口/ACK 优化
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_ecn=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
EOF

# rc.local：扩容 + 防火墙 + opkg 多轮防报错 + 网卡优化 + irqbalance 通用启用
cat > package/base-files/files/etc/rc.local <<'EOF'
#!/bin/sh
ulimit -n 1048576

# 自动扩容 rootfs
[ -f /etc/.expanded ] || {
    logger -t expand "开始自动扩容..."
    ROOT_PART=$(findmnt -no SOURCE /)
    [ "$ROOT_PART" ] && {
        for i in {1..3}; do
            opkg update && opkg install growpart && break
            sleep 5
        done
        DISK=${ROOT_PART%[0-9]*}
        PART_NUM=${ROOT_PART##*[a-z]}
        growpart "$DISK" "$PART_NUM" && partprobe "$DISK"
        e2fsck -f -y "$ROOT_PART"
        resize2fs "$ROOT_PART" && logger -t expand "扩容完成"
    }
    touch /etc/.expanded
}

# 防火墙启动
[ -x /etc/init.d/firewall ] && {
    /etc/init.d/firewall enable
    /etc/init.d/firewall restart
}

# opkg 首次刷新（多轮防报错）
logger -t opkg "首次刷新 opkg 缓存..."
rm -rf /var/opkg-lists/*
for i in {1..5}; do
    opkg update --force-checksum --force-depends && break
    sleep 8
done

# 万兆网卡环缓冲区优化（通用值）
for i in $(ls /sys/class/net | grep -E 'eth|enp|ens'); do
    ethtool -G "$i" rx 8192 tx 8192 2>/dev/null
done

# irqbalance 启用（多核中断分布，通用收益）
[ -x /etc/init.d/irqbalance ] && {
    /etc/init.d/irqbalance enable
    /etc/init.d/irqbalance start
}

# 可选：CPU governor performance（高性能模式，功耗增加；注释掉为默认省电）
# echo performance > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

exit 0
EOF
chmod +x package/base-files/files/etc/rc.local

# 默认 Argon 主题
mkdir -p package/base-files/files/etc/config
cat > package/base-files/files/etc/config/luci <<EOF
config luci
        option lang 'auto'
        option mediaurlbase '/luci-static/argon'
EOF

echo "通用性能优化版 3.9 完成！"
echo "nf_conntrack_max 已调整为 524288（安全值，适合大多数内存配置）"
echo "网页管理：http://192.168.1.2"
echo "所有第三方软件全预编译，运行时基本零报错"
echo "编译前：./scripts/feeds update -a && ./scripts/feeds install -a"
echo "推荐 OpenWrt 24.10 stable 分支"