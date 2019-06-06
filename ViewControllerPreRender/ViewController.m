//
//  ViewController.m
//  ViewControllerPreRender
//
//  Created by liang on 2019/5/29.
//  Copyright © 2019 liang. All rights reserved.
//

#import "ViewController.h"
#import "ViewControllerPreRender.h"
#import "AppDelegate.h"

@import WebKit;

@interface ViewController ()<WKNavigationDelegate>
@property (nonatomic, strong) WKWebView *webView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self printViews];
    [self.view addSubview:self.webView];
    
    UIBarButtonItem *reuse = [[UIBarButtonItem alloc] initWithTitle:@"reuse" style:UIBarButtonItemStylePlain target:self action:@selector(push2vc:)];
    UIBarButtonItem *no_reuse = [[UIBarButtonItem alloc] initWithTitle:@"no_reuse" style:UIBarButtonItemStylePlain target:self action:@selector(push2vc_v2:)];
    self.navigationItem.rightBarButtonItems = @[reuse, no_reuse];
    
    NSLog(@"%@ : %@, %p",self.url, NSStringFromSelector(_cmd), self);
    [self printViews];
}

- (void)printViews
{
    printf("\r\n");
    UIView *view = self.viewIfLoaded;
    int i = 0;
    while (view != nil) {
        printf("%d = %s\r\n", i++, [[view description] UTF8String]);
        view = view.superview;
    }
    printf("\r\n");
}

#define mylog(format, ...) _mylog("[Timing] ", format, ##__VA_ARGS__)
#define _mylog(prefix, format, ...) do{printf(prefix);printf(format, ##__VA_ARGS__);printf("\r\n");}while(0)

/**
 setUrl 是本类的主要业务逻辑入口。需要合适的时候手动触发

 @param url  WebView 加载的需求
 */
- (void)setUrl:(NSString *)url
{
    if (url.length > 0) {
        _url = url;
        NSURL *url2 = [NSURL URLWithString:_url?:@"about:blank"];
        mylog("push2setUrl = %f ", [[NSDate date] timeIntervalSince1970] * 1000 - kPushStart);
        [self.webView loadRequest:[NSURLRequest requestWithURL:url2 cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:1000]];
        
    }
    [self printViews];
}

- (void)push2vc:(id)sender
{
    kPushStart = [[NSDate date] timeIntervalSince1970] * 1000;
    mylog("");

    [CATransaction commit];
    [[ViewControllerPreRender defaultRender] showRenderedViewController:ViewController.class completion:^(UIViewController * _Nonnull vc) {
        
        ViewController *vc3 = (ViewController *)vc;
        long now = [[NSDate date] timeIntervalSince1970] * 1000;
        NSInteger type = now % 5;
        NSString *url = nil;
        switch (type) {
            case 0:
                url = @"http://hite.me";
                break;
            case 1:
                url = @"http://dota2.uuu9.com";
                break;
            case 2:
                url = @"http://www.vpgame.com";
                break;
            case 3:
                url = @"https://m.chouti.com";
                break;
            case 4:
                url = @"http://m.you.163.com";
                break;
                
            default:
                break;
        }
        vc3.url = @"http://m.you.163.com";
        [self.navigationController pushViewController:vc3 animated:YES];
    }];
}

- (void)push2vc_v2:(id)sender
{
    kPushStart = [[NSDate date] timeIntervalSince1970] * 1000;
    mylog("");
    
    ViewController *vc1 = [ViewController new];
    vc1.url = @"http://m.you.163.com";
    [self.navigationController pushViewController:vc1 animated:YES];
}

#pragma mark - navigation

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    NSLog(@"<%p> %s", self, [NSStringFromSelector(_cmd) UTF8String]);
    [webView evaluateJavaScript:@"window.performance.timing.navigationStart" completionHandler:^(id _Nullable r, NSError * _Nullable error) {
        long long navigationStart = [r longLongValue];
        //        mylog("navigationStart time = %lld, decidePolicy = %lld ", navigationStart, kDecidePolicyStart);
        mylog("push2decidePolicy = %lld ", kDecidePolicyStart - kPushStart);
        mylog("decidePolicy2navigationStart = %lld ", navigationStart - kDecidePolicyStart);
        mylog("push2navigationStart = %lld ", navigationStart - kPushStart);
    }];
    mylog("push2finish = %f ", ([[NSDate date] timeIntervalSince1970] * 1000) - kPushStart);
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    mylog("<%p> %s", self, [NSStringFromSelector(_cmd) UTF8String]);
}
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView{
    mylog("<%p> %s", self, [NSStringFromSelector(_cmd) UTF8String]);
}
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURLRequest *request = navigationAction.request;
    NSLog(@"<%p> decidePolicyForNavigationAction. URL = %@,Method = %@, body = %@, allKey = %@", self, request.URL,request.HTTPMethod, request.HTTPBody,[request.allHTTPHeaderFields allKeys]);
    decisionHandler(WKNavigationActionPolicyAllow);
    kDecidePolicyStart = [[NSDate date] timeIntervalSince1970] * 1000;
}

#pragma mark - getter
- (WKWebView *)webView
{
    if (_webView == nil) {
        //
        WKWebViewConfiguration *webViewConfig = [WKWebViewConfiguration new];

        CGRect size = [[UIScreen mainScreen] bounds];
        WKWebView *webview = [[WKWebView alloc] initWithFrame:size configuration:webViewConfig];
        webview.navigationDelegate = self;
        _webView = webview;
    }
    return _webView;
}

// 以下为测试 view 都干了啥而设置的代理
#pragma mark - test
- (void)loadView{
    [self printViews];
    [super loadView];
    NSLog(@"%@ : %@, %p",self.url, NSStringFromSelector(_cmd), self);
    [self printViews];
}
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    NSLog(@"%@ : %@, %p",self.url, NSStringFromSelector(_cmd), self);
    [self printViews];
}
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    NSLog(@"%@ : %@, %p",self.url, NSStringFromSelector(_cmd), self);
    [self printViews];
}
- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    NSLog(@"%@ : %@, %p",self.url, NSStringFromSelector(_cmd), self);
    [self printViews];
}
- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    NSLog(@"%@ : %@, %p",self.url, NSStringFromSelector(_cmd), self);
    [self printViews];
}

- (void)viewWillLayoutSubviews{
    [super viewWillLayoutSubviews];
    NSLog(@"%@ : %@, %p",self.url, NSStringFromSelector(_cmd), self);
    [self printViews];
}

- (void)viewDidLayoutSubviews{
    [super viewDidLayoutSubviews];
    NSLog(@"%@ : %@, %p",self.url, NSStringFromSelector(_cmd), self);
    [self printViews];
}

- (void)dealloc
{
    NSLog(@"%@ : %@, %p",self.url, NSStringFromSelector(_cmd), self);
}

- (void)viewLayoutMarginsDidChange{
    [super viewLayoutMarginsDidChange];
    NSLog(@"%@ : %@, %p",self.url, NSStringFromSelector(_cmd), self);
    [self printViews];
}

#pragma contentContainer
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    NSLog(@"%@ : %@, %p",self.url, NSStringFromSelector(_cmd), self);
    [self printViews];
}
- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super willTransitionToTraitCollection:newCollection withTransitionCoordinator:coordinator];
    NSLog(@"%@ : %@, %p",self.url, NSStringFromSelector(_cmd), self);
    [self printViews];
}
@end
