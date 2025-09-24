//
//  FLEXAPNSViewController.m
//  FLEX
//
//  Created by Tanner Bennett on 6/28/22.
//  Copyright © 2022 FLEX Team. All rights reserved.
//

#import "FLEXAPNSViewController.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXMutableListSection.h"
#import "FLEXSingleRowSection.h"
#import "NSUserDefaults+FLEX.h"
#import "UIBarButtonItem+FLEX.h"
#import "NSDateFormatter+FLEX.h"
#import "FLEXResources.h"
#import "FLEXUtility.h"
#import "FLEXRuntimeUtility.h"
#import "flex_fishhook.h"
#import <dlfcn.h>
#import <UserNotifications/UserNotifications.h>

#define orig(method, ...) if (orig_##method) { orig_##method(__VA_ARGS__); }
#define method_lookup(__selector, __cls, __return, ...) \
    ([__cls instancesRespondToSelector:__selector] ? \
        (__return(*)(__VA_ARGS__))class_getMethodImplementation(__cls, __selector) : nil)

@interface FLEXAPNSViewController ()
@property (nonatomic, readonly, class) Class appDelegateClass;
@property (nonatomic, class) NSData *deviceToken;
@property (nonatomic, class) NSError *registrationError;
@property (nonatomic, readonly, class) NSString *deviceTokenString;
@property (nonatomic, readonly, class) NSMutableArray<NSDictionary *> *remoteNotifications;
@property (nonatomic, readonly, class) NSMutableArray<UNNotification *> *userNotifications API_AVAILABLE(ios(10.0));

@property (nonatomic) FLEXSingleRowSection *deviceToken;
@property (nonatomic) FLEXMutableListSection<NSDictionary *> *remoteNotifications;
@property (nonatomic) FLEXMutableListSection<UNNotification *> *userNotifications API_AVAILABLE(ios(10.0));
@end

@implementation FLEXAPNSViewController

// 将 +load 的逻辑移到这个新方法中
+ (void)flex_hookAPNSMethods {
    if (!NSUserDefaults.standardUserDefaults.flex_enableAPNSCapture) {
        return;
    }

    // Hook app delegate to listen for registration
    // [self hookAppDelegateClass:FLEXUtility.appDelegate.class]; // 原始代码存在错误
    // 使用标准方式获取 app delegate
    id<UIApplicationDelegate> appDelegate = [UIApplication sharedApplication].delegate;
    if (appDelegate) {
        [self hookAppDelegateClass:[appDelegate class]];
    }

    // Hook UNUserNotificationCenter delegate
    if (@available(iOS 10.0, *)) {
        id centerDelegate = UNUserNotificationCenter.currentNotificationCenter.delegate;
        if (centerDelegate) {
            [self hookUNUserNotificationCenterDelegateClass:object_getClass(centerDelegate)];
        }
    }
}

// 注释掉原来的 +load 方法
/*
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // We need to wait until the app delegate is set up
        dispatch_async(dispatch_get_main_queue(), ^{
            if (NSUserDefaults.standardUserDefaults.flex_enableAPNSCapture) {
                [self hookAppDelegateClass:FLEXUtility.appDelegate.class];

                id centerDelegate = UNUserNotificationCenter.currentNotificationCenter.delegate;
                if (centerDelegate) {
                    [self hookUNUserNotificationCenterDelegateClass:object_getClass(centerDelegate)];
                }
            }
        });
    });
}
*/

+ (void)hookAppDelegateClass:(Class)appDelegate {
    // Abort if we already hooked something
    if (_appDelegateClass) {
        return;
    }
    
    _appDelegateClass = appDelegate;
    
    // Better documentation for what's happening is in hookUNUserNotificationCenterDelegateClass: below
    
    auto types_didRegisterForRemoteNotificationsWithDeviceToken = "v@:@@";
    auto types_didFailToRegisterForRemoteNotificationsWithError = "v@:@@";
    auto types_didReceiveRemoteNotification = "v@:@@@?";
    
    auto sel_didRegisterForRemoteNotifications = @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:);
    auto sel_didFailToRegisterForRemoteNotifs = @selector(application:didFailToRegisterForRemoteNotificationsWithError:);
    auto sel_didReceiveRemoteNotification = @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:);
    
    auto orig_didRegisterForRemoteNotificationsWithDeviceToken = method_lookup(
        sel_didRegisterForRemoteNotifications, appDelegate, void, id, SEL, id, id);
    auto orig_didFailToRegisterForRemoteNotificationsWithError = method_lookup(
        sel_didFailToRegisterForRemoteNotifs, appDelegate, void, id, SEL, id, id);
    auto orig_didReceiveRemoteNotification = method_lookup(
        sel_didReceiveRemoteNotification, appDelegate, void, id, SEL, id, id, id);
    
    IMP didRegisterForRemoteNotificationsWithDeviceToken = imp_implementationWithBlock(^(id _, id app, NSData *token) {
        self.deviceToken = token;
        orig(didRegisterForRemoteNotificationsWithDeviceToken, _, nil, app, token);
    });
    IMP didFailToRegisterForRemoteNotificationsWithError = imp_implementationWithBlock(^(id _, id app, NSError *error) {
        self.registrationError = error;
        orig(didFailToRegisterForRemoteNotificationsWithError, _, nil, app, error);
    });
    IMP didReceiveRemoteNotification = imp_implementationWithBlock(^(id _, id app, NSDictionary *payload, id handler) {
        // TODO: notify when new notifications are added
        [self.remoteNotifications addObject:payload];
        orig(didReceiveRemoteNotification, _, nil, app, payload, handler);
    });
    
    class_replaceMethod(
        appDelegate,
        sel_didRegisterForRemoteNotifications,
        didRegisterForRemoteNotificationsWithDeviceToken,
        types_didRegisterForRemoteNotificationsWithDeviceToken
    );
    class_replaceMethod(
        appDelegate,
        sel_didFailToRegisterForRemoteNotifs,
        didFailToRegisterForRemoteNotificationsWithError,
        types_didFailToRegisterForRemoteNotificationsWithError
    );
    class_replaceMethod(
        appDelegate,
        sel_didReceiveRemoteNotification,
        didReceiveRemoteNotification,
        types_didReceiveRemoteNotification
    );
}

+ (void)hookUNUserNotificationCenterDelegateClass:(Class)delegate API_AVAILABLE(ios(10.0)) {
    // Selector
    auto sel_didReceiveNotification =
        @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:);
    // Original implementation (or nil if unimplemented)
    auto orig_didReceiveNotification = method_lookup(
        sel_didReceiveNotification, delegate, void, id, SEL, id, id, id);
    // Our hook (ignores self and other unneeded parameters)
    IMP didReceiveNotification = imp_implementationWithBlock(^(id _, id __, UNNotification *notification, id ___) {
        [self.userNotifications addObject:notification];
        // This macro is a no-op if there is no original implementation
        orig(didReceiveNotification, _, nil, __, notification, ___);
    });
    
    // Set the hook
    class_replaceMethod(
        delegate,
        sel_didReceiveNotification,
        didReceiveNotification,
        "v@:@@@?"
    );
}

#pragma mark Class Properties

static Class _appDelegateClass = nil;
+ (Class)appDelegateClass {
    return _appDelegateClass;
}

static NSData *_apnsDeviceToken = nil;
+ (NSData *)deviceToken {
    return _apnsDeviceToken;
}

+ (void)setDeviceToken:(NSData *)deviceToken {
    _apnsDeviceToken = deviceToken;
}

+ (NSString *)deviceTokenString {
    static NSString *_deviceTokenString = nil;
    
    if (!_deviceTokenString && self.deviceToken) {
        NSData *token = self.deviceToken;
        NSUInteger capacity = token.length * 2;
        NSMutableString *tokenString = [NSMutableString stringWithCapacity:capacity];
        
        const UInt8 *tokenData = token.bytes;
        for (NSUInteger idx = 0; idx < token.length; ++idx) {
            [tokenString appendFormat:@"%02X", (int)tokenData[idx]];
        }
        
        _deviceTokenString = tokenString;
    }
    
    return _deviceTokenString;
}

static NSError *_apnsRegistrationError = nil;
+ (NSError *)registrationError {
    return _apnsRegistrationError;
}

+ (void)setRegistrationError:(NSError *)error {
    _apnsRegistrationError = error;
}

+ (NSMutableArray<NSDictionary *> *)userNotifications {
    static NSMutableArray *_userNotifications = nil;
    if (!_userNotifications) {
        _userNotifications = [NSMutableArray new];
    }
    
    return _userNotifications;
}

+ (NSMutableArray<NSDictionary *> *)remoteNotifications {
    static NSMutableArray *_remoteNotifications = nil;
    if (!_remoteNotifications) {
        _remoteNotifications = [NSMutableArray new];
    }
    
    return _remoteNotifications;
}

#pragma mark Instance stuff

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"推送通知";
    
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(reloadData) forControlEvents:UIControlEventValueChanged];
    
    [self addToolbarItems:@[
        [UIBarButtonItem
            flex_itemWithImage:FLEXResources.gearIcon
            target:self
            action:@selector(settingsButtonTapped)
        ],
    ]];
}

- (NSArray<FLEXTableViewSection *> *)makeSections {
    self.deviceToken = [FLEXSingleRowSection title:@"APNS 设备令牌" reuse:nil cell:^(UITableViewCell *cell) {
        NSString *tokenString = FLEXAPNSViewController.deviceTokenString;
        if (tokenString) {
            cell.textLabel.text = tokenString;
            cell.textLabel.numberOfLines = 0;
        }
        else if (!NSUserDefaults.standardUserDefaults.flex_enableAPNSCapture) {
            cell.textLabel.text = @"APNS 捕获已禁用";
        }
        else {
            cell.textLabel.text = @"尚未注册";
        }
    }];
    self.deviceToken.selectionAction = ^(UIViewController *host) {
        UIPasteboard.generalPasteboard.string = FLEXAPNSViewController.deviceTokenString;
        [FLEXAlert showQuickAlert:@"已复制到剪贴板" from:host];
    };
    
    // 远程通知 //
    
    self.remoteNotifications = [FLEXMutableListSection list:FLEXAPNSViewController.remoteNotifications
        cellConfiguration:^(UITableViewCell *cell, NSDictionary *notif, NSInteger row) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            // TODO: 接收日期
            cell.detailTextLabel.text = [FLEXRuntimeUtility summaryForObject:notif];
        }
        filterMatcher:^BOOL(NSString *filterText, NSDictionary *notif) {
            return [notif.description localizedCaseInsensitiveContainsString:filterText];
        }
    ];
    
    self.remoteNotifications.customTitle = @"远程通知";
    self.remoteNotifications.selectionHandler = ^(UIViewController *host, NSDictionary *notif) {
        [host.navigationController pushViewController:[
            FLEXObjectExplorerFactory explorerViewControllerForObject:notif
        ] animated:YES];
    };
    
    // 用户通知 //
    
    if (@available(iOS 10.0, *)) {
        self.userNotifications = [FLEXMutableListSection list:FLEXAPNSViewController.userNotifications
            cellConfiguration:^(UITableViewCell *cell, UNNotification *notif, NSInteger row) {
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                
                // 副标题是 'subtitle \n date'
                NSString *dateString = [NSDateFormatter flex_stringFrom:notif.date format:FLEXDateFormatPreciseClock];
                NSString *subtitle = notif.request.content.subtitle;
                subtitle = subtitle ? [NSString stringWithFormat:@"%@\n%@", subtitle, dateString] : dateString;
            
                cell.textLabel.text = notif.request.content.title;
                cell.detailTextLabel.text = subtitle;
            }
            filterMatcher:^BOOL(NSString *filterText, NSDictionary *notif) {
                return [notif.description localizedCaseInsensitiveContainsString:filterText];
            }
        ];
        
        self.userNotifications.customTitle = @"推送通知";
        self.userNotifications.selectionHandler = ^(UIViewController *host, UNNotification *notif) {
            [host.navigationController pushViewController:[
                FLEXObjectExplorerFactory explorerViewControllerForObject:notif.request
            ] animated:YES];
        };
        
        return @[self.deviceToken, self.remoteNotifications, self.userNotifications];
    }
    else {
        return @[self.deviceToken, self.remoteNotifications];
    }
}

- (void)reloadData {
    [self.refreshControl endRefreshing];
    
    self.remoteNotifications.customTitle = [NSString stringWithFormat:
        @"%@ 条通知", @(self.remoteNotifications.filteredList.count)
    ];
    [super reloadData];
}

- (void)settingsButtonTapped {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL enabled = defaults.flex_enableAPNSCapture;

    NSString *apnsToggle = enabled ? @"禁用捕获" : @"启用捕获";
    
    [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title(@"设置")
            .message(@"启用或禁用推送通知的捕获。\n\n")
            .message(@"这将在启动时连接UIApplicationMain，直到它被禁用，")
            .message(@"并刷一些应用程序委托方法。重新启动应用程序，以使更改生效。");
        
        make.button(apnsToggle).destructiveStyle().handler(^(NSArray<NSString *> *strings) {
            [defaults flex_toggleBoolForKey:kFLEXDefaultsAPNSCaptureEnabledKey];
        });
        make.button(@"取消").cancelStyle();
    } showFrom:self];
}

#pragma mark - FLEXGlobalsEntry

+ (NSString *)globalsEntryTitle:(FLEXGlobalsRow)row {
    return @"📌  推送通知";
}

+ (UIViewController *)globalsEntryViewController:(FLEXGlobalsRow)row {
    return [self new];
}

@end
