# SPDX-License-Identifier: GPL-2.0
obj-m += rknpu.o

ccflags-y += -I$(srctree)/$(src)/include
ccflags-y += -I$(src)/include
ccflags-y += -DCONFIG_ROCKCHIP_RKNPU_DRM_GEM=1

rknpu-y += rknpu_drv.o
rknpu-y += rknpu_reset.o
rknpu-y += rknpu_job.o
rknpu-y += rknpu_debugger.o
rknpu-$(CONFIG_PM_DEVFREQ) += rknpu_devfreq.o
rknpu-y += rknpu_iommu.o
rknpu-y += rknpu_gem.o
