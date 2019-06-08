UIViewController 预加载方案浅谈

### 一. 引子
预加载作为常规性能优化手段，在所有性能敏感的场景都有使用。不同的场景会有不同的方案。举个例子，网易邮箱简约邮里，收件箱列表使用了数据预加载，首页加载完毕后会加载后一页的分页数据，在用户继续翻页时，能极大提升响应速度；在微信公众号列表，不仅预加载了多个分页数据，还加载了某个公众文章的文字部分，所以当列表加载完毕之后，你走到了没有网络的电梯里，依然可以点击某个文字，阅读文字部分，图片是空白。

在 iOS 常规的优化方案中，预加载也是极常见的手段，多见于：预加载图片、配置文件、离线包等业务资源。查阅后知， ASDK 有一套很智能的预加载策略；
>在滚动方向（Leading）上 Fetch Data 区域会是非滚动方向（Trailing）的两倍，ASDK 会根据滚动方向的变化实时改变缓冲区的位置；在向下滚动时，下面的 Fetch Data 区域就是上面的两倍，向上滚动时，上面的 Fetch Data 区域就是下面的两倍。

系统层面，iOS 10 里`UIKit` 还为开发者新增了`UITableViewDataSourcePrefetching`
```objective-c
@protocol UITableViewDataSourcePrefetching <NSObject>
@required

// indexPaths are ordered ascending by geometric distance from the table view
- (void)tableView:(UITableView *)tableView prefetchRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

@optional

// indexPaths that previously were considered as candidates for pre-fetching, but were not actually used; may be a subset of the previous call to -tableView:prefetchRowsAtIndexPaths:
- (void)tableView:(UITableView *)tableView cancelPrefetchingForRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

@end
```
等新的协议来提供` UITableView\UICollectionView` 预加载 data 的能力。

但是对于整个 App 的核心组件 `UIViewController` 却少见预加载的策略。极少数场景是这样的：整个界面包含多个 `UIViewController` 的层级，除了显示第一个 `UIViewController` 外 ，预加载其他的  `UIViewController` 。
###  二. `UIViewController`  到底能不能预加载？
在和同事解决严选 App 内“领取津贴”弹窗慢的问题时，我思考了这个问题，所以查阅了 [ Developer Documentation](apple-reference-documentation://hc25s7SuiZ)， 大概有以下的收获；
1. 在同一个 `navigation stack`里不能 push 相同的一个`UIViewController`  ，否则会崩溃；而来自不同 `navigation stack` 的 `UIViewController` 是可以被压入 stack 的，这也是预加载的关键。
2. 当某个 `UIViewController` 执行了 `viewDidLoad()`之后，整个 `UIViewController` 对象已经在内存内。如果我们要使用 VC 时，可以直接从内存里获取，将会获得速度提升
2.  `UIViewController` 作为 `UIWindow` 和 `vc.view`中间层，负责事件分发、响应链，  `UIViewController` 子元素容器，子元素根据  `UIViewController` 的尺寸 layout
2. `UIViewController.view` 是个懒加载属性，由 `loadView()` 初始化，在 viewDidLoad 事件开始时，就已经完成
3. `UIViewController` 在被添加到 `navigation stack`后是否会被渲染，取决于所在的 window 是不是 hidden = NO，和在不在屏幕上没有关系

**答案：可以被预加载，除了本文尝试的多个` navigation stack`的方式外， apple 自己在早期推广 storyboard 和 xib 文件模式开发 iOS 应用时，也抱有相同的意图**

###  三. `UIViewController`  渲染的流程？
因为 UIKit 没有开源，我从 Apple Documents 和 `Chameleon` project 的重写源码里试图还原真实的 `UIViewController` 在 UIKit 中的渲染逻辑。以下是我根据自己的理解画的 UIViewController 被添加到 UIWindow 的渲染流程，肯定有错误和遗漏，仅供理解本文使用。

**图例参考 Safari**，序号后面的图形，表示本阶段 ViewController 的 view 层级，认清这些事件，可以知道哪个阶段做哪些操作是合适的？
![vc render flow.png](https://upload-images.jianshu.io/upload_images/277783-622238450881ef36.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
*注意：以上为 iOS 12 里的情况，在 iOS 13 里，第 5 序号的 View 比目前 iOS 12 要多两个 View，`UIDropShadowView`,`UITransitionView`*。

###  四. ViewControllerPreRender
在整理出上面的流程结论后，编写了`ViewControllerPreRender`，虽然不到 100 行，前后却花了一周，主要是为了解决下面这个 XCode 警告。
```
"Unbalanced calls to begin/end appearance transitions for <UIViewController: 0xa98e050>"
```
幸好通过多次尝试，最终解决掉。
代码很短，全文摘录，以下以注释的方式详细解读。
```objective-c
//.h 文件
@interface ViewControllerPreRender : NSObject

+ (instancetype)defaultRender;

- (void)showRenderedViewController:(Class)viewControllerClass completion:(void (^)(UIViewController *vc))block;
@end
//.m 文件
#import "ViewControllerPreRender.h"

@interface ViewControllerPreRender ()

@property (nonatomic, strong) UIWindow *windowNO2;
/**
 已经被渲染过后的 ViewController，池子,在必要时候 purge 掉
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
        // 增加一个监听，当内存紧张时，丢弃这些预加载的对象不会造成功能错误，
        // 这样也要求 UIViewController 的 dealloc 都能正确处理资源释放
        [[NSNotificationCenter defaultCenter] addObserver:_myRender
                                                 selector:@selector(dealMemoryWarnings:)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
    });
    return _myRender;
}

/**
 内部方法，用来产生可用的 ViewController，如果第一次使用。
 直接返回全新创建的对象，同时也预热一个相同类的对象，供下次使用。
 支持预热多个 ViewController，但是不易过多，容易引起内存紧张

 @param viewControllerClass UIViewController 子类
 @return UIViewControllerd 实例
 */
- (UIViewController *)getRendered:(Class)viewControllerClass{
    if (_windowNO2 == nil) {
        CGRect full = [UIScreen mainScreen].bounds;
        // 对于 no2 的尺寸多少为合适。我自己做了下实验
        // 这里设置的尺寸会影响被缓存的 VC 实例的尺寸。但在预热好的 VC 被添加到当前工作的 navigation stack 时，它的 View 的尺寸是正确的和 no2 的尺寸无关。
        // 同样的，在被添加到 navigation stack 时，会触发 viewLayoutMarginsDidChange 事件。
        // 而且对于内存而言，尺寸越小内存占用越少，理论上 （1，1，1，1） 的 no2 有能达到预热 VC 的效果。
        // 但是有些 view 不是被 presented 或者 pushed，而是作为子 ViewController 的子 view 来渲染界面的。这需要 view 有正确的尺寸。
        // 所以这里预先设置将来真正展示时的尺寸，减少 resize、和作为子 ViewController 使用时出错，在本 demo 中，默认大部分的尺寸是全屏。
        UIWindow *no2 = [[UIWindow alloc] initWithFrame:CGRectOffset(full, CGRectGetWidth(full), 0)];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[UIViewController new]];
        no2.rootViewController = nav;
        no2.hidden = NO;// 必须是显示的 window，才会触发预热 ViewController，隐藏的 window 不可用。但是和是否在屏幕可见没关系
        no2.windowLevel = UIWindowLevelStatusBar + 14;
        
        _windowNO2= no2;
    }
    
    NSString *key = NSStringFromClass(viewControllerClass);
    UIViewController *vc = [self.renderedViewControllers objectForKey:key];
    if (vc == nil) { // 下次使用缓存
        vc = [viewControllerClass new];
        // 解决 Unbalanced calls to begin/end appearance transitions for <UIViewController: 0xa98e050> 关键点
        // 1. 使用 UINavigationController  作为 no2 的 rootViewController
        // 2. 如果使用 UIViewController 作为 no2 的 rootViewController，始终有 Unbalanced calls 的错误
        // 虽然是编译器警告，实际上 Unbalanced calls  会影响被缓存的 vc， 当它被添加到当前活动的 UINavigation stack 时，它的生命周期是错误的
        // 所以这个警告必须解决。
        UINavigationController *nav = (UINavigationController *)_windowNO2.rootViewController;
        [nav pushViewController:vc animated:NO];
        [self.renderedViewControllers setObject:vc forKey:key];
        //
        return [viewControllerClass new];
    }  else { // 本次使用缓存，同时储备下次
        // 必须是先设置 no2 的新 rootViewController，之后再复用从缓存中拿到的 viewControllerClass。否则会奔溃
        UINavigationController *nav = (UINavigationController *)_windowNO2.rootViewController;
        [nav popViewControllerAnimated:NO];
        UIViewController *fresh = [viewControllerClass new];

        [nav pushViewController:fresh animated:NO];
        // 在 setObject to renderedViewControllers 字典时，保证被渲染过
        [self.renderedViewControllers setObject:fresh forKey:key];
        
        return vc;
    }
}

/**
 主方法。传入一个 UIViewController 的 class 对象，在调用的 block 中同步的返回一个预先被渲染的 ViewController

 @param viewControllerClass  必须是 UIViewController 的 Class 对象
 @param block 业务逻辑回调
 */
- (void)showRenderedViewController:(Class)viewControllerClass completion:(void (^)(UIViewController *vc))block{
    // CATransaction 为了避免一个 push 动画和另外一个 push 动画同时进行的问题。
    [CATransaction begin];
    UIViewController *vc1 = [self getRendered:viewControllerClass];
    
    // 这里包含一个陷阱—— 必须先渲染将要被 cached 的 ViewController，然后再执行真实的 block
    // 理想情况，应该是先执行 block，然后执行 cache ViewController，因为 block 更重要些。暂时没想到方法
    [CATransaction setCompletionBlock:^{
        block(vc1);
    }];
    [CATransaction commit];
}

- (void)dealMemoryWarnings:(id)notif
{
    NSLog(@"release memory pressure");
    [self.renderedViewControllers removeAllObjects];
}
@end
```
### 五. 性能提升如何？
以 native 体验中通常体验最差的 webview 为例， 目标是严选商城的 h5 ，`http://m.you.163.com`，分别以传统的，每次都新创建 `ViewController`的方式；第二次之后使用预热的 `ViewController`加载严选首页两种方式测试，保持 `ViewController`内部逻辑相同，详见 demo 工程里注释。

测试方案：*模拟器，每种方式测试时都重启，各测试了 20 次左右*，统计表格如下，navigationStart 作为网络加载时间的开始标志，以 document.onload 作为页面加载完毕的标志；
\> 1. 传统方式
点击到网络加载时间（ms）   |   点击到页面加载完毕时间（ms）
---|---
409.042969  |      2237.258057
382.000244  |      2294.206055
421.780762  |      2377.906250
435.476318  |      2358.933350
443.190186  |      2261.447998
379.502930  |      2243.837158
386.897949  |      2322.465088
508.499023  |      2385.695068
490.614014  |      2639.933105
407.436035  |      2384.422852
478.447998  |      2305.270264
426.408691  |      2340.742920
598.571777  |      2465.007812
453.924072  |      2424.213135
441.053955  |      2371.049805
399.669922  |      2218.141113
779.028809  |      2659.640625
68.835938  |       1934.873047
515.513916  |      2552.829834
439.666016  |      2268.033936
440.330811  |      2357.508789
**Avg of 21:** |
443.14         |   2352.54
\> 2. 使用预加载方式

点击到网络加载时间（ms）   |   点击到页面加载完毕时间（ms）
---|---
63.797852  |       2538.381836
63.152832  |       2333.105957
64.150146  |       2302.843750
59.484863  |       2155.601074
57.637207  |       2382.412842
55.749756  |       2050.655762
51.270020  |       1895.146729
54.883789  |       1793.544922
53.313965  |       1897.723877
78.262207  |       1777.684814
48.425049  |       1828.953857
50.403320  |       2075.978027
48.640625  |       2168.324951
58.913818  |       1946.458984
40.200928  |       1850.614990
54.635010  |       2198.915039
51.363770  |       1956.969971
**Avg of 17:** | 
56.13         |    2067.84

**从测试数据可见**，使用预加载的方式显著的提升了 `navigationStart`的性能，`443 ms` 减少到 `56 ms`，相应的 `document.onload`事件也提前，`2357` 到 `2067`。
相比之下，预加载方式提前 400ms 发送网络请求（但是完成加载耗时只少 300ms，猜测是 CPU 资源调度问题）。以上数据只作为性能提升参考，对于加载 WebView 的 VC 而言，预初始化 WebView 以及其他元素，可以提高加载 h5 页面的速度。

### 六，原因探析
对 `ViewControllerPrerender`的逻辑分析解释为什么会有提速，在使用`ViewControllerPreRender`时，需要特别留意什么地方，以免掉入误区。
**根据 preRender 的原理**，我大概画了图例来解释。
![old vs new vc route.png](https://upload-images.jianshu.io/upload_images/277783-e780286788d6f10a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上半部分，所有阶段是线性的；下半部分，可以做到并行，尤其是第三个 VC 的显示，将异步加载数据也放到并行逻辑了，这对有性能瓶颈的界面优化不失为一种方式
总结：预加载利用了并行这一传统性能优化技术，同时对 ViewController 的生命周期也提出更高的要求，譬如：
1. 被预热的 ViewController，需要划分职责，在`viewDidLoad`里搭建框架，，而在另一个单独的接口如本 demo 里的`setUrl`用来使用业务数据渲染页面。
2. 被预加载的 ViewController 的`viewDidLoad` 不宜占用太多主线程资源，避免对当前界面打开产生负面影响。

### 七，preRender 适宜的场景
在 App 性能问题中， native 自己的 ViewController性能表现并不是瓶颈，所以目前业界对 UIViewController 的预加载并没有太多可参考的案例，不过对于某些场景优化还是有指导意义。在本文开始时提到的严选商品详情页里领取津贴是弹窗，常规情况下弹出是比较慢的，经过讨论后，我们决定对津贴弹窗做两个优化
1. 在弹窗出现时使用缩放动画，h5 加载也使用 loading
2. 使用预加载弹窗的 ViewController。
从测试数据来看，从点击到最后加载完毕，大概节省了 300 ms，还需要进一步考虑 h5 的页面优化。

题外话，App 作为严选用户体验的重要载体，App 性能是极其重要一环。我们对弹窗的体验做了少许优化。

在严选里弹窗有两种，一种是被动弹窗，比方说从后台数据返回中，得知有弹窗需要显示，native 根据全局弹窗排序，决定显示那个——当后台数据返回指定的 url 被加载完毕之后，才弹出遮罩，显示被加载好的 url；如果 url 加载失败，就不会弹出弹窗。
而对于用户主动弹出的弹窗，如用户在详情页点击 cell，弹出领取津贴，我们分 native 加速（使用预加载）和 h5 加速两部分。

另外比较适合 preRender 的地方如，
1. 我的订单界面，当用户某个订单有商家已发货未收货时，根据行为统计，用户大概率会打开第一条已发货的订单去查看当前物流（物流数据来自第三方，响应速度没有保证），所以在进入我的订单时，可以预先加载一个查看最新未完成订单的物流的 ViewController。
2. 用户在详情页面，点击了我好评率，那么大概率，用户还会打开用户晒单的视频和图片。这时候可以预加载一个视频播放器和图片浏览器，提供用户的响应速度等。
![好评跳转到带图评分列表](https://upload-images.jianshu.io/upload_images/277783-27c0e5fd3badb36a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

对于大部分功能也能而言， prefetch 并不是必选项，还需要根据自身的业务来决定使用可以 prefetch 的思想解决 App 体验的瓶颈问题，不要随意使用 `ViewControllerPrefetch`，增加额外复杂度。

### 八，xib 和 storyboard 带来的启示
当我接触 iOS 开发时，已经到了 iOS 推销 storyboard 开发方式失败的时候，大部分可需要持续迭代的 App，其实不适合用 xib 和 storyboard 来开发，它的可视化带来的好处相比项目协作迭代里遇到的 diff 困难、复用困难、启动慢等坏处，不值一提。
时至今日，当我思考预加载方式在 `viewDidiLoad` 里还要多少操作空间时，我发现 xib 和 storyboard 在被苹果推广时没有被提到它预加载的优点，一直没有引起重视。
相同的 ViewController 使用的 xib 和 storyboard 文件被 init 为 实例之后，后续相同的ViewController 都会来 copy 被初始化好的 storyboard 来构建界面。开发人员创建完 xib 和 storyboard，需要持久化为文件，使用 initWithCoder：方法实现序列化，打开 xib 和 storyboard 时，先从文件反序列化解析得到 xml 文件，然后用 xml 文件绘制 interface builder。它的底层机制决定了它在开发启动、App 启动时会有性能损耗，不过也为我们做了一个例子—— 如何预加载 View 片段乃至 ViewController 本身。以 storyboard 为例，你可以在 storyboard 里做以下操作；
1. 绘制 ViewController 的 view 层次，特别的，会首先限制 storyboard 里绘制的静态数据
2. 添加 view 之间的约束
3. 转场（segue）和按钮动作跳转

而最终的用户界面需要等待网络返回真实数据后重新渲染，在此期间，显示静态的等待界面。所以在需要被缓存的 `UIViewController`需要可以安全的编写 UI、事件和转场等逻辑，将动态部分（网络请求）的发起逻辑写在转场结束之后。

### 十，补记
1.  [Unbalanced calls to begin/end appearance transitions for <UIViewController: 0xa98e050> ，这个警告必须解决，否则会导致被缓存的 ViewController 被添加到活动 stack 时，生命周期紊乱导致一些依赖生命周期执行的逻辑失效，如电商行业里很看重的曝光统计数据不正确
2. Demo 工程里已经有 calc.rb 可以直接将从 console 里拿到的数据实现为报表，方便你测试自己的页面性能加载提升对比。

### 参考
[1] [预加载与智能预加载（iOS）](https://draveness.me/preload)
[2] [iOS性能优化系列篇之“列表流畅度优化”](https://juejin.im/post/5b72aaf46fb9a009764bbb6a)
[3] [UIWindow 源码 of Chameleon](https://github.com/BigZaphod/Chameleon/blob/master/UIKit/Classes/UIWindow.m)s
[4][https://developer.apple.com/documentation/uikit/uiviewcontroller?language=objc](https://developer.apple.com/documentation/uikit/uiviewcontroller?language=objc)
[5] [Sharing the Same UIViewController as the rootViewController with Two UINavigationControllers](https://stackoverflow.com/questions/9710676/sharing-the-same-uiviewcontroller-as-the-rootviewcontroller-with-two-uinavigatio)
[6]  [Storyboards vs. the old XIB way](https://stackoverflow.com/questions/13834999/storyboards-vs-the-old-xib-way)
[7]  [Unbalanced calls to begin/end appearance transitions for <UINavigationController: 0xa98e050>](https://stackoverflow.com/questions/14412890/unbalanced-calls-to-begin-end-appearance-transitions-for-uinavigationcontroller)
[8] [ViewControllerPreRender](https://github.com/hite/ViewControllerPreRender)

