TARGET := iphone:clang:latest:15.0
export THEOS=/Users/aldazdev/theos
ARCHS  := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := SpringBoardTweak

SpringBoardTweak_FILES  := Tweak.m \
                    LFGestalt.m \
                    LFIconPack.m \
                    LFWallpaper.m \
                    Model/LFPrefs.m \
                    Views/LFClockView.m \
                    Views/LFButton.m \
                    Controllers/LFPanelController.m \
                    Controllers/LFWindowManager.m \
                    LFGoogleFonts.m

SpringBoardTweak_CFLAGS := -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable
SpringBoardTweak_LDFLAGS := -lz
SpringBoardTweak_FRAMEWORKS := CoreText

include $(THEOS_MAKE_PATH)/tweak.mk
