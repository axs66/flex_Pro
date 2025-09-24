//
//  RTBTreeTVC.m
//  OCRuntime
//
//  Created by Nicolas Seriot on 7/17/13.
//  Copyright (c) 2013 Nicolas Seriot. All rights reserved.
//

#import "RTBTreeTVC.h"
#import "RTBRuntime.h"
#import "RTBClassCell.h"
#import "RTBClass.h"
#import "RTBClassDisplayVC.h"

@interface RTBTreeTVC ()

@end

@implementation RTBTreeTVC

- (RTBClassDisplayVC *)classDisplayVC {
    if(_classDisplayVC == nil) {
        self.classDisplayVC = [[RTBClassDisplayVC alloc] initWithNibName:@"ClassDisplayVC" bundle:nil];
    }
    return _classDisplayVC;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.allClasses = [RTBRuntime sharedInstance];
    if(!_isSubLevel) {
        self.classStubs = [_allClasses rootClasses];
        // self.title = @"Tree";
        self.navigationItem.title = @"Root Classes";
    }
}

- (void)viewDidUnload {
    self.classDisplayVC = nil;
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated {
    if(!_isSubLevel) {
        self.classStubs = [_allClasses rootClasses]; // classes might have changed because of dynamic loading
    }
    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}

- (void)showHeader:(id)sender {
    NSLog(@"-- showHeader:%@", sender);
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_classStubs count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    RTBClassCell *cell = (RTBClassCell *)[tableView dequeueReusableCellWithIdentifier:@"RTBClassCell"];
    
    // Set up the cell
    RTBClass *cs = [_classStubs objectAtIndex:indexPath.row];
    cell.textLabel.text = cs.classObjectName;
    cell.accessoryType = [[cs subclassesStubs] count] > 0 ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    RTBClass *cs = [_classStubs objectAtIndex:indexPath.row];
    
    if([[cs subclassesStubs] count] == 0) return;
    
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
    RTBTreeTVC *tvc = (RTBTreeTVC *)[sb instantiateViewControllerWithIdentifier:@"RTBTreeTVC"];
    tvc.isSubLevel = YES;
    tvc.classStubs = [cs subclassesStubs];
    tvc.title = cs.classObjectName;
    [self.navigationController pushViewController:tvc animated:YES];
}

// 确保RTBTreeTVC有一个关闭方法
- (void)dismissModalView:(id)sender {
    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

@end
