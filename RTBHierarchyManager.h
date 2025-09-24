#import <Foundation/Foundation.h>

@interface RTBHierarchyManager : NSObject

+ (instancetype)sharedInstance;

// 构建整个类层次体系
- (void)buildClassHierarchy;

// 获取指定类的子类
- (NSArray<Class> *)subclassesOf:(Class)parentClass;

// 获取指定类的完整继承链
- (NSArray<Class> *)classHierarchyForClass:(Class)cls;

// 类别/协议分组
- (NSDictionary<NSString*, NSArray<Class>*> *)classesGroupedByPrefix;
- (NSDictionary<NSString*, NSArray<Class>*> *)classesGroupedByFramework;

@end