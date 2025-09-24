#import "FLEXToolbarItem.h"

@implementation FLEXToolbarItem

+ (instancetype)toolbarItemWithTitle:(NSString *)title image:(UIImage *)image {
    FLEXToolbarItem *item = [[self alloc] init];
    item.title = title;
    item.image = image;
    return item;
}

@end