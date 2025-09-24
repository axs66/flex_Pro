#import <Foundation/Foundation.h>

@interface RTBProperty : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *attributes;
@property (nonatomic, assign) BOOL isReadOnly;
@property (nonatomic, copy) NSString *type;

@end