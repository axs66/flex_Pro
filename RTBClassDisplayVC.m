//
//  ClassDisplayViewController.m
//  RuntimeBrowser
//
//  Created by Nicolas Seriot on 31.08.08.
//  Copyright 2008 seriot.ch. All rights reserved.
//

#import "RTBClassDisplayVC.h"
#import "RTBAppDelegate.h"
#import "RTBObjectsTVC.h"
#import "NSString+SyntaxColoring.h"
#import "RTBRuntimeHeader.h"
#import "RTBExtendedAnalyzer.h"

@interface RTBClassDisplayVC ()

@property (nonatomic, retain) IBOutlet UITextView *textView;
@property (nonatomic, retain) UIBarButtonItem *useButton;

@end

@implementation RTBClassDisplayVC

- (void)use:(id)sender {

	[self dismissViewControllerAnimated:YES completion:^{
        
        RTBAppDelegate *appDelegate = (RTBAppDelegate *)[[UIApplication sharedApplication] delegate];
        [appDelegate useClass:self.className];
    }];
}

- (void)dismissModalView:(id)sender {
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
	self.textView.font = [UIFont systemFontOfSize:[UIFont smallSystemFontSize]];
    
    self.useButton = _className ? [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Use", nil) style:UIBarButtonItemStylePlain target:self action:@selector(use:)] : nil;
    self.navigationItem.leftBarButtonItem = self.useButton;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissModalView:)];
    
    // 添加扩展分析按钮到工具栏
    UIBarButtonItem *analyzeButton = [[UIBarButtonItem alloc] 
                                     initWithTitle:@"扩展分析"
                                             style:UIBarButtonItemStylePlain
                                            target:self
                                            action:@selector(showExtendedAnalysis)];
    self.navigationItem.rightBarButtonItems = @[self.navigationItem.rightBarButtonItem, analyzeButton];
}

- (void)showExtendedAnalysis {
    Class cls = NSClassFromString(self.className);
    if (!cls) {
        return;
    }
    
    UIAlertController *alert = [UIAlertController 
                              alertControllerWithTitle:@"扩展分析"
                              message:@"选择分析类型"
                              preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"性能分析"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction * _Nonnull action) {
        UIViewController *vc = [RTBExtendedAnalyzer performanceAnalyzerForClass:cls];
        if (vc) {
            [self.navigationController pushViewController:vc animated:YES];
        }
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"引用关系分析"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction * _Nonnull action) {
        UIViewController *vc = [RTBExtendedAnalyzer classReferenceAnalyzerForClass:cls];
        if (vc) {
            [self.navigationController pushViewController:vc animated:YES];
        }
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"创建实例并分析内存"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction * _Nonnull action) {
        if ([cls respondsToSelector:@selector(new)]) {
            @try {
                id instance = [cls new];
                UIViewController *vc = [RTBExtendedAnalyzer objectMemoryAnalyzerForObject:instance];
                if (vc) {
                    [self.navigationController pushViewController:vc animated:YES];
                }
            } @catch (NSException *exception) {
                UIAlertController *errorAlert = [UIAlertController 
                                              alertControllerWithTitle:@"错误" 
                                              message:[NSString stringWithFormat:@"无法创建实例: %@", exception.reason]
                                              preferredStyle:UIAlertControllerStyleAlert];
                [errorAlert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:errorAlert animated:YES completion:nil];
            }
        }
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
	self.textView.text = @"";
    self.title = _className ? _className : _protocolName;
	
//	// FIXME: ??
//	NSArray *forbiddenClasses = [NSArray arrayWithObjects:@"NSMessageBuilder", /*, @"NSObject", @"NSProxy", */@"Object", @"_NSZombie_", nil];
//	
//	self.useButton.enabled = ![forbiddenClasses containsObject:self.className];
    self.useButton.enabled = YES;
}

- (void)viewDidDisappear:(BOOL)animated {
	self.textView.text = @"";
    
    [super viewDidDisappear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    NSString *header = nil;
    
    if(_className) {
        BOOL displayPropertiesDefaultValues = [[NSUserDefaults standardUserDefaults] boolForKey:@"RTBDisplayPropertiesDefaultValues"];
        header = [RTBRuntimeHeader headerForClass:NSClassFromString(self.className) displayPropertiesDefaultValues:displayPropertiesDefaultValues];
    } else if (_protocolName) {
        RTBProtocol *p = [RTBProtocol protocolStubWithProtocolName:_protocolName];
        header = [RTBRuntimeHeader headerForProtocol:p];
    }
    
    NSString *keywordsPath = [[NSBundle mainBundle] pathForResource:@"Keywords" ofType:@"plist"];
	
	NSArray *keywords = [NSArray arrayWithContentsOfFile:keywordsPath];
    
    NSAttributedString *as = [header colorizeWithKeywords:keywords classes:nil colorize:YES];
    
    self.textView.attributedText = as;
}

@end
