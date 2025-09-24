#import <Foundation/Foundation.h>

@interface RTBClassAnalyzer : NSObject

// 类继承关系分析
- (NSDictionary *)analyzeClassHierarchy:(Class)cls;
- (NSArray *)getSubclasses:(Class)cls;
- (NSArray *)getSuperclassChain:(Class)cls;

// 协议遵循分析
- (NSArray *)analyzeProtocolConformance:(Class)cls;
- (NSDictionary *)getProtocolMethodImplementations:(Class)cls;

// 类依赖分析
- (NSDictionary *)analyzeClassDependencies:(Class)cls;
- (NSArray *)getAssociatedClasses:(Class)cls;

@end