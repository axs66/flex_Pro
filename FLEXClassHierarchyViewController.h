#import <UIKit/UIKit.h>

@interface FLEXClassHierarchyViewController : UIViewController

// 用特定类初始化
- (instancetype)initWithClass:(Class)aClass;

// 使用类名初始化
- (instancetype)initWithClassName:(NSString *)className;

@end