#import <Foundation/Foundation.h>

@interface RTBClassReferenceAnalyzer : NSObject

// 获取类的引用关系
+ (NSDictionary *)getClassDependencies:(Class)cls;

// 分析类的引用关系树
+ (NSDictionary *)buildClassDependencyTree:(Class)rootClass maxDepth:(NSInteger)depth;

// 获取类的所有子类
+ (NSArray *)getSubclasses:(Class)parentClass;

// 检查循环引用风险
+ (NSDictionary *)checkCyclicReferences:(Class)cls;

@end