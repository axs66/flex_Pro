//
//  NSObject+Doraemon.m
//  FLEX_Pro
//
//  Created on 2025/6/9.
//

#import "NSObject+Doraemon.h"
#import <objc/runtime.h>

@implementation NSObject (Doraemon)

+ (void)doraemon_swizzleInstanceMethodWithOriginSel:(SEL)originalSel swizzledSel:(SEL)swizzledSel {
    Class cls = self;
    
    Method originalMethod = class_getInstanceMethod(cls, originalSel);
    Method swizzledMethod = class_getInstanceMethod(cls, swizzledSel);
    
    BOOL didAddMethod = class_addMethod(cls,
                                        originalSel,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(cls,
                            swizzledSel,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

+ (void)doraemon_swizzleClassMethodWithOriginSel:(SEL)oriSel swizzledSel:(SEL)swiSel {
    Class cls = object_getClass(self);
    
    Method originalMethod = class_getClassMethod(cls, oriSel);
    Method swizzledMethod = class_getClassMethod(cls, swiSel);
    
    BOOL didAddMethod = class_addMethod(cls,
                                        oriSel,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(cls,
                            swiSel,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}
@end