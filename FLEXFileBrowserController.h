//
//  FLEXFileBrowserController.h
//  Flipboard
//
//  Created by Ryan Olson on 6/9/14.
//  Based on previous work by Evan Doll
//

#import "FLEXTableViewController.h"
#import "FLEXGlobalsEntry.h"

@interface FLEXFileBrowserController : FLEXTableViewController <FLEXGlobalsEntry>

+ (instancetype)path:(NSString *)path;
- (id)initWithPath:(NSString *)path;

// 添加这些方法的声明
- (void)reloadDisplayedPaths;
- (void)reloadCurrentPath;
- (NSString *)filePathAtIndexPath:(NSIndexPath *)indexPath;
- (void)fileBrowserRename:(id)sender;
- (void)fileBrowserDelete:(id)sender;
- (void)fileBrowserCopyPath:(id)sender;
- (void)fileBrowserShare:(id)sender;

@end
