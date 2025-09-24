#import <Foundation/Foundation.h>
#import "RTBRuntime.h"
#import "RTBClassDisplayVC.h"
#import "RTBObjectsTVC.h"
#import "RTBViewHierarchyVC.h"

// RTBRuntime类别扩展
@interface RTBRuntime (DYYY_Additions)
+ (void)DYYY_analyzeClass:(Class)cls;
+ (NSString *)DYYY_generateHeaderForClass:(Class)cls;
+ (void)DYYY_saveHeaderForClass:(Class)cls toPath:(NSString *)path;
@end

// RTBClassDisplayVC类别扩展
@interface RTBClassDisplayVC (DYYY_Additions)
- (void)DYYY_displayClassInfo:(Class)cls;
- (void)DYYY_displayObject:(id)object;
@end

// RTBObjectsTVC类别扩展
@interface RTBObjectsTVC (DYYY_Additions)
- (void)DYYY_inspectObject:(id)object;
- (NSArray *)DYYY_getAllMethodsForObject:(id)object;
@end