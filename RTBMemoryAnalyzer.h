#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface RTBMemoryAnalyzer : NSObject

// 分析对象内存布局
- (NSDictionary *)analyzeObjectMemoryLayout:(id)object;

// 获取对象中 ivar 的值
- (id)getIvarValue:(Ivar)ivar fromObject:(id)object;

// 分析类的内存布局
- (NSDictionary *)analyzeClassMemoryLayout:(Class)cls;

// 获取对象的强引用
- (NSArray *)getObjectStrongReferences:(id)object;

@end