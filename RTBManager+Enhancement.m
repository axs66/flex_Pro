#import "RTBManager.h"
#import "RTBHierarchyManager.h"
#import "RTBMethodInfo.h"
#import "RTBAnalyzer.h"
#import "RTBMethodTracker.h"
#import <objc/runtime.h>

@interface RTBManager (Enhancement)

// 类层次分析
- (NSArray<Class> *)subclassesOf:(Class)parentClass;
- (NSArray<Class> *)classHierarchyForClass:(Class)cls;

// 方法分析
- (NSArray<RTBMethodInfo *> *)methodInfosForClass:(Class)cls;
- (NSArray<RTBMethodInfo *> *)methodsAddedInClass:(Class)cls;
- (NSArray<RTBMethodInfo *> *)overriddenMethodsInClass:(Class)cls;

// 框架分析
- (NSDictionary<NSString*, NSArray<Class>*> *)classesGroupedByFramework;
- (NSDictionary<NSString*, NSNumber*> *)methodCountByFramework;

// 方法跟踪
- (void)startTrackingClass:(Class)cls;
- (void)stopTrackingClass:(Class)cls;
- (NSArray<RTBMethodTrackerRecord *> *)recentMethodCalls;
- (NSArray<RTBMethodTrackerRecord *> *)methodCallsWithDurationAbove:(NSTimeInterval)threshold;

@end

@implementation RTBManager (Enhancement)

#pragma mark - Class Hierarchy Analysis

- (void)prepareEnhancedFeatures {
    // 确保层次结构已构建
    [[RTBHierarchyManager sharedInstance] buildClassHierarchy];
}

- (NSArray<Class> *)subclassesOf:(Class)parentClass {
    return [[RTBHierarchyManager sharedInstance] subclassesOf:parentClass];
}

- (NSArray<Class> *)classHierarchyForClass:(Class)cls {
    return [[RTBHierarchyManager sharedInstance] classHierarchyForClass:cls];
}

#pragma mark - Method Analysis

- (NSArray<RTBMethodInfo *> *)methodInfosForClass:(Class)cls {
    NSMutableArray<RTBMethodInfo *> *methodInfos = [NSMutableArray array];
    
    // 获取实例方法
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        RTBMethodInfo *info = [RTBMethodInfo methodInfoWithMethod:methods[i] 
                                                         isClass:NO 
                                                  declaringClass:cls];
        [methodInfos addObject:info];
    }
    
    free(methods);
    
    // 获取类方法
    methodCount = 0;
    methods = class_copyMethodList(object_getClass(cls), &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        RTBMethodInfo *info = [RTBMethodInfo methodInfoWithMethod:methods[i] 
                                                         isClass:YES 
                                                  declaringClass:cls];
        [methodInfos addObject:info];
    }
    
    free(methods);
    
    return methodInfos;
}

- (NSArray<RTBMethodInfo *> *)methodsAddedInClass:(Class)cls {
    return [[RTBAnalyzer sharedAnalyzer] methodsAddedByClass:cls];
}

- (NSArray<RTBMethodInfo *> *)overriddenMethodsInClass:(Class)cls {
    return [[RTBAnalyzer sharedAnalyzer] overriddenMethodsInClass:cls];
}

#pragma mark - Framework Analysis

- (NSDictionary<NSString*, NSArray<Class>*> *)classesGroupedByFramework {
    return [[RTBHierarchyManager sharedInstance] classesGroupedByFramework];
}

- (NSDictionary<NSString*, NSNumber*> *)methodCountByFramework {
    return [[RTBAnalyzer sharedAnalyzer] methodCountByFramework];
}

#pragma mark - Method Tracking

- (void)startTrackingClass:(Class)cls {
    [[RTBMethodTracker sharedTracker] startTrackingClass:cls];
}

- (void)stopTrackingClass:(Class)cls {
    [[RTBMethodTracker sharedTracker] stopTrackingClass:cls];
}

- (void)startTrackingClassesWithPrefix:(NSString *)prefix {
    [[RTBMethodTracker sharedTracker] startTrackingClassesWithPrefix:prefix];
}

- (void)stopTrackingAllClasses {
    [[RTBMethodTracker sharedTracker] stopTrackingAllClasses];
}

- (NSArray<RTBMethodTrackerRecord *> *)recentMethodCalls {
    return [[RTBMethodTracker sharedTracker] recentCalls];
}

- (NSArray<RTBMethodTrackerRecord *> *)methodCallsWithDurationAbove:(NSTimeInterval)threshold {
    return [[RTBMethodTracker sharedTracker] callsWithDurationAbove:threshold];
}

@end