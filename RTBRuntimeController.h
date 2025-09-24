#import <Foundation/Foundation.h>

@class RTBSearchToken;

@interface RTBRuntimeController : NSObject

+ (instancetype)sharedController;
- (NSArray *)allBundleNames;
- (NSArray *)classesForToken:(RTBSearchToken *)token inBundles:(NSArray *)bundles;
- (NSString *)shortBundleNameForClass:(NSString *)className;
- (NSArray *)getClassHierarchyForClass:(Class)cls;
- (NSArray *)getSubclassesForClass:(Class)cls;
- (NSArray *)getMethodsForClass:(Class)cls includePrivate:(BOOL)includePrivate;
- (NSArray *)getPropertiesForClass:(Class)cls includePrivate:(BOOL)includePrivate;
- (NSArray *)getProtocolsForClass:(Class)cls;
- (NSArray *)getIvarsForClass:(Class)cls;
- (NSInteger)getInstanceCountForClass:(Class)cls;
- (NSArray *)getAllInstancesOfClass:(Class)cls;

@end