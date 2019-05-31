//
//  ViewControllerPreRender.m
//  ViewControllerPreRender
//
//  Created by liang on 2019/5/29.
//  Copyright © 2019 liang. All rights reserved.
//

#import "ViewControllerPreRender.h"

@interface ViewControllerPreRender ()

@property (nonatomic, strong) UIWindow *windowNO2;
/**
 已经被渲染过后的 ViewController，池子；
 */
@property (nonatomic, strong) NSMutableDictionary *renderedViewControllers;
@end

static ViewControllerPreRender *_myRender = nil;
@implementation ViewControllerPreRender

+ (instancetype)defaultRender{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _myRender = [ViewControllerPreRender new];
        _myRender.renderedViewControllers = [NSMutableDictionary dictionaryWithCapacity:3];
    });
    return _myRender;
}

- (UIViewController *)getRendered:(Class)viewControllerClass{
    if (_windowNO2 == nil) {
        CGRect full = [UIScreen mainScreen].bounds;
        UIWindow *no2 = [[UIWindow alloc] initWithFrame:CGRectOffset(full, CGRectGetWidth(full), 0)];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[UIViewController new]];
        no2.rootViewController = nav;
        no2.hidden = NO;
        no2.windowLevel = UIWindowLevelStatusBar + 14;
        
        _windowNO2= no2;
    }
    
    NSString *key = NSStringFromClass(viewControllerClass);
    UIViewController *vc = [self.renderedViewControllers objectForKey:key];
    if (vc == nil) { // 下次使用缓存
        vc = [viewControllerClass new];

        UINavigationController *nav = (UINavigationController *)_windowNO2.rootViewController;
        [nav pushViewController:vc animated:NO];
        [self.renderedViewControllers setObject:vc forKey:key];
        //
        return [viewControllerClass new];
    }  else { // 本次使用缓存，同时储备下次
        UINavigationController *nav = (UINavigationController *)_windowNO2.rootViewController;
        [nav popViewControllerAnimated:NO];
        UIViewController *fresh = [viewControllerClass new];

        [nav pushViewController:fresh animated:NO];
        [self.renderedViewControllers setObject:fresh forKey:key];
        
        return vc;
    }
}

- (void)showRenderedViewController:(Class)viewControllerClass completion:(void (^)(UIViewController *vc))block{
    
    [CATransaction begin];
    UIViewController *vc1 = [self getRendered:viewControllerClass];
    
    [CATransaction setCompletionBlock:^{
        block(vc1);
    }];
    [CATransaction commit];
}
@end
