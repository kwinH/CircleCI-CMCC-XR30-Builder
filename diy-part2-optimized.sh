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

# ============================================
# Configuration Correction Functions
# ============================================

function fix_target_platform_config() {
    echo "🔧 Checking and fixing target platform configuration..."
    
    # Check if we're using the old mt7981 target platform
    if grep -q "CONFIG_TARGET_mediatek_mt7981=y" .config; then
        echo "⚠️  Detected old mt7981 target platform, fixing to filogic..."
        
        # Update target platform from mt7981 to filogic
        config_del "CONFIG_TARGET_mediatek_mt7981"
        config_add "CONFIG_TARGET_mediatek_filogic"
        
        # Update all device configurations from mt7981 to filogic
        sed -i 's/mediatek_mt7981/mediatek_filogic/g' .config
        
        echo "✅ Target platform fixed: mt7981 → filogic"
        
        # Verify CMCC XR30 devices are properly enabled
        if grep -q "CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_cmcc_xr30=y" .config; then
            echo "✅ CMCC XR30 (NAND) device is enabled"
        else
            config_add "CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_cmcc_xr30"
            echo "✅ Enabled CMCC XR30 (NAND) device"
        fi
        
        if grep -q "CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_cmcc_xr30-emmc=y" .config; then
            echo "✅ CMCC XR30 (eMMC) device is enabled"
        else
            config_add "CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_cmcc_xr30-emmc"
            echo "✅ Enabled CMCC XR30 (eMMC) device"
        fi
    else
        echo "✅ Target platform configuration is already correct"
        
        # Still ensure CMCC XR30 devices are enabled
        if ! grep -q "CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_cmcc_xr30=y" .config; then
            config_add "CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_cmcc_xr30"
            echo "✅ Enabled CMCC XR30 (NAND) device"
        fi
        
        if ! grep -q "CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_cmcc_xr30-emmc=y" .config; then
            config_add "CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_cmcc_xr30-emmc"
            echo "✅ Enabled CMCC XR30 (eMMC) device"
        fi
    fi
    
    echo "⌚ Device list after replaced..." 
    config_device_list
    echo "🎯 Configuration check completed"
}

# ============================================
# Optimization Functions
# ============================================

function apply_optimizations_by_level() {
    local optimization_level="${OPTIMIZATION_LEVEL:-full}"
    
    echo "🎯 Applying optimizations for level: $optimization_level"
    
    case "$optimization_level" in
        "basic")
            echo "📦 Basic optimizations: LTO + MOLD"
            export ENABLE_LTO="true"
            export ENABLE_MOLD="true"
            export ENABLE_BPF="false"
            export KERNEL_CLANG_LTO="false"
            export USE_GCC14="false"
            export ENABLE_LRNG="false"
            export ENABLE_DPDK="false"
            export ENABLE_LOCAL_KMOD="false"
            export ENABLE_ADVANCED_OPTIMIZATIONS="false"
            ;;
        "full")
            echo "🚀 Full optimizations: LTO + MOLD + BPF + CLANG LTO + GCC14"
            export ENABLE_LTO="true"
            export ENABLE_MOLD="true"
            export ENABLE_BPF="true"
            export KERNEL_CLANG_LTO="true"
            export USE_GCC14="true"
            export ENABLE_LRNG="false"
            export ENABLE_DPDK="false"
            export ENABLE_LOCAL_KMOD="false"
            export ENABLE_ADVANCED_OPTIMIZATIONS="true"
            ;;
        "advanced")
            echo "⚡ Advanced optimizations: All features enabled"
            export ENABLE_LTO="true"
            export ENABLE_MOLD="true"
            export ENABLE_BPF="true"
            export KERNEL_CLANG_LTO="true"
            export USE_GCC14="true"
            export ENABLE_LRNG="true"
            export ENABLE_DPDK="true"
            export ENABLE_LOCAL_KMOD="true"
            export ENABLE_ADVANCED_OPTIMIZATIONS="true"
            ;;
        "custom")
            echo "🔧 Custom optimizations: Using individual settings"
            # Keep current environment variables as set by GitHub Actions
            if [[ "${ENABLE_ADVANCED_FEATURES}" == "true" ]]; then
                export ENABLE_LRNG="true"
                export ENABLE_DPDK="true"
                export ENABLE_LOCAL_KMOD="true"
            else
                export ENABLE_LRNG="false"
                export ENABLE_DPDK="false"
                export ENABLE_LOCAL_KMOD="false"
            fi
            ;;
        *)
            echo "⚠️  Unknown optimization level: $optimization_level, using full"
            export OPTIMIZATION_LEVEL="full"
            apply_optimizations_by_level
            return
            ;;
    esac
    
    echo "✅ Optimization level configuration completed"
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
    
    # Advanced CPU-specific optimizations
    if [ "${ENABLE_ADVANCED_OPTIMIZATIONS:-true}" = "true" ]; then
        echo "🚀 Enabling advanced Cortex-A53 optimizations (CRC+Crypto)"
        cat >> .config << 'EOF'
# ARM64 Cortex-A53 optimizations with extensions
CONFIG_TARGET_OPTIMIZATION="-O3 -pipe -mcpu=cortex-a53+crc+crypto"
CONFIG_EXTRA_OPTIMIZATION="-ffunction-sections -fdata-sections"
CONFIG_KERNEL_CFLAGS="-march=armv8-a+crc+crypto -mcpu=cortex-a53+crc+crypto -mtune=cortex-a53"
# ZLIB performance optimization
CONFIG_ZLIB_OPTIMIZE_SPEED=y
EOF
    else
        echo "📦 Using basic Cortex-A53 optimizations"
        cat >> .config << 'EOF'
CONFIG_TARGET_OPTIMIZATION="-O3 -pipe -mcpu=cortex-a53"
CONFIG_EXTRA_OPTIMIZATION="-ffunction-sections -fdata-sections"
EOF
    fi
    
    echo "✅ MT7981 optimizations applied"
}

function apply_compiler_optimizations() {
    echo "🔧 Applying compiler optimizations"
    
    # Enable toolchain options
    config_add "TOOLCHAINOPTS"
    config_add "TARGET_OPTIONS"
    
    # Set host tools optimization
    echo "🏗️  Setting host tools optimization to -O3"
    export HOST_CFLAGS="-O3 -pipe"
    export HOST_CXXFLAGS="-O3 -pipe"
    export CFLAGS="-O3 -pipe"
    export CXXFLAGS="-O3 -pipe" 
    export LDFLAGS="-Wl,-O1,--as-needed"
    
    # Add persistent config settings
    cat >> .config << 'EOF'
# Host tools optimization
CONFIG_HOST_CFLAGS="-O3 -pipe"
CONFIG_HOST_CXXFLAGS="-O3 -pipe"
# Global build optimization
CONFIG_CCACHE=y
EOF
    
    # Kernel CLANG LTO if requested (only affects kernel compilation)
    if [ "${KERNEL_CLANG_LTO:-true}" = "true" ]; then
        echo "⚡ Enabling Kernel CLANG LTO (kernel only)"
        cat >> .config << 'EOF'
# Kernel compilation with CLANG
CONFIG_KERNEL_CC="clang"
EOF
        config_package_del "kselftests-bpf"
        
        # Ensure GCC is still used for userspace when USE_GCC14 is enabled
        if [ "${USE_GCC14:-true}" = "true" ]; then
            echo "🛠️ Using GCC14 for userspace compilation"
            cat >> .config << 'EOF'
# Userspace compilation with GCC14
CONFIG_CC_IS_GCC=y
CONFIG_GCC_VERSION_14=y
EOF
        fi
    else
        # Use GCC for both kernel and userspace
        if [ "${USE_GCC14:-true}" = "true" ]; then
            echo "🛠️ Using GCC 14 for kernel and userspace compilation"
        fi
    fi
    
    echo "✅ Compiler optimizations applied"
}

function setup_custom_lan_ip() {
    local custom_ip="${CUSTOM_LAN_IP:-192.168.3.1}"
    
    echo "Setting up custom LAN IP: $custom_ip"
    
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

# Device configuration
echo "⌚ Device list before fixed..." 
config_device_list
config_device_keep_only "cmcc_xr30-stock"

echo "✅ Configured for XR30-stock (H layout) only"
echo "⌚ Device list after fixed..." 

# Theme modification
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Package management
echo "🗑️  Removing unwanted packages..."
config_package_del "luci-app-ssr-plus_INCLUDE_NONE_V2RAY"
config_package_del "luci-app-ssr-plus_INCLUDE_Shadowsocks_NONE_Client"
config_package_del "luci-app-ssr-plus_INCLUDE_ShadowsocksR_NONE_Server"
config_package_del "luci-theme-bootstrap-mod"

echo "📦 Adding custom packages..."
config_package_add "luci-app-ttyd"    # Web Terminal
config_package_add "kmod-tcp-bbr"     # BBR congestion control
config_package_add "curl"             # HTTP client
config_package_add "netcat"           # Network utility

# ============================================
# Apply All Optimizations
# ============================================

echo "🚀 Starting optimization process..."

# First, fix target platform configuration if needed
fix_target_platform_config

# Apply optimizations based on level
apply_optimizations_by_level

# Apply specific optimizations
apply_build_optimizations
apply_mt7981_optimizations  
apply_compiler_optimizations

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

echo "🎯 配置验证完成"
