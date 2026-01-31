#!/bin/bash
# ==================================================
# OpenWrt 定制脚本 - 最终完整优化 + 编译失败保险版 3.9.2 (2026)
# 特点：
#   - 全预编译 PassWall2 / SmartDNS / Docker（首选开箱即用）
#   - 编译失败保险：保留并强化手动修复脚本（passwall2-setup.sh / smartdns-setup.sh）
#   - rc.local 自动检测缺失包并提示/尝试修复
#   - nf_conntrack_max = 524288（安全值）
#   - nftables + Docker 桥接兼容 + 通用极致性能优化
#   - 网页管理 IP：192.168.1.2
# ==================================================

TARGET_DIR=${1:-$(pwd)}
cd "$TARGET_DIR"

# === DNSMASQ 满血替换逻辑 (兼容 24.10 精准版) ===
# 1. 批量修正所有第三方包对 dnsmasq 的依赖，引向 dnsmasq-full
find package/feeds/ -name Makefile -exec sed -i 's/+dnsmasq\b/+dnsmasq-full/g' {} +

# 2. 从 target 默认包列表移除 dnsmasq (清理硬编码)
sed -i 's/\bdnsmasq\b//g' include/target.mk
sed -i 's/\bdnsmasq\b//g' target/linux/x86/Makefile

# 3. 性能优化 (可选)
sed -i 's/-Os/-O3/g' include/target.mk

# 固定管理 IP 为 192.168.1.2
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# .config：核心包 + 依赖（全预编译）
cat >> .config <<EOF
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
CONFIG_TARGET_x86_64_DEVICE_generic=y
CONFIG_TARGET_KERNEL_PARTSIZE=256
CONFIG_TARGET_ROOTFS_PARTSIZE=2048

# LuCI + bootstrap + 中文
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-theme-bootstrap=y
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-compat=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
CONFIG_PACKAGE_uhttpd=y
CONFIG_PACKAGE_uhttpd-mod-ubus=y
CONFIG_PACKAGE_luci-mod-admin-full=y
CONFIG_PACKAGE_luci-lib-ipkg=y
CONFIG_PACKAGE_luci-lib-fs=y
CONFIG_PACKAGE_libustream-openssl=y
CONFIG_PACKAGE_luci-ssl-openssl=y

# 纯 nftables
CONFIG_PACKAGE_iptables=n
CONFIG_PACKAGE_iptables-nft=y
CONFIG_PACKAGE_ip6tables=n
CONFIG_PACKAGE_ip6tables-nft=y
CONFIG_PACKAGE_kmod-ipt-offload=y
CONFIG_PACKAGE_firewall4=y
CONFIG_PACKAGE_kmod-nft-nat=y
CONFIG_PACKAGE_kmod-nft-queue=y
CONFIG_PACKAGE_nftables=y
# --- 4. UI 界面与兼容性 ---
CONFIG_PACKAGE_luci-app-firewall=y
CONFIG_PACKAGE_luci-i18n-firewall-zh-cn=y

# 满血网络核心 (DNSMASQ-Full)
CONFIG_PACKAGE_dnsmasq=n

# 2. 启用满血版 DNSMASQ-FULL
CONFIG_PACKAGE_dnsmasq-full=y

# 修正 24.10 兼容性
CONFIG_PACKAGE_libcrypt-compat=y

# 3. 开启 DNSMASQ-FULL 的满血特性插件
CONFIG_PACKAGE_dnsmasq_full_ipset=y
CONFIG_PACKAGE_dnsmasq_full_nftset=y
CONFIG_PACKAGE_dnsmasq_full_tftp=y
CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y
CONFIG_PACKAGE_dnsmasq_full_dnssec=y
CONFIG_PACKAGE_dnsmasq_full_auth=y
CONFIG_PACKAGE_dnsmasq_full_conntrack=y
CONFIG_PACKAGE_dnsmasq_full_nls=y
CONFIG_PACKAGE_luci-app-dnsmasq=y

# PassWall2 预编译（核心依赖齐全）
CONFIG_PACKAGE_luci-app-passwall=y
CONFIG_PACKAGE_luci-i18n-passwall-zh-cn=y
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

# Docker 预编译（nft 桥接兼容）
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
CONFIG_PACKAGE_kmod-tap=y

# 1. 允许 Docker 容器直接操作磁盘分区 (如果你要在 Docker 里跑挂载任务)
CONFIG_PACKAGE_kmod-loop=y

# 2. 增强 Docker 的存储驱动支持 (防止某些镜像因为文件系统问题无法启动)
CONFIG_PACKAGE_kmod-lib-crc32c=y

# 3. 既然用了 Docker Compose，建议加上 cgroup 支持，防止资源限制失效
CONFIG_PACKAGE_cgroupfs-mount=y

# SmartDNS 预编译
CONFIG_PACKAGE_luci-app-smartdns=y
CONFIG_PACKAGE_luci-i18n-smartdns-zh-cn=y
CONFIG_PACKAGE_smartdns=y
CONFIG_PACKAGE_libubus-lua=y
CONFIG_PACKAGE_libnetfilter-conntrack=y

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
# 1. 分区表调整工具 (对应脚本中的 growpart)
CONFIG_PACKAGE_cloud-utils-growpart=y

# 2. 磁盘分区刷新工具 (对应脚本中的 partprobe)
CONFIG_PACKAGE_parted=y

# 3. 文件系统调整工具 (对应脚本中的 resize2fs 和 e2fsck)
CONFIG_PACKAGE_e2fsprogs=y

# 4. 挂载查询工具 (对应脚本中的 findmnt)
CONFIG_PACKAGE_util-linux=y
CONFIG_PACKAGE_util-linux-findmnt=y

# 5. 基础系统工具 (确保脚本执行环境)
CONFIG_PACKAGE_bash=y
CONFIG_PACKAGE_lsblk=y
EOF

# 性能调优 sysctl（通用优化）
mkdir -p package/base-files/files/etc
cat > package/base-files/files/etc/sysctl.conf <<EOF
net.core.default_qdisc=cake
net.ipv4.tcp_congestion_control=bbr
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_rmem=4096 131072 67108864
net.ipv4.tcp_wmem=4096 131072 67108864
net.netfilter.nf_conntrack_max=524288
net.netfilter.nf_conntrack_tcp_timeout_established=600
net.netfilter.nf_conntrack_udp_timeout=60
net.netfilter.nf_conntrack_udp_timeout_stream=180
net.bridge.bridge-nf-call-nftables=1
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_low_latency=1
net.ipv4.tcp_no_metrics_save=1
net.core.somaxconn=65535
net.core.netdev_max_backlog=200000
net.ipv4.tcp_max_syn_backlog=16384
net.ipv4.ip_local_port_range=1024 65535
net.ipv4.tcp_syn_retries=2
net.ipv4.tcp_synack_retries=2
net.ipv4.tcp_keepalive_time=300
net.ipv4.neigh.default.gc_thresh1=2048
net.ipv4.neigh.default.gc_thresh2=8192
net.ipv4.neigh.default.gc_thresh3=16384
net.ipv6.neigh.default.gc_thresh1=2048
net.ipv6.neigh.default.gc_thresh2=8192
net.ipv6.neigh.default.gc_thresh3=16384
fs.file-max=2097152
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.swappiness=10
vm.overcommit_memory=1
vm.overcommit_ratio=80
vm.vfs_cache_pressure=50
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_ecn=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
EOF

# rc.local：扩容 + 防火墙 + opkg + 网卡 + irqbalance + 包缺失检测 & 修复提示
cat > package/base-files/files/etc/rc.local <<'EOF'
#!/bin/sh
ulimit -n 1048576

# 自动扩容 rootfs (优化版)
[ -f /etc/.expanded ] || {
    logger -t expand "开始自动扩容..."
    ROOT_PART=$(findmnt -no SOURCE /)
    [ "$ROOT_PART" ] && {
        # 已经在固件里内置了工具，直接调用
        DISK=${ROOT_PART%[0-9]*}
        PART_NUM=${ROOT_PART##*[a-z]}
        /usr/bin/growpart "$DISK" "$PART_NUM" && /usr/sbin/partprobe "$DISK"
        /usr/sbin/e2fsck -f -y "$ROOT_PART"
        /usr/sbin/resize2fs "$ROOT_PART" && logger -t expand "扩容完成"
    }
    touch /etc/.expanded
}

# 防火墙启动
[ -x /etc/init.d/firewall ] && /etc/init.d/firewall enable && /etc/init.d/firewall restart

# opkg 首次刷新（多轮防报错）
logger -t opkg "首次刷新 opkg 缓存..."
rm -rf /var/opkg-lists/*
for i in {1..5}; do
    opkg update --force-checksum --force-depends && break
    sleep 8
done

# 万兆网卡环缓冲区优化 (增加上限判断，防止报错中断)
for i in $(ls /sys/class/net | grep -E 'eth|enp|ens'); do
    # 尝试设置 4096 (大部分 2.5G 网卡上限)，如果失败则跳过
    ethtool -G "$i" rx 4096 tx 4096 2>/dev/null || ethtool -G "$i" rx 1024 tx 1024 2>/dev/null
done

# irqbalance 启用 + 日志
[ -x /etc/init.d/irqbalance ] && {
    /etc/init.d/irqbalance enable
    /etc/init.d/irqbalance start
    logger -t perf "irqbalance 状态: $(/etc/init.d/irqbalance status 2>/dev/null || echo '未运行')"
}

# 编译失败保险：检测核心包是否缺失，并提示手动修复
logger -t check "检查第三方软件预编译状态..."
MISSING=""
opkg list-installed | grep -q luci-app-passwall || MISSING="$MISSING passwall"
opkg list-installed | grep -q luci-app-smartdns || MISSING="$MISSING smartdns"
opkg list-installed | grep -q dockerd || MISSING="$MISSING docker"

if [ -n "$MISSING" ]; then
    logger -t check "警告：以下包预编译失败：$MISSING"
    logger -t check "请登录 LuCI 或 SSH 执行以下命令手动修复："
    [ -f /etc/passwall-setup.sh ] && logger -t check "  sh /etc/passwall-setup.sh"
    [ -f /etc/smartdns-setup.sh ] && logger -t check "  sh /etc/smartdns-setup.sh"
    logger -t check "或手动 opkg update && opkg install luci-app-passwall luci-app-smartdns docker"
else
    logger -t check "所有第三方软件预编译成功"
fi

exit 0
EOF
chmod +x package/base-files/files/etc/rc.local

# 预置 PassWall 手动修复脚本（如果预编译失败，可直接运行）
mkdir -p package/base-files/files/etc
cat > package/base-files/files/etc/passwall-setup.sh <<'EOF'
#!/bin/sh
echo "===== PassWall 手动修复/升级脚本（防编译失败） ====="

# 清理缓存并更新
rm -rf /var/opkg-lists/*
opkg update --force-checksum || { echo "opkg update 失败，请检查网络"; exit 1; }

# 安装/修复核心包（force 容错）
opkg install luci-app-passwall luci-i18n-passwall-zh-cn sing-box chinadns-ng v2ray-geoip v2ray-geosite \
    kmod-nft-tproxy kmod-nft-socket kmod-nft-xfrm kmod-nft-nat6 ipset resolveip kmod-tun \
    --force-checksum --force-depends || echo "部分包安装失败，继续尝试启动"

# 启用并重启服务
[ -x /etc/init.d/passwall ] && {
    /etc/init.d/passwall enable
    /etc/init.d/passwall restart
}

echo "修复完成！请检查 LuCI → Services → PassWall 2 是否正常"
EOF
chmod +x package/base-files/files/etc/passwall-setup.sh

# 预置 SmartDNS 手动修复脚本
cat > package/base-files/files/etc/smartdns-setup.sh <<'EOF'
#!/bin/sh
echo "===== SmartDNS 手动修复/安装脚本 ====="

rm -rf /var/opkg-lists/*
opkg update --force-checksum || { echo "opkg update 失败"; exit 1; }

opkg install luci-app-smartdns luci-i18n-smartdns-zh-cn smartdns \
    --force-checksum --force-depends || echo "安装失败，继续尝试启动"

[ -x /etc/init.d/smartdns ] && {
    /etc/init.d/smartdns enable
    /etc/init.d/smartdns restart
}

echo "SmartDNS 修复完成！请检查 LuCI → Services → SmartDNS"
EOF
chmod +x package/base-files/files/etc/smartdns-setup.sh

echo "最终保险优化版 3.9.2 完成！"
echo "即使编译第三方包失败，也可通过 SSH 或 LuCI 执行："
echo "  sh /etc/passwall-setup.sh"
echo "  sh /etc/smartdns-setup.sh"
echo "网页管理：http://192.168.1.2"
echo "编译前：./scripts/feeds update -a && ./scripts/feeds install -a"
echo "推荐 OpenWrt 24.10 stable 分支"
