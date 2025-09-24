//
//  ObjectWithMethodsViewController.m
//  RuntimeBrowser
//
//  Created by Nicolas Seriot on 11.06.09.
//  Copyright 2009 Sen:te. All rights reserved.
//

#import "RTBObjectsTVC.h"
#import "RTBMethodCell.h"
#import "RTBRuntimeHeader.h"
#import "UIAlertView+Blocks.h"
#import "RTBMethod.h"
#import "RTBRuntime.h"
#import "RTBClass.h"
#import "UIAlertView+RTB.h"

@interface RTBObjectsTVC ()

@property (nonatomic, strong) NSMutableArray *methodsSections; // [ { 'ClassName':'xxx', 'Methods':[a,b,c,...] }, { 'ClassName':'ParentClass', 'Methods':[a,x,y] } ]
@property (nonatomic, strong) NSMutableArray *paramsToAdd;
@property (nonatomic, strong) NSMutableArray *paramsToRemove;
@property (nonatomic, strong) id object;

@end

@implementation RTBObjectsTVC

- (void)viewDidLoad {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close:)];
    [super viewDidLoad];
}

- (IBAction)close:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^{
        //
    }];
}

- (void)setInspectedObject:(id)o {
    
    self.object = o;

    self.methodsSections = [NSMutableArray array];

    if(_object == nil) {
        [self.tableView reloadData];
        return;
    }

    BOOL objectIsAClass = _object == [_object class];

    Class c = [_object class];
    
    do {
        RTBClass *classObject = [[RTBRuntime sharedInstance] classStubForClassName:NSStringFromClass(c)];
        NSArray *methods = [classObject sortedMethodsIsClassMethod:objectIsAClass];
        NSDictionary *d = @{ @"ClassName":NSStringFromClass(c), @"Methods":methods };
        [_methodsSections addObject:d];
        c = class_getSuperclass(c);
    } while (c != NULL);
    
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    if(!_object) {
        UIAlertController *alert = [UIAlertController 
            alertControllerWithTitle:@"No class!" 
            message:@"请选择一个类查看"
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        
        return;
    }
    
    // (sometimes fails to get the description)
    self.title = [_object description];
    
    [self setInspectedObject:_object];
}
/*
 - (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
 [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
 }
 
 - (void)viewDidUnload {
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
 }
 */

#pragma mark Table view methods

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    NSMutableArray *ma = [NSMutableArray array];
    
    for(int i = 0; i < [_methodsSections count]; i++) {
        [ma addObject:[NSString stringWithFormat:@"%d", i]];
    }
    return ma;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSDictionary *d = _methodsSections[section];
    return d[@"ClassName"];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [_methodsSections count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSDictionary *d = _methodsSections[section];
    NSArray *methods = d[@"Methods"];
    return [methods count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    RTBMethodCell *cell = (RTBMethodCell *)[tableView dequeueReusableCellWithIdentifier:@"RTBMethodCell"];
    
    if (!cell) {
        cell = [[RTBMethodCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"RTBMethodCell"];
    }
    
    // Set up the cell
    NSDictionary *d = _methodsSections[indexPath.section];
    NSArray *methods = d[@"Methods"];
    RTBMethod *m = methods[indexPath.row];
    
    cell.method = m;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSDictionary *d = _methodsSections[indexPath.section];
    NSArray *methods = d[@"Methods"];
    RTBMethod *m = methods[indexPath.row];

    NSString *headerDescription = [m headerDescriptionWithNewlineAfterArgs:YES];
    NSArray *argTypes = [m argumentsTypesDecoded];
    
    BOOL hasParameters = [argTypes count] > 2;
    
    if (hasParameters) {
        
        NSMutableArray *params = [NSMutableArray array];
        
        [argTypes enumerateObjectsUsingBlock:^(NSString *argType, NSUInteger idx, BOOL *stop) {
            
            if (idx <= 1) return; // skip id and SEL

            // eg. "(unsigned long)arg1"
            NSString *s = [NSString stringWithFormat:@"(%@)arg%u", argType, (unsigned int)(idx-1)];
            [params addObject:s];
        }];
        
        // 替换 __weak 引用为 __unsafe_unretained 避免在MRC模式下的问题
        __unsafe_unretained typeof(self) blockSelf = self;
        
        for (NSString *objects in [params reverseObjectEnumerator]) {
            // 使用 UIAlertController 替代 UIAlertView
            UIAlertController *alertController = [UIAlertController 
                alertControllerWithTitle:objects
                message:headerDescription
                preferredStyle:UIAlertControllerStyleAlert];
            
            // 添加取消按钮
            [alertController addAction:[UIAlertAction 
                actionWithTitle:@"Cancel" 
                style:UIAlertActionStyleCancel 
                handler:^(UIAlertAction * _Nonnull action) {
                    // 如果这是第一个对象，清除数组
                    if ([params.firstObject isEqualToString:objects]) {
                        blockSelf.paramsToAdd = nil;
                        blockSelf.paramsToRemove = nil;
                    }
                    
                    // 验证 paramsArray
                    if (blockSelf.paramsToAdd == nil) {
                        blockSelf.paramsToAdd = [[NSMutableArray alloc] init];
                    }
                    
                    // 验证 paramsRemoveArray
                    if (blockSelf.paramsToRemove == nil) {
                        blockSelf.paramsToRemove = [[NSMutableArray alloc] init];
                    }
                    
                    // 添加参数
                    [blockSelf.paramsToAdd addObject:@""];
                    [blockSelf.paramsToRemove addObject:objects];
                }]];
            
            // 添加文本输入
            [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
                textField.placeholder = @"Enter value";
            }];
            
            // 添加确认按钮
            [alertController addAction:[UIAlertAction 
                actionWithTitle:@"Enter" 
                style:UIAlertActionStyleDefault 
                handler:^(UIAlertAction * _Nonnull action) {
                    NSString *output = alertController.textFields.firstObject.text;
                    
                    // 如果这是第一个对象，清除数组
                    if ([params.firstObject isEqualToString:objects]) {
                        blockSelf.paramsToAdd = nil;
                        blockSelf.paramsToRemove = nil;
                    }
                    
                    // 验证 paramsArray
                    if (blockSelf.paramsToAdd == nil) {
                        blockSelf.paramsToAdd = [[NSMutableArray alloc] init];
                    }
                    
                    // 验证 paramsRemoveArray
                    if (blockSelf.paramsToRemove == nil) {
                        blockSelf.paramsToRemove = [[NSMutableArray alloc] init];
                    }
                    
                    // 验证输出
                    if (output.length < 1 || output == nil || [output isEqualToString:@"nil"] || [output isEqualToString:@"NULL"] || [output isEqualToString:@""] || [output isEqualToString:@"null"] || [output isEqualToString:@"0"]) {
                        // 传递 nil
                        output = @"";
                    }
                    
                    // 基于类型创建输出
                    NSUInteger bracketEnd = [objects rangeOfString:@")" options:NSCaseInsensitiveSearch].location;
                    NSRange typeRange = NSMakeRange(1, bracketEnd - 1);
                    NSString *typeParam = [objects substringWithRange:typeRange];
                    
                    // int
                    if ([typeParam isEqualToString:@"int"]) {
                        [blockSelf.paramsToAdd addObject:[NSNumber numberWithInt:[output intValue]]];
                    }
                    // Bool
                    else if ([typeParam isEqualToString:@"BOOL"]) {
                        [blockSelf.paramsToAdd addObject:[NSNumber numberWithBool:[output boolValue]]];
                    }
                    // 其他情况
                    else {
                        // 添加到参数数组
                        [blockSelf.paramsToAdd addObject:output];
                    }
                    
                    // 添加到可移除参数数组
                    [blockSelf.paramsToRemove addObject:objects];
                    
                    // 检查这是否是方法中的最后一个参数
                    if ([params.lastObject isEqualToString:objects]) {
                        // 是的
                        // 将数组中的参数传递给对象并运行
                        
                        // 使用 __unsafe_unretained 替代 __weak
                        __unsafe_unretained typeof(blockSelf) blockSelf2 = blockSelf;
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            // 在主线程上
                            NSLog(@"-- [%@ %@]", blockSelf2, [m selectorString]);
                            [blockSelf2 performMethod:m withParameters:blockSelf2.paramsToAdd removing:blockSelf2.paramsToRemove];
                        });
                    }
                }]];
            
            [self presentViewController:alertController animated:YES completion:nil];
        }
        
        return;
    }
    
    NSString *returnTypeDecodedString = [m returnTypeDecoded];
    
    NSString *selectorString = [m selectorString];
    
    if([selectorString isEqualToString:@"dealloc"]) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    
    SEL selector = [m selector];
    
    if([_object respondsToSelector:selector] == NO) {
        return;
    }
    
    if([returnTypeDecodedString hasPrefix:@"struct"]) return;
    
    id o = nil;
    
    NSParameterAssert(selector != NULL);
    NSParameterAssert([_object respondsToSelector:selector]);
    
    NSMethodSignature *methodSig = [_object methodSignatureForSelector:selector];
    if(methodSig == nil) {
        NSLog(@"Invalid Method Signature for class: %@ and selector: %@", _object, NSStringFromSelector(selector));
        return;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    
    // Check to see if it's alloc
    if ([headerDescription isEqualToString:@"alloc"]) {
        // Alloc and init the class
        
        o = [_object performSelector:selector];
        
        id theOb = o;
        
        // Verify we can init it
        if ([o respondsToSelector:NSSelectorFromString(@"init")]) {
            theOb = [o performSelector:NSSelectorFromString(@"init")];
        }
        
        RTBObjectsTVC *ovc = [[RTBObjectsTVC alloc] initWithStyle:UITableViewStylePlain];
        ovc.object = theOb;
        [self.navigationController pushViewController:ovc animated:YES];
        
        return;
    }
    
    const char* retType = [methodSig methodReturnType];
    
    @try {

        if(strcmp(retType, @encode(id)) == 0) {
            o = [_object performSelector:selector];
        } else {
            
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSig];
            [invocation setTarget:_object];
            [invocation setSelector:selector];
            [invocation invoke];

            if (strcmp(retType, @encode(BOOL)) == 0) {
                BOOL result;
                [invocation getReturnValue:&result];
                o = result ? @"YES" : @"NO";
            } else if (strcmp(retType, @encode(void)) == 0) {
                [_object performSelector:selector];
            } else if (strcmp(retType, @encode(int)) == 0) {
                int result;
                [invocation getReturnValue:&result];
                o = [@(result) description];
            } else if (strcmp(retType, @encode(unsigned int)) == 0) {
                unsigned int result;
                [invocation getReturnValue:&result];
                o = [@(result) description];
            } else if (strcmp(retType, @encode(unsigned long long)) == 0) {
                unsigned long long result;
                [invocation getReturnValue:&result];
                o = [@(result) description];
            } else if (strcmp(retType, @encode(double)) == 0) {
                double result;
                [invocation getReturnValue:&result];
                o = [@(result) description];
            } else if (strcmp(retType, @encode(float)) == 0) {
                float result;
                [invocation getReturnValue:&result];
                o = [@(result) description];
            } else {
                NSLog(@"-[%@ performSelector:@selector(%@)] shouldn't be used. The selector doesn't return an object or void", _object, NSStringFromSelector(selector));
                return;
            }
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Exception!  Broke this:  %@", exception);
        // 替换 UIAlertView 为 UIAlertController
        UIAlertController *alert = [UIAlertController 
            alertControllerWithTitle:@"Error"
            message:[exception description]
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
    
#pragma clang diagnostic pop
    
    // Verify the output is good
    if (o == NULL || o == nil) {
        // o is empty
        NSLog(@"Output is empty");
        o = @"NULL";
    }
    
    if(![returnTypeDecodedString isEqualToString:@"id"]) {
        if([returnTypeDecodedString isEqualToString:@"NSInteger"] || [returnTypeDecodedString isEqualToString:@"NSUInteger"] || [returnTypeDecodedString hasSuffix:@"int"]) {
            o = [NSString stringWithFormat:@"%@", o]; // 直接使用对象描述
        } else if([returnTypeDecodedString isEqualToString:@"double"] || [returnTypeDecodedString isEqualToString:@"float"]) {
            o = [NSString stringWithFormat:@"%f", [o floatValue]];
        } else if([returnTypeDecodedString isEqualToString:@"BOOL"]) {
            o = ([o boolValue]) ? @"YES" : @"NO";
        } else if ([returnTypeDecodedString isEqualToString:@"void"]) {
            o = @"Completed";
        } else {
            o = [NSString stringWithFormat:@"%@", o]; // default
        }
    }
    
    if([o isKindOfClass:[NSString class]] || [o isKindOfClass:[NSArray class]] || [o isKindOfClass:[NSDictionary class]] || [o isKindOfClass:[NSSet class]]) {
        
        // 替换 UIAlertView 为 UIAlertController
        UIAlertController *alert = [UIAlertController 
            alertControllerWithTitle:@""
            message:[o description]
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        
        return;
    }
    
    RTBObjectsTVC *ovc = [[RTBObjectsTVC alloc] initWithStyle:UITableViewStylePlain];
    ovc.object = o;
    [self.navigationController pushViewController:ovc animated:YES];
}

- (void)performMethod:(RTBMethod *)m withParameters:(NSMutableArray *)parameters removing:(NSMutableArray *)removing {
    
    NSString *selectorString = [m selectorString];
    
    NSString *returnTypeDecoded = [m returnTypeDecoded];
    if([returnTypeDecoded hasPrefix:@"struct"]) return;

    if([selectorString isEqualToString:@"dealloc"]) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }

    RTBObjectsTVC *ovc = [[RTBObjectsTVC alloc] initWithStyle:UITableViewStylePlain];
    
    SEL selector = NSSelectorFromString([m selectorString]);
    
    if(![_object respondsToSelector:selector]) {
        return;
    }
    
    id o = nil;
    
    NSParameterAssert(selector != NULL);
    NSParameterAssert([_object respondsToSelector:selector]);
    
    NSMethodSignature *methodSig = [_object methodSignatureForSelector:selector];
    if(methodSig == nil) {
        NSLog(@"Invalid Method Signature for class: %@ and selector: %@", _object, NSStringFromSelector(selector));
        return;
    }
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    
    // Check to see if it's alloc
    if ([selectorString isEqualToString:@"alloc"]) {
        // Alloc and init the class
        o = [_object performSelector:selector];
        
        id theOb = o;
        
        // Verify we can init it
        if ([o respondsToSelector:NSSelectorFromString(@"init")]) {
            theOb = [o performSelector:NSSelectorFromString(@"init")];
        }
        
        ovc.object = theOb;
        
        [self.navigationController pushViewController:ovc animated:YES];
        
        return;
    }
    
    #pragma clang diagnostic pop
    
    const char* retType = [methodSig methodReturnType];
    
    @try {
        // Allow the object to perform the selector if it's of certain types
        if(strcmp(retType, @encode(id)) == 0) {
            // id
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[_object methodSignatureForSelector:selector]];
            [inv setSelector:selector];
            [inv setTarget:_object];
            
            NSLog(@"-- PARAMETERS: %@", parameters);
            
            for (int x = 0; x < [parameters count]; x++) {
                // Determine the type of input
                if ([[removing objectAtIndex:x] rangeOfString:@"BOOL"].location != NSNotFound) {
                    // BOOL
                    BOOL obj = NO;
                    if ([[parameters objectAtIndex:x] isEqualToString:@""]) {
                        obj = false;
                    } else if ([[parameters objectAtIndex:x] isEqualToString:@"true"]) {
                        obj = true;
                    } else if ([[parameters objectAtIndex:x] isEqualToString:@"false"]) {
                        obj = false;
                    } else if ([[parameters objectAtIndex:x] isEqualToString:@"yes"]) {
                        obj = false;
                    } else if ([[parameters objectAtIndex:x] isEqualToString:@"no"]) {
                        obj = false;
                    }  else {
                        obj = [[parameters objectAtIndex:x] boolValue];
                    }
                    [inv setArgument:&obj atIndex:(x + 2)];
                } else if ([[removing objectAtIndex:x] rangeOfString:@"int"].location != NSNotFound) {
                    // int
                    NSInteger obj = [[parameters objectAtIndex:x] integerValue];
                    [inv setArgument:&obj atIndex:(x + 2)];
                } else if ([[removing objectAtIndex:x] rangeOfString:@"id"].location != NSNotFound) {
                    // id
                    id obj;
                    if ([[parameters objectAtIndex:x] isEqualToString:@""]) {
                        obj = nil;
                    } else {
                        obj = [parameters objectAtIndex:x];
                    }
                    [inv setArgument:&obj atIndex:(x + 2)];
                } else {
                    // Something else
                    id obj;
                    if ([[parameters objectAtIndex:x] isEqualToString:@""]) {
                        obj = nil;
                    } else {
                        obj = [parameters objectAtIndex:x];
                    }
                    [inv setArgument:&obj atIndex:(x + 2)];
                }
            }
            
            [inv retainArguments];
            
            id result;
            [inv invoke];
            [inv getReturnValue:&result];
            if (result) {
                o = result;
            }
        } else if (strcmp(retType, @encode(BOOL)) == 0) {
            // BOOL
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[_object methodSignatureForSelector:selector]];
            [inv setSelector:selector];
            [inv setTarget:_object];
            
            for (int x = 0; x < parameters.count; x++) {
                // Determine the type of input
                if ([[removing objectAtIndex:x] rangeOfString:@"BOOL"].location != NSNotFound) {
                    // BOOL
                    BOOL obj;
                    if ([[parameters objectAtIndex:x] isEqualToString:@""]) {
                        obj = false;
                    } else if ([[parameters objectAtIndex:x] isEqualToString:@"true"]) {
                        obj = true;
                    } else if ([[parameters objectAtIndex:x] isEqualToString:@"false"]) {
                        obj = false;
                    } else if ([[parameters objectAtIndex:x] isEqualToString:@"yes"]) {
                        obj = false;
                    } else if ([[parameters objectAtIndex:x] isEqualToString:@"no"]) {
                        obj = false;
                    }  else {
                        obj = [[parameters objectAtIndex:x] boolValue];
                    }
                    [inv setArgument:&obj atIndex:(x + 2)];
                } else if ([[removing objectAtIndex:x] rangeOfString:@"int"].location != NSNotFound) {
                    // int
                    NSInteger obj = [[parameters objectAtIndex:x] integerValue];
                    [inv setArgument:&obj atIndex:(x + 2)];
                } else if ([[removing objectAtIndex:x] rangeOfString:@"id"].location != NSNotFound) {
                    // id
                    id obj;
                    if ([[parameters objectAtIndex:x] isEqualToString:@""]) {
                        obj = nil;
                    } else {
                        obj = [parameters objectAtIndex:x];
                    }
                    [inv setArgument:&obj atIndex:(x + 2)];
                } else {
                    // Something else
                    id obj;
                    if ([[parameters objectAtIndex:x] isEqualToString:@""]) {
                        obj = nil;
                    } else {
                        obj = [parameters objectAtIndex:x];
                    }
                    [inv setArgument:&obj atIndex:(x + 2)];
                }
            }
            
            [inv retainArguments];
            
            id result;
            [inv invoke];
            [inv getReturnValue:&result];
            if (result) {
                BOOL b = [result boolValue];
                o = [NSNumber numberWithBool:b];
            }
        } else if (strcmp(retType, @encode(void)) == 0) {
            // void
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[_object methodSignatureForSelector:selector]];
            [inv setSelector:selector];
            [inv setTarget:_object];
            
            for (int x = 0; x < parameters.count; x++) {
                // Determine the type of input
                if ([[removing objectAtIndex:x] rangeOfString:@"BOOL"].location != NSNotFound) {
                    // BOOL
                    BOOL obj = [[parameters objectAtIndex:x] boolValue];
                    [inv setArgument:&obj atIndex:(x + 2)];
                } else if ([[removing objectAtIndex:x] rangeOfString:@"int"].location != NSNotFound) {
                    // int
                    NSInteger obj = [[parameters objectAtIndex:x] integerValue];
                    [inv setArgument:&obj atIndex:(x + 2)];
                } else if ([[removing objectAtIndex:x] rangeOfString:@"id"].location != NSNotFound) {
                    // id
                    id obj;
                    if ([[parameters objectAtIndex:x] isEqualToString:@""]) {
                        obj = nil;
                    } else {
                        obj = [parameters objectAtIndex:x];
                    }
                    [inv setArgument:&obj atIndex:(x + 2)];
                } else {
                    // Something else
                    id obj;
                    if ([[parameters objectAtIndex:x] isEqualToString:@""]) {
                        obj = nil;
                    } else {
                        obj = [parameters objectAtIndex:x];
                    }
                    [inv setArgument:&obj atIndex:(x + 2)];
                }
            }
            
            [inv retainArguments];
            [inv invoke];
        } else if (strcmp(retType, @encode(int)) == 0) {
            // int
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[_object methodSignatureForSelector:selector]];
            [inv setSelector:selector];
            [inv setTarget:_object];
            
            for (int x = 0; x < parameters.count; x++) {
                // Determine the type of input
                if ([[removing objectAtIndex:x] rangeOfString:@"BOOL"].location != NSNotFound) {
                    // BOOL
                    BOOL obj;
                    if ([[parameters objectAtIndex:x] isEqualToString:@""]) {
                        obj = false;
                    } else if ([[parameters objectAtIndex:x] isEqualToString:@"true"]) {
                        obj = true;
                    } else if ([[parameters objectAtIndex:x] isEqualToString:@"false"]) {
                        obj = false;
                    } else if ([[parameters objectAtIndex:x] isEqualToString:@"yes"]) {
                        obj = false;
                    } else if ([[parameters objectAtIndex:x] isEqualToString:@"no"]) {
                        obj = false;
                    }  else {
                        obj = [[parameters objectAtIndex:x] boolValue];
                    }
                    [inv setArgument:&obj atIndex:(x + 2)];
                } else if ([[removing objectAtIndex:x] rangeOfString:@"int"].location != NSNotFound) {
                    // int
                    NSInteger obj = [[parameters objectAtIndex:x] integerValue];
                    [inv setArgument:&obj atIndex:(x + 2)];
                } else if ([[removing objectAtIndex:x] rangeOfString:@"id"].location != NSNotFound) {
                    // id
                    id obj;
                    if ([[parameters objectAtIndex:x] isEqualToString:@""]) {
                        obj = nil;
                    } else {
                        obj = [parameters objectAtIndex:x];
                    }
                    [inv setArgument:&obj atIndex:(x + 2)];
                } else {
                    // Something else
                    id obj;
                    if ([[parameters objectAtIndex:x] isEqualToString:@""]) {
                        obj = nil;
                    } else {
                        obj = [parameters objectAtIndex:x];
                    }
                    [inv setArgument:&obj atIndex:(x + 2)];
                }
            }
            
            [inv retainArguments];
            
            CFTypeRef result;
            [inv invoke];
            [inv getReturnValue:&result];
            if (result) {
                CFRetain(result);
                int i = 0;
                if (CFGetTypeID(result) == CFNumberGetTypeID()) {
                    CFNumberGetValue((CFNumberRef)result, kCFNumberIntType, &i);
                }
                o = [NSNumber numberWithInt:i];
            }
        } else {
            NSLog(@"-[%@ performSelector:@selector(%@)] shouldn't be used. The selector doesn't return an object or void", _object, NSStringFromSelector(selector));
            return;
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Exception!  Broke this:  %@", exception);
        // 替换 UIAlertView 为 UIAlertController
        UIAlertController *alert = [UIAlertController 
            alertControllerWithTitle:@"Error"
            message:[exception description]
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
    
    // Verify the output is good
    if (o == NULL || o == nil) {
        // o is empty
        NSLog(@"Output is empty");
        o = @"NULL";
    }
    
    if(![returnTypeDecoded isEqualToString:@"id"]) {
        if([returnTypeDecoded isEqualToString:@"NSInteger"] || [returnTypeDecoded isEqualToString:@"NSUInteger"] || [returnTypeDecoded hasSuffix:@"int"]) {
            if ([o isKindOfClass:[NSNumber class]]) {
                o = [NSString stringWithFormat:@"%d", [(NSNumber *)o intValue]];
            } else {
                o = [NSString stringWithFormat:@"%@", o];
            }
        } else if([returnTypeDecoded isEqualToString:@"double"] || [returnTypeDecoded isEqualToString:@"float"]) {
            o = [NSString stringWithFormat:@"%f", [o floatValue]];
        } else if([returnTypeDecoded isEqualToString:@"BOOL"]) {
            o = ([o boolValue]) ? @"YES" : @"NO";
        } else if ([returnTypeDecoded isEqualToString:@"void"]) {
            o = @"Completed";
        } else {
            if ([o isKindOfClass:[NSNumber class]]) {
                o = [NSString stringWithFormat:@"%d", [(NSNumber *)o intValue]];
            } else {
                o = [NSString stringWithFormat:@"%@", o];
            }
        }
    }
    
    if([o isKindOfClass:[NSString class]] || [o isKindOfClass:[NSArray class]] || [o isKindOfClass:[NSDictionary class]] || [o isKindOfClass:[NSSet class]]) {
        
        // 替换 UIAlertView 为 UIAlertController
        UIAlertController *alert = [UIAlertController 
            alertControllerWithTitle:@""
            message:[o description]
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        
        return;
    }
    
    ovc.object = o;
    
    [self.navigationController pushViewController:ovc animated:YES];
}

@end