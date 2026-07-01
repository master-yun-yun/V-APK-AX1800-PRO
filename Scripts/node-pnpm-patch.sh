#!/bin/bash
# 修复 node-pnpm 因上游文件布局变化导致的 cp 失败
# 适用于 OpenWrt/ImmortalWrt 编译环境

set -e

FILE="package/feeds/packages/node-pnpm/Makefile"
if [ ! -f "$FILE" ]; then
    echo "node-pnpm Makefile not found, skipping patch."
    exit 0
fi

# 删除旧的 Host/Install 块
sed -i '/^define Host\/Install/,/^endef/d' "$FILE"

TAB=$(printf '\t')

{
    echo "define Host/Install"
    echo "${TAB}\$(INSTALL_DIR) \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist"
    echo "${TAB}if [ -f \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/dist/pnpm.cjs ]; then \\"
    echo "${TAB}${TAB}cp -a \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/dist/pnpm.cjs \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/ ;\\"
    echo "${TAB}${TAB}cp -a \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/dist/worker.js \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/ 2>/dev/null || true ;\\"
    echo "${TAB}elif [ -f \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/bin/pnpm.cjs ]; then \\"
    echo "${TAB}${TAB}cp -a \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/bin/pnpm.cjs \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/pnpm.cjs ;\\"
    echo "${TAB}elif [ -f \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/pnpm.cjs ]; then \\"
    echo "${TAB}${TAB}cp -a \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/pnpm.cjs \$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/pnpm.cjs ;\\"
    echo "${TAB}else \\"
    echo "${TAB}${TAB}echo \"ERROR: pnpm build artifacts not found\"; \\"
    echo "${TAB}${TAB}ls -la \$(BUILD_DIR)/node-pnpm-\$(PKG_VERSION)/ ;\\"
    echo "${TAB}${TAB}exit 1 ;\\"
    echo "${TAB}fi"
    echo "endef"
} >> "$FILE"

echo "node-pnpm Makefile patched successfully."
