#!/bin/bash

set -e


function setup_custom_lan_ip() {
    local custom_ip="${CUSTOM_LAN_IP:-192.168.6.1}"

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

CUSTOM_LAN_IP="192.168.6.1"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --custom-lan-ip)
            CUSTOM_LAN_IP="$2"
            shift 2
            ;;
        --help)
            echo "用法: $0 [选项]"
            echo "选项:"
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

echo "  - CUSTOM_LAN_IP: $CUSTOM_LAN_IP"

# 设置环境变量
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

cp /workdir/feeds.conf.default openwrt/feeds.conf.default

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
cp /workdir/24.10-6.6.config .config

echo "🔧 集成 iStore 商店..."
echo >> feeds.conf.default
echo 'src-git istore https://github.com/linkease/istore;main' >> feeds.conf.default
./scripts/feeds update istore
./scripts/feeds install -d y -p istore luci-app-store

if [ -f "/workdir/scripts/diy-part2.sh" ]; then
    sudo chmod +x /workdir/scripts/diy-part2.sh
    /workdir/scripts/diy-part2.sh
fi

setup_custom_lan_ip

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



