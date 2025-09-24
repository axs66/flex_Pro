#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class RTBTreeTVC;
@class RTBObjectsTVC;
@class RTBClassDisplayVC;

@interface RuntimeBrowserFactory : NSObject

+ (RTBTreeTVC *)createClassHierarchyBrowser;
+ (RTBObjectsTVC *)createObjectBrowserForObject:(id)object;
+ (RTBClassDisplayVC *)createClassDisplayViewControllerForClass:(Class)cls;
+ (NSString *)generateHeaderForClass:(Class)cls;
+ (void)startMethodProfiler;
+ (void)stopMethodProfiler;
+ (NSArray *)getProfiledMethodResults;
+ (UIViewController *)createHookDetectorViewController;
+ (UIViewController *)createNetworkAnalyzerViewController;
+ (UIViewController *)createPerformanceMonitorViewController;
+ (UIViewController *)createMemoryAnalyzerViewController;
+ (NSDictionary *)getSystemAnalysis;

@end