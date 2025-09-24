#import "FLEXRuntimeBrowser.h"
#import "FLEXManager+RuntimeBrowser.h"

@implementation FLEXRuntimeBrowser

+ (void)enableRuntimeBrowser {
    [[NSClassFromString(@"FLEXManager") sharedManager] registerRuntimeBrowserTools];
}

@end