#import "RTBHierarchyManager.h"
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>

@interface RTBHierarchyManager()
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSMutableArray<Class>*> *hierarchyCache;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSString*> *classToFrameworkCache;
@property (nonatomic, strong) NSArray<Class> *allClasses;
@end

@implementation RTBHierarchyManager

+ (instancetype)sharedInstance {
    static RTBHierarchyManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _hierarchyCache = [NSMutableDictionary dictionary];
        _classToFrameworkCache = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)buildClassHierarchy {
    // 获取所有类
    unsigned int classCount = 0;
    Class *classList = objc_copyClassList(&classCount);
    NSMutableArray *classes = [NSMutableArray array];
    
    // 创建基本分类
    for (unsigned int i = 0; i < classCount; i++) {
        Class cls = classList[i];
        [classes addObject:cls];
        
        // 缓存类所属的框架
        [self cacheFrameworkForClass:cls];
        
        // 构建层次结构
        Class superCls = class_getSuperclass(cls);
        if (superCls) {
            NSString *superClassName = NSStringFromClass(superCls);
            if (!_hierarchyCache[superClassName]) {
                _hierarchyCache[superClassName] = [NSMutableArray array];
            }
            [_hierarchyCache[superClassName] addObject:cls];
        }
    }
    
    free(classList);
    _allClasses = [classes copy];
}

- (void)cacheFrameworkForClass:(Class)cls {
    NSString *className = NSStringFromClass(cls);
    if (_classToFrameworkCache[className]) return;
    
    Dl_info info;
    if (dladdr((__bridge const void *)cls, &info) && info.dli_fname) {
        NSString *imagePath = [NSString stringWithUTF8String:info.dli_fname];
        NSString *frameworkName = [[imagePath lastPathComponent] stringByDeletingPathExtension];
        _classToFrameworkCache[className] = frameworkName;
    } else {
        _classToFrameworkCache[className] = @"Unknown";
    }
}

- (NSArray<Class> *)subclassesOf:(Class)parentClass {
    NSString *className = NSStringFromClass(parentClass);
    return _hierarchyCache[className] ?: @[];
}

- (NSArray<Class> *)classHierarchyForClass:(Class)cls {
    NSMutableArray<Class> *hierarchy = [NSMutableArray array];
    Class currentClass = cls;
    
    while (currentClass) {
        [hierarchy addObject:currentClass];
        currentClass = class_getSuperclass(currentClass);
    }
    
    return [hierarchy copy];
}

- (NSDictionary<NSString*, NSArray<Class>*> *)classesGroupedByPrefix {
    NSMutableDictionary<NSString*, NSMutableArray<Class>*> *result = [NSMutableDictionary dictionary];
    
    for (Class cls in self.allClasses) {
        NSString *className = NSStringFromClass(cls);
        NSString *prefix = [self prefixForClassName:className];
        
        if (!result[prefix]) {
            result[prefix] = [NSMutableArray array];
        }
        [result[prefix] addObject:cls];
    }
    
    return result;
}

- (NSDictionary<NSString*, NSArray<Class>*> *)classesGroupedByFramework {
    NSMutableDictionary<NSString*, NSMutableArray<Class>*> *result = [NSMutableDictionary dictionary];
    
    for (Class cls in self.allClasses) {
        NSString *className = NSStringFromClass(cls);
        NSString *framework = _classToFrameworkCache[className] ?: @"Unknown";
        
        if (!result[framework]) {
            result[framework] = [NSMutableArray array];
        }
        [result[framework] addObject:cls];
    }
    
    return result;
}

- (NSString *)prefixForClassName:(NSString *)className {
    // 提取类名前缀 (如NS, UI, CA等)
    NSArray<NSString*> *commonPrefixes = @[@"NS", @"UI", @"CA", @"AV", @"CG", @"CF", @"CI", @"MK", @"SK"];
    
    for (NSString *prefix in commonPrefixes) {
        if ([className hasPrefix:prefix] && className.length > prefix.length) {
            return prefix;
        }
    }
    
    // 自定义处理其他前缀
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[A-Z]{2,3}" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:className options:0 range:NSMakeRange(0, className.length)];
    
    if (match) {
        return [className substringWithRange:match.range];
    }
    
    return @"Other";
}

@end