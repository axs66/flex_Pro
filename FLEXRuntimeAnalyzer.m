#import "FLEXRuntimeAnalyzer.h"
#import <objc/runtime.h>
#import "RTBAnalyzer.h"

@implementation FLEXRuntimeAnalyzer

+ (instancetype)sharedAnalyzer {
    static FLEXRuntimeAnalyzer *analyzer = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        analyzer = [[self alloc] init];
    });
    return analyzer;
}

- (FLEXRuntimeAnalyzerResult *)analyzeAllClasses {
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    
    FLEXRuntimeAnalyzerResult *result = [[FLEXRuntimeAnalyzerResult alloc] init];
    result.totalClassCount = count;
    
    NSMutableArray *allClasses = [NSMutableArray arrayWithCapacity:count];
    NSUInteger totalMethodCount = 0;
    NSUInteger totalPropertyCount = 0;
    NSUInteger totalProtocolCount = 0;
    
    // 修改为使用 RTBAnalyzer
    for (unsigned int i = 0; i < count; i++) {
        Class cls = classes[i];
        RTBAnalyzerResult *analyzerResult = [[RTBAnalyzer sharedAnalyzer] analyzeClass:cls];
        
        totalMethodCount += analyzerResult.methodCount;
        totalPropertyCount += analyzerResult.propertyCount;
        totalProtocolCount += analyzerResult.protocolCount;
        
        [allClasses addObject:cls];
    }
    
    free(classes);
    
    result.classes = allClasses;
    result.totalMethodCount = totalMethodCount;
    result.totalPropertyCount = totalPropertyCount;
    result.totalProtocolCount = totalProtocolCount;
    
    // 按大小和方法数排序类
    result.classesBySize = [self sortClassesBySize:allClasses];
    result.classesByMethodCount = [self sortClassesByMethodCount:allClasses];
    
    return result;
}

- (FLEXRuntimeAnalyzerResult *)analyzeClassesWithPrefix:(NSString *)prefix {
    if (!prefix.length) {
        return [self analyzeAllClasses];
    }
    
    FLEXRuntimeAnalyzerResult *fullResult = [self analyzeAllClasses];
    NSMutableArray *filteredClasses = [NSMutableArray array];
    
    for (Class cls in fullResult.classes) {
        NSString *className = NSStringFromClass(cls);
        if ([className hasPrefix:prefix]) {
            [filteredClasses addObject:cls];
        }
    }
    
    FLEXRuntimeAnalyzerResult *result = [[FLEXRuntimeAnalyzerResult alloc] init];
    result.classes = filteredClasses;
    result.totalClassCount = filteredClasses.count;
    
    // 重新计算过滤后类的统计数据
    NSUInteger totalMethodCount = 0;
    NSUInteger totalPropertyCount = 0;
    NSUInteger totalProtocolCount = 0;
    
    for (Class cls in filteredClasses) {
        RTBAnalyzerResult *analyzerResult = [[RTBAnalyzer sharedAnalyzer] analyzeClass:cls];
        
        totalMethodCount += analyzerResult.methodCount;
        totalPropertyCount += analyzerResult.propertyCount;
        totalProtocolCount += analyzerResult.protocolCount;
    }
    
    result.totalMethodCount = totalMethodCount;
    result.totalPropertyCount = totalPropertyCount;
    result.totalProtocolCount = totalProtocolCount;
    
    result.classesBySize = [self sortClassesBySize:filteredClasses];
    result.classesByMethodCount = [self sortClassesByMethodCount:filteredClasses];
    
    return result;
}

- (FLEXRuntimeAnalyzerResult *)analyzeClass:(Class)aClass {
    if (!aClass) {
        return nil;
    }
    
    FLEXRuntimeAnalyzerResult *result = [[FLEXRuntimeAnalyzerResult alloc] init];
    result.classes = @[aClass];
    result.totalClassCount = 1;
    
    RTBAnalyzerResult *analyzerResult = [[RTBAnalyzer sharedAnalyzer] analyzeClass:aClass];
    
    result.totalMethodCount = analyzerResult.methodCount;
    result.totalPropertyCount = analyzerResult.propertyCount;
    result.totalProtocolCount = analyzerResult.protocolCount;
    
    return result;
}

- (NSArray *)buildClassHierarchyForClass:(Class)aClass {
    NSMutableArray *hierarchy = [NSMutableArray array];
    Class currentClass = aClass;
    
    while (currentClass) {
        [hierarchy addObject:currentClass];
        currentClass = class_getSuperclass(currentClass);
    }
    
    return hierarchy;
}

- (NSDictionary *)calculateMethodCountsForClass:(Class)aClass {
    if (!aClass) {
        return @{};
    }
    
    // 将 RTBClassAnalyzer 替换为 RTBAnalyzer
    // 原代码:
    // RTBClassAnalyzer *analyzer = [[RTBClassAnalyzer alloc] initWithClass:aClass];
    // [analyzer analyze];
    
    // 修改为:
    RTBAnalyzer *analyzer = [RTBAnalyzer sharedAnalyzer];
    RTBAnalyzerResult *result = [analyzer analyzeClass:aClass];
    
    // 属性名称也需要调整，RTBAnalyzerResult 中的属性名称与之前不同
    return @{
        @"instanceMethods": @(result.instanceMethodCount),
        @"classMethods": @(result.classMethodCount),
        @"properties": @(result.propertyCount),
        @"protocols": @(result.protocolCount)
    };
}

- (NSArray *)findClassesConformingToProtocol:(Protocol *)protocol {
    if (!protocol) {
        return @[];
    }
    
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    NSMutableArray *conformingClasses = [NSMutableArray array];
    
    for (unsigned int i = 0; i < count; i++) {
        Class cls = classes[i];
        if (class_conformsToProtocol(cls, protocol)) {
            [conformingClasses addObject:cls];
        }
    }
    
    free(classes);
    return conformingClasses;
}

#pragma mark - Helper Methods

- (NSArray *)sortClassesBySize:(NSArray *)classes {
    return [classes sortedArrayUsingComparator:^NSComparisonResult(Class cls1, Class cls2) {
        NSUInteger size1 = class_getInstanceSize(cls1);
        NSUInteger size2 = class_getInstanceSize(cls2);
        
        if (size1 > size2) {
            return NSOrderedAscending;
        } else if (size1 < size2) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];
}

- (NSArray *)sortClassesByMethodCount:(NSArray *)classes {
    return [classes sortedArrayUsingComparator:^NSComparisonResult(Class cls1, Class cls2) {
        RTBAnalyzerResult *analyzer1 = [[RTBAnalyzer sharedAnalyzer] analyzeClass:cls1];
        RTBAnalyzerResult *analyzer2 = [[RTBAnalyzer sharedAnalyzer] analyzeClass:cls2];
        
        NSUInteger count1 = analyzer1.methodCount;
        NSUInteger count2 = analyzer2.methodCount;
        
        if (count1 > count2) {
            return NSOrderedAscending;
        } else if (count1 < count2) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];
}

@end

@implementation FLEXRuntimeAnalyzerResult
@end