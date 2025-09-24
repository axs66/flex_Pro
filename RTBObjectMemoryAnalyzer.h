#import <Foundation/Foundation.h>

@interface RTBObjectMemoryAnalyzer : NSObject

// 分析对象内存布局
+ (NSDictionary *)analyzeObjectMemoryLayout:(id)object;

// 获取对象占用的内存大小
+ (NSUInteger)getObjectMemorySize:(id)object;

// 获取对象的所有引用
+ (NSDictionary *)getObjectReferences:(id)object;

// 分析对象内存中的值
+ (NSDictionary *)inspectObjectMemoryValues:(id)object;

@end