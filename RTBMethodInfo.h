#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef NS_ENUM(NSInteger, RTBMethodType) {
    RTBMethodTypeInstance,
    RTBMethodTypeClass,
    RTBMethodTypeProperty
};

typedef NS_ENUM(NSInteger, RTBMethodCategory) {
    RTBMethodCategoryLifecycle,    // init, dealloc等
    RTBMethodCategoryUIKit,        // UI相关方法
    RTBMethodCategoryAccessors,    // getter/setter
    RTBMethodCategoryFoundation,   // 标准库方法
    RTBMethodCategoryDelegate,     // 代理方法
    RTBMethodCategoryCustom        // 自定义方法
};

@interface RTBMethodInfo : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *signature;
@property (nonatomic, assign) RTBMethodType type;
@property (nonatomic, assign) RTBMethodCategory category;
@property (nonatomic, assign) Method method;
@property (nonatomic, assign) Class declaringClass;

+ (instancetype)methodInfoWithMethod:(Method)method 
                              isClass:(BOOL)isClass 
                       declaringClass:(Class)declaringClass;

// 方法实现地址
- (void *)implementation;

// 方法参数和返回类型
- (NSArray<NSString*> *)argumentTypes;
- (NSString *)returnType;

// 方法相关性分析
- (BOOL)isInitializer;
- (BOOL)isAccessor;
- (BOOL)isUIKit;
- (BOOL)isDelegateMethod;

// 比较
- (BOOL)isOverridingMethod:(RTBMethodInfo *)otherMethod;

@end