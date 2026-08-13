# Dockerfile — agibot armbian 编译容器(builder image)
#
# 仓库通过 docker-build.sh 的 -v 挂载进容器,不 COPY 进镜像 → 镜像小、build 快。
# 容器内文件系统为 ext4/virtiofs(非 WSL2 的 9p),无 fsync hang / fchmod EPERM 坑,
# 故 setup.sh 在容器内不 apply WSL2 patch(见 setup.sh detect_platform 的 /.dockerenv 分支)。
# 交叉编译 arm64 rootfs 的 qemu binfmt 由 host kernel 提供(Docker Desktop 自带 / WSL 已注册)。
#
# build: docker build -t agibot-armbian-builder .   (由 docker-build.sh 自动做)
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# armbian/build host 编译依赖(核心集;compile.sh 启动会自查并补全其余,需容器可联网 apt)
RUN apt-get update && apt-get install -y --no-install-recommends \
		ca-certificates gnupg fakeroot curl wget git \
		grep unzip lz4 xz-utils zstd \
		python3 python3-distutils \
		build-essential gcc make bc bison flex \
		libssl-dev ncurses-dev \
		udev fdisk mount kmod losetup \
		device-tree-compiler qemu-user-static binfmt-support \
		sudo less procps iproute2 \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /docker-agibot-armbian
CMD ["bash"]
