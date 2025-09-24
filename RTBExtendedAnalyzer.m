#import "RTBExtendedAnalyzer.h"
#import <objc/runtime.h>
#import "RTBViewHierarchyAnalyzer.h"
#import "RTBViewHierarchyVC.h"
#import "RTBClassPerformanceAnalyzer.h"
#import "RTBObjectMemoryAnalyzer.h"
#import "RTBClassReferenceAnalyzer.h"
#import "RTBRuntimeController.h"

@implementation RTBExtendedAnalyzer

+ (instancetype)sharedAnalyzer {
    static RTBExtendedAnalyzer *analyzer = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        analyzer = [[self alloc] init];
    });
    return analyzer;
}

// 修复层次分析视图方法
+ (UIViewController *)viewHierarchyAnalyzerForView:(UIView *)view {
    RTBViewHierarchyVC *vc = [[RTBViewHierarchyVC alloc] init];
    
    // 设置视图层次控制器的根视图
    if ([vc respondsToSelector:@selector(setRootView:)]) {
        [vc performSelector:@selector(setRootView:) withObject:view];
    } else {
        // 回退方案：创建自定义视图
        UIView *container = [[UIView alloc] initWithFrame:vc.view.bounds];
        container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [container addSubview:view];
        view.center = CGPointMake(container.bounds.size.width / 2, container.bounds.size.height / 2);
        [vc.view addSubview:container];
    }
    
    vc.title = [NSString stringWithFormat:@"%@ 层次分析", NSStringFromClass([view class])];
    return vc;
}

+ (UIViewController *)performanceAnalyzerForClass:(Class)cls {
    UIViewController *vc = [[UIViewController alloc] init];
    UITableView *tableView = [[UITableView alloc] initWithFrame:vc.view.bounds style:UITableViewStyleGrouped];
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [vc.view addSubview:tableView];
    
    // 分析类性能
    NSDictionary *perfAnalysis = [RTBClassPerformanceAnalyzer analyzeMethodCallsForClass:cls];
    
    vc.title = [NSString stringWithFormat:@"%@ 性能分析", NSStringFromClass(cls)];
    
    // 添加数据到视图控制器
    NSLog(@"性能分析结果: %@", perfAnalysis);
    
    return vc;
}

// 修复类引用分析方法
+ (UIViewController *)classReferenceAnalyzerForClass:(Class)cls {
    UIViewController *vc = [[UIViewController alloc] init];
    UITableView *tableView = [[UITableView alloc] initWithFrame:vc.view.bounds style:UITableViewStyleGrouped];
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [vc.view addSubview:tableView];
    
    // 使用自己实现的分析方法，而不调用不存在的类方法
    NSDictionary *references = @{
        @"className": NSStringFromClass(cls),
        @"subclasses": [self findSubclassesOfClass:cls],
        @"instanceMethods": [self getMethodsForClass:cls isClassMethod:NO],
        @"classMethods": [self getMethodsForClass:cls isClassMethod:YES]
    };
    
    vc.title = [NSString stringWithFormat:@"%@ 引用分析", NSStringFromClass(cls)];
    
    // 添加数据到视图控制器
    NSLog(@"引用分析结果: %@", references);
    
    return vc;
}

// 辅助方法：获取类的方法列表
+ (NSArray *)getMethodsForClass:(Class)cls isClassMethod:(BOOL)isClassMethod {
    NSMutableArray *methodsList = [NSMutableArray array];
    
    unsigned int methodCount = 0;
    Method *methods = NULL;
    
    if (isClassMethod) {
        // 获取类方法 (实际上是元类的实例方法)
        methods = class_copyMethodList(object_getClass(cls), &methodCount);
    } else {
        // 获取实例方法
        methods = class_copyMethodList(cls, &methodCount);
    }
    
    if (methods) {
        for (unsigned int i = 0; i < methodCount; i++) {
            Method method = methods[i];
            SEL selector = method_getName(method);
            [methodsList addObject:NSStringFromSelector(selector)];
        }
        free(methods);
    }
    
    return methodsList;
}

// 辅助方法：查找子类
+ (NSArray *)findSubclassesOfClass:(Class)parentClass {
    NSMutableArray *subclasses = [NSMutableArray array];
    
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class cls = classes[i];
        Class superClass = cls;
        while (superClass && superClass != parentClass) {
            superClass = class_getSuperclass(superClass);
        }
        
        if (superClass == parentClass && cls != parentClass) {
            [subclasses addObject:NSStringFromClass(cls)];
        }
    }
    
    free(classes);
    return subclasses;
}

+ (UIViewController *)objectMemoryAnalyzerForObject:(id)object {
    UIViewController *vc = [[UIViewController alloc] init];
    UITableView *tableView = [[UITableView alloc] initWithFrame:vc.view.bounds style:UITableViewStyleGrouped];
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [vc.view addSubview:tableView];
    
    // 分析对象内存
    NSDictionary *memoryLayout = [RTBObjectMemoryAnalyzer analyzeObjectMemoryLayout:object];
    
    vc.title = [NSString stringWithFormat:@"%@ 内存分析", NSStringFromClass([object class])];
    
    // 添加数据到视图控制器
    NSLog(@"内存分析结果: %@", memoryLayout);
    
    return vc;
}

// 修复运行时分析方法 - 避免使用performSelector警告
+ (UIViewController *)runtimeAnalysisForObject:(id)object {
    if (!object) {
        return nil;
    }
    
    // 修复：直接创建视图控制器
    Class cls = [object class];
    UIViewController *vc = nil;
    
    // 直接创建基本视图控制器
    vc = [[UIViewController alloc] init];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, 280, 44)];
    label.text = [NSString stringWithFormat:@"分析 %@ 类", NSStringFromClass(cls)];
    label.textAlignment = NSTextAlignmentCenter;
    [vc.view addSubview:label];
    
    // 添加一个包含类信息的表格视图
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 150, vc.view.bounds.size.width, vc.view.bounds.size.height - 150) 
                                                         style:UITableViewStyleGrouped];
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [vc.view addSubview:tableView];
    
    // 使用我们自己的分析方法分析对象
    NSDictionary *analysis = [self.sharedAnalyzer analyzeObject:object];
    NSLog(@"运行时分析结果: %@", analysis);
    
    vc.title = [NSString stringWithFormat:@"%@ 运行时分析", NSStringFromClass(cls)];
    return vc;
}

// 保留原有的分析方法
- (NSDictionary *)analyzeClass:(Class)cls {
    if (!cls) return nil;
    
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    // 基本信息
    result[@"className"] = NSStringFromClass(cls);
    result[@"superClass"] = NSStringFromClass(class_getSuperclass(cls));
    
    // 分析方法
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    result[@"instanceMethodCount"] = @(methodCount);
    
    NSMutableArray *methodsInfo = [NSMutableArray array];
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        [methodsInfo addObject:@{
            @"name": NSStringFromSelector(method_getName(method)),
            @"encoding": @(method_getTypeEncoding(method))
        }];
    }
    result[@"instanceMethods"] = methodsInfo;
    free(methods);
    
    // 分析类方法
    methodCount = 0;
    methods = class_copyMethodList(object_getClass(cls), &methodCount);
    result[@"classMethodCount"] = @(methodCount);
    free(methods);
    
    // 分析属性
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    result[@"propertyCount"] = @(propertyCount);
    free(properties);
    
    // 分析协议
    unsigned int protocolCount = 0;
    Protocol * __unsafe_unretained *protocols = class_copyProtocolList(cls, &protocolCount);
    result[@"protocolCount"] = @(protocolCount);
    free(protocols);
    
    return result;
}

- (NSDictionary *)analyzeObject:(id)object {
    if (!object) return nil;
    
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    // 基本的对象分析
    Class cls = [object class];
    result[@"className"] = NSStringFromClass(cls);
    result[@"address"] = [NSString stringWithFormat:@"%p", object];
    
    // 内存大小
    result[@"instanceSize"] = @(class_getInstanceSize(cls));
    
    // 实例变量分析
    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    
    NSMutableArray *ivarInfo = [NSMutableArray array];
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        NSString *name = @(ivar_getName(ivar));
        NSString *type = @(ivar_getTypeEncoding(ivar));
        
        id value = nil;
        // 安全地尝试获取值
        @try {
            if ([type hasPrefix:@"@"]) { // 只有对象类型才尝试获取
                value = object_getIvar(object, ivar);
                if (value) {
                    value = [NSString stringWithFormat:@"%@ (%p)", [value class], value];
                } else {
                    value = @"nil";
                }
            } else {
                value = @"<非对象类型>";
            }
        } @catch (NSException *e) {
            value = @"<无法访问>";
        }
        
        [ivarInfo addObject:@{
            @"name": name,
            @"type": type,
            @"value": value ?: @"nil"
        }];
    }
    
    free(ivars);
    result[@"ivars"] = ivarInfo;
    
    return result;
}

@end