#import "RTBRuntime.h"
#import "RTBClass.h"
#import "RTBRuntimeHeader.h"
#import "RTBClassDisplayVC.h"
#import "RTBObjectsTVC.h"
#import "NSString+SyntaxColoring.h"
#import <objc/runtime.h>

// RTBRuntime相关扩展方法
@implementation RTBRuntime (DYYY_Additions)

+ (void)DYYY_analyzeClass:(Class)cls {
    // 使用直接的runtime API而不是私有方法
    unsigned int count;
    Method *methods = class_copyMethodList(cls, &count);
    free(methods); // 仅分析，不需要实际使用methods
}

+ (NSString *)DYYY_generateHeaderForClass:(Class)cls {
    // 使用公开的RTBRuntimeHeader API
    BOOL displayPropertiesDefaultValues = NO;
    return [RTBRuntimeHeader headerForClass:cls displayPropertiesDefaultValues:displayPropertiesDefaultValues];
}

+ (void)DYYY_saveHeaderForClass:(Class)cls toPath:(NSString *)path {
    NSString *header = [self DYYY_generateHeaderForClass:cls];
    if (header) {
        [header writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

@end

// RTBClassDisplayVC的扩展实现
@implementation RTBClassDisplayVC (DYYY_Additions)

- (void)DYYY_displayClassInfo:(Class)cls {
    // 设置类名，让RTBClassDisplayVC使用自己的机制显示类信息
    self.className = NSStringFromClass(cls);
    
    // 手动触发显示加载
    if ([self respondsToSelector:@selector(viewWillAppear:)]) {
        [self viewWillAppear:NO];
    }
    
    if ([self respondsToSelector:@selector(viewDidAppear:)]) {
        [self viewDidAppear:NO];
    }
}

- (void)DYYY_displayObject:(id)object {
    if (object) {
        [self DYYY_displayClassInfo:[object class]];
    }
}

@end

// RTBObjectsTVC的扩展实现
@implementation RTBObjectsTVC (DYYY_Additions)

- (void)DYYY_inspectObject:(id)object {
    if (object) {
        // 使用KVC设置属性，避免直接访问私有属性
        [self setValue:object forKey:@"object"];
        
        // 刷新表视图
        UITableView *tableView = [self valueForKey:@"tableView"];
        if (tableView) {
            [tableView reloadData];
        }
    }
}

- (NSArray *)DYYY_getAllMethodsForObject:(id)object {
    if (!object) return @[];
    
    unsigned int count;
    Method *methods = class_copyMethodList([object class], &count);
    NSMutableArray *methodNames = [NSMutableArray arrayWithCapacity:count];
    
    for (unsigned int i = 0; i < count; i++) {
        SEL selector = method_getName(methods[i]);
        [methodNames addObject:NSStringFromSelector(selector)];
    }
    
    free(methods);
    return methodNames;
}

@end