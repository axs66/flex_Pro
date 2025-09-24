#import "RTBFileBrowserController.h"

@interface RTBFileBrowserController ()
@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) NSArray *files;
@end

@implementation RTBFileBrowserController

+ (instancetype)withPath:(NSString *)path {
    RTBFileBrowserController *controller = [[self alloc] init];
    controller.path = path;
    return controller;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = [self.path lastPathComponent];
    
    [self loadFiles];
}

- (void)loadFiles {
    NSError *error;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    self.files = [fileManager contentsOfDirectoryAtPath:self.path error:&error];
    
    if (error) {
        NSLog(@"Error loading directory contents: %@", error);
    }
    
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.files.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"FileCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
    }
    
    NSString *filename = self.files[indexPath.row];
    cell.textLabel.text = filename;
    
    NSString *fullPath = [self.path stringByAppendingPathComponent:filename];
    
    BOOL isDirectory;
    [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory];
    
    if (isDirectory) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

@end