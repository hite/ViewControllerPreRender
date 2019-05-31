//
//  ViewControllerPreRender.h
//  ViewControllerPreRender
//
//  Created by liang on 2019/5/29.
//  Copyright © 2019 liang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ViewControllerPreRender : NSObject

+ (instancetype)defaultRender;

- (void)showRenderedViewController:(Class)viewControllerClass completion:(void (^)(UIViewController *vc))block;
@end

NS_ASSUME_NONNULL_END
