#import "FLEXClassSearcher.h"
#import "FLEXRuntimeClient.h"
#import <objc/runtime.h>

@implementation FLEXClassSearcher

+ (instancetype)sharedSearcher {
    static FLEXClassSearcher *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (NSArray *)classesMatchingPattern:(NSString *)searchText {
    if (searchText.length == 0) return @[];
    
    NSMutableArray *matchingClasses = [NSMutableArray array];
    NSString *pattern = [searchText lowercaseString];
    
    // 获取所有类
    unsigned int classCount;
    Class *classes = objc_copyClassList(&classCount);
    
    if (classes) {
        for (unsigned int i = 0; i < classCount; i++) {
            NSString *className = NSStringFromClass(classes[i]);
            if ([[className lowercaseString] containsString:pattern]) {
                [matchingClasses addObject:className];
            }
        }
        free(classes);
    }
    
    return [matchingClasses sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (NSArray *)methodsMatchingPattern:(NSString *)searchText inClass:(NSString *)className {
    if (searchText.length == 0 || className.length == 0) return @[];
    
    Class cls = NSClassFromString(className);
    if (!cls) return @[];
    
    NSMutableArray *matchingMethods = [NSMutableArray array];
    NSString *pattern = [searchText lowercaseString];
    
    // 实例方法
    unsigned int methodCount;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    if (methods) {
        for (unsigned int i = 0; i < methodCount; i++) {
            SEL selector = method_getName(methods[i]);
            NSString *methodName = NSStringFromSelector(selector);
            if ([[methodName lowercaseString] containsString:pattern]) {
                [matchingMethods addObject:methodName];
            }
        }
        free(methods);
    }
    
    // 类方法
    methods = class_copyMethodList(object_getClass(cls), &methodCount);
    
    if (methods) {
        for (unsigned int i = 0; i < methodCount; i++) {
            SEL selector = method_getName(methods[i]);
            NSString *methodName = [NSString stringWithFormat:@"+ %@", NSStringFromSelector(selector)];
            if ([[methodName lowercaseString] containsString:pattern]) {
                [matchingMethods addObject:methodName];
            }
        }
        free(methods);
    }
    
    return [matchingMethods sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

@end