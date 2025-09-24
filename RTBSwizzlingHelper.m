#import "RTBSwizzlingHelper.h"
#import <objc/runtime.h>

@implementation RTBSwizzlingHelper

+ (void)swizzleMethodWithOriginSel:(SEL)oriSel
                         oriMethod:(Method)oriMethod
                       swizzledSel:(SEL)swizzledSel
                    swizzledMethod:(Method)swizzledMethod
                            class:(Class)cls {
    BOOL didAddMethod = class_addMethod(cls, oriSel, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(cls, swizzledSel, method_getImplementation(oriMethod), method_getTypeEncoding(oriMethod));
    } else {
        method_exchangeImplementations(oriMethod, swizzledMethod);
    }
}

+ (void)swizzleClassMethodWithOriginSel:(SEL)oriSel swizzledSel:(SEL)swiSel class:(Class)cls {
    Class metaCls = object_getClass(cls);
    Method originMethod = class_getClassMethod(metaCls, oriSel);
    Method swizzledMethod = class_getClassMethod(metaCls, swiSel);
    
    [self swizzleMethodWithOriginSel:oriSel 
                          oriMethod:originMethod 
                        swizzledSel:swiSel 
                     swizzledMethod:swizzledMethod 
                             class:metaCls];
}

+ (void)swizzleInstanceMethodWithOriginSel:(SEL)oriSel swizzledSel:(SEL)swiSel class:(Class)cls {
    Method originMethod = class_getInstanceMethod(cls, oriSel);
    Method swizzledMethod = class_getInstanceMethod(cls, swiSel);
    
    [self swizzleMethodWithOriginSel:oriSel 
                          oriMethod:originMethod 
                        swizzledSel:swiSel 
                     swizzledMethod:swizzledMethod 
                             class:cls];
}

@end