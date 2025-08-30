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

# Build optimization notice
echo "🚀 Enhanced DIY-Part2 with build optimizations"

function config_del(){
    yes="CONFIG_$1=y"
    no="# CONFIG_$1 is not set"

    sed -i "s/$yes/$no/" .config
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
    package="PACKAGE_$1"
    config_del $package
}

function config_package_add(){
    package="PACKAGE_$1"
    config_add $package
}

function drop_package(){
    if [ "$1" != "golang" ];then
        # feeds/base -> package
        find package/ -follow -name $1 -not -path "package/custom/*" | xargs -rt rm -rf
        find feeds/ -follow -name $1 -not -path "feeds/base/custom/*" | xargs -rt rm -rf
    fi
}

function clean_packages(){
    path=$1
    dir=$(ls -l ${path} | awk '/^d/ {print $NF}')
    for item in ${dir}
        do
            drop_package ${item}
        done
}

function config_device_del(){
    device="TARGET_DEVICE_$1"
    packages="TARGET_DEVICE_PACKAGES_$1"

    packages_list="CONFIG_TARGET_DEVICE_PACKAGES_$1="""    
    deleted_packages_list="# CONFIG_TARGET_DEVICE_PACKAGES_$1 is not set"

    config_del $device
    sed -i "s/$packages_list/$deleted_packages_list/" .config
}

function config_device_list(){
    grep -E 'CONFIG_TARGET_DEVICE_|CONFIG_TARGET_DEVICE_PACKAGES_' .config | while read -r line; do
        if [[ $line =~ CONFIG_TARGET_DEVICE_([^=]+)=y ]]; then
            chipset_device=${BASH_REMATCH[1]}
            chipset=${chipset_device%_DEVICE_*}
            device=${chipset_device#*_DEVICE_}
            echo "Chipset: $chipset, Model: $device"
        fi
    done | sort -u
}

function config_device_keep_only(){
    local keep_devices=("$@")
    grep -E 'CONFIG_TARGET_DEVICE_|CONFIG_TARGET_DEVICE_PACKAGES_' .config | while read -r line; do
        if [[ $line =~ CONFIG_TARGET_DEVICE_([^=]+)=y ]]; then
            chipset_device=${BASH_REMATCH[1]}
            device=${chipset_device#*_DEVICE_}
            if [[ ! " ${keep_devices[@]} " =~ " ${device} " ]]; then
                config_device_del $chipset_device
            fi
        fi
    done
}

config_device_list

config_device_keep_only "cmcc_xr30"

config_device_del "cmcc_xr30-emmc"

# Modify default theme
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Delete unwanted packages
config_package_del luci-app-ssr-plus_INCLUDE_NONE_V2RAY
config_package_del luci-app-ssr-plus_INCLUDE_Shadowsocks_NONE_Client
config_package_del luci-app-ssr-plus_INCLUDE_ShadowsocksR_NONE_Server
config_package_del luci-theme-bootstrap-mod

# # Add custom packages

## Web Terminal
config_package_add luci-app-ttyd
# ## IP-Mac Binding
# config_package_add luci-app-arpbind
# ## Wake on Lan
# config_package_add luci-app-wol
# ## QR Code Generator
# config_package_add qrencode
# ## Zsh
# config_package_add zsh
# ## Temporarily disable USB3.0
# config_package_add luci-app-usb3disable
# ## USB
# # config_package_add kmod-usb-net-huawei-cdc-ncm
# config_package_add kmod-usb-net-ipheth
# config_package_add kmod-usb-net-aqc111
# config_package_add kmod-usb-net-rtl8152-vendor
# config_package_add kmod-usb-net-sierrawireless
# config_package_add kmod-usb-storage
# config_package_add kmod-usb-ohci
# config_package_add kmod-usb-uhci
# config_package_add usb-modeswitch
# config_package_add sendat
## bbr
config_package_add kmod-tcp-bbr
# ## coremark cpu 跑分
# config_package_add coremark
# ## autocore + lm-sensors-detect： cpu 频率、温度
# config_package_add autocore
# config_package_add lm-sensors-detect
# ## autoreboot
# config_package_add luci-app-autoreboot
# ## 多拨
# config_package_add kmod-macvlan
# config_package_add mwan3
# config_package_add luci-app-mwan3
# # ## frpc
# # config_package_add luci-app-frpc
# ## mosdns
# config_package_add luci-app-mosdns
## curl
config_package_add curl
## netcat
config_package_add netcat
# ## disk
# # config_package_add gdisk
# # config_package_add sgdisk


# # Third-party packages
# mkdir -p package/custom
# git clone --depth 1  https://github.com/217heidai/OpenWrt-Packages.git package/custom
# clean_packages package/custom

# ## golang
# rm -rf feeds/packages/lang/golang
# mv package/custom/golang feeds/packages/lang/

# ## Passwall
# config_package_add luci-app-passwall
# config_package_add luci-app-passwall_Nftables_Transparent_Proxy
# config_package_del luci-app-passwall_Iptables_Transparent_Proxy
# config_package_del luci-app-passwall_INCLUDE_Shadowsocks_Libev_Client
# config_package_del luci-app-passwall_INCLUDE_Shadowsocks_Libev_Server
# config_package_del luci-app-passwall_INCLUDE_Shadowsocks_Rust_Client
# config_package_del luci-app-passwall_INCLUDE_Shadowsocks_Rust_Server
# config_package_del luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Client
# config_package_del luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Server
# config_package_del luci-app-passwall_INCLUDE_Trojan_Plus
# config_package_del luci-app-passwall_INCLUDE_Simple_Obfs
# config_package_del luci-app-passwall_INCLUDE_tuic_client


# ## 定时任务。重启、关机、重启网络、释放内存、系统清理、网络共享、关闭网络、自动检测断网重连、MWAN3负载均衡检测重连、自定义脚本等10多个功能
# config_package_add luci-app-autotimeset
# config_package_add luci-lib-ipkg

## byobu, tmux
# config_package_add byobu
#config_package_add tmux

# ## Frp Latest version patch

# FRP_MAKEFILE_PATH="feeds/packages/net/frp/Makefile"

# FRP_LATEST_RELEASE=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')

# if [ -z "$FRP_LATEST_RELEASE" ]; then
  # echo "无法获取最新的 Release 名称"
  # exit 1
# fi

# FRP_LATEST_VERSION=${FRP_LATEST_RELEASE#v}

# FRP_PKG_NAME="frp"
# FRP_PKG_SOURCE="${FRP_PKG_NAME}-${FRP_LATEST_VERSION}.tar.gz"
# FRP_PKG_SOURCE_URL="https://codeload.github.com/fatedier/frp/tar.gz/v${FRP_LATEST_VERSION}?"
# curl -L -o "$FRP_PKG_SOURCE" "$FRP_PKG_SOURCE_URL"

# FRP_PKG_HASH=$(sha256sum "$FRP_PKG_SOURCE" | awk '{print $1}')
# rm -r "$FRP_PKG_SOURCE"

# sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=${FRP_LATEST_VERSION}/" "$FRP_MAKEFILE_PATH"

# Helper functions for package configuration
function config_package_add() {
    local pkg="$1"
    echo "CONFIG_PACKAGE_${pkg}=y" >> .config
    echo "✓ Added package: ${pkg}"
}

function config_package_del() {
    local pkg="$1"
    echo "# CONFIG_PACKAGE_${pkg} is not set" >> .config
    echo "✗ Removed package: ${pkg}"
}
function apply_build_optimizations() {
    echo "🔧 Applying build optimizations..."
    
    # Link Time Optimization
    if [ "${ENABLE_LTO:-true}" = "true" ]; then
        echo "📦 Enabling Link Time Optimization (LTO)"
        config_add "USE_GC_SECTIONS"
        config_add "USE_LTO"
    fi
    
    # MOLD linker for faster builds
    if [ "${ENABLE_MOLD:-true}" = "true" ]; then
        echo "⚡ Enabling MOLD linker"
        config_add "USE_MOLD"
    fi
    
    # Extended BPF support
    if [ "${ENABLE_BPF:-true}" = "true" ]; then
        echo "🌐 Enabling extended BPF support"
        config_add "DEVEL"
        config_add "BPF_TOOLCHAIN_HOST"
        config_del "BPF_TOOLCHAIN_NONE"
        config_add "KERNEL_BPF_EVENTS"
        config_add "KERNEL_CGROUP_BPF"
        config_add "KERNEL_DEBUG_INFO"
        config_add "KERNEL_DEBUG_INFO_BTF"
        config_del "KERNEL_DEBUG_INFO_REDUCED"
        config_add "KERNEL_MODULE_ALLOW_BTF_MISMATCH"
        config_add "KERNEL_XDP_SOCKETS"
        # BPF packages
        config_package_add "kmod-sched-core"
        config_package_add "kmod-sched-bpf"
        config_package_add "kmod-xdp-sockets-diag"
    fi
    
    # Linux Random Number Generator (LRNG)
    if [ "${ENABLE_LRNG:-false}" = "true" ]; then
        echo "🎲 Enabling Linux Random Number Generator (LRNG)"
        config_add "KERNEL_LRNG"
        config_package_del "urandom-seed"
        config_package_del "urngd"
    fi
    
    # Data Plane Development Kit (DPDK)
    if [ "${ENABLE_DPDK:-false}" = "true" ]; then
        echo "🚀 Enabling Data Plane Development Kit (DPDK)"
        config_package_add "dpdk-tools"
        config_package_add "numactl"
    fi
    
    # Local kernel module support
    if [ "${ENABLE_LOCAL_KMOD:-false}" = "true" ]; then
        echo "📦 Enabling local kernel module support"
        config_add "TARGET_ROOTFS_LOCAL_PACKAGES"
    fi
    
    # Enable build acceleration tools
    config_add "CCACHE"
    
    echo "✅ Build optimizations applied"
}

function apply_mt7981_optimizations() {
    echo "🎯 Applying MT7981 specific optimizations"
    
    # Ensure XR30 devices are properly configured
    config_add "TARGET_mediatek_filogic_DEVICE_cmcc_xr30"
    #config_add "TARGET_mediatek_filogic_DEVICE_cmcc_xr30-emmc"
    
    # Advanced CPU-specific optimizations
    if [ "${ENABLE_ADVANCED_OPTIMIZATIONS:-true}" = "true" ]; then
        echo "🚀 Enabling advanced Cortex-A53 optimizations (CRC+Crypto)"
        # ARM64 Cortex-A53 with CRC and Crypto extensions
        echo '# ARM64 Cortex-A53 optimizations with extensions' >> .config
        echo 'CONFIG_TARGET_OPTIMIZATION="-O3 -pipe -mcpu=cortex-a53+crc+crypto"' >> .config
        echo 'CONFIG_EXTRA_OPTIMIZATION="-ffunction-sections -fdata-sections"' >> .config
        
        # Kernel optimizations for Cortex-A53
        echo 'CONFIG_KERNEL_CFLAGS="-march=armv8-a+crc+crypto -mcpu=cortex-a53+crc+crypto -mtune=cortex-a53"' >> .config
        
        # ZLIB speed optimization for better compression/decompression performance
        echo '# ZLIB performance optimization' >> .config
        echo 'CONFIG_ZLIB_OPTIMIZE_SPEED=y' >> .config
    else
        echo "📦 Using basic Cortex-A53 optimizations"
        echo 'CONFIG_TARGET_OPTIMIZATION="-O3 -pipe -mcpu=cortex-a53"' >> .config
        echo 'CONFIG_EXTRA_OPTIMIZATION="-ffunction-sections -fdata-sections"' >> .config
    fi
    
    # ARM64 specific optimizations
    # config_add "KERNEL_ARM64_SW_TTBR0_PAN"
    # config_add "KERNEL_ARM64_TAGGED_ADDR_ABI"
    
    # Network performance optimizations
    # config_add "KERNEL_NET_FLOW_LIMIT"
    # config_add "KERNEL_NETFILTER_NETLINK_ACCT"
    
    echo "✅ MT7981 optimizations applied"
}

function apply_compiler_optimizations() {
    echo "🔧 Applying compiler optimizations"
    
    # Enable toolchain options
    config_add "TOOLCHAINOPTS"
    config_add "TARGET_OPTIONS"
    
    # Kernel CLANG LTO if requested (only affects kernel compilation)
    if [ "${KERNEL_CLANG_LTO:-true}" = "true" ]; then
        echo "⚡ Enabling Kernel CLANG LTO (kernel only)"
        # These need to be added as raw config lines
        echo '# Kernel compilation with CLANG' >> .config
        echo 'CONFIG_KERNEL_CC="clang"' >> .config
        echo 'CONFIG_EXTRA_OPTIMIZATION=""' >> .config
        config_package_del "kselftests-bpf"
        
        # Ensure GCC is still used for userspace when USE_GCC14 is enabled
        if [ "${USE_GCC14:-true}" = "true" ]; then
            echo '# Userspace compilation with GCC14' >> .config
            # Note: TARGET_OPTIMIZATION is set in apply_mt7981_optimizations for Cortex-A53
        fi
    else
        # Use GCC for both kernel and userspace
        if [ "${USE_GCC14:-true}" = "true" ]; then
            echo "🛠️ Using GCC 14 for kernel and userspace compilation"
            # Note: TARGET_OPTIMIZATION is set in apply_mt7981_optimizations for Cortex-A53
        fi
    fi
    
    echo "✅ Compiler optimizations applied"
}

# Apply all optimizations
apply_build_optimizations
apply_mt7981_optimizations  
apply_compiler_optimizations

echo "🎉 All optimizations completed successfully"
# sed -i "s/^PKG_HASH:=.*/PKG_HASH:=${FRP_PKG_HASH}/" "$FRP_MAKEFILE_PATH"

# echo "已更新 Makefile 中的 PKG_VERSION 和 PKG_HASH"
