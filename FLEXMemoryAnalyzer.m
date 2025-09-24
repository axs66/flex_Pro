//
//  FLEXMemoryAnalyzer.m
//  FLEX
//
//  Created from RuntimeBrowser functionalities.
//

#import "FLEXMemoryAnalyzer.h"
#import <objc/runtime.h>
#import <malloc/malloc.h>

@implementation FLEXMemoryAnalyzer

+ (instancetype)sharedAnalyzer {
    static FLEXMemoryAnalyzer *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (NSDictionary *)getAllClassesMemoryUsage {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    // 获取所有类
    int numClasses;
    Class *classes = NULL;
    
    numClasses = objc_getClassList(NULL, 0);
    if (numClasses > 0) {
        classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);
        
        for (int i = 0; i < numClasses; i++) {
            Class cls = classes[i];
            NSString *className = NSStringFromClass(cls);
            
            // 获取类的实例大小
            size_t instanceSize = class_getInstanceSize(cls);
            result[className] = @(instanceSize);
        }
        
        free(classes);
    }
    
    return result;
}

@end