#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
	echo " "

	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	rm -rf ./$HP_PATH/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi

#修改argon主题字体和颜色
if [ -d *"luci-theme-argon"* ]; then
	echo " " && cd ./luci-theme-argon/

	sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon

	cd $PKG_PATH && echo "theme-argon has been fixed!"
fi

#修改aurora菜单式样
if [ -d *"luci-app-aurora-config"* ]; then
	echo " " && cd ./luci-app-aurora-config/

	sed -i "s/nav_submenu_type '.*'/nav_submenu_type 'boxed-dropdown'/g" $(find ./root/usr/share/aurora/ -type f -name "*.template")

	cd $PKG_PATH && echo "theme-aurora has been fixed!"
fi

#修改mini-diskmanager菜单位置
if [ -d *"luci-app-mini-diskmanager"* ]; then
	echo " " && cd ./luci-app-mini-diskmanager/

	sed -i "s/services/system/g" ./luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json

	cd $PKG_PATH && echo "mini-diskmanager has been fixed!"
fi

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	echo " "

	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "

	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

	cd $PKG_PATH && echo "rust has been fixed!"
fi

# -----------------------------------------------------------
# 彻底修复 APK 包管理器对版本号格式的严格校验
# -----------------------------------------------------------
echo "正在修复不规范的软件包版本号为 apk 兼容格式(点号分隔)..."

# 1. 批量修复包含日期后缀的版本号（将连字符 - 或下划线 _ 均替换为点号 . ）
# 效果：1.0.2-20240822 或 1.0.2_20240822 -> 1.0.2.20240822
find ./ -name "Makefile" -exec sed -i 's/PKG_VERSION:=\(.*\)-\(20[0-9]\{2\}[0-9]\{4\}\)/PKG_VERSION:=\1.\2/g' {} +
find ./ -name "Makefile" -exec sed -i 's/PKG_VERSION:=\(.*\)_\(20[0-9]\{2\}[0-9]\{4\}\)/PKG_VERSION:=\1.\2/g' {} +
# 先所有Makefile批量修多余“-r1-r1”为“-r1”
find ./ -name "Makefile" -exec sed -i 's/\(PKG_VERSION:=.*\)-r\([0-9]\+\)-r\2/\1-r\2/g' {} +
find ./ -name "Makefile" -exec sed -i 's/\(PKG_VERSION.*:=.*\)-r1-*\(r1\|r2\|r[0-9]\{1,2\}\)/\1-r1/g' {} +

# 2. 针对性修复 luci-app-memos，强制使用点号格式
find ./ -name "Makefile" -path "*/luci-app-memos/*" -exec sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=1.0.2.20240822/g' {} +

# 3. 针对性修复 luci-app-sunpanel，去除多余后缀
find ./ -name "Makefile" -path "*/luci-app-sunpanel/*" -exec sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=1.0.0/g' {} +

# 4. 针对性修复 luci-app-pushbot，去除多余后缀
find ./ -name "Makefile" -path "*/luci-app-pushbot/*" -exec sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=1.0.0/g' {} +

# 4. 针对性修复 luci-app-istoreenhance，去除多余后缀
find ./ -name "Makefile" -path "*/luci-app-istoreenhance/*" -exec sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=0.6.6/g' {} +

echo "APK 兼容版本号修复完成！"

# --------------------------以下2026.06.06---------------------------------#
# 【终极防线】全方位无死角修复 luci-app-openvpn-server
# -----------------------------------------------------------
# 1. 采用绝对路径，涵盖 package 和 feeds 所有可能存在的目录
OVPNS_DIR=$(find "$GITHUB_WORKSPACE/wrt/" -type d -path "*/luci-app-openvpn-server" | head -n 1)

if [ -n "$OVPNS_DIR" ]; then
    echo ">> 正在启动全方位核查，实施 luci-app-openvpn-server 核弹级修复..."

    # -----------------------------------------------------------
    # 第一层：静态文件正则清洗（解决设备抢占与协议死锁）
    # -----------------------------------------------------------
    # 统一替换所有的 tun0, tun, 'tun0', "tun" 等各种奇怪的硬编码为专属的 tun-ovpn
    find "$OVPNS_DIR" -type f -exec sed -i -E "s/(dev|device)[[:space:]]+['\"]?tun[0-9]*['\"]?/\1 'tun-ovpn'/g" {} +
    find "$OVPNS_DIR" -type f -exec sed -i -E "s/option dev ['\"]?tun[0-9]*['\"]?/option dev 'tun-ovpn'/g" {} +
    
    # 修复 LuCI 界面协议变灰（锁定为系统原生 none 协议）
    find "$OVPNS_DIR" -type f -exec sed -i -E "s/proto[[:space:]]*=[[:space:]]*['\"]?(ovpn|openvpn)['\"]?/proto='none'/g" {} +
    find "$OVPNS_DIR" -type f -exec sed -i -E "s/option proto ['\"]?(ovpn|openvpn)['\"]?/option proto 'none'/g" {} +

    # 粗筛删除可见的 secret 毒药代码
    find "$OVPNS_DIR" -type f -exec sed -i '/secret.*static\.key/d' {} +
    find "$OVPNS_DIR" -type f -exec sed -i '/option secret/d' {} +

    # -----------------------------------------------------------
    # 第二层：运行时自愈守卫（解决 TLS 证书漏写与互斥崩溃）
    # -----------------------------------------------------------
    # 寻找插件中所有可能生成 server.conf 的 shell 脚本
    find "$OVPNS_DIR" -type f -name "*.sh" -o -path "*/init.d/*" | while read -r SH_FILE; do
        # 只要该脚本涉及操作 server.conf，就在其末尾强行注入“自愈守护进程”
        if grep -q "server.conf" "$SH_FILE"; then
            cat << 'EOF' >> "$SH_FILE"

# 【系统级自愈补丁】在进程启动前最后把关，确保配置文件绝对健康
if [ -f "/etc/openvpn/server.conf" ]; then
    # 1. 如果插件漏写了 TLS 证书，强制补齐
    grep -q "ca /etc/openvpn/pki/ca.crt" /etc/openvpn/server.conf || echo "ca /etc/openvpn/pki/ca.crt" >> /etc/openvpn/server.conf
    grep -q "cert /etc/openvpn/pki/server.crt" /etc/openvpn/server.conf || echo "cert /etc/openvpn/pki/server.crt" >> /etc/openvpn/server.conf
    grep -q "key /etc/openvpn/pki/server.key" /etc/openvpn/server.conf || echo "key /etc/openvpn/pki/server.key" >> /etc/openvpn/server.conf
    grep -q "dh /etc/openvpn/pki/dh.pem" /etc/openvpn/server.conf || echo "dh /etc/openvpn/pki/dh.pem" >> /etc/openvpn/server.conf
    
    # 2. 如果插件在运行时又偷偷生成了废弃的 secret 参数，强制处决
    sed -i '/secret/d' /etc/openvpn/server.conf
    
    # 3. 确保底层设备绝对是 tun-ovpn
    sed -i -E 's/^dev tun[0-9]*$/dev tun-ovpn/g' /etc/openvpn/server.conf
fi
EOF
        fi
    done

    # -----------------------------------------------------------
    # 第三层：网络与防火墙接管（解决无法连入及管理界面阻断）
    # -----------------------------------------------------------
    # 创建 OpenWrt 首次开机执行脚本
    mkdir -p "$OVPNS_DIR/root/etc/uci-defaults"
    cat << 'EOF' > "$OVPNS_DIR/root/etc/uci-defaults/99-fix-openvpn-firewall"
#!/bin/sh

# 1. 自动将专属虚拟网卡 tun-ovpn 加入 lan 区域，解决 VPN 连上却打不开后台的问题
if ! uci show firewall.@zone[0].network | grep -q 'tun-ovpn'; then
    uci add_list firewall.@zone[0].network='tun-ovpn'
    uci commit firewall
fi

# 2. 自动在外部防火墙撕开 1194 端口的口子，允许客户端从外网拨号进入
if ! uci show firewall | grep -q 'Allow-OpenVPN'; then
    uci add firewall rule
    uci set firewall.@rule[-1].name='Allow-OpenVPN'
    uci set firewall.@rule[-1].src='wan'
    uci set firewall.@rule[-1].target='ACCEPT'
    uci set firewall.@rule[-1].proto='udp'
    uci set firewall.@rule[-1].dest_port='1194'
    uci commit firewall
fi

exit 0
EOF
    # 赋予执行权限
    chmod +x "$OVPNS_DIR/root/etc/uci-defaults/99-fix-openvpn-firewall"

    echo ">> luci-app-openvpn-server 核弹级修复完成，安全防护已拉满！"
fi
# --------------------------以上2026.06.06---------------------------------#
