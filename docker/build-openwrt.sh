#!/bin/bash

set -e

# 重定向所有输出到带时间戳的日志文件
CURRENT_TIME=$(date +"%Y%m%d_%H%M%S")
exec > >(tee -a "/output/build_${CURRENT_TIME}.log") 2>&1

# 更新 hosts 文件以加速网络访问
echo "🔄 获取github hosts 配置..."
curl -fsSL "https://gitlab.com/ineo6/hosts/-/raw/master/hosts" | sudo tee -a /etc/hosts > /dev/null
echo "✅ hosts 文件已更新"

# 在编译前添加 Go 环境变量
export GOPROXY=https://goproxy.cn,direct
export GOSUMDB=sum.golang.google.cn
export GO111MODULE=on

# 构建参数默认值
APP_MTK=false
OPTIMIZATION_LEVEL="full"
ENABLE_LTO=true
ENABLE_MOLD=true
ENABLE_BPF=true
KERNEL_CLANG_LTO=true
USE_GCC14=true
ENABLE_ADVANCED_FEATURES=false
CUSTOM_LAN_IP="192.168.6.1"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --app-mtk)
            APP_MTK=true
            shift
            ;;
        --optimization-level)
            OPTIMIZATION_LEVEL="$2"
            shift 2
            ;;
        --enable-lto)
            ENABLE_LTO=true
            shift
            ;;
        --disable-lto)
            ENABLE_LTO=false
            shift
            ;;
        --enable-mold)
            ENABLE_MOLD=true
            shift
            ;;
        --disable-mold)
            ENABLE_MOLD=false
            shift
            ;;
        --enable-bpf)
            ENABLE_BPF=true
            shift
            ;;
        --disable-bpf)
            ENABLE_BPF=false
            shift
            ;;
        --enable-kernel-clang-lto)
            KERNEL_CLANG_LTO=true
            shift
            ;;
        --disable-kernel-clang-lto)
            KERNEL_CLANG_LTO=false
            shift
            ;;
        --use-gcc14)
            USE_GCC14=true
            shift
            ;;
        --use-default-gcc)
            USE_GCC14=false
            shift
            ;;
        --enable-advanced-features)
            ENABLE_ADVANCED_FEATURES=true
            shift
            ;;
        --disable-advanced-features)
            ENABLE_ADVANCED_FEATURES=false
            shift
            ;;
        --custom-lan-ip)
            CUSTOM_LAN_IP="$2"
            shift 2
            ;;
        --help)
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  --app-mtk                    使用 luci-app-mtk wifi 配置"
            echo "  --optimization-level LEVEL   优化级别 (basic/full/advanced/custom)"
            echo "  --enable/disable-lto         启用/禁用 LTO"
            echo "  --enable/disable-mold        启用/禁用 MOLD"
            echo "  --enable/disable-bpf         启用/禁用 BPF"
            echo "  --enable/disable-kernel-clang-lto  启用/禁用内核 CLANG LTO"
            echo "  --use-gcc14/default-gcc      使用 GCC14/默认 GCC"
            echo "  --enable/disable-advanced-features  启用/禁用高级功能"
            echo "  --custom-lan-ip IP           自定义 LAN IP 地址"
            echo "  --help                       显示帮助"
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            exit 1
            ;;
    esac
done

echo "🚀 开始 Docker OpenWrt 编译..."
echo "⚙️  编译配置:"
echo "  - APP_MTK: $APP_MTK"
echo "  - OPTIMIZATION_LEVEL: $OPTIMIZATION_LEVEL"
echo "  - ENABLE_LTO: $ENABLE_LTO"
echo "  - ENABLE_MOLD: $ENABLE_MOLD"
echo "  - ENABLE_BPF: $ENABLE_BPF"
echo "  - KERNEL_CLANG_LTO: $KERNEL_CLANG_LTO"
echo "  - USE_GCC14: $USE_GCC14"
echo "  - ENABLE_ADVANCED_FEATURES: $ENABLE_ADVANCED_FEATURES"
echo "  - CUSTOM_LAN_IP: $CUSTOM_LAN_IP"

# 设置环境变量
export OPTIMIZATION_LEVEL
export ENABLE_LTO
export ENABLE_MOLD
export ENABLE_BPF
export KERNEL_CLANG_LTO
export USE_GCC14
export ENABLE_ADVANCED_FEATURES
export CUSTOM_LAN_IP

# 检查磁盘空间
echo "📊 当前磁盘使用情况:"
df -hT

if [ ! -d "data" ]; then
mkdir data
fi

# 测试 GitHub 连接
ping -c 4 github.com || { echo "❌ GitHub ping 失败，退出脚本"; exit 1; }

cd data
# 检查是否已有源码
if [ ! -d "openwrt" ]; then
    echo "📥 克隆源码（$REPO_URL:$REPO_BRANCH）..."
    git clone -b "$REPO_BRANCH" --single-branch --depth 1 "$REPO_URL" openwrt
    cd openwrt
else
    echo "🚀 源码已存在，开始更新..."
    cd openwrt
    git pull
    make clean
fi

# 执行 DIY 脚本
echo "🔧 执行 DIY 脚本..."

# 检查并执行 diy-part1.sh
if [ -f "/workdir/scripts/diy-part1.sh" ]; then
    sudo chmod +x /workdir/scripts/diy-part1.sh
    /workdir/scripts/diy-part1.sh
else
    echo "⚠️  diy-part1.sh 不存在，跳过"
fi

# 更新和安装 feeds
echo "🔄 更新和安装 feeds..."
./scripts/feeds update -a
./scripts/feeds install -a

# 复制配置文件并执行第二部分 DIY 脚本
echo "⚙️  配置编译选项..."
cp defconfig/mt7981-ax3000.config .config

if [ -f "/workdir/scripts/diy-part2-optimized.sh" ]; then
    sudo chmod +x /workdir/scripts/diy-part2-optimized.sh
    /workdir/scripts/diy-part2-optimized.sh
fi

# 应用 MTK 配置（如果启用）
if [ "$APP_MTK" = true ]; then
    echo "📱 应用 MTK WiFi 配置..."
    sed -i 's/CONFIG_PACKAGE_luci-app-mtwifi-cfg=y/CONFIG_PACKAGE_luci-app-mtk=y/g' .config
    sed -i 's/CONFIG_PACKAGE_luci-i18n-mtwifi-cfg-zh-cn=y/CONFIG_PACKAGE_luci-i18n-mtk-zh-cn=y/g' .config
    sed -i 's/CONFIG_PACKAGE_mtwifi-cfg=y/CONFIG_PACKAGE_wifi-profile=y/g' .config
    sed -i 's/CONFIG_PACKAGE_lua-cjson=y/CONFIG_WIFI_NORMAL_SETTING=y/g' .config
fi

# 下载包
echo "📥 下载编译所需包..."
make defconfig

CORES=$(nproc)
JOBS=$((CORES - 1))
echo "🚀 使用 $JOBS 个并行任务下载包 ($CORES 核心检测到)"
make download -j"$JOBS"

# 清理小文件
find dl -size -1024c -exec ls -l {} \; 2>/dev/null || true
find dl -size -1024c -exec rm -f {} \; 2>/dev/null || true

echo "📊 下载目录大小:"
du -sh dl/

# 编译固件
echo "🔨 开始编译固件..."
echo "📊 编译前磁盘使用情况:"
df -hT

# 记录编译开始时间
BUILD_START=$(date +%s)

# 编译命令
if [ "$ENABLE_LTO" = true ] && [ "$ENABLE_MOLD" = true ]; then
    echo "⚙️  启用了 LTO 和 MOLD 优化"
fi

echo "🚀 使用 $JOBS 个并行任务编译 ($CORES 核心检测到)"
make -j"$JOBS" V=s || {
        echo "⚠️  并行编译失败，尝试单线程编译..."
        make -j1 V=s
    }

# 计算编译时间
BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))
BUILD_MINUTES=$((BUILD_TIME / 60))
BUILD_SECONDS=$((BUILD_TIME % 60))
echo "⏱️ 编译完成，耗时 ${BUILD_MINUTES} 分 ${BUILD_SECONDS} 秒"

# 检测 WiFi 配置
if grep -q 'CONFIG_PACKAGE_mtwifi-cfg=y' .config; then
    WIFI_INTERFACE="-mtwifi"
else
    WIFI_INTERFACE=""
fi

COMPILE_DATE=$(date +"%Y%m%d%H%M")

# 整理编译结果
echo "📦 整理编译结果..."
cd bin/targets/*/*

echo "📋 检查构建结果..."
echo "生成的所有文件："
ls -la

echo "查找 CMCC XR30 相关文件："
find . -name "*cmcc*" -o -name "*xr30*" || echo "⚠️  未找到 CMCC XR30 文件"

# 检查是否生成了 XR30 固件
if ! find . -name "*cmcc_xr30*sysupgrade.bin" | grep -q .; then
    echo "❌ 警告：未找到 CMCC XR30 升级固件"
    echo "📋 所有生成的 .bin 文件："
    find . -name "*.bin" | head -10
fi

rm -rf packages

# 获取设备列表
devices=()
while IFS= read -r line; do
    if [[ $line =~ ^CONFIG_TARGET_DEVICE_.*=y ]]; then
        device_name=$(echo "$line" | sed -n 's/CONFIG_TARGET_DEVICE_\([^=]*\)=y/\1/p')
        devices+=("$device_name")
    fi
done < ../../.config

for val in "${devices[@]}"; do
    if command -v rename >/dev/null 2>&1; then
        rename "s/.*${val}/${COMPILE_DATE}-${OPENWRT_NAME}-${val}${WIFI_INTERFACE}/" *
    else
        # 如果没有 rename 命令，使用 shell 方式重命名
        for file in *"${val}"*; do
            if [ -f "$file" ]; then
                new_name="${COMPILE_DATE}-${OPENWRT_NAME}-${val}${WIFI_INTERFACE}-${file##*-}"
                mv "$file" "$new_name"
            fi
        done
    fi
    echo "$val"
done

FIRMWARE_DIR="$PWD"
echo "✅ 固件整理完成，位于: $FIRMWARE_DIR"

# 将编译结果复制到共享卷
if [ -d "/output" ]; then
    echo "💾 将编译结果复制到 /output..."
    cp -r * /output/
    echo "📁 固件已保存到宿主机的挂载目录"
fi

echo "🎉 Docker 编译完成！"
echo "📁 固件位置: $FIRMWARE_DIR"
if [ -d "/output" ]; then
    echo "📁 固件也已保存到: /output"
fi
