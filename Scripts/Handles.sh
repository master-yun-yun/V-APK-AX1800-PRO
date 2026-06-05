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
# -----------------------------------------------------------
# 【终极完美版】luci-app-openvpn-server 安全修复与环境适配
# -----------------------------------------------------------
OVPNS_DIR=$(find "$GITHUB_WORKSPACE/wrt/" -maxdepth 5 -type d -path "*/luci-app-openvpn-server" 2>/dev/null | head -n 1)

if [ -n "$OVPNS_DIR" ]; then
    echo ">> 启动 luci-app-openvpn-server 终极修复方案..."
    
    # 开启严格模式：任何命令失败立刻阻断，防止带着隐患打包
    set -euo pipefail

    # 1. 极高兼容性的正则：匹配带空格、有无引号的 proto 赋值，规避 LuCI 协议变灰死锁
    find "$OVPNS_DIR" -type f \( -name "*.lua" -o -name "*.sh" \) -exec sh -c '
        for file do
            sed -i "s/\(network\.[a-zA-Z0-9_]*\.proto\)[[:space:]]*=[[:space:]]*['\''\"]\?[a-zA-Z0-9_]*['\''\"]\?/\1='\''none'\''/g" "$file"
        done
    ' sh {} +

    # 2. 生成安全、幂等、全动态解析的 UCI 初始化脚本
    mkdir -p "$OVPNS_DIR/root/etc/uci-defaults"
    
    cat << 'EOF' > "$OVPNS_DIR/root/etc/uci-defaults/99-fix-openvpn-firewall"
#!/bin/sh

# 【防呆机制】置于系统根目录的标记文件，确保仅执行一次
[ -f "/etc/.ovpn_patch_applied" ] && exit 0

# 【时序自洽】如果 openvpn 配置尚未生成，跳过本次执行，等待依赖插件先创建
if ! uci show openvpn 2>/dev/null | grep -q "=openvpn"; then
    exit 0
fi

# 【动态截获一】准确寻找 lan 区域的 UCI 索引
LAN_ZONE=$(uci show firewall | awk -F. '/=zone/{split($2,a,"[\\[\\]]"); idx=a[2]} /name='\''lan'\''/{if(idx!="") print "@zone["idx"]"}' | head -n 1)

# 【动态截获二】区分配置节名与接口名，优先获取 dev 虚拟设备参数
OVPN_CFG=$(uci show openvpn 2>/dev/null | awk -F[.=] '/=openvpn/{print $2; exit}')
OVPN_IFACE=$(uci get openvpn."$OVPN_CFG".dev 2>/dev/null || true)
OVPN_IFACE=${OVPN_IFACE:-$OVPN_CFG}

# 绑定网卡至防火墙
if [ -n "$LAN_ZONE" ] && [ -n "$OVPN_IFACE" ]; then
    if ! uci show firewall."$LAN_ZONE".network | grep -q "$OVPN_IFACE"; then
        uci add_list firewall."$LAN_ZONE".network="$OVPN_IFACE"
        uci commit firewall
    fi
fi

# 【绝对精准匹配】放行 1194 端口
if ! uci show firewall | grep -q "\.name='Allow-OpenVPN'$"; then
    uci add firewall rule
    uci set firewall.@rule[-1].name='Allow-OpenVPN'
    uci set firewall.@rule[-1].src='wan'
    uci set firewall.@rule[-1].target='ACCEPT'
    uci set firewall.@rule[-1].proto='udp'
    uci set firewall.@rule[-1].dest_port='1194'
    uci commit firewall
fi

# 写入执行成功标记，形成闭环
touch /etc/.ovpn_patch_applied
exit 0
EOF

    # 赋予执行权限并恢复非严格模式，保障后续 Actions 其他编译环节不受影响
    chmod +x "$OVPNS_DIR/root/etc/uci-defaults/99-fix-openvpn-firewall"
    set +euo pipefail
    
    echo ">> luci-app-openvpn-server 修复完毕：动态截获与安全防护已全面就绪！"
fi
# --------------------------以上2026.06.06---------------------------------#
