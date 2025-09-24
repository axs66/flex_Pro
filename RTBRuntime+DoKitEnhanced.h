#import <UIKit/UIKit.h>
#import "RTBRuntime.h"
#import <objc/runtime.h>

@interface RTBRuntime (DoKitEnhanced)

// DoKit风格的运行时分析
- (NSArray *)dokit_getAllClassesWithPrefix:(NSString *)prefix;
- (NSArray *)dokit_getMethodsForClass:(Class)cls includeHooked:(BOOL)includeHooked;
- (NSArray *)dokit_getHookedMethodsForClass:(Class)cls;
- (BOOL)dokit_isMethodHooked:(Method)method;
- (NSDictionary *)dokit_getClassHierarchyTree;
- (NSArray *)dokit_searchClassesByKeyword:(NSString *)keyword;

// 内存和性能分析
- (NSArray *)dokit_getAllInstancesOfClass:(Class)cls;
- (NSUInteger)dokit_getInstanceCountForClass:(Class)cls;
- (NSArray *)dokit_getViewHierarchyFromView:(UIView *)view;

// 网络请求分析
- (NSArray *)dokit_getAllNetworkRequests;
- (void)dokit_startNetworkMonitoring;
- (void)dokit_stopNetworkMonitoring;

@end