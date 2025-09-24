#import <Foundation/Foundation.h>

// 所有的RuntimeBrowser集成类
#import "FLEXRuntimeClient+RuntimeBrowser.h"
#import "FLEXClassHierarchyViewController.h"
#import "FLEXClassPerformanceViewController.h"
#import "FLEXManager+RuntimeBrowser.h"
#import "FLEXSystemAnalyzerViewController+RuntimeBrowser.h"
#import "FLEXMemoryAnalyzer+RuntimeBrowser.h"
#import "FLEXHookDetector+RuntimeBrowser.h"
#import "FLEXFileBrowserController+RuntimeBrowser.h"

// 只需包含此头文件即可启用所有RuntimeBrowser功能
@interface FLEXRuntimeBrowser : NSObject

+ (void)enableRuntimeBrowser;

@end