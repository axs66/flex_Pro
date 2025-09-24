#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface RTBExtendedAnalyzer : NSObject

+ (instancetype)sharedAnalyzer;

// 视图分析
+ (UIViewController *)viewHierarchyAnalyzerForView:(UIView *)view;

// 类性能分析
+ (UIViewController *)performanceAnalyzerForClass:(Class)cls;

// 引用关系分析
+ (UIViewController *)classReferenceAnalyzerForClass:(Class)cls;

// 对象内存分析
+ (UIViewController *)objectMemoryAnalyzerForObject:(id)object;

// 运行时分析入口
+ (UIViewController *)runtimeAnalysisForObject:(id)object;

- (NSDictionary *)analyzeClass:(Class)cls;
- (NSDictionary *)analyzeObject:(id)object;

@end