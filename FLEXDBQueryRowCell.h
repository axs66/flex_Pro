//
//  FLEXDBQueryRowCell.h
//  FLEX
//


#import <UIKit/UIKit.h>

@class FLEXDBQueryRowCell;

extern NSString * const kFLEXDBQueryRowCellReuse;

@protocol FLEXDBQueryRowCellLayoutSource <NSObject>

- (CGFloat)dbQueryRowCell:(FLEXDBQueryRowCell *)dbQueryRowCell minXForColumn:(NSUInteger)column;
- (CGFloat)dbQueryRowCell:(FLEXDBQueryRowCell *)dbQueryRowCell widthForColumn:(NSUInteger)column;

@end

@interface FLEXDBQueryRowCell : UITableViewCell

/// An array of NSString, NSNumber, or NSData objects
@property (nonatomic, strong) NSArray *data;
@property (nonatomic, unsafe_unretained) id<FLEXDBQueryRowCellLayoutSource> layoutSource;

@end
