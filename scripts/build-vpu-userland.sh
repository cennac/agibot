#!/bin/bash
# VPU 用户态库源码构建路线(2026-08-16 在板上实证,产物已固化进 overlay/usr/local)
#
# 背景:Armbian/Jammy 仓库没有 rockchip-mpp / librga 包,必须源码/预编译自取。
# 内核侧 /dev/mpp_service 本来就绪(vendor 6.1),缺的只是用户态。
#
# 在板(aarch64, Ubuntu jammy rootfs)上执行:
#   apt-get install -y build-essential cmake git pkg-config ffmpeg
#
# 1) rockchip-mpp(源码编译,codeload tarball;默认分支是 develop 不是 master)
#    curl -sL -o mpp.tgz https://codeload.github.com/rockchip-linux/mpp/tar.gz/refs/heads/develop
#    tar xzf mpp.tgz && mv mpp-develop mpp && cd mpp && mkdir build && cd build
#    cmake .. && make -j8 && make install && ldconfig
#    产物: /usr/local/lib/librockchip_{mpp,vpu}.so.0(真身,SONAME=.so.1)
#          /usr/local/bin/mpi_*_test / mpp_info_test 等
#
# 2) librga(注意:rockchip-linux/librga 仓库已 404,官方迁到 airockchip/librga;
#    且新版不再带根 CMakeLists,库以预编译 .so 交付)
#    curl -sL -o rga.tgz https://codeload.github.com/airockchip/librga/tar.gz/refs/heads/main
#    tar xzf rga.tgz && mv librga-main librga
#    cp librga/libs/Linux/gcc-aarch64/librga.so /usr/local/lib/
#    cp -r librga/include/rga* /usr/local/include/ && ldconfig
#
# 3) 功能验证(真硬解,软解不可能到这个速度):
#    ffmpeg -y -f lavfi -i testsrc2=duration=2:size=320x240:rate=15 \
#        -c:v libx264 -pix_fmt nv12 /tmp/t.h264
#    mpi_dec_test -t 7 -i /tmp/t.h264 -n 30
#    实测: decode 30 frames time 14 ms, fps 2123.89, max memory 1.03 MB
#
# 镜像固化方式:overlay/usr/local/{lib,include,bin} 只带真身文件
# (.so.0/.so 与 .so.1/.so 链接由 customize-image.sh 重建,因 Windows git
# 不能可靠保存 symlink)。重新出产物时:在板上跑完上面两步后,
# SFTP 递归取回 /usr/local/{lib,include,bin},剔除 *.a、python3.10、
# f2py/numpy-config 等无关文件即可。
echo "此脚本文档性质,按注释步骤在板上执行;产物已固化于 overlay/usr/local" >&2
