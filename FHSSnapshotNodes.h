//
//  FHSSnapshotNodes.h
//  FLEX
//
//  Created by Tanner Bennett on 1/7/20.
//

#import "FHSViewSnapshot.h"
#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FHSSnapshotNodes : NSObject

+ (instancetype)snapshot:(FHSViewSnapshot *)snapshot depth:(NSInteger)depth;

@property (nonatomic, readonly) FHSViewSnapshot *snapshotItem;
@property (nonatomic, readonly) NSInteger depth;

@property (nonatomic, strong, nullable) SCNNode *snapshot;

@property (nonatomic, strong, nullable) SCNNode *header;

@property (nonatomic, strong, nullable) SCNNode *border;

@property (nonatomic, getter=isHighlighted) BOOL highlighted;

@property (nonatomic, getter=isDimmed) BOOL dimmed;

@property (nonatomic) BOOL forceHideHeader;

@end

NS_ASSUME_NONNULL_END
