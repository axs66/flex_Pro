//
//  FLEXHeapEnumerator.h
//  Flipboard
//
//  Created by Ryan Olson on 5/28/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 堆枚举回调块
/// @param object 发现的对象实例
/// @param actualClass 对象的实际类
typedef void (^FLEXHeapEnumeratorBlock)(__unsafe_unretained id object, __unsafe_unretained Class actualClass);

/// 堆内存枚举器，用于安全地遍历堆中的所有活动对象
@interface FLEXHeapEnumerator : NSObject

/// 枚举堆中的所有活动对象
/// @param block 每发现一个对象时调用的回调块
+ (void)enumerateLiveObjectsUsingBlock:(FLEXHeapEnumeratorBlock)block;

/// 获取指定类名的所有实例
/// @param className 目标类名
/// @return 该类的所有实例数组
+ (NSArray *)instancesOfClassWithName:(NSString *)className;

/// 获取指定类的所有实例
/// @param targetClass 目标类
/// @return 该类的所有实例数组
+ (NSArray *)instancesOfClass:(Class)targetClass;

/// 获取指定类的实例数量
/// @param targetClass 目标类
/// @return 实例数量
+ (NSUInteger)instanceCountOfClass:(Class)targetClass;

/// 获取所有类的实例数量统计
/// @return 类名到实例数量的映射字典
+ (NSDictionary<NSString *, NSNumber *> *)instanceCountsByClassName;

/// 获取所有有活动实例的类
/// @return 按类名排序的类数组
+ (NSArray<Class> *)allLiveClasses;

/// 计算所有对象的总内存占用
/// @return 总内存大小（字节）
+ (size_t)totalMemoryFootprint;

/// 获取各类的内存占用统计
/// @return 类名到内存大小的映射字典
+ (NSDictionary<NSString *, NSNumber *> *)memoryFootprintByClassName;

@end

NS_ASSUME_NONNULL_END
