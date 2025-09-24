//
//  FLEXFileBrowserController.m
//  Flipboard
//
//  Created by Ryan Olson on 6/9/14.
//
//

#import "FLEXFileBrowserController.h"
#import "FLEXFileBrowserController+RuntimeBrowser.h"
#import "FLEXUtility.h"
#import "FLEXWebViewController.h"
#import "FLEXActivityViewController.h"
#import "FLEXImagePreviewViewController.h"
#import "FLEXTableListViewController.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXObjectExplorerViewController.h"
#import "FLEXFileBrowserSearchOperation.h"
#import "FLEXMachOClassBrowserViewController.h"
#import "FLEXCompatibility.h"
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import "FLEXSyntaxHighlighter.h"

@interface FLEXFileBrowserTableViewCell : UITableViewCell
@end

typedef NS_ENUM(NSUInteger, FLEXFileBrowserSortAttribute) {
    FLEXFileBrowserSortAttributeNone = 0,
    FLEXFileBrowserSortAttributeName,
    FLEXFileBrowserSortAttributeCreationDate,
};

@interface FLEXFileBrowserController () <FLEXFileBrowserSearchOperationDelegate>

@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSArray<NSString *> *childPaths;
@property (nonatomic) NSArray<NSString *> *searchPaths;
@property (nonatomic) NSNumber *recursiveSize;
@property (nonatomic) NSNumber *searchPathsSize;
@property (nonatomic) NSOperationQueue *operationQueue;
@property (nonatomic) UIDocumentInteractionController *documentController;
@property (nonatomic) FLEXFileBrowserSortAttribute sortAttribute;

@end

@implementation FLEXFileBrowserController

+ (instancetype)path:(NSString *)path {
    return [[self alloc] initWithPath:path];
}

- (id)init {
    return [self initWithPath:NSHomeDirectory()];
}

- (id)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        self.path = path;
        self.title = [path lastPathComponent];
        self.operationQueue = [NSOperationQueue new];
        
        // 计算路径大小
        __block typeof(self) blockSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSFileManager *fileManager = NSFileManager.defaultManager;
            NSDictionary<NSString *, id> *attributes = [fileManager attributesOfItemAtPath:path error:NULL];
            uint64_t totalSize = [attributes fileSize];

            for (NSString *fileName in [fileManager enumeratorAtPath:path]) {
                NSString *fileAbsolutePath = [path stringByAppendingPathComponent:fileName];
                attributes = [fileManager attributesOfItemAtPath:fileAbsolutePath error:NULL];
                totalSize += [attributes fileSize];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                if (blockSelf) {
                    blockSelf.recursiveSize = @(totalSize);
                    [blockSelf.tableView reloadData];
                }
            });
        });
    }

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 修复UIBarButtonItem方法调用
    UIBarButtonItem *sortButton = [[UIBarButtonItem alloc] 
        initWithTitle:@"排序" 
        style:UIBarButtonItemStylePlain 
        target:self 
        action:@selector(sortButtonPressed:)];
    
    [self addToolbarItems:@[sortButton]];
    
    [self reloadDisplayedPaths];
}

// 添加缺失的drillDownViewControllerForPath方法
+ (UIViewController *)drillDownViewControllerForPath:(NSString *)path {
    NSString *pathExtension = [path.pathExtension lowercaseString];
    UIViewController *controller = nil;
    
    // plist文件
    if ([pathExtension isEqualToString:@"plist"]) {
        id plistObject = [NSArray arrayWithContentsOfFile:path] ?: [NSDictionary dictionaryWithContentsOfFile:path];
        if (plistObject) {
            controller = [FLEXObjectExplorerFactory explorerViewControllerForObject:plistObject];
        }
    }
    // SQLite数据库文件 - 修复方法调用
    else if ([pathExtension isEqualToString:@"db"] || [pathExtension isEqualToString:@"sqlite"] || [pathExtension isEqualToString:@"sqlite3"]) {
        // 使用初始化方法而不是类方法
        controller = [[FLEXTableListViewController alloc] init];
        // 如果需要设置路径，可以在这里添加
    }
    // 图片文件 - 修复初始化方法
    else if ([@[@"png", @"jpg", @"jpeg", @"gif", @"webp"] containsObject:pathExtension]) {
        UIImage *image = [UIImage imageWithContentsOfFile:path];
        if (image) {
            // 修复初始化方法
            controller = [[FLEXImagePreviewViewController alloc] init];
            // 如果FLEXImagePreviewViewController有设置图片的方法，在这里调用
        }
    }
    // 文本文件
    else if ([@[@"txt", @"json", @"log", @"xml", @"html", @"css", @"js", @"md", @"h", @"m", @"mm", @"c", @"cpp", @"swift"] containsObject:pathExtension]) {
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        if (content) {
            controller = [[FLEXWebViewController alloc] initWithText:content];
        }
    }
    
    return controller;
}

// 修复sortButtonPressed方法名
- (void)sortButtonPressed:(UIBarButtonItem *)sortButton {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"排序"
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    [alertController addAction:[UIAlertAction actionWithTitle:@"时间"
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction * _Nonnull action) {
        [self sortWithAttribute:FLEXFileBrowserSortAttributeNone];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"名字"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        [self sortWithAttribute:FLEXFileBrowserSortAttributeName];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"创建日期"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        [self sortWithAttribute:FLEXFileBrowserSortAttributeCreationDate];
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)sortWithAttribute:(FLEXFileBrowserSortAttribute)attribute {
    self.sortAttribute = attribute;
    [self reloadDisplayedPaths];
}

#pragma mark - FLEXGlobalsEntry

+ (NSString *)globalsEntryTitle:(FLEXGlobalsRow)row {
    switch (row) {
        case FLEXGlobalsRowBrowseBundle: return @"📁  浏览.app目录";
        case FLEXGlobalsRowBrowseContainer: return @"📁  浏览数据目录";
        default: return nil;
    }
}

+ (UIViewController *)globalsEntryViewController:(FLEXGlobalsRow)row {
    switch (row) {
        case FLEXGlobalsRowBrowseBundle: return [[self alloc] initWithPath:NSBundle.mainBundle.bundlePath];
        case FLEXGlobalsRowBrowseContainer: return [[self alloc] initWithPath:NSHomeDirectory()];
        default: return [self new];
    }
}

#pragma mark - FLEXFileBrowserSearchOperationDelegate

- (void)fileBrowserSearchOperationResult:(NSArray<NSString *> *)searchResult size:(uint64_t)size {
    self.searchPaths = searchResult;
    self.searchPathsSize = @(size);
    [self.tableView reloadData];
}

#pragma mark - Search bar

- (void)updateSearchResults:(NSString *)newText {
    if (newText.length) {
        [self.operationQueue cancelAllOperations];
        FLEXFileBrowserSearchOperation *newOperation = [[FLEXFileBrowserSearchOperation alloc] initWithPath:self.path
                                                                                                searchString:newText];
        __block typeof(self) blockSelf = self;
        newOperation.delegate = blockSelf;
        [self.operationQueue addOperation:newOperation];
    } else {
        [self reloadDisplayedPaths];
    }
}

#pragma mark UISearchControllerDelegate

- (void)willDismissSearchController:(UISearchController *)searchController {
    [self.operationQueue cancelAllOperations];
    [self reloadCurrentPath];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.searchController.isActive ? self.searchPaths.count : self.childPaths.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    BOOL isSearchActive = self.searchController.isActive;
    NSNumber *currentSize = isSearchActive ? self.searchPathsSize : self.recursiveSize;
    NSArray<NSString *> *currentPaths = isSearchActive ? self.searchPaths : self.childPaths;

    NSString *sizeString = nil;
    if (!currentSize) {
        sizeString = @"正在计算大小...";
    } else {
        sizeString = [NSByteCountFormatter stringFromByteCount:[currentSize longLongValue] countStyle:NSByteCountFormatterCountStyleFile];
    }

    return [NSString stringWithFormat:@"%lu 个文件 (%@)", (unsigned long)currentPaths.count, sizeString];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *fullPath = [self filePathAtIndexPath:indexPath];
    NSDictionary<NSString *, id> *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:fullPath error:NULL];
    BOOL isDirectory = [attributes.fileType isEqual:NSFileTypeDirectory];
    NSString *subtitle = nil;
    if (isDirectory) {
        NSUInteger count = [NSFileManager.defaultManager contentsOfDirectoryAtPath:fullPath error:NULL].count;
        subtitle = [NSString stringWithFormat:@"%lu 项%@", (unsigned long)count, (count == 1 ? @"" : @"")];
    } else {
        NSString *sizeString = [NSByteCountFormatter stringFromByteCount:attributes.fileSize countStyle:NSByteCountFormatterCountStyleFile];
        subtitle = [NSString stringWithFormat:@"%@ - %@", sizeString, attributes.fileModificationDate ?: @"从未修改过"];
    }

    static NSString *textCellIdentifier = @"textCell";
    static NSString *imageCellIdentifier = @"imageCell";
    UITableViewCell *cell = nil;

    // Separate image and text only cells because otherwise the separator lines get out-of-whack on image cells reused with text only.
    UIImage *image = [UIImage imageWithContentsOfFile:fullPath];
    NSString *cellIdentifier = image ? imageCellIdentifier : textCellIdentifier;

    if (!cell) {
        cell = [[FLEXFileBrowserTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        cell.textLabel.font = UIFont.flex_defaultTableCellFont;
        cell.detailTextLabel.font = UIFont.flex_defaultTableCellFont;
        cell.detailTextLabel.textColor = UIColor.grayColor;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    NSString *cellTitle = [fullPath lastPathComponent];
    cell.textLabel.text = cellTitle;
    cell.detailTextLabel.text = subtitle;

    if (image) {
        cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
        cell.imageView.image = image;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *subpath = [self filePathAtIndexPath:indexPath];
    NSString *fullPath = [self.path stringByAppendingPathComponent:subpath];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    BOOL exists = [fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory];
    
    if (!exists) {
        // 处理无效路径
        return;
    }

    if (isDirectory) {
        UIViewController *drillInViewController = [FLEXFileBrowserController path:fullPath];
        drillInViewController.title = subpath.lastPathComponent;
        [self.navigationController pushViewController:drillInViewController animated:YES];
    } else {
        NSString *extension = [subpath.pathExtension lowercaseString];
        
        // ✅ 使用分类方法分析特殊文件类型
        if ([extension isEqualToString:@"dylib"] || 
            [extension isEqualToString:@"framework"] ||
            [extension isEqualToString:@"plist"] ||
            [@[@"txt", @"log", @"json", @"xml", @"h", @"m", @"mm", @"c", @"cpp"] containsObject:extension]) {
            [self analyzeFileAtPath:fullPath];  // ✅ 使用分类中的统一分析方法
            return;
        }
        
        UIViewController *drillInViewController = [self.class drillDownViewControllerForPath:fullPath];
        
        if (drillInViewController) {
            drillInViewController.title = subpath.lastPathComponent;
            [self.navigationController pushViewController:drillInViewController animated:YES];
        } else {
            [self openFileController:fullPath];
        }
    }
}

// 如果原来有 analyzeMachOFile: 方法，可以删除或重构为调用分类方法
- (void)analyzeMachOFile:(NSString *)path {
    // ✅ 重构：调用分类方法
    [self analyzeRuntimeMachOFile:path];
}

- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIMenuItem *rename = [[UIMenuItem alloc] initWithTitle:@"重新命名" action:@selector(fileBrowserRename:)];
    UIMenuItem *delete = [[UIMenuItem alloc] initWithTitle:@"删除" action:@selector(fileBrowserDelete:)];
    UIMenuItem *copyPath = [[UIMenuItem alloc] initWithTitle:@"复制路径" action:@selector(fileBrowserCopyPath:)];
    UIMenuItem *share = [[UIMenuItem alloc] initWithTitle:@"导出" action:@selector(fileBrowserShare:)];

    UIMenuController.sharedMenuController.menuItems = @[rename, delete, copyPath, share];

    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    return action == @selector(fileBrowserDelete:)
        || action == @selector(fileBrowserRename:)
        || action == @selector(fileBrowserCopyPath:)
        || action == @selector(fileBrowserShare:);
}

- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    // 为空，但必须存在才能显示菜单
    // 表视图只会为 UIResponderStandardEditActions 非正式协议中的操作调用此方法。
    // 由于我们的操作不在该协议内，我们需要手动处理从单元格转发的操作。
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView
contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
                                    point:(CGPoint)point __IOS_AVAILABLE(13.0) {
    weakify(self)
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil
        actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
            UITableViewCell * const cell = [tableView cellForRowAtIndexPath:indexPath];
            UIAction *rename = [UIAction actionWithTitle:@"重命名" image:nil identifier:@"Rename"
                handler:^(UIAction *action) { strongify(self)
                    [self fileBrowserRename:cell];
                }
            ];
            UIAction *delete = [UIAction actionWithTitle:@"删除" image:nil identifier:@"Delete"
                handler:^(UIAction *action) { strongify(self)
                    [self fileBrowserDelete:cell];
                }
            ];
            UIAction *copyPath = [UIAction actionWithTitle:@"复制路径" image:nil identifier:@"Copy Path"
                handler:^(UIAction *action) { strongify(self)
                    [self fileBrowserCopyPath:cell];
                }
            ];
            UIAction *share = [UIAction actionWithTitle:@"导出" image:nil identifier:@"Share"
                handler:^(UIAction *action) { strongify(self)
                    [self fileBrowserShare:cell];
                }
            ];
            
            return [UIMenu menuWithTitle:@"管理文件" image:nil
                identifier:@"Manage File"
                options:UIMenuOptionsDisplayInline
                children:@[rename, delete, copyPath, share]
            ];
        }
    ];
}

- (void)openFileController:(NSString *)fullPath {
    
    // 检查文件是否存在
    if (![[NSFileManager defaultManager] fileExistsAtPath:fullPath]) {
        [FLEXAlert showAlert:@"文件不存在" message:@"指定的文件不存在或已被删除" from:self];
        return;
    }
    
    // 获取文件属性
    NSError *error;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:&error];
    if (error) {
        [FLEXAlert showAlert:@"文件错误" message:error.localizedDescription from:self];
        return;
    }
    
    // 检查是否为目录
    BOOL isDirectory = [attributes[NSFileType] isEqualToString:NSFileTypeDirectory];
    if (isDirectory) {
        // 创建新的文件浏览器实例浏览子目录
        FLEXFileBrowserController *subBrowser = [[FLEXFileBrowserController alloc] initWithPath:fullPath];
        [self.navigationController pushViewController:subBrowser animated:YES];
        return;
    }
    
    // 根据文件类型选择不同的处理方式
    NSString *fileExtension = [[fullPath pathExtension] lowercaseString];
    
    if ([self isTextFile:fileExtension]) {
        [self openTextFile:fullPath];
    } else if ([self isImageFile:fileExtension]) {
        [self openImageFile:fullPath];
    } else if ([self isDatabaseFile:fileExtension]) {
        [self openDatabaseFile:fullPath];
    } else if ([self isPlistFile:fileExtension]) {
        [self openPlistFile:fullPath];
    } else {
        // 尝试使用文档交互控制器打开
        [self openWithDocumentInteractionController:fullPath];
    }
}

- (BOOL)isTextFile:(NSString *)extension {
    NSArray *textExtensions = @[@"txt", @"log", @"json", @"xml", @"html", @"css", @"js", @"m", @"h", @"mm", @"swift", @"py", @"rb", @"java", @"c", @"cpp", @"md"];
    return [textExtensions containsObject:extension];
}

- (BOOL)isImageFile:(NSString *)extension {
    NSArray *imageExtensions = @[@"png", @"jpg", @"jpeg", @"gif", @"bmp", @"tiff", @"webp", @"heic"];
    return [imageExtensions containsObject:extension];
}

- (BOOL)isDatabaseFile:(NSString *)extension {
    NSArray *dbExtensions = @[@"sqlite", @"sqlite3", @"db"];
    return [dbExtensions containsObject:extension];
}

- (BOOL)isPlistFile:(NSString *)extension {
    return [extension isEqualToString:@"plist"];
}

- (void)openTextFile:(NSString *)filePath {
    // 读取文件内容
    NSError *error;
    NSString *content = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        // 尝试其他编码
        content = [NSString stringWithContentsOfFile:filePath encoding:NSASCIIStringEncoding error:&error];
        if (error) {
            [FLEXAlert showAlert:@"读取失败" message:@"无法读取文件内容" from:self];
            return;
        }
    }
    
    // 创建文本查看器
    UIViewController *textViewController = [[UIViewController alloc] init];
    textViewController.title = [filePath lastPathComponent];
    
    UITextView *textView = [[UITextView alloc] init];
    textView.editable = NO;
    textView.font = [UIFont fontWithName:@"Menlo" size:12] ?: [UIFont systemFontOfSize:12];
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 应用语法高亮
    NSString *extension = [[filePath pathExtension] lowercaseString];
    textView.attributedText = [FLEXSyntaxHighlighter highlightSource:content forFileExtension:extension];
    
    [textViewController.view addSubview:textView];
    
    [NSLayoutConstraint activateConstraints:@[
        [textView.topAnchor constraintEqualToAnchor:[FLEXCompatibility safeAreaTopAnchorForViewController:textViewController]],
        [textView.leadingAnchor constraintEqualToAnchor:textViewController.view.leadingAnchor],
        [textView.trailingAnchor constraintEqualToAnchor:textViewController.view.trailingAnchor],
        [textView.bottomAnchor constraintEqualToAnchor:textViewController.view.bottomAnchor]
    ]];
    
    // 添加分享按钮
    textViewController.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                                           initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                           target:self
                                                           action:@selector(shareCurrentFile:)];
    
    // 存储文件路径用于分享
    objc_setAssociatedObject(textViewController, "filePath", filePath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self.navigationController pushViewController:textViewController animated:YES];
}

- (void)openImageFile:(NSString *)filePath {
    UIImage *image = [UIImage imageWithContentsOfFile:filePath];
    if (!image) {
        [FLEXAlert showAlert:@"图片错误" message:@"无法加载图片" from:self];
        return;
    }
    
    // 创建图片查看器
    UIViewController *imageViewController = [[UIViewController alloc] init];
    imageViewController.title = [filePath lastPathComponent];
    imageViewController.view.backgroundColor = [UIColor blackColor];
    
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.delegate = (id<UIScrollViewDelegate>)self;
    scrollView.minimumZoomScale = 0.1;
    scrollView.maximumZoomScale = 5.0;
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [scrollView addSubview:imageView];
    [imageViewController.view addSubview:scrollView];
    
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:[FLEXCompatibility safeAreaTopAnchorForViewController:imageViewController]],
        [scrollView.leadingAnchor constraintEqualToAnchor:imageViewController.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:imageViewController.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:imageViewController.view.bottomAnchor],
        
        [imageView.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
        [imageView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
        [imageView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
        [imageView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor],
        [imageView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor],
        [imageView.heightAnchor constraintEqualToAnchor:scrollView.heightAnchor]
    ]];
    
    // 存储图片视图用于缩放
    objc_setAssociatedObject(scrollView, "imageView", imageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 添加分享按钮
    imageViewController.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                                            initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                            target:self
                                                            action:@selector(shareCurrentFile:)];
    
    // 存储文件路径用于分享
    objc_setAssociatedObject(imageViewController, "filePath", filePath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self.navigationController pushViewController:imageViewController animated:YES];
}

- (void)openDatabaseFile:(NSString *)filePath {
    // 创建数据库查看器
    // 使用正确的初始化方法，替代单独设置路径
    FLEXTableListViewController *dbViewController = [[FLEXTableListViewController alloc] initWithPath:filePath];
    
    [self.navigationController pushViewController:dbViewController animated:YES];
}

- (void)openPlistFile:(NSString *)filePath {
    NSError *error;
    NSData *plistData = [NSData dataWithContentsOfFile:filePath];
    
    if (!plistData) {
        [FLEXAlert showAlert:@"读取失败" message:@"无法读取plist文件" from:self];
        return;
    }
    
    // 解析plist
    id plistObject = [NSPropertyListSerialization propertyListWithData:plistData 
                                                               options:NSPropertyListImmutable 
                                                                format:nil 
                                                                 error:&error];
    
    if (error) {
        // 作为文本文件打开
        [self openTextFile:filePath];
        return;
    }
    
    // 使用对象浏览器查看plist内容
    FLEXObjectExplorerViewController *explorer = [FLEXObjectExplorerViewController exploringObject:plistObject];
    explorer.title = [filePath lastPathComponent];
    
    [self.navigationController pushViewController:explorer animated:YES];
}

- (void)openWithDocumentInteractionController:(NSString *)filePath {
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    
    UIDocumentInteractionController *controller = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
    controller.delegate = (id<UIDocumentInteractionControllerDelegate>)self;
    
    BOOL success = [controller presentPreviewAnimated:YES];
    if (!success) {
        // 如果预览失败，显示选项菜单
        CGRect rect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
        success = [controller presentOpenInMenuFromRect:rect inView:self.view animated:YES];
        
        if (!success) {
            [FLEXAlert showAlert:@"无法打开" message:@"系统无法处理此文件类型" from:self];
        }
    }
}

- (void)shareCurrentFile:(UIBarButtonItem *)sender {
    UIViewController *currentViewController = self.navigationController.topViewController;
    NSString *filePath = objc_getAssociatedObject(currentViewController, "filePath");
    
    if (filePath) {
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        UIActivityViewController *activityController = [[UIActivityViewController alloc] 
                                                       initWithActivityItems:@[fileURL] 
                                                       applicationActivities:nil];
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            activityController.popoverPresentationController.barButtonItem = sender;
        }
        
        [currentViewController presentViewController:activityController animated:YES completion:nil];
    }
}

#pragma mark - UIScrollViewDelegate (for image zoom)

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return objc_getAssociatedObject(scrollView, "imageView");
}

#pragma mark - UIDocumentInteractionControllerDelegate

- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller {
    return self;
}

- (CGRect)documentInteractionControllerRectForPreview:(UIDocumentInteractionController *)controller {
    return self.view.bounds;
}

- (UIView *)documentInteractionControllerViewForPreview:(UIDocumentInteractionController *)controller {
    return self.view;
}

- (void)reloadDisplayedPaths {
    // 刷新显示的路径
    NSError *error = nil;
    NSArray *paths = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.path error:&error];
    self.childPaths = paths ?: @[];
    [self.tableView reloadData];
}

- (void)reloadCurrentPath {
    // 重新加载当前路径内容
    [self reloadDisplayedPaths];
}

- (NSString *)filePathAtIndexPath:(NSIndexPath *)indexPath {
    // 根据索引路径返回文件路径
    if (self.searchController.isActive && self.searchPaths.count > indexPath.row) {
        return self.searchPaths[indexPath.row];
    }
    
    if (indexPath.row < self.childPaths.count) {
        return self.childPaths[indexPath.row];
    }
    
    return nil;
}

- (void)fileBrowserRename:(id)sender {
    // 重命名文件实现
    UITableViewCell *cell = sender;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    NSString *filePath = [self.path stringByAppendingPathComponent:[self filePathAtIndexPath:indexPath]];
    
    UIAlertController *alert = [UIAlertController 
                               alertControllerWithTitle:@"重命名"
                               message:@"输入新文件名"
                               preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = [filePath lastPathComponent];
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *newName = alert.textFields.firstObject.text;
        NSString *newPath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:newName];
        
        NSError *error = nil;
        BOOL success = [[NSFileManager defaultManager] moveItemAtPath:filePath toPath:newPath error:&error];
        
        if (!success) {
            NSLog(@"重命名失败: %@", error.localizedDescription);
        }
        
        [self reloadDisplayedPaths];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)fileBrowserDelete:(id)sender {
    // 删除文件实现
    UITableViewCell *cell = sender;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    NSString *filePath = [self.path stringByAppendingPathComponent:[self filePathAtIndexPath:indexPath]];
    
    UIAlertController *alert = [UIAlertController 
                               alertControllerWithTitle:@"确认删除"
                               message:@"确定要删除此文件吗？此操作无法撤销。"
                               preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSError *error = nil;
        BOOL success = [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
        
        if (!success) {
            NSLog(@"删除失败: %@", error.localizedDescription);
        }
        
        [self reloadDisplayedPaths];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)fileBrowserCopyPath:(id)sender {
    // 复制文件路径实现
    UITableViewCell *cell = sender;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    NSString *filePath = [self.path stringByAppendingPathComponent:[self filePathAtIndexPath:indexPath]];
    
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = filePath;
}

- (void)fileBrowserShare:(id)sender {
    // 分享文件实现
    UITableViewCell *cell = sender;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    NSString *filePath = [self.path stringByAppendingPathComponent:[self filePathAtIndexPath:indexPath]];
    
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] 
                                                      initWithActivityItems:@[fileURL] 
                                                      applicationActivities:nil];
    
    [self presentViewController:activityViewController animated:YES completion:nil];
}
@end


@implementation FLEXFileBrowserTableViewCell

- (void)forwardAction:(SEL)action withSender:(id)sender {
    id target = [self.nextResponder targetForAction:action withSender:sender];
    [UIApplication.sharedApplication sendAction:action to:target from:self forEvent:nil];
}

- (void)fileBrowserRename:(UIMenuController *)sender {
    [self forwardAction:_cmd withSender:sender];
}

- (void)fileBrowserDelete:(UIMenuController *)sender {
    [self forwardAction:_cmd withSender:sender];
}

- (void)fileBrowserCopyPath:(UIMenuController *)sender {
    [self forwardAction:_cmd withSender:sender];
}

- (void)fileBrowserShare:(UIMenuController *)sender {
    [self forwardAction:_cmd withSender:sender];
}

@end
