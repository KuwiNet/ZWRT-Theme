include $(TOPDIR)/rules.mk
THEME_NAME:=zwrt
THEME_TITLE:=ZWRT Theme
PKG_NAME:=luci-theme-$(THEME_NAME)
LUCI_TITLE:=ZWRT Theme by kuwi.net
LUCI_DEPENDS:=+luci-base +wget +curl +jsonfilter
PKG_VERSION:=3.6.3
# 主题自带 ucode/template，新版 luci.mk 会因此自动加 "ucode (>=2026.02.27)" 依赖，
# 这是"预编译模板字节码"的最低运行时要求。我们关闭模板预编译（见 build_apk.sh），
# 直接发布 .ut 源码由运行时解释，因此把门槛降到旧版本，兼容 25.x 正式版等旧固件。
LUCI_UT_MIN_UCODE:=2019.01.01

define Package/luci-theme-$(THEME_NAME)/conffiles
/www/luci-static/resources/background/
endef

include $(TOPDIR)/feeds/luci/luci.mk

define Package/luci-theme-$(THEME_NAME)/description
ZWRT Theme by kuwi.net
endef

define Build/Compile
	$(call Build/Compile/Default)
endef

# call BuildPackage - OpenWrt buildroot signature
