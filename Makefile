# 因为有大量iOS9历史代码！
TARGET = iphone:latest:9.0

ARCHS = arm64

# 名称和类型
LIBRARY_NAME = FLEX_Pro

# 动态库类型 - 兼容各种越狱环境
LIBRARY_TYPE = dynamic

# 直接输出到当前目录
export THEOS_PACKAGE_DIR = $(CURDIR)

# Rootless
export THEOS_PACKAGE_SCHEME = rootless
THEOS_PACKAGE_INSTALL_PREFIX = /var/jb

# 设置路径
$(LIBRARY_NAME)_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

# 必要的框架和库
$(LIBRARY_NAME)_FRAMEWORKS = Foundation UIKit CoreGraphics CoreFoundation QuartzCore CoreText
$(LIBRARY_NAME)_PRIVATE_FRAMEWORKS = JavaScriptCore

# 系统库
$(LIBRARY_NAME)_LIBRARIES = system sqlite3 z

# 修正的链接选项
$(LIBRARY_NAME)_LDFLAGS += -framework CoreFoundation -framework IOKit

# 定义要排除的 Dobby 相关文件
EXCLUDE_FILES = \
    FLEX-DobbyIntegration.m \
    FLEXDobbyManager.m \
    FLEXDobbyBridge.m \
    FLEXDobbyViewController.m \
    FLEXHookDetector+Dobby.m \
    RTBRuntime+DobbySupport.m

# FLEX 源文件 (自动排除上面定义的文件)
$(LIBRARY_NAME)_FILES = $(filter-out $(EXCLUDE_FILES), $(wildcard *.m */*.m *.mm */*.mm))
$(LIBRARY_NAME)_FILES += flex_fishhook.c

# 处理警告
$(LIBRARY_NAME)_CFLAGS += -Wno-objc-property-no-attribute -Wno-unsupported-availability-guard -Wno-objc-missing-super-calls

# Dobby 库正确链接 (此行保留，因为 fishhook 等也可能需要)
$(LIBRARY_NAME)_LDFLAGS += -ldl

# 所有架构都使用 MRC
$(LIBRARY_NAME)_CFLAGS += -fno-objc-arc

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk