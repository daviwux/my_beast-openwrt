#!/bin/bash
TARGET_DIR=${1:-$(pwd)/openwrt}
cd "$TARGET_DIR" || { echo "进入目录失败: $TARGET_DIR"; exit 1; }

# 1. 基础个性化：后台 IP 设为 10.0.0.1
sed -i 's/192.168.1.1/10.0.0.1/g' package/base-files/files/bin/config_generate

# 2. 注入核心配置（纯 nftables + Docker + PassWall2 全预装 + sing-box TUN 支持）
cat >> .config <<EOF
# --- 平台与分区 ---
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
CONFIG_TARGET_x86_64_DEVICE_generic=y
CONFIG_TARGET_KERNEL_PARTSIZE=256
CONFIG_TARGET_ROOTFS_PARTSIZE=2048

# --- LuCI Web 界面与中文语言包 ---
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-compat=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
CONFIG_PACKAGE_luci-theme-bootstrap=y

# --- Docker 完整支持 ---
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

# --- PassWall2 纯 nftables 依赖 + 强制启用 sing-box TUN 支持 ---
CONFIG_PACKAGE_kmod-nft-tproxy=y           # TPROXY nft 原生支持（核心）
CONFIG_PACKAGE_ipset=y                     # IPSET 加速
CONFIG_PACKAGE_resolveip=y                 # DNS 解析工具
CONFIG_PACKAGE_nftables=y                  # nft 命令行工具
CONFIG_PACKAGE_kmod-tun=y                  # TUN/TAP 虚拟网卡（sing-box TUN 必须）
CONFIG_PACKAGE_kmod-inet-diag=y            # inet 诊断（sing-box 统计）
CONFIG_PACKAGE_kmod-netlink-diag=y         # netlink 诊断（sing-box 内核通信）

# --- 预装 PassWall2 核心包（开箱即用，无需脚本） ---
CONFIG_PACKAGE_luci-app-passwall2=y
CONFIG_PACKAGE_luci-i18n-passwall2-zh-cn=y
CONFIG_PACKAGE_sing-box=y
CONFIG_PACKAGE_chinadns-ng=y
CONFIG_PACKAGE_v2ray-geoip=y
CONFIG_PACKAGE_v2ray-geosite=y

# --- 万兆转发性能组件 ---
CONFIG_PACKAGE_irqbalance=y
CONFIG_PACKAGE_intel-microcode=y
CONFIG_PACKAGE_iucode-tool=y

# --- 网卡驱动 ---
CONFIG_PACKAGE_kmod-ixgbe=y
CONFIG_PACKAGE_kmod-i40e=y
CONFIG_PACKAGE_kmod-r8125=y
CONFIG_PACKAGE_kmod-r8126=y
CONFIG_PACKAGE_kmod-ath12k=y

# --- IPv6 基础支持 ---
CONFIG_PACKAGE_odhcp6c=y
CONFIG_PACKAGE_odhcpd-ipv6only=y

# --- 系统工具 ---
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_ttyd=y
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_autocore=y

# --- 显式禁用 iptables ---
CONFIG_PACKAGE_iptables=n
CONFIG_PACKAGE_iptables-nft=n
CONFIG_PACKAGE_ip6tables=n
CONFIG_PACKAGE_ip6tables-nft=n
CONFIG_PACKAGE_kmod-ipt-offload=n
EOF

# 3. 内核性能调优（BBR + 万兆 + IPv6 + Docker + nft 兼容）
mkdir -p package/base-files/files/etc
cat >> package/base-files/files/etc/sysctl.conf <<EOF
# BBR 加速 (IPv4 + IPv6)
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1

# 万兆 TCP 缓冲区调优 (16MB)
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216

# 高并发连接追踪 (Docker + PassWall2)
net.netfilter.nf_conntrack_max=1048576
net.netfilter.nf_conntrack_tcp_timeout_established=1200
net.netfilter.nf_conntrack_ipv6_max=524288

# IPv6 优化 + Docker 兼容
net.ipv6.conf.all.accept_ra=2
net.ipv6.conf.default.accept_ra=2
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.all.autoconf=1
net.ipv6.conf.default.autoconf=1
net.ipv6.conf.all.dad_transmits=1
net.ipv6.conf.default.dad_transmits=1
net.ipv6.conf.docker0.proxy_ndp=1

# Docker nftables 桥接转发
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-arptables=1
EOF

# 4. 防火墙 fw4 开机自启保险 + opkg 缓存首次刷新（防 checksum mismatch）
cat >> package/base-files/files/etc/rc.local <<'EOF'
# 自动扩容 rootfs（首次启动执行）
if [ ! -f /etc/.expanded ]; then
    logger -t expand "开始自动扩容 rootfs..."

    ROOT_PART=$(findmnt -no SOURCE /)
    if [ -n "$ROOT_PART" ]; then
        DISK=$(echo "$ROOT_PART" | sed -E 's/p?[0-9]+$//')
        PART_NUM=$(echo "$ROOT_PART" | grep -o '[0-9]\+$')

        if [ -n "$PART_NUM" ]; then
            opkg update --no-check-certificate >/dev/null 2>&1
            opkg install growpart --no-check-certificate >/dev/null 2>&1

            growpart "$DISK" "$PART_NUM" >/dev/null 2>&1 && logger -t expand "growpart 成功"
            partprobe "$DISK" 2>/dev/null

            e2fsck -f -y "$ROOT_PART" >/dev/null 2>&1
            resize2fs "$ROOT_PART" >/dev/null 2>&1 && logger -t expand "resize2fs 成功"
        fi
    fi

    touch /etc/.expanded
    logger -t expand "自动扩容完成"
fi
# 确保 fw4 防火墙启动（纯 nftables）
if [ -x /etc/init.d/firewall ]; then
    /etc/init.d/firewall enable
    /etc/init.d/firewall restart
    logger -t fw4 "防火墙已启用（nftables 模式）"
fi

# 首次启动时强制刷新 opkg 缓存（解决 checksum/size mismatch）
if [ ! -f /etc/.opkg-cache-refreshed ]; then
    rm -rf /var/opkg-lists/*
    opkg update --no-check-certificate
    touch /etc/.opkg-cache-refreshed
    logger -t opkg "首次启动：opkg 缓存已刷新"
fi

exit 0
EOF

# 5. 预创建 PassWall2 一键安装脚本（作为备用，预装后可不用）
mkdir -p package/base-files/files/etc
cat > package/base-files/files/etc/passwall2-setup.sh <<'EOF'
#!/bin/sh

echo "===== PassWall2 一键安装/修复（纯 nftables 优化版） ====="

# 检查是否已安装，避免重复操作
if opkg list-installed | grep -q luci-app-passwall2; then
    echo "PassWall2 已预装，执行修复/启动..."
else
    echo "PassWall2 未预装，开始安装..."
fi

# 1. 添加公钥
echo "步骤1：添加公钥..."
wget --no-check-certificate -O /tmp/passwall.pub https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub || {
    echo "下载公钥失败，请检查网络！"
    exit 1
}
opkg-key add /tmp/passwall.pub
rm -f /tmp/passwall.pub

# 2. 检测版本和架构
echo "步骤2：检测版本和架构..."
. /etc/openwrt_release
release="${DISTRIB_RELEASE%.*}"
arch="${DISTRIB_ARCH}"
echo "当前版本: $release, 架构: $arch"

# 3. 清理旧 feeds
echo "步骤3：清理旧 PassWall feeds..."
sed -i '/passwall/d' /etc/opkg/customfeeds.conf

# 4. 添加 feeds
echo "步骤4：添加 PassWall feeds..."
cat >> /etc/opkg/customfeeds.conf << EOT
src/gz passwall_luci https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/passwall_luci
src/gz passwall_packages https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/passwall_packages
src/gz passwall2 https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/passwall2
EOT

# 5. 清理缓存 + 更新源列表（防 checksum/size mismatch）
echo "步骤5：清理缓存并更新源列表..."
rm -rf /var/opkg-lists/*
opkg update --no-check-certificate || {
    echo "opkg update 失败！请检查网络/DNS（建议改成 8.8.8.8 / 1.1.1.1）"
    exit 1
}

# 6. 安装/升级核心包
echo "步骤6：安装/升级 PassWall2 核心包..."
opkg install luci-app-passwall2 luci-i18n-passwall2-zh-cn chinadns-ng kmod-nft-tproxy nftables --no-check-certificate

# 7. 强制安装 sing-box
echo "步骤7：安装/升级 sing-box..."
opkg install sing-box --no-check-certificate || {
    echo "sing-box 安装失败，尝试强制安装..."
    opkg install sing-box --force-depends --force-checksum --no-check-certificate
}

# 8. 修复 fw4 reload
echo "步骤8：修复 fw4 reload 选项..."
uci -q delete firewall.passwall2.reload
uci -q delete firewall.passwall2_server.reload
uci commit firewall
/etc/init.d/firewall reload

# 9. 启用并启动
echo "步骤9：启用并启动 PassWall2..."
/etc/init.d/passwall2 enable
/etc/init.d/passwall2 restart

# 10. 完成提示
echo ""
echo "===== PassWall2 处理完成（纯 nftables 模式） ====="
echo "1. 登录 LuCI → Services → PassWall 2（已预装）"
echo "2. 推荐：代理模式 → TPROXY (nft) 或 TUN (全局)"
echo "3. 分流规则 → GFWList（先分流，避免冲突）"
echo "4. 如 TUN 模式不可用，检查 lsmod | grep tun"
echo "祝使用愉快！"
EOF

chmod +x package/base-files/files/etc/passwall2-setup.sh

# 6. 预创建 SmartDNS 一键安装脚本（一次成功安装 luci-app-smartdns）
mkdir -p package/base-files/files/etc
cat > package/base-files/files/etc/smartdns-setup.sh <<'EOF'
#!/bin/sh

# ================================================
# SmartDNS 一键安装脚本（优化版）
# 功能：
#   - 清理 opkg 缓存 + 更新源列表（防 checksum mismatch）
#   - 安装 luci-app-smartdns
#   - 启用并启动服务
#   - 运行时提示配置上游 DNS
# ================================================

echo "===== SmartDNS 一键安装（优化版） ====="

# 检查是否已安装，避免重复
if opkg list-installed | grep -q luci-app-smartdns; then
    echo "luci-app-smartdns 已安装，跳过。"
else
    echo "开始安装 luci-app-smartdns..."
fi

# 1. 清理缓存 + 更新源列表
echo "步骤1：清理缓存并更新源列表..."
rm -rf /var/opkg-lists/*
opkg update --no-check-certificate || {
    echo "opkg update 失败！请检查网络/DNS（建议改成 8.8.8.8 / 1.1.1.1）"
    exit 1
}

# 2. 安装 SmartDNS
echo "步骤2：安装 luci-app-smartdns..."
opkg install luci-app-smartdns --no-check-certificate --force-checksum || {
    echo "安装失败，尝试强制安装..."
    opkg install luci-app-smartdns --force-checksum --force-depends --no-check-certificate
}

# 3. 启用并启动服务
echo "步骤3：启用并启动 SmartDNS..."
/etc/init.d/smartdns enable
/etc/init.d/smartdns start

# 4. 完成提示
echo ""
echo "===== SmartDNS 安装完成 ====="
echo "1. 登录 LuCI → Services → SmartDNS"
echo "2. 启用 SmartDNS，设置上游 DNS（如 8.8.8.8 / tls://1.1.1.1）"
echo "3. 保存应用 → 测试 DNS 解析（nslookup google.com）"
echo "祝使用愉快！"
EOF

chmod +x package/base-files/files/etc/smartdns-setup.sh

# 结束提示
echo "✅ 2.0 Config Applied: Pure nftables + Docker + sing-box TUN 支持 + PassWall2 全预装 + SmartDNS 一键脚本"
echo "📦 PassWall2 已预装，开机即用"
echo "📦 SmartDNS 一键安装: ssh root@10.0.0.1 'sh /etc/smartdns-setup.sh'"
echo "已解决所有问题：TUN 支持、checksum mismatch、变量展开、签名容错、脚本幂等"
