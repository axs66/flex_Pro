#import "RTBSystemAnalysisViewController.h"

@interface RTBSystemAnalysisViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) NSDictionary *sectionData;
@end

@implementation RTBSystemAnalysisViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"系统分析";
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
    
    [self processAnalysisData];
}

- (void)processAnalysisData {
    if (!self.analysisData) {
        self.sections = @[@"没有数据"];
        return;
    }
    
    NSMutableArray *sections = [NSMutableArray array];
    NSMutableDictionary *sectionData = [NSMutableDictionary dictionary];
    
    for (NSString *key in self.analysisData) {
        [sections addObject:key];
        sectionData[key] = self.analysisData[key];
    }
    
    self.sections = sections;
    self.sectionData = sectionData;
    
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSString *sectionKey = self.sections[section];
    id sectionObj = self.sectionData[sectionKey];
    
    if ([sectionObj isKindOfClass:[NSDictionary class]]) {
        return [sectionObj count];
    } else if ([sectionObj isKindOfClass:[NSArray class]]) {
        return [sectionObj count];
    } 
    
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    NSString *sectionKey = self.sections[indexPath.section];
    id sectionObj = self.sectionData[sectionKey];
    
    if ([sectionObj isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)sectionObj;
        NSArray *keys = dict.allKeys;
        NSString *key = keys[indexPath.row];
        
        cell.textLabel.text = key;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", dict[key]];
    } else if ([sectionObj isKindOfClass:[NSArray class]]) {
        NSArray *array = (NSArray *)sectionObj;
        cell.textLabel.text = [NSString stringWithFormat:@"%@", array[indexPath.row]];
    } else {
        cell.textLabel.text = [NSString stringWithFormat:@"%@", sectionObj];
    }
    
    return cell;
}

@end