#import "FLEXRuntimeBrowserViewController.h"

@implementation FLEXRuntimeBrowserViewController

+ (instancetype)new {
    return [[self alloc] init];
}

+ (instancetype)alloc {
    return [super alloc];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.title = @"运行时浏览器";
    }
    return self;
}

@end