//
//  InfoViewController.m
//  RuntimeBrowser
//
//  Created by Nicolas Seriot on 25.01.09.
//  Copyright 2009 Sen:te. All rights reserved.
//

#import "RTBInfoVC.h"
#import "RTBAppDelegate.h"

@interface RTBInfoVC ()

@property (nonatomic, retain) IBOutlet UISwitch *showOCRuntimeClassesSwitch;
@property (nonatomic, retain) IBOutlet UISwitch *addCommentForBlocksSwitch;

@end

@implementation RTBInfoVC

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [_showOCRuntimeClassesSwitch setOn:[[[NSUserDefaults standardUserDefaults] valueForKey:@"RTBShowOCRuntimeClasses"] boolValue]];
    [_addCommentForBlocksSwitch setOn:[[[NSUserDefaults standardUserDefaults] valueForKey:@"RTBAddCommentsForBlocks"] boolValue]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"About", nil);
}

- (IBAction)openWebSiteAction:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://github.com/nst/RuntimeBrowser/"];
    
    // 使用新的 API，支持 iOS 10 及以上版本
    if (@available(iOS 10.0, *)) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    } else {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [[UIApplication sharedApplication] openURL:url];
        #pragma clang diagnostic pop
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (IBAction)showOCRuntimeClassesAction:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:((UISwitch *)sender).isOn forKey:@"RTBShowOCRuntimeClasses"];
}

- (IBAction)addBlockCommentsAction:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:((UISwitch *)sender).isOn forKey:@"RTBAddCommentsForBlocks"];
}

@end
