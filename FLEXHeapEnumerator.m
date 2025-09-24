//
//  FLEXHeapEnumerator.m
//  Flipboard
//
//  Created by Ryan Olson on 5/28/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXHeapEnumerator.h"
#import "FLEXRuntimeUtility.h"
#import <malloc/malloc.h>
#import <mach/mach.h>
#import <objc/runtime.h>

typedef struct {
    FLEXHeapEnumeratorBlock block;
    unsigned int count;
    unsigned int maxCount;
} FLEXHeapEnumerationContext;

@implementation FLEXHeapEnumerator

+ (void)enumerateLiveObjectsUsingBlock:(FLEXHeapEnumeratorBlock)block {
    if (!block) {
        return;
    }
    
    // 创建枚举上下文
    FLEXHeapEnumerationContext context = {
        .block = block,
        .count = 0,
        .maxCount = 10000 // 限制最大枚举数量
    };
    
    // 获取所有内存区域
    vm_address_t *zones = NULL;
    unsigned int zoneCount = 0;
    
    kern_return_t result = malloc_get_all_zones(0, NULL, &zones, &zoneCount);
    if (result != KERN_SUCCESS) {
        return;
    }
    
    // 枚举每个内存区域
    for (unsigned int i = 0; i < zoneCount && context.count < context.maxCount; i++) {
        malloc_zone_t *zone = (malloc_zone_t *)zones[i];
        if (!zone || !zone->introspect || !zone->introspect->enumerator) {
            continue;
        }
        
        @try {
            zone->introspect->enumerator(mach_task_self(), &context, MALLOC_PTR_IN_USE_RANGE_TYPE, 
                                       zones[i], NULL, heapEnumerationCallback);
        } @catch (NSException *exception) {
            // 忽略枚举过程中的异常
            NSLog(@"FLEXHeapEnumerator: Exception during enumeration: %@", exception);
            continue;
        }
    }
}

static void heapEnumerationCallback(task_t task, void *context, unsigned type, 
                                   vm_range_t *ranges, unsigned count) {
    FLEXHeapEnumerationContext *enumContext = (FLEXHeapEnumerationContext *)context;
    
    for (unsigned i = 0; i < count && enumContext->count < enumContext->maxCount; i++) {
        vm_range_t range = ranges[i];
        
        // 检查地址范围是否有效
        if (range.size < sizeof(void *)) {
            continue;
        }
        
        // 尝试读取对象指针
        void *ptr = (void *)range.address;
        
        @try {
            // 验证是否为有效的Objective-C对象
            if ([FLEXRuntimeUtility pointerIsValidObjcObject:ptr]) {
                id obj = (__bridge id)ptr;
                Class actualClass = object_getClass(obj);
                
                if (actualClass) {
                    enumContext->block(obj, actualClass);
                    enumContext->count++;
                }
            }
        } @catch (NSException *exception) {
            // 忽略无效对象访问异常
            continue;
        }
    }
}

+ (NSArray *)instancesOfClassWithName:(NSString *)className {
    if (!className || className.length == 0) {
        return @[];
    }
    
    Class targetClass = NSClassFromString(className);
    if (!targetClass) {
        return @[];
    }
    
    return [self instancesOfClass:targetClass];
}

+ (NSArray *)instancesOfClass:(Class)targetClass {
    if (!targetClass) {
        return @[];
    }
    
    NSMutableArray *instances = [NSMutableArray array];
    
    [self enumerateLiveObjectsUsingBlock:^(__unsafe_unretained id object, __unsafe_unretained Class actualClass) {
        if ([object isKindOfClass:targetClass]) {
            [instances addObject:object];
            
            // 限制数量以避免内存问题
            if (instances.count >= 1000) {
                return;
            }
        }
    }];
    
    return [instances copy];
}

+ (NSUInteger)instanceCountOfClass:(Class)targetClass {
    if (!targetClass) {
        return 0;
    }
    
    __block NSUInteger count = 0;
    
    [self enumerateLiveObjectsUsingBlock:^(__unsafe_unretained id object, __unsafe_unretained Class actualClass) {
        if ([object isKindOfClass:targetClass]) {
            count++;
        }
    }];
    
    return count;
}

+ (NSDictionary<NSString *, NSNumber *> *)instanceCountsByClassName {
    // 将 NSMutableString * 改为 NSNumber *
    NSMutableDictionary<NSString *, NSNumber *> *counts = [NSMutableDictionary dictionary];
    
    [self enumerateLiveObjectsUsingBlock:^(__unsafe_unretained id object, __unsafe_unretained Class actualClass) {
        NSString *className = NSStringFromClass(actualClass);
        if (className) {
            NSNumber *currentCount = counts[className];
            counts[className] = @(currentCount.unsignedIntegerValue + 1);
        }
    }];
    
    return [counts copy];
}

+ (NSArray<Class> *)allLiveClasses {
    NSMutableSet<Class> *classSet = [NSMutableSet set];
    
    [self enumerateLiveObjectsUsingBlock:^(__unsafe_unretained id object, __unsafe_unretained Class actualClass) {
        if (object && actualClass) {
            [classSet addObject:actualClass];
        }
    }];
    
    // 按照类名对类进行排序
    NSArray<Class> *sortedClasses = [[classSet allObjects] sortedArrayUsingComparator:^NSComparisonResult(Class cls1, Class cls2) {
        return [NSStringFromClass(cls1) compare:NSStringFromClass(cls2)];
    }];
    
    return sortedClasses;
}

+ (size_t)totalMemoryFootprint {
    __block size_t totalFootprint = 0;
    
    [self enumerateLiveObjectsUsingBlock:^(__unsafe_unretained id object, __unsafe_unretained Class actualClass) {
        totalFootprint += malloc_size((__bridge const void *)object);
    }];
    
    return totalFootprint;
}

+ (NSDictionary<NSString *, NSNumber *> *)memoryFootprintByClassName {
    NSMutableDictionary<NSString *, NSNumber *> *footprints = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSNumber *> *counts = [NSMutableDictionary dictionary];
    
    [self enumerateLiveObjectsUsingBlock:^(__unsafe_unretained id object, __unsafe_unretained Class actualClass) {
        NSString *className = NSStringFromClass(actualClass);
        size_t size = malloc_size((__bridge const void *)object);
        
        NSNumber *currentSize = footprints[className] ?: @0;
        footprints[className] = @(currentSize.longLongValue + size);
        
        NSNumber *currentCount = counts[className] ?: @0;
        counts[className] = @(currentCount.integerValue + 1);
    }];
    
    return [footprints copy];
}

@end
