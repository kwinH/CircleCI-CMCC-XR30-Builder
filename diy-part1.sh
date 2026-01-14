#!/bin/bash
#
# Thanks for https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (After Update feeds)
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#


# 安全设置构建目录覆盖选项
if [ -f ".config" ]; then
    # 检查配置是否已存在（包括被注释的情况）
    if grep -q "^CONFIG_BUILD_DIR_OVERRIDE=" .config; then
        # 已启用的配置，直接更新
        sed -i 's/^CONFIG_BUILD_DIR_OVERRIDE=.*/CONFIG_BUILD_DIR_OVERRIDE="\/mnt\/openwrt_build"/' .config
        echo "已更新构建目录/mnt/openwrt_build覆盖选项"
    elif grep -q "# CONFIG_BUILD_DIR_OVERRIDE is not set" .config; then
        # 被注释的配置，取消注释并设置值
        sed -i 's/^# CONFIG_BUILD_DIR_OVERRIDE is not set$/CONFIG_BUILD_DIR_OVERRIDE="\/mnt\/openwrt_build"/' .config
        echo "已启用并更新构建目录/mnt/openwrt_build覆盖选项"
    else
        # 配置不存在，添加新配置
        echo 'CONFIG_BUILD_DIR_OVERRIDE="/mnt/openwrt_build"' >> .config
        echo "已添加构建目录/mnt/openwrt_build覆盖选项"
    fi
fi

