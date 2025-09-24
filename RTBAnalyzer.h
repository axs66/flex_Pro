#import <Foundation/Foundation.h>
#import "RTBMethodInfo.h"

@interface RTBAnalyzerResult : NSObject

@property (nonatomic, copy) NSString *className;
@property (nonatomic, assign) NSInteger methodCount;
@property (nonatomic, assign) NSInteger propertyCount;
@property (nonatomic, assign) NSInteger instanceSize;
@property (nonatomic, assign) NSInteger ivarCount;
@property (nonatomic, assign) NSInteger instanceMethodCount;
@property (nonatomic, assign) NSInteger classMethodCount;
@property (nonatomic, assign) NSInteger protocolCount;

@end

@interface RTBAnalyzer : NSObject

+ (instancetype)sharedAnalyzer;

// 类分析
- (RTBAnalyzerResult *)analyzeClass:(Class)cls;
- (NSArray<RTBAnalyzerResult *> *)analyzeClassesWithPrefix:(NSString *)prefix;

// 框架分析
- (NSDictionary<NSString*, NSNumber*> *)classCountByFramework;
- (NSDictionary<NSString*, NSNumber*> *)methodCountByFramework;

// 方法分析
- (NSDictionary<NSNumber*, NSNumber*> *)methodCountByCategory:(Class)cls;
- (NSArray<RTBMethodInfo *> *)overriddenMethodsInClass:(Class)cls;
- (NSArray<RTBMethodInfo *> *)methodsAddedByClass:(Class)cls;

@end