#import <Foundation/Foundation.h>

@interface FLEXClassSearcher : NSObject

+ (instancetype)sharedSearcher;
- (NSArray *)classesMatchingPattern:(NSString *)searchText;
- (NSArray *)methodsMatchingPattern:(NSString *)searchText inClass:(NSString *)className;

@end