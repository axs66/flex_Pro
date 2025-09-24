#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 类层次分析器
 * 用于分析类的结构、继承关系和组成
 */
@interface RTBClassHierarchyAnalyzer : NSObject

/**
 * 分析指定类的层次结构
 * @param cls 要分析的类
 * @return 包含类分析信息的字典
 */
+ (NSDictionary *)analyzeClassHierarchy:(Class)cls;

/**
 * 分析指定类的协议实现
 * @param cls 要分析的类
 * @return 包含协议分析信息的数组
 */
+ (NSArray *)analyzeProtocolConformance:(Class)cls;

/**
 * 获取类的属性类型信息
 * @param attributes 属性特性字符串
 * @return 人类可读的类型字符串
 */
+ (NSString *)typeFromAttributes:(NSString *)attributes;

/**
 * 获取类的所有父类链
 * @param cls 要分析的类
 * @return 父类链数组
 */
+ (NSArray *)getSuperclassChain:(Class)cls;

/**
 * 获取类的所有子类
 * @param cls 要分析的类
 * @return 子类数组
 */
+ (NSArray *)getSubclasses:(Class)cls;

/**
 * 分析类的依赖关系
 * @param cls 要分析的类
 * @return 包含依赖信息的字典
 */
+ (NSDictionary *)analyzeClassDependencies:(Class)cls;

/**
 * 获取协议的方法列表
 * @param protocol 要分析的协议
 * @param required 是否获取必须实现的方法
 * @return 方法信息数组
 */
+ (NSArray *)getProtocolMethods:(Protocol *)protocol required:(BOOL)required;

@end

NS_ASSUME_NONNULL_END