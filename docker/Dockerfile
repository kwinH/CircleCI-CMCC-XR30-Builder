FROM ubuntu:22.04

ENV GOPROXY=https://goproxy.cn,direct

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai
ENV REPO_URL=https://github.com/padavanonly/immortalwrt-mt798x-6.6
ENV REPO_BRANCH=openwrt-24.10-6.6
ENV OPENWRT_NAME=padavanonly
ENV UPLOAD_TAG_NAME=cmcc_xr30
ENV DIY_P1_SH=diy-part1.sh
ENV DIY_P2_SH=diy-part2-optimized-mnt.sh


# 更换为国内镜像源
RUN sed -i 's@http://.*archive.ubuntu.com@http://mirrors.aliyun.com@g' /etc/apt/sources.list && \
    sed -i 's@http://security.ubuntu.com@http://mirrors.aliyun.com@g' /etc/apt/sources.list

# 安装基础依赖（移除与 init_build_environment.sh 重复的部分）
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    sudo \
    xz-utils \
    file \
    iputils-ping \
    dnsutils \
    net-tools \
    screen \
    && rm -rf /var/lib/apt/lists/*

# 设置时区
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 创建工作目录和用户
RUN mkdir -p /workdir
RUN groupadd -r builder && useradd -r -g builder builder
RUN usermod -aG sudo builder
RUN echo 'builder ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# 设置工作目录
WORKDIR /workdir

# 在切换用户前创建脚本目录并设置权限
RUN mkdir -p /workdir/scripts && chown -R builder:builder /workdir

# 安装 ImmortalWrt 构建环境
RUN bash -c 'bash <(curl -s https://build-scripts.immortalwrt.org/init_build_environment.sh)'

# 切换到 builder 用户
USER builder

# 设置默认启动命令，保持容器运行
CMD ["tail", "-f", "/dev/null"]

