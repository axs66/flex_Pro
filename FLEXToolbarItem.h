#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^FLEXToolbarItemActionBlock)(void);

@interface FLEXToolbarItem : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, copy) FLEXToolbarItemActionBlock action;

+ (instancetype)toolbarItemWithTitle:(NSString *)title image:(UIImage *)image;

@end

NS_ASSUME_NONNULL_END