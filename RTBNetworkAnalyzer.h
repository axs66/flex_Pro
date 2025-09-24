#import <Foundation/Foundation.h>

@interface RTBNetworkRequest : NSObject
@property (nonatomic, strong) NSString *requestId;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSString *method;
@property (nonatomic, strong) NSDictionary *headers;
@property (nonatomic, strong) NSData *body;
@property (nonatomic, strong) NSDate *startTime;
@property (nonatomic, strong) NSDate *endTime;
@property (nonatomic, assign) NSInteger statusCode;
@property (nonatomic, strong) NSData *responseData;
@property (nonatomic, assign) NSTimeInterval duration;
@end

@interface RTBNetworkAnalyzer : NSObject

+ (instancetype)sharedAnalyzer;
- (NSDictionary *)getNetworkStatistics;
- (NSArray *)getAllRequests;

@end