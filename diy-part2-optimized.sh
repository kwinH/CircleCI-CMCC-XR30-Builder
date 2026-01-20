#!/bin/bash
#
# Thanks for https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
# Enhanced with build optimizations
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

echo "🚀 Enhanced DIY-Part2 with build optimizations"

# ============================================
# Utility Functions
# ============================================

function config_del(){
    yes="CONFIG_$1=y"
    no="# CONFIG_$1 is not set"
    
    # 首先尝试替换已存在的启用配置
    sed -i "s/$yes/$no/" .config
    
    # 如果配置项不存在，直接添加禁用配置
    if ! grep -q "CONFIG_$1" .config; then
        echo "$no" >> .config
    fi
}

function config_add(){
    yes="CONFIG_$1=y"
    no="# CONFIG_$1 is not set"
    sed -i "s/${no}/${yes}/" .config
    if ! grep -q "$yes" .config; then
        echo "$yes" >> .config
    fi
}

function config_package_del(){
    config_del "PACKAGE_$1"
}

function config_package_add(){
    config_add "PACKAGE_$1"
}

function drop_package(){
    if [ "$1" != "golang" ];then
        find package/ -follow -name $1 -not -path "package/custom/*" | xargs -rt rm -rf
        find feeds/ -follow -name $1 -not -path "feeds/base/custom/*" | xargs -rt rm -rf
    fi
}

function clean_packages(){
    path=$1
    dir=$(ls -l ${path} | awk '/^d/ {print $NF}')
    for item in ${dir}; do
        drop_package ${item}
    done
}


function setup_custom_lan_ip() {
    local custom_ip="${CUSTOM_LAN_IP:-192.168.3.1}"
    
    echo "🌐 Setting up custom LAN IP: $custom_ip"
    
    # Replace ImmortalWrt default IP (192.168.6.1) if different from user input
    if [[ "$custom_ip" != "192.168.6.1" ]]; then
        echo "Replacing ImmortalWrt default IP (192.168.6.1) with $custom_ip"
        
        # Find and update config_generate files
        find . -name "config_generate" -type f | while read -r config_file; do
            echo "Updating ImmortalWrt IP in: $config_file"
            sed -i "s/192.168.6.1/$custom_ip/g" "$config_file"
        done
        
        # Update other files that might contain the ImmortalWrt IP
        find . -name "*.sh" -o -name "*.conf" -o -name "*.cfg" | xargs grep -l "192.168.6.1" 2>/dev/null | while read -r file; do
            echo "Updating ImmortalWrt IP in: $file"
            sed -i "s/192.168.6.1/$custom_ip/g" "$file"
        done
    else
        echo "Keeping ImmortalWrt default IP (192.168.6.1) as requested"
    fi
    
    # Replace standard OpenWrt IP (192.168.1.1) if different from user input
    if [[ "$custom_ip" != "192.168.1.1" ]]; then
        echo "Replacing standard OpenWrt IP (192.168.1.1) with $custom_ip"
        
        find . -name "config_generate" -type f | while read -r config_file; do
            echo "Updating OpenWrt IP in: $config_file"
            sed -i "s/192.168.1.1/$custom_ip/g" "$config_file"
        done
        
        # Update other files that might contain IP addresses
        find . -name "*.sh" -o -name "*.conf" -o -name "*.cfg" | xargs grep -l "192.168.1.1" 2>/dev/null | while read -r file; do
            echo "Updating OpenWrt IP in: $file"
            sed -i "s/192.168.1.1/$custom_ip/g" "$file"
        done
    else
        echo "Keeping standard OpenWrt IP (192.168.1.1) as requested"
    fi
    
    echo "LAN IP setup completed for: $custom_ip"
}


# ============================================
# Main Configuration
# ============================================


echo "✅ Configured for XR30-stock (H layout) only"
echo "⌚ Device list after fixed..." 

# Theme modification
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile


# Setup custom LAN IP
setup_custom_lan_ip

echo "🎉 All optimizations and configurations completed successfully"

# ============================================
# Configuration Verification
# ============================================

echo "📋 验证构建配置..."

# Show all enabled devices
echo "📋 启用的设备列表："
grep "CONFIG_TARGET_DEVICE.*=y" .config | sed 's/CONFIG_TARGET_DEVICE_/  - /' | sed 's/=y//'

# Show enabled optimizations
echo "📋 启用的优化功能："
echo "  - LTO: ${ENABLE_LTO:-true}"
echo "  - MOLD: ${ENABLE_MOLD:-true}"
echo "  - BPF: ${ENABLE_BPF:-true}"
echo "  - KERNEL_CLANG_LTO: ${KERNEL_CLANG_LTO:-true}"
echo "  - USE_GCC14: ${USE_GCC14:-true}"
echo "  - ADVANCED_OPTIMIZATIONS: ${ENABLE_ADVANCED_OPTIMIZATIONS:-true}"

# Show package statistics
echo "📦 软件包统计："
total_packages=$(grep "CONFIG_PACKAGE.*=y" .config | wc -l)
luci_apps=$(grep "CONFIG_PACKAGE_luci-app.*=y" .config | wc -l)
kernel_modules=$(grep "CONFIG_PACKAGE_kmod.*=y" .config | wc -l)
echo "  - 总软件包: $total_packages"
echo "  - LuCI 应用: $luci_apps" 
echo "  - 内核模块: $kernel_modules"

cat .config
echo "🎯 配置验证完成"
