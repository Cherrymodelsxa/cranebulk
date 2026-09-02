# CraneBulk — tweak rootless pour Dopamine / Fugu15 Max.
# libcrane n'est deliberement pas liee : CraneManager est resolue au runtime,
# ce qui evite que SpringBoard refuse de charger le tweak si Crane est absent.

export ARCHS = arm64 arm64e
export TARGET = iphone:clang:16.5:15.0
export THEOS_PACKAGE_SCHEME = rootless

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CraneBulk

CraneBulk_FILES = Tweak.x \
                  Sources/CBCraneBridge.m \
                  Sources/CBBulkOperations.m \
                  Sources/CBUI.m \
                  Sources/CBLocalization.m \
                  Sources/CBFlowController.m

CraneBulk_CFLAGS = -fobjc-arc -Wno-format-nonliteral -Wno-deprecated-declarations
CraneBulk_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
