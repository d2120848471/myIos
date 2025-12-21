TARGET := iphone:clang:latest:16.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AutoTap

AutoTap_FILES = $(shell find Sources -name '*.m')
AutoTap_CFLAGS = -fobjc-arc \
	-ISources \
	-ISources/Core/Models \
	-ISources/Core/Persistence \
	-ISources/Core/ClickEngine \
	-ISources/Core/TouchPicker \
	-ISources/Core/HID \
	-ISources/UI \
	-ISources/Entry
AutoTap_FRAMEWORKS = UIKit Foundation QuartzCore CoreGraphics IOKit CoreFoundation
AutoTap_PLIST_FILES = AutoTap.plist

include $(THEOS_MAKE_PATH)/tweak.mk
