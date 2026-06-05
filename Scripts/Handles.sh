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

#-------------以下===============2026.06.05=============----------#
# 彻底修复 luci-app-openvpn-server 协议报错及深度设备冲突 (终极安全版)
OVPNS_FILE=$(find ./ -maxdepth 4 -type f -path "*/luci-app-openvpn-server/root/etc/init.d/openvpn-server")
if [ -f "$OVPNS_FILE" ]; then
	echo "Fixing openvpn-server network interface proto and device..."

	# 1. 兼容性协议修复：强制替换为 none (不配置协议)
	sed -i -E "s/network\.myvpn\.proto=['\"]?(ovpn|openvpn)['\"]?/network.myvpn.proto='none'/g" "$OVPNS_FILE"

	# 2. 终极设备防冲突：使用专属名称 tun-ovpn，彻底杜绝与 OpenClash/Passwall 等插件抢夺 tun0/tun1
	sed -i -E "s/network\.myvpn\.device=['\"]?tun0['\"]?/network.myvpn.device='tun-ovpn'/g" "$OVPNS_FILE"

	# 3. 同步修改 OpenVPN 进程自身的配置选项
	sed -i -E "s/option dev ['\"]?tun0['\"]?/option dev 'tun-ovpn'/g" "$OVPNS_FILE"

	echo "openvpn-server interface and device have been completely fixed!"
fi

# 4. 暴力排查并修复该插件目录下所有可能硬编码 tun0 的文件（如防火墙、LuCI 界面默认值）
OVPNS_DIR=$(find ./ -maxdepth 4 -type d -path "*/luci-app-openvpn-server" | head -n 1)
if [ -n "$OVPNS_DIR" ]; then
	echo "Scanning and fixing hardcoded tun0 in openvpn-server firewall/luci files..."
	find "$OVPNS_DIR" -type f -exec grep -l "tun0" {} + | while read -r file; do
		sed -i "s/tun0/tun-ovpn/g" "$file"
		echo "  -> Fixed hardcoded tun0 in: $file"
	done
fi

# 自动将 OpenVPN 接口加入 LAN 防火墙区域，解决无法访问管理页面的问题
mkdir -p ./package/base-files/files/etc/uci-defaults/
cat << 'EOF' > ./package/base-files/files/etc/uci-defaults/99-openvpn-firewall
#!/bin/sh

# 检查防火墙配置中是否存在 myvpn 接口，如果不存在则将其加入 lan 区域的涵盖网络中
if ! uci show firewall.@zone[0].network | grep -q 'myvpn'; then
    uci add_list firewall.@zone[0].network='myvpn'
    uci commit firewall
fi

exit 0
EOF
# 赋予执行权限
chmod +x ./package/base-files/files/etc/uci-defaults/99-openvpn-firewall
echo "OpenVPN firewall auto-binding script added!"
#-------------以上===============2026.06.05=============----------#
