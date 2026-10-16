include $(TOPDIR)/rules.mk
THEME_NAME:=zwrt
THEME_TITLE:=ZWRT Theme
PKG_NAME:=luci-theme-$(THEME_NAME)
LUCI_TITLE:=ZWRT Theme by kuwi.net
LUCI_DEPENDS:=+luci-base +wget +curl +jsonfilter
PKG_VERSION:=3.6.1

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
