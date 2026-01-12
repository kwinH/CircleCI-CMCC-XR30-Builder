FROM --platform=linux/amd64 ubuntu:22.04

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

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    clang \
    flex \
    bison \
    g++ \
    gawk \
    gettext \
    git \
    libncurses5-dev \
    libssl-dev \
    python3 \
    python3-setuptools \
    rsync \
    swig \
    time \
    unzip \
    zlib1g-dev \
    file \
    wget \
    subversion \
    autoconf \
    automake \
    autogen \
    shtool \
    upx-ucl \
    libtool-bin \
    autogen \
    intltool \
    mercurial \
    bzr \
    ecj \
    fastjar \
    python3-dev \
    python3-pip \
    golang-go \
    mold \
    libisl-dev \
    gcc-12 \
    g++-12 \
    rename \
    sudo \
    cpio \
    curl \
    iputils-ping \
    dnsutils \
    net-tools \
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

# 安装并配置 alternatives 用于 GCC 12
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 100 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 100

# 安装 ImmortalWrt 构建环境
RUN bash -c 'bash <(curl -s https://build-scripts.immortalwrt.org/init_build_environment.sh)'

# 切换到 builder 用户
USER builder

# 创建入口点脚本
RUN echo '#!/bin/bash\n\
echo "🚀 启动 OpenWrt 编译容器..."\n\
echo "📊 磁盘使用情况:"\n\
df -hT\n\
echo "🔧 执行构建脚本..."\n\
/workdir/scripts/build-openwrt.sh "$@"' > /workdir/entrypoint.sh
RUN chmod +x /workdir/entrypoint.sh

ENTRYPOINT ["/workdir/entrypoint.sh"]
