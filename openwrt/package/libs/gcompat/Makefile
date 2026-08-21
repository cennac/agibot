include $(TOPDIR)/rules.mk

PKG_NAME:=gcompat
PKG_RELEASE:=1
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://git.adelielinux.org/adelie/gcompat.git
PKG_SOURCE_VERSION:=06600632096b14e03e32b234ec0b02a9d4d045e9
PKG_MIRROR_HASH:=skip

include $(INCLUDE_DIR)/package.mk

define Package/gcompat
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=glibc compatibility layer for musl
  URL:=https://git.adelielinux.org/adelie/gcompat
endef

MAKE_FLAGS += \
	LINKER_PATH=/lib/ld-musl-aarch64.so.1 \
	LOADER_NAME=ld-linux-aarch64.so.1 \
	WITH_OBSTACK=no

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) $(MAKE_FLAGS) libgcompat.so.0
endef

define Package/gcompat/install
	$(INSTALL_DIR) $(1)/lib
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/libgcompat.so.0 $(1)/lib/
	ln -sf ld-musl-aarch64.so.1 $(1)/lib/libc.so.6
	ln -sf ld-musl-aarch64.so.1 $(1)/lib/libpthread.so.0
	ln -sf ld-musl-aarch64.so.1 $(1)/lib/libdl.so.2
	ln -sf ld-musl-aarch64.so.1 $(1)/lib/libm.so.6
endef

$(eval $(call BuildPackage,gcompat))
