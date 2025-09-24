#import <Foundation/Foundation.h>

@class FLEXRuntimeAnalyzerResult;

@interface FLEXRuntimeAnalyzer : NSObject

+ (instancetype)sharedAnalyzer;

// 分析所有已加载类
- (FLEXRuntimeAnalyzerResult *)analyzeAllClasses;

// 分析特定前缀的类
- (FLEXRuntimeAnalyzerResult *)analyzeClassesWithPrefix:(NSString *)prefix;

// 分析特定类
- (FLEXRuntimeAnalyzerResult *)analyzeClass:(Class)aClass;

// 分析类的继承层次
- (NSArray *)buildClassHierarchyForClass:(Class)aClass;

// 计算类的方法数量
- (NSDictionary *)calculateMethodCountsForClass:(Class)aClass;

// 查找所有遵循特定协议的类
- (NSArray *)findClassesConformingToProtocol:(Protocol *)protocol;

@end

@interface FLEXRuntimeAnalyzerResult : NSObject

@property (nonatomic, strong) NSArray *classes;
@property (nonatomic, assign) NSUInteger totalClassCount;
@property (nonatomic, assign) NSUInteger totalMethodCount;
@property (nonatomic, assign) NSUInteger totalPropertyCount;
@property (nonatomic, assign) NSUInteger totalProtocolCount;
@property (nonatomic, strong) NSArray *classesBySize;
@property (nonatomic, strong) NSArray *classesByMethodCount;

@end