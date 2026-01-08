#!/bin/bash

# chmod +x run-build.sh
#./run-build.sh

# 构建 Docker 镜像
echo "🔨 构建 Docker 镜像..."
docker build -t immortalwrt-builder .

# 运行编译容器
echo "🚀 运行编译容器..."

# 创建输出目录
OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)/output}"
mkdir -p "$OUTPUT_DIR"

# 运行容器并挂载输出目录
docker run --rm \
    -v "$OUTPUT_DIR:/output" \
    -v "../diy-part1.sh:/workdir/scripts/diy-part1.sh:ro" \
    -v "../diy-part2-optimized-mnt.sh:/workdir/scripts/diy-part2-optimized-mnt.sh:ro" \
    -e OUTPUT_DIR=/output \
#    --optimization-level full \
#    --enable-advanced-features \
#    --custom-lan-ip 192.168.3.1
    immortalwrt-builder \
    "$@"

## 使用 docker-compose
#docker-compose up

# macOS创建大小写敏感的磁盘镜像
#hdiutil create -type SPARSE -fs 'Case-sensitive APFS' -size 200g -volname OpenWrtBuild ./data
#hdiutil attach ./data.sparseimage -mountpoint ./data