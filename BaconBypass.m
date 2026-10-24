#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import <sys/utsname.h>
#import <mach/mach.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#include <dlfcn.h>
#include <unistd.h>
#include <stdlib.h>

// ============================================================
// 1. LỚP VIEW TRONG SUỐT (GẮN TRỰC TIẾP LÊN GAME)
// Chống văng Delta Console & Đổi Server mượt mà
// ============================================================
static UIView *crosshairContainer = nil;
static UIButton *floatingCircleBtn = nil;
static UIView *menuContainer = nil;

@interface BaconPassthroughView : UIView
@end

@implementation BaconPassthroughView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self) {
        return nil; // Xuyên thủng các điểm chạm ngoài menu xuống thẳng game
    }
    return hitView;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGSize size = self.bounds.size;
    if (size.width <= 0 || size.height <= 0) return;

    if (crosshairContainer) {
        crosshairContainer.center = CGPointMake(size.width / 2.0, size.height / 2.0);
    }
    if (floatingCircleBtn) {
        CGFloat cx = MIN(MAX(25.0, floatingCircleBtn.center.x), size.width - 25.0);
        CGFloat cy = MIN(MAX(40.0, floatingCircleBtn.center.y), size.height - 25.0);
        floatingCircleBtn.center = CGPointMake(cx, cy);
    }
    if (menuContainer) {
        CGFloat halfW = menuContainer.bounds.size.width / 2.0;
        CGFloat halfH = menuContainer.bounds.size.height / 2.0;
        CGFloat mx = MIN(MAX(halfW + 6.0, menuContainer.center.x), size.width - halfW - 6.0);
        CGFloat my = MIN(MAX(halfH + 6.0, menuContainer.center.y), size.height - halfH - 6.0);
        menuContainer.center = CGPointMake(mx, my);
    }
}

@end

// ============================================================
// 2. MAIN CONTROLLER & HỆ THỐNG TIỆN ÍCH BACONBYPASS
// ============================================================
@interface BaconWebTab : NSObject
@property (nonatomic, assign) NSInteger tabId;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *iconText;
@property (nonatomic, strong) UIColor *themeColor;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIView *windowView;
@property (nonatomic, strong) UIButton *bubbleBtn;
@property (nonatomic, strong) UITextField *urlField;
@property (nonatomic, assign) BOOL isMinimized;
@end
@implementation BaconWebTab
@end

@interface BaconBypassOverlay : NSObject <WKNavigationDelegate>
+ (void)loadDylibSafely;
@end

@implementation BaconBypassOverlay

#define ADMIN_PIN @"151009"
#define DEFAULT_API_KEY @"Bacon-28fe90f03ab833ecdca1-1163020b864e1f997083"
#define TRACKER_API @"https://ok.tdat1510009.workers.dev"
#define STORAGE_KEY @"BaconBypass_CustomAPIKey"
#define HISTORY_KEY @"BaconBypass_HistoryLinks"

static BaconPassthroughView *baconOverlayView = nil;
static NSTimer *attachmentWatchdogTimer = nil;
static UIVisualEffectView *menuBlurView = nil;
static UIView *menuBorderOverlay = nil;
static UIView *menuDashboardBar = nil;
static UILabel *hudInfoLabel = nil;

static UIView *pinPromptContainer = nil;
static UITextField *pinInputField = nil;

static UIView *nickPromptContainer = nil;
static UITextField *nickInputField = nil;
static NSString *editingDeviceID = nil;

static NSMutableArray<BaconWebTab *> *webTabsList = nil;
static NSInteger nextTabId = 1;

static UIView *historyContainer = nil;
static UIScrollView *historyScrollView = nil;
static UIView *deviceLogsContainer = nil;
static UIScrollView *deviceLogsScrollView = nil;

static UIButton *tabSwitchBtn = nil;
static BOOL isUtilsTabActive = NO;
static UIView *bypassTabContainer = nil;
static UITextField *apiKeyInput = nil;
static UIView *keyActionContainer = nil;
static UITextField *linkInput = nil;
static UIButton *bypassBtn = nil;
static UIButton *copyBtn = nil;
static UIView *resultBox = nil;
static UITextView *resultDisplay = nil;
static UIButton *viewDevicesBtn = nil;
static UIButton *killswitchBtn = nil;
static NSString *extractedLink = nil;

static UIView *utilsTabContainer = nil;
static UITextView *utilsResultDisplay = nil;
static UIView *afkOverlay = nil;

static UIButton *btnBackground = nil;
static UIButton *btnFPSUnlock = nil;
static UIButton *btnMuteGame = nil;

static BOOL isBackgroundRunning = NO;
static BOOL isGameAudioMuted = NO;
static NSInteger currentFpsTarget = 60;
static AVAudioPlayer *silentAudioPlayer = nil;
static UIBackgroundTaskIdentifier bgTaskIdentifier; 

static BOOL isAdminMode = NO;
static BOOL isServerKillswitchActive = NO;

static CADisplayLink *renderLoop = nil;
static NSInteger frameCount = 0;
static CFTimeInterval lastFpsTime = 0;
static NSInteger currentFPS = 60;
static NSInteger currentPingMs = 0;
static CFTimeInterval lastPingCheckTime = 0;
static long currentAppRamMB = 0;

+ (void)applyRainbowBorderAnimationToLayer:(CALayer *)layer {
    if (!layer) return;
    [layer removeAnimationForKey:@"rainbowBorder"];
    CAKeyframeAnimation *anim = [CAKeyframeAnimation animationWithKeyPath:@"borderColor"];
    anim.values = @[
        (id)[UIColor colorWithHue:0.00 saturation:0.95 brightness:1.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithHue:0.17 saturation:0.95 brightness:1.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithHue:0.33 saturation:0.95 brightness:1.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithHue:0.50 saturation:0.95 brightness:1.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithHue:0.67 saturation:0.95 brightness:1.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithHue:0.83 saturation:0.95 brightness:1.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithHue:1.00 saturation:0.95 brightness:1.0 alpha:1.0].CGColor
    ];
    anim.duration = 3.5;
    anim.repeatCount = HUGE_VALF;
    anim.removedOnCompletion = NO;
    anim.fillMode = kCAFillModeForwards;
    [layer addAnimation:anim forKey:@"rainbowBorder"];
}

+ (void)triggerImpact:(UIImpactFeedbackStyle)style {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
        [gen prepare];
        [gen impactOccurred];
        AudioServicesPlaySystemSound(1104);
    });
}

+ (void)triggerNotify:(UINotificationFeedbackType)type {
    dispatch_async(dispatch_get_main_queue(), ^{
        UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
        [gen prepare];
        [gen notificationOccurred:type];
        if (type == UINotificationFeedbackTypeSuccess) AudioServicesPlaySystemSound(1001);
        else if (type == UINotificationFeedbackTypeError) AudioServicesPlaySystemSound(1053);
        else if (type == UINotificationFeedbackTypeWarning) AudioServicesPlaySystemSound(1057);
    });
}

+ (void)autoDetectClipboardLink {
    UIPasteboard *board = [UIPasteboard generalPasteboard];
    if (board && board.string) {
        NSString *clip = [board.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([clip hasPrefix:@"http://"] || [clip hasPrefix:@"https://"]) {
            if (linkInput && ![linkInput.text isEqualToString:clip]) {
                linkInput.text = clip;
                [self triggerImpact:UIImpactFeedbackStyleLight];
                resultDisplay.text = @"📋 Đã tự động dán link từ bộ nhớ tạm!";
                resultDisplay.textColor = [UIColor colorWithRed:0.4 green:0.8 blue:1.0 alpha:1.0];
            }
        }
    }
}

+ (void)measureNetworkPing {
    static BOOL isMeasuring = NO;
    if (isMeasuring) return;
    isMeasuring = YES;

    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://1.1.1.1"] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:2.0];
    req.HTTPMethod = @"HEAD";

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    cfg.timeoutIntervalForRequest = 2.0;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];

    [[session dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        isMeasuring = NO;
        if (!error) {
            currentPingMs = (NSInteger)round((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0);
        } else {
            currentPingMs = -1;
        }
        [session finishTasksAndInvalidate];
    }] resume];
}

+ (void)applyFPSLimit:(NSInteger)fps {
    if (!renderLoop) return;
    if (@available(iOS 15.0, *)) {
        renderLoop.preferredFrameRateRange = CAFrameRateRangeMake(fps / 2, fps, fps);
    } else {
        renderLoop.preferredFramesPerSecond = fps;
    }
}

+ (void)cycleFPSTarget {
    [self triggerImpact:UIImpactFeedbackStyleMedium];
    if (currentFpsTarget == 60) currentFpsTarget = 120;
    else if (currentFpsTarget == 120) currentFpsTarget = 30;
    else currentFpsTarget = 60;

    [self applyFPSLimit:currentFpsTarget];
    [btnFPSUnlock setTitle:[NSString stringWithFormat:@"⚡ FPS: %ldHz", (long)currentFpsTarget] forState:UIControlStateNormal];
    [self triggerNotify:UINotificationFeedbackTypeSuccess];
    utilsResultDisplay.text = [NSString stringWithFormat:@"🚀 Đã áp dụng tần số quét: %ld FPS!", (long)currentFpsTarget];
    utilsResultDisplay.textColor = [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
}

+ (void)toggleMuteGameAudio {
    [self triggerImpact:UIImpactFeedbackStyleHeavy];
    isGameAudioMuted = !isGameAudioMuted;

    if (isGameAudioMuted) {
        [btnMuteGame setTitle:@"🔇 Tiếng Game: TẮT" forState:UIControlStateNormal];
        btnMuteGame.backgroundColor = [[UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0] colorWithAlphaComponent:0.35];
        btnMuteGame.layer.borderColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0].CGColor;
        NSError *err = nil;
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&err];
        [self triggerNotify:UINotificationFeedbackTypeSuccess];
        utilsResultDisplay.text = @"🔇 Đã TẮT tiếng game! Nhạc ngoài máy vẫn nghe bình thường.";
        utilsResultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0];
    } else {
        [btnMuteGame setTitle:@"🔊 Tiếng Game: BẬT" forState:UIControlStateNormal];
        btnMuteGame.backgroundColor = [[UIColor colorWithRed:0.2 green:0.5 blue:1.0 alpha:1.0] colorWithAlphaComponent:0.25];
        btnMuteGame.layer.borderColor = [[UIColor colorWithRed:0.2 green:0.5 blue:1.0 alpha:1.0] colorWithAlphaComponent:0.6].CGColor;
        NSError *err = nil;
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&err];
        [self triggerNotify:UINotificationFeedbackTypeWarning];
        utilsResultDisplay.text = @"🔊 Đã khôi phục tiếng game.";
        utilsResultDisplay.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    }
}

// Tab Web Browser...
+ (void)openNewWebTabWithURL:(NSString *)urlString {
    if (!baconOverlayView) return;
    [self triggerImpact:UIImpactFeedbackStyleMedium];
    if (!webTabsList) webTabsList = [NSMutableArray array];

    BaconWebTab *tab = [[BaconWebTab alloc] init];
    tab.tabId = nextTabId++;
    tab.isMinimized = NO;

    CGFloat bWidth = MIN(baconOverlayView.bounds.size.width - 24, 360.0);
    CGFloat bHeight = MIN(baconOverlayView.bounds.size.height - 80, 440.0);
    tab.windowView = [[UIView alloc] initWithFrame:CGRectMake((baconOverlayView.bounds.size.width - bWidth) / 2, 40, bWidth, bHeight)];
    tab.windowView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:0.98];
    tab.windowView.layer.cornerRadius = 16.0;
    tab.windowView.layer.borderWidth = 1.2;
    tab.windowView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.25].CGColor;
    tab.windowView.clipsToBounds = YES;

    UIView *wHeader = [[UIView alloc] initWithFrame:CGRectMake(0, 0, bWidth, 42)];
    wHeader.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.18 alpha:1.0];
    UIPanGestureRecognizer *panWin = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragTabWindow:)];
    [wHeader addGestureRecognizer:panWin];
    [tab.windowView addSubview:wHeader];

    tab.title = @"Tab Mới";
    tab.iconText = @"🌐";
    tab.themeColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0];

    UIButton *minBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    minBtn.frame = CGRectMake(8, 7, 30, 28);
    minBtn.backgroundColor = [UIColor colorWithRed:0.3 green:0.5 blue:0.9 alpha:0.4];
    minBtn.layer.cornerRadius = 6.0;
    [minBtn setTitle:@"🔽" forState:UIControlStateNormal];
    objc_setAssociatedObject(minBtn, "targetTab", tab, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [minBtn addTarget:self action:@selector(minimizeTabToBubble:) forControlEvents:UIControlEventTouchUpInside];
    [wHeader addSubview:minBtn];

    tab.urlField = [[UITextField alloc] initWithFrame:CGRectMake(44, 7, bWidth - 140, 28)];
    tab.urlField.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    tab.urlField.textColor = [UIColor whiteColor];
    tab.urlField.font = [UIFont systemFontOfSize:11];
    tab.urlField.layer.cornerRadius = 6.0;
    tab.urlField.text = urlString;
    tab.urlField.keyboardType = UIKeyboardTypeURL;
    tab.urlField.returnKeyType = UIReturnKeyGo;
    tab.urlField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 6, 28)];
    tab.urlField.leftViewMode = UITextFieldViewModeAlways;
    objc_setAssociatedObject(tab.urlField, "targetTab", tab, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [tab.urlField addTarget:self action:@selector(handleUrlFieldGo:) forControlEvents:UIControlEventEditingDidEndOnExit];
    [wHeader addSubview:tab.urlField];

    UIButton *relBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    relBtn.frame = CGRectMake(bWidth - 92, 7, 28, 28);
    relBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.6];
    relBtn.layer.cornerRadius = 6.0;
    [relBtn setTitle:@"🔄" forState:UIControlStateNormal];
    objc_setAssociatedObject(relBtn, "targetTab", tab, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [relBtn addTarget:self action:@selector(reloadTab:) forControlEvents:UIControlEventTouchUpInside];
    [wHeader addSubview:relBtn];

    UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    addBtn.frame = CGRectMake(bWidth - 60, 7, 28, 28);
    addBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:0.4];
    addBtn.layer.cornerRadius = 6.0;
    [addBtn setTitle:@"➕" forState:UIControlStateNormal];
    [addBtn addTarget:self action:@selector(promptNewTab) forControlEvents:UIControlEventTouchUpInside];
    [wHeader addSubview:addBtn];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(bWidth - 28, 7, 22, 28);
    closeBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:0.4];
    closeBtn.layer.cornerRadius = 6.0;
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    objc_setAssociatedObject(closeBtn, "targetTab", tab, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [closeBtn addTarget:self action:@selector(closeTab:) forControlEvents:UIControlEventTouchUpInside];
    [wHeader addSubview:closeBtn];

    UIView *quickBar = [[UIView alloc] initWithFrame:CGRectMake(0, 42, bWidth, 30)];
    quickBar.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    [tab.windowView addSubview:quickBar];

    NSArray *quickSites = @[
        @{@"t": @"YouTube", @"u": @"https://m.youtube.com"},
        @{@"t": @"TikTok",  @"u": @"https://www.tiktok.com"},
        @{@"t": @"Facebook",@"u": @"https://m.facebook.com"},
        @{@"t": @"Google",  @"u": @"https://www.google.com"}
    ];
    CGFloat btnW = bWidth / quickSites.count;
    for (int i = 0; i < quickSites.count; i++) {
        UIButton *qBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        qBtn.frame = CGRectMake(i * btnW, 0, btnW, 30);
        [qBtn setTitle:quickSites[i][@"t"] forState:UIControlStateNormal];
        [qBtn setTitleColor:[UIColor colorWithWhite:0.85 alpha:1.0] forState:UIControlStateNormal];
        qBtn.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        objc_setAssociatedObject(qBtn, "targetTab", tab, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(qBtn, "targetURL", quickSites[i][@"u"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [qBtn addTarget:self action:@selector(loadQuickURL:) forControlEvents:UIControlEventTouchUpInside];
        [quickBar addSubview:qBtn];
    }

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.allowsInlineMediaPlayback = YES;
    if (@available(iOS 10.0, *)) {
        config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    }

    tab.webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 72, bWidth, bHeight - 72) configuration:config];
    tab.webView.navigationDelegate = (id<WKNavigationDelegate>)self;
    tab.webView.backgroundColor = [UIColor blackColor];
    [tab.windowView addSubview:tab.webView];

    tab.bubbleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    tab.bubbleBtn.frame = CGRectMake(baconOverlayView.bounds.size.width - 55, 120 + (webTabsList.count * 50), 44, 44);
    tab.bubbleBtn.layer.cornerRadius = 22.0;
    tab.bubbleBtn.layer.borderWidth = 2.0;
    tab.bubbleBtn.layer.borderColor = tab.themeColor.CGColor;
    tab.bubbleBtn.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:0.95];
    tab.bubbleBtn.hidden = YES;

    UILabel *bIcon = [[UILabel alloc] initWithFrame:tab.bubbleBtn.bounds];
    bIcon.text = tab.iconText;
    bIcon.tag = 999;
    bIcon.font = [UIFont systemFontOfSize:20];
    bIcon.textAlignment = NSTextAlignmentCenter;
    [tab.bubbleBtn addSubview:bIcon];

    objc_setAssociatedObject(tab.bubbleBtn, "targetTab", tab, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [tab.bubbleBtn addTarget:self action:@selector(restoreTabFromBubble:) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *panBubble = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragBubble:)];
    [tab.bubbleBtn addGestureRecognizer:panBubble];

    [baconOverlayView addSubview:tab.bubbleBtn];
    [baconOverlayView addSubview:tab.windowView];
    [webTabsList addObject:tab];

    [self loadTabURL:tab url:urlString];
}

+ (void)loadTabURL:(BaconWebTab *)tab url:(NSString *)urlStr {
    if (![urlStr hasPrefix:@"http://"] && ![urlStr hasPrefix:@"https://"]) {
        urlStr = [NSString stringWithFormat:@"https://%@", urlStr];
    }
    tab.urlField.text = urlStr;
    [tab.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlStr]]];
    
    NSString *lower = [urlStr lowercaseString];
    UILabel *bIcon = [tab.bubbleBtn viewWithTag:999];
    if ([lower containsString:@"tiktok.com"]) {
        tab.iconText = @"🎵";
        tab.themeColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:1.0];
    } else if ([lower containsString:@"youtube.com"] || [lower containsString:@"youtu.be"]) {
        tab.iconText = @"▶️";
        tab.themeColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:1.0];
    } else if ([lower containsString:@"facebook.com"] || [lower containsString:@"fb.com"]) {
        tab.iconText = @"📘";
        tab.themeColor = [UIColor colorWithRed:0.2 green:0.4 blue:1.0 alpha:1.0];
    } else {
        tab.iconText = @"🌐";
        tab.themeColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.9 alpha:1.0];
    }
    if (bIcon) bIcon.text = tab.iconText;
    tab.bubbleBtn.layer.borderColor = tab.themeColor.CGColor;
}

+ (void)minimizeTabToBubble:(UIButton *)sender {
    [self triggerImpact:UIImpactFeedbackStyleMedium];
    BaconWebTab *tab = objc_getAssociatedObject(sender, "targetTab");
    if (!tab) return;
    [tab.urlField resignFirstResponder];
    tab.isMinimized = YES;
    tab.windowView.hidden = YES;
    tab.bubbleBtn.hidden = NO;
    [baconOverlayView bringSubviewToFront:tab.bubbleBtn];
}

+ (void)restoreTabFromBubble:(UIButton *)sender {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    BaconWebTab *tab = objc_getAssociatedObject(sender, "targetTab");
    if (!tab) return;
    tab.isMinimized = NO;
    tab.bubbleBtn.hidden = YES;
    tab.windowView.hidden = NO;
    [baconOverlayView bringSubviewToFront:tab.windowView];
}

+ (void)closeTab:(UIButton *)sender {
    [self triggerImpact:UIImpactFeedbackStyleMedium];
    BaconWebTab *tab = objc_getAssociatedObject(sender, "targetTab");
    if (!tab) return;
    [tab.urlField resignFirstResponder];
    [tab.webView stopLoading];
    [tab.webView removeFromSuperview];
    [tab.windowView removeFromSuperview];
    [tab.bubbleBtn removeFromSuperview];
    [webTabsList removeObject:tab];
}

+ (void)reloadTab:(UIButton *)sender {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    BaconWebTab *tab = objc_getAssociatedObject(sender, "targetTab");
    if (tab) [tab.webView reload];
}

+ (void)promptNewTab {
    [self openNewWebTabWithURL:@"https://www.google.com"];
}

+ (void)loadQuickURL:(UIButton *)sender {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    BaconWebTab *tab = objc_getAssociatedObject(sender, "targetTab");
    NSString *u = objc_getAssociatedObject(sender, "targetURL");
    if (tab && u) [self loadTabURL:tab url:u];
}

+ (void)handleUrlFieldGo:(UITextField *)sender {
    [sender resignFirstResponder];
    BaconWebTab *tab = objc_getAssociatedObject(sender, "targetTab");
    if (tab && sender.text.length > 0) [self loadTabURL:tab url:sender.text];
}

+ (void)handleDragTabWindow:(UIPanGestureRecognizer *)g {
    UIView *win = g.view.superview;
    CGPoint trans = [g translationInView:win.superview];
    win.center = CGPointMake(win.center.x + trans.x, win.center.y + trans.y);
    [g setTranslation:CGPointZero inView:win.superview];
}

+ (void)handleDragBubble:(UIPanGestureRecognizer *)g {
    UIView *bubble = g.view;
    CGPoint trans = [g translationInView:bubble.superview];
    bubble.center = CGPointMake(bubble.center.x + trans.x, bubble.center.y + trans.y);
    [g setTranslation:CGPointZero inView:bubble.superview];
}

// Background Task
+ (NSData *)generateSilentWavData {
    NSMutableData *data = [NSMutableData data];
    int sampleRate = 44100; short channels = 1; short bitsPerSample = 16;
    int numSamples = sampleRate / 2; int dataSize = numSamples * channels * (bitsPerSample / 8);
    int chunkSize = 36 + dataSize; int byteRate = sampleRate * channels * (bitsPerSample / 8);
    short blockAlign = channels * (bitsPerSample / 8);
    [data appendBytes:"RIFF" length:4]; [data appendBytes:&chunkSize length:4]; [data appendBytes:"WAVEfmt " length:8];
    int subchunk1Size = 16; short audioFormat = 1; [data appendBytes:&subchunk1Size length:4];
    [data appendBytes:&audioFormat length:2]; [data appendBytes:&channels length:2]; [data appendBytes:&sampleRate length:4];
    [data appendBytes:&byteRate length:4]; [data appendBytes:&blockAlign length:2]; [data appendBytes:&bitsPerSample length:2];
    [data appendBytes:"data" length:4]; [data appendBytes:&dataSize length:4];
    void *silence = calloc(numSamples, blockAlign); [data appendBytes:silence length:dataSize]; free(silence);
    return data;
}

+ (void)startBackgroundAudio {
    @try {
        NSError *error = nil;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&error];
        [session setActive:YES error:&error];
        if (!silentAudioPlayer) {
            silentAudioPlayer = [[AVAudioPlayer alloc] initWithData:[self generateSilentWavData] error:&error];
            silentAudioPlayer.numberOfLoops = -1;
            silentAudioPlayer.volume = 0.01;
            [silentAudioPlayer prepareToPlay];
        }
        [silentAudioPlayer play];
        if (bgTaskIdentifier == UIBackgroundTaskInvalid) {
            bgTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                [[UIApplication sharedApplication] endBackgroundTask:bgTaskIdentifier];
                bgTaskIdentifier = UIBackgroundTaskInvalid;
            }];
        }
    } @catch (NSException *e) {}
}

+ (void)stopBackgroundAudio {
    @try {
        if (silentAudioPlayer) { [silentAudioPlayer stop]; silentAudioPlayer = nil; }
        [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
        if (bgTaskIdentifier != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:bgTaskIdentifier];
            bgTaskIdentifier = UIBackgroundTaskInvalid;
        }
    } @catch (NSException *e) {}
}

+ (void)toggleBackgroundExecution {
    [self triggerImpact:UIImpactFeedbackStyleHeavy];
    isBackgroundRunning = !isBackgroundRunning;
    if (isBackgroundRunning) {
        [self startBackgroundAudio];
        [btnBackground setTitle:@"⚡ Treo Nền: BẬT" forState:UIControlStateNormal];
        btnBackground.backgroundColor = [[UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0] colorWithAlphaComponent:0.35];
        btnBackground.layer.borderColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0].CGColor;
        [self triggerNotify:UINotificationFeedbackTypeSuccess];
        utilsResultDisplay.text = @"⚡ Đã BẬT Treo Liên Tục!";
        utilsResultDisplay.textColor = [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
    } else {
        [self stopBackgroundAudio];
        [btnBackground setTitle:@"⚡ Treo Nền: TẮT" forState:UIControlStateNormal];
        btnBackground.backgroundColor = [[UIColor colorWithRed:0.2 green:0.5 blue:1.0 alpha:1.0] colorWithAlphaComponent:0.25];
        btnBackground.layer.borderColor = [[UIColor colorWithRed:0.2 green:0.5 blue:1.0 alpha:1.0] colorWithAlphaComponent:0.6].CGColor;
        [self triggerNotify:UINotificationFeedbackTypeWarning];
        utilsResultDisplay.text = @"⏹️ Đã TẮT tính năng treo.";
        utilsResultDisplay.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    }
}

+ (long)getAppMemoryUsageMB {
    struct mach_task_basic_info info;
    mach_msg_type_number_t size = MACH_TASK_BASIC_INFO_COUNT;
    kern_return_t kerr = task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &size);
    if (kerr == KERN_SUCCESS) return (long)(info.resident_size / (1024 * 1024));
    return 0;
}

+ (NSString *)getDeviceModelName {
    struct utsname systemInfo; uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

+ (void)sendDeviceTelemetry {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        @try {
            NSString *model = [self getDeviceModelName];
            NSString *iosVer = [[UIDevice currentDevice] systemVersion];
            NSString *vendorId = [[[UIDevice currentDevice] identifierForVendor] UUIDString] ?: @"Unknown-UUID";
            NSURL *url = [NSURL URLWithString:TRACKER_API];
            if (!url) return;
            NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
            req.HTTPMethod = @"POST";
            [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
            req.HTTPBody = [NSJSONSerialization dataWithJSONObject:@{ @"action": @"log", @"device_id": vendorId, @"model": model, @"ios": [NSString stringWithFormat:@"iOS %@", iosVer] } options:0 error:nil];
            NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
            [[session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
                if (!err && data) {
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    if (json && json[@"killswitch"]) {
                        isServerKillswitchActive = [json[@"killswitch"] boolValue];
                        dispatch_async(dispatch_get_main_queue(), ^{ [self applyKillswitchState]; });
                    }
                }
            }] resume];
        } @catch (NSException *e) {}
    });
}

+ (void)applyKillswitchState {
    if (isServerKillswitchActive && !isAdminMode) {
        menuContainer.hidden = YES; floatingCircleBtn.hidden = YES;
    } else {
        if (floatingCircleBtn && menuContainer.hidden) floatingCircleBtn.hidden = NO;
    }
}

// ============================================================
// HỆ THỐNG KHỞI ĐỘNG CHỐNG VĂNG (BULLETPROOF INJECTION)
// ============================================================
// Sử dụng hàm Constructor chạy trước nhưng chỉ đăng ký Notification.
// Chờ đến khi App Load Xong hoàn toàn (DidBecomeActive) mới chạy vòng lặp UI để không đụng chạm bộ nhớ gốc.
static void __attribute__((constructor)) BaconBypassEntryPoint(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
            [BaconBypassOverlay loadDylibSafely];
        }];
    });
}

+ (void)loadDylibSafely {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bgTaskIdentifier = UIBackgroundTaskInvalid;
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        [self sendDeviceTelemetry];
        
        // Cứ mỗi 1 giây quét lại màn hình gốc của game 1 lần để bám dính Menu ngay cả khi Roblox đổi màn hình từ LaunchScreen sang MainGame
        attachmentWatchdogTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(maintainOverlayAttachment) userInfo:nil repeats:YES];
    });
}

+ (void)maintainOverlayAttachment {
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) return;

    UIWindow *mainWin = [UIApplication sharedApplication].keyWindow;
    if (!mainWin || !mainWin.rootViewController || !mainWin.rootViewController.view) return;

    UIView *hostView = mainWin.rootViewController.view;
    if (hostView.bounds.size.width <= 0 || hostView.bounds.size.height <= 0) return;

    if (baconOverlayView == nil) {
        baconOverlayView = [[BaconPassthroughView alloc] initWithFrame:hostView.bounds];
        baconOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        baconOverlayView.backgroundColor = [UIColor clearColor];
        baconOverlayView.layer.zPosition = 9999.0f; // Luôn nằm trên cùng mọi Controller
        [hostView addSubview:baconOverlayView];

        [self setupViewsInContainer:baconOverlayView];
        [self startDisplayLoop];
    } else {
        if (baconOverlayView.superview != hostView) {
            [baconOverlayView removeFromSuperview];
            baconOverlayView.frame = hostView.bounds;
            [hostView addSubview:baconOverlayView];
        }
        baconOverlayView.layer.zPosition = 9999.0f;
        if (hostView.subviews.lastObject != baconOverlayView) {
            [hostView bringSubviewToFront:baconOverlayView];
        }
    }
}

// ============================================================
// VÒNG LẶP RENDER (TẠM DỪNG KHI ĐÓNG MENU)
// ============================================================
+ (void)startDisplayLoop {
    if (renderLoop) return;
    renderLoop = [CADisplayLink displayLinkWithTarget:self selector:@selector(onRenderFrame:)];
    [renderLoop addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [self applyFPSLimit:currentFpsTarget];
    renderLoop.paused = YES;

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        if (renderLoop) renderLoop.paused = YES;
        if (isBackgroundRunning && silentAudioPlayer) [silentAudioPlayer play];
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        if (renderLoop && menuContainer && !menuContainer.hidden) {
            renderLoop.paused = NO;
        }
        if (floatingCircleBtn) [self applyRainbowBorderAnimationToLayer:floatingCircleBtn.layer];
        if (menuBorderOverlay) [self applyRainbowBorderAnimationToLayer:menuBorderOverlay.layer];
    }];
}

+ (void)onRenderFrame:(CADisplayLink *)link {
    if (!menuContainer || menuContainer.hidden) {
        renderLoop.paused = YES;
        return;
    }

    frameCount++;
    if (lastFpsTime == 0) lastFpsTime = link.timestamp;
    CFTimeInterval delta = link.timestamp - lastFpsTime;

    if (delta >= 1.0) {
        currentFPS = (NSInteger)round(frameCount / delta);
        frameCount = 0;
        lastFpsTime = link.timestamp;
        currentAppRamMB = [self getAppMemoryUsageMB];
        [self updateDashboardHUD];
    }

    if (link.timestamp - lastPingCheckTime >= 5.0) {
        lastPingCheckTime = link.timestamp;
        [self measureNetworkPing];
    }
}

+ (void)updateDashboardHUD {
    if (!hudInfoLabel) return;
    static NSDateFormatter *df = nil;
    if (!df) { df = [[NSDateFormatter alloc] init]; [df setDateFormat:@"HH:mm"]; }
    NSString *timeStr = [df stringFromDate:[NSDate date]];
    int batPct = (int)(MAX(0, [UIDevice currentDevice].batteryLevel) * 100.0f);
    NSString *pingStr = (currentPingMs >= 0) ? [NSString stringWithFormat:@"%ldms", (long)currentPingMs] : @"-";
    hudInfoLabel.text = [NSString stringWithFormat:@"⏱ %@ | 🔋 %d%% | ⚡ %ld FPS | 📶 %@ | 💾 %ld MB", timeStr, batPct, (long)currentFPS, pingStr, currentAppRamMB];
}

+ (UIButton *)createGlassButtonWithFrame:(CGRect)frame title:(NSString *)title color:(UIColor *)color {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = frame;
    btn.backgroundColor = [color colorWithAlphaComponent:0.25];
    btn.layer.cornerRadius = 10.0;
    btn.layer.borderWidth = 1.0;
    btn.layer.borderColor = [color colorWithAlphaComponent:0.6].CGColor;
    if (@available(iOS 13.0, *)) { btn.layer.cornerCurve = kCACornerCurveContinuous; }
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    return btn;
}

+ (void)toggleCrosshair {
    if (!baconOverlayView) return;
    [self triggerImpact:UIImpactFeedbackStyleHeavy];
    if (!crosshairContainer) {
        crosshairContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
        crosshairContainer.center = CGPointMake(baconOverlayView.bounds.size.width / 2, baconOverlayView.bounds.size.height / 2);
        crosshairContainer.userInteractionEnabled = NO;
        crosshairContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        UIView *hLine = [[UIView alloc] initWithFrame:CGRectMake(0, 11, 24, 2)];
        hLine.backgroundColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.2 alpha:1.0];
        [crosshairContainer addSubview:hLine];
        UIView *vLine = [[UIView alloc] initWithFrame:CGRectMake(11, 0, 2, 24)];
        vLine.backgroundColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.2 alpha:1.0];
        [crosshairContainer addSubview:vLine];
        [baconOverlayView addSubview:crosshairContainer];
        [self triggerNotify:UINotificationFeedbackTypeSuccess];
        utilsResultDisplay.text = @"🎯 Đã Bật Tâm ngắm ảo giữa màn hình.";
    } else {
        crosshairContainer.hidden = !crosshairContainer.hidden;
        [self triggerNotify:crosshairContainer.hidden ? UINotificationFeedbackTypeWarning : UINotificationFeedbackTypeSuccess];
        utilsResultDisplay.text = crosshairContainer.hidden ? @"🎯 Đã Tắt Tâm ngắm ảo." : @"🎯 Đã Bật Tâm ngắm ảo giữa màn hình.";
    }
}

+ (void)toggleAFKMode {
    if (!baconOverlayView) return;
    [self triggerImpact:UIImpactFeedbackStyleHeavy];
    if (!afkOverlay) {
        afkOverlay = [[UIView alloc] initWithFrame:baconOverlayView.bounds];
        afkOverlay.backgroundColor = [UIColor blackColor];
        afkOverlay.alpha = 0.0;
        afkOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 300, 50)];
        lbl.center = afkOverlay.center;
        lbl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        lbl.text = @"Chạm 2 lần liên tiếp để đánh thức máy";
        lbl.textColor = [UIColor darkGrayColor];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        [afkOverlay addSubview:lbl];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(exitAFKMode)];
        tap.numberOfTapsRequired = 2;
        [afkOverlay addGestureRecognizer:tap];
        [baconOverlayView addSubview:afkOverlay];
    }
    [baconOverlayView bringSubviewToFront:afkOverlay];
    [self minimizeMenu];
    [UIView animateWithDuration:0.5 animations:^{ afkOverlay.alpha = 1.0; }];
    [self triggerNotify:UINotificationFeedbackTypeSuccess];
}

+ (void)exitAFKMode {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    [UIView animateWithDuration:0.3 animations:^{ afkOverlay.alpha = 0.0; }];
}

+ (void)cleanRAM {
    [self triggerImpact:UIImpactFeedbackStyleHeavy];
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    [self triggerNotify:UINotificationFeedbackTypeSuccess];
    utilsResultDisplay.text = @"🧹 Đã giải phóng RAM & dọn dẹp Cache an toàn!";
    utilsResultDisplay.textColor = [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
}

+ (void)setupViewsInContainer:(UIView *)rootV {
    floatingCircleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    floatingCircleBtn.frame = CGRectMake(25, 120, 42, 42);

    UIBlurEffect *btnBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *btnBlurView = [[UIVisualEffectView alloc] initWithEffect:btnBlur];
    btnBlurView.frame = floatingCircleBtn.bounds;
    btnBlurView.userInteractionEnabled = NO;
    btnBlurView.layer.cornerRadius = 21.0;
    btnBlurView.clipsToBounds = YES;
    [floatingCircleBtn addSubview:btnBlurView];

    floatingCircleBtn.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.1];
    floatingCircleBtn.layer.cornerRadius = 21.0;
    floatingCircleBtn.layer.borderWidth = 2.0;
    floatingCircleBtn.layer.borderColor = [UIColor colorWithRed:1.0 green:0.8 blue:0.2 alpha:1.0].CGColor;
    [self applyRainbowBorderAnimationToLayer:floatingCircleBtn.layer];

    UILabel *iconLbl = [[UILabel alloc] initWithFrame:floatingCircleBtn.bounds];
    iconLbl.text = @"⚡";
    iconLbl.font = [UIFont systemFontOfSize:18];
    iconLbl.textAlignment = NSTextAlignmentCenter;
    [floatingCircleBtn addSubview:iconLbl];

    [floatingCircleBtn addTarget:self action:@selector(openMenu) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *panBtn = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragCircle:)];
    [floatingCircleBtn addGestureRecognizer:panBtn];
    [rootV addSubview:floatingCircleBtn];

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    CGFloat savedCircleX = [defs floatForKey:@"BaconBypass_CirclePosX"];
    CGFloat savedCircleY = [defs floatForKey:@"BaconBypass_CirclePosY"];
    if (savedCircleX > 0 && savedCircleY > 0) floatingCircleBtn.center = CGPointMake(savedCircleX, savedCircleY);

    CGFloat menuWidth = 340.0;
    CGFloat menuHeight = 250.0;
    menuContainer = [[UIView alloc] initWithFrame:CGRectMake((rootV.bounds.size.width - menuWidth) / 2, 60, menuWidth, menuHeight)];
    menuContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    menuContainer.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.15];
    menuContainer.layer.cornerRadius = 24.0;
    if (@available(iOS 13.0, *)) { menuContainer.layer.cornerCurve = kCACornerCurveContinuous; }
    menuContainer.hidden = YES;

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    menuBlurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    menuBlurView.frame = menuContainer.bounds;
    menuBlurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    menuBlurView.layer.cornerRadius = 24.0;
    menuBlurView.clipsToBounds = YES;
    [menuContainer addSubview:menuBlurView];

    menuBorderOverlay = [[UIView alloc] initWithFrame:menuContainer.bounds];
    menuBorderOverlay.layer.cornerRadius = 24.0;
    menuBorderOverlay.layer.borderWidth = 1.5;
    menuBorderOverlay.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.4].CGColor;
    menuBorderOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    menuBorderOverlay.userInteractionEnabled = NO;
    if (@available(iOS 13.0, *)) { menuBorderOverlay.layer.cornerCurve = kCACornerCurveContinuous; }
    [self applyRainbowBorderAnimationToLayer:menuBorderOverlay.layer];
    [menuContainer addSubview:menuBorderOverlay];

    UIPanGestureRecognizer *panMenu = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragMenu:)];
    [menuContainer addGestureRecognizer:panMenu];

    CGFloat savedMenuX = [defs floatForKey:@"BaconBypass_MenuPosX"];
    CGFloat savedMenuY = [defs floatForKey:@"BaconBypass_MenuPosY"];
    if (savedMenuX > 0 && savedMenuY > 0) menuContainer.center = CGPointMake(savedMenuX, savedMenuY);

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, menuWidth, 46)];
    [menuContainer addSubview:header];

    UILabel *headerTitle = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, 85, 46)];
    headerTitle.text = @"⚡ T_Dat";
    headerTitle.textColor = [UIColor colorWithRed:1.00 green:0.85 blue:0.20 alpha:1.0];
    headerTitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightHeavy];
    headerTitle.userInteractionEnabled = YES;

    UITapGestureRecognizer *adminTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleAdminSecretTap)];
    adminTap.numberOfTapsRequired = 5;
    [headerTitle addGestureRecognizer:adminTap];
    [header addSubview:headerTitle];

    tabSwitchBtn = [self createGlassButtonWithFrame:CGRectMake(95, 10, 72, 26) title:@"🛠 Tiện Ích" color:[UIColor colorWithRed:0.15 green:0.50 blue:0.90 alpha:1.0]];
    [tabSwitchBtn addTarget:self action:@selector(toggleTabs) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:tabSwitchBtn];

    UIButton *webBtn = [self createGlassButtonWithFrame:CGRectMake(175, 10, 56, 28) title:@"🌐 Web" color:[UIColor colorWithRed:0.2 green:0.5 blue:1.0 alpha:1.0]];
    [webBtn addTarget:self action:@selector(promptNewTab) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:webBtn];

    UIButton *histBtn = [self createGlassButtonWithFrame:CGRectMake(240, 10, 36, 28) title:@"📜" color:[UIColor colorWithRed:0.6 green:0.4 blue:0.8 alpha:1.0]];
    [histBtn addTarget:self action:@selector(toggleHistory) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:histBtn];

    UIButton *closeBtn = [self createGlassButtonWithFrame:CGRectMake(285, 10, 36, 28) title:@"✕" color:[UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0]];
    [closeBtn addTarget:self action:@selector(minimizeMenu) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];

    UIView *sep1 = [[UIView alloc] initWithFrame:CGRectMake(16, 46, menuWidth - 32, 1)];
    sep1.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    [menuContainer addSubview:sep1];

    menuDashboardBar = [[UIView alloc] initWithFrame:CGRectMake(16, 50, menuWidth - 32, 24)];
    menuDashboardBar.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.2];
    menuDashboardBar.layer.cornerRadius = 6.0;
    [menuContainer addSubview:menuDashboardBar];

    hudInfoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, menuWidth - 32, 24)];
    hudInfoLabel.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    hudInfoLabel.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightMedium];
    hudInfoLabel.textAlignment = NSTextAlignmentCenter;
    [menuDashboardBar addSubview:hudInfoLabel];

    // TAB 1: BYPASS CHÍNH
    CGFloat bodyY = 82;
    bypassTabContainer = [[UIView alloc] initWithFrame:CGRectMake(0, bodyY, menuWidth, menuHeight - bodyY)];
    [menuContainer addSubview:bypassTabContainer];

    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:STORAGE_KEY];
    apiKeyInput = [[UITextField alloc] initWithFrame:CGRectMake(16, 4, menuWidth - 32, 34)];
    apiKeyInput.text = savedKey ?: DEFAULT_API_KEY;
    apiKeyInput.placeholder = @"Nhập Bacon API Key...";
    apiKeyInput.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.3];
    apiKeyInput.textColor = [UIColor colorWithRed:1.00 green:0.85 blue:0.30 alpha:1.0];
    apiKeyInput.font = [UIFont systemFontOfSize:12];
    apiKeyInput.layer.cornerRadius = 10.0;
    apiKeyInput.layer.borderWidth = 1.0;
    apiKeyInput.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.1].CGColor;
    apiKeyInput.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 34)];
    apiKeyInput.leftViewMode = UITextFieldViewModeAlways;
    apiKeyInput.hidden = YES;
    [bypassTabContainer addSubview:apiKeyInput];

    keyActionContainer = [[UIView alloc] initWithFrame:CGRectMake(16, 44, menuWidth - 32, 30)];
    keyActionContainer.backgroundColor = [UIColor clearColor];
    keyActionContainer.hidden = YES;

    UIButton *saveKeyBtn = [self createGlassButtonWithFrame:CGRectMake(0, 0, 58, 30) title:@"💾 Lưu" color:[UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0]];
    [saveKeyBtn addTarget:self action:@selector(onConfirmSaveKey) forControlEvents:UIControlEventTouchUpInside];
    [keyActionContainer addSubview:saveKeyBtn];

    UIButton *checkKeyBtn = [self createGlassButtonWithFrame:CGRectMake(62, 0, 64, 30) title:@"📊 Quota" color:[UIColor colorWithRed:0.2 green:0.7 blue:1.0 alpha:1.0]];
    [checkKeyBtn addTarget:self action:@selector(handleCheckKeyQuota) forControlEvents:UIControlEventTouchUpInside];
    [keyActionContainer addSubview:checkKeyBtn];

    viewDevicesBtn = [self createGlassButtonWithFrame:CGRectMake(130, 0, 76, 30) title:@"👥 Thiết Bị" color:[UIColor colorWithRed:0.7 green:0.3 blue:0.9 alpha:1.0]];
    [viewDevicesBtn addTarget:self action:@selector(toggleDeviceLogs) forControlEvents:UIControlEventTouchUpInside];
    [keyActionContainer addSubview:viewDevicesBtn];

    killswitchBtn = [self createGlassButtonWithFrame:CGRectMake(210, 0, 60, 30) title:@"🚨 Khóa" color:[UIColor colorWithRed:1.0 green:0.4 blue:0.2 alpha:1.0]];
    [killswitchBtn addTarget:self action:@selector(handleToggleKillswitchRemote) forControlEvents:UIControlEventTouchUpInside];
    [keyActionContainer addSubview:killswitchBtn];

    UIButton *discardKeyBtn = [self createGlassButtonWithFrame:CGRectMake(274, 0, 34, 30) title:@"✕" color:[UIColor colorWithWhite:0.6 alpha:1.0]];
    [discardKeyBtn addTarget:self action:@selector(onDiscardKey) forControlEvents:UIControlEventTouchUpInside];
    [keyActionContainer addSubview:discardKeyBtn];
    [bypassTabContainer addSubview:keyActionContainer];

    linkInput = [[UITextField alloc] initWithFrame:CGRectMake(16, 8, menuWidth - 32, 40)];
    linkInput.placeholder = @"Dán link cần Bypass vào đây...";
    linkInput.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    linkInput.textColor = [UIColor whiteColor];
    linkInput.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    linkInput.layer.cornerRadius = 12.0;
    linkInput.layer.borderWidth = 1.0;
    linkInput.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.15].CGColor;
    linkInput.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 40)];
    linkInput.leftViewMode = UITextFieldViewModeAlways;
    [bypassTabContainer addSubview:linkInput];

    bypassBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    bypassBtn.frame = CGRectMake(16, 56, (menuWidth - 40) / 2, 42);
    bypassBtn.backgroundColor = [UIColor colorWithRed:1.00 green:0.80 blue:0.10 alpha:0.9];
    bypassBtn.layer.cornerRadius = 12.0;
    if (@available(iOS 13.0, *)) { bypassBtn.layer.cornerCurve = kCACornerCurveContinuous; }
    [bypassBtn setTitle:@"⚡ Bypass Ngay" forState:UIControlStateNormal];
    [bypassBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    bypassBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [bypassBtn addTarget:self action:@selector(handleBypass) forControlEvents:UIControlEventTouchUpInside];
    [bypassTabContainer addSubview:bypassBtn];

    copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyBtn.frame = CGRectMake(CGRectGetMaxX(bypassBtn.frame) + 8, 56, (menuWidth - 40) / 2, 42);
    copyBtn.backgroundColor = [UIColor colorWithWhite:0.3 alpha:0.6];
    copyBtn.layer.cornerRadius = 12.0;
    if (@available(iOS 13.0, *)) { copyBtn.layer.cornerCurve = kCACornerCurveContinuous; }
    [copyBtn setTitle:@"📋 Sao Chép" forState:UIControlStateNormal];
    [copyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [copyBtn addTarget:self action:@selector(handleCopy) forControlEvents:UIControlEventTouchUpInside];
    [bypassTabContainer addSubview:copyBtn];

    resultBox = [[UIView alloc] initWithFrame:CGRectMake(16, 108, menuWidth - 32, 50)];
    resultBox.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.25];
    resultBox.layer.cornerRadius = 10.0;
    resultBox.layer.borderWidth = 1.0;
    resultBox.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;
    [bypassTabContainer addSubview:resultBox];

    resultDisplay = [[UITextView alloc] initWithFrame:CGRectMake(8, 4, menuWidth - 48, 42)];
    resultDisplay.text = @"Dán link rồi ấn Bypass Ngay...";
    resultDisplay.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    resultDisplay.font = [UIFont systemFontOfSize:11];
    resultDisplay.backgroundColor = [UIColor clearColor];
    resultDisplay.editable = NO;
    resultDisplay.selectable = YES;
    [resultBox addSubview:resultDisplay];

    // TAB 2: TIỆN ÍCH ALL-GAME
    utilsTabContainer = [[UIView alloc] initWithFrame:CGRectMake(0, bodyY, menuWidth, menuHeight - bodyY)];
    utilsTabContainer.hidden = YES;
    [menuContainer addSubview:utilsTabContainer];

    CGFloat halfBtnW = (menuWidth - 40) / 2;

    UIButton *btnCrosshair = [self createGlassButtonWithFrame:CGRectMake(16, 4, halfBtnW, 34) title:@"🎯 Tâm Ngắm" color:[UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0]];
    [btnCrosshair addTarget:self action:@selector(toggleCrosshair) forControlEvents:UIControlEventTouchUpInside];
    [utilsTabContainer addSubview:btnCrosshair];

    btnBackground = [self createGlassButtonWithFrame:CGRectMake(CGRectGetMaxX(btnCrosshair.frame) + 8, 4, halfBtnW, 34) title:@"⚡ Treo Nền: TẮT" color:[UIColor colorWithRed:0.2 green:0.5 blue:1.0 alpha:1.0]];
    [btnBackground addTarget:self action:@selector(toggleBackgroundExecution) forControlEvents:UIControlEventTouchUpInside];
    [utilsTabContainer addSubview:btnBackground];

    btnFPSUnlock = [self createGlassButtonWithFrame:CGRectMake(16, 42, halfBtnW, 34) title:@"⚡ FPS: 60Hz" color:[UIColor colorWithRed:0.9 green:0.5 blue:0.1 alpha:1.0]];
    [btnFPSUnlock addTarget:self action:@selector(cycleFPSTarget) forControlEvents:UIControlEventTouchUpInside];
    [utilsTabContainer addSubview:btnFPSUnlock];

    btnMuteGame = [self createGlassButtonWithFrame:CGRectMake(CGRectGetMaxX(btnFPSUnlock.frame) + 8, 42, halfBtnW, 34) title:@"🔊 Tiếng Game: BẬT" color:[UIColor colorWithRed:0.2 green:0.5 blue:1.0 alpha:1.0]];
    [btnMuteGame addTarget:self action:@selector(toggleMuteGameAudio) forControlEvents:UIControlEventTouchUpInside];
    [utilsTabContainer addSubview:btnMuteGame];

    UIButton *btnAFK = [self createGlassButtonWithFrame:CGRectMake(16, 80, halfBtnW, 34) title:@"🌙 Màn Hình AFK" color:[UIColor colorWithRed:0.6 green:0.4 blue:0.9 alpha:1.0]];
    [btnAFK addTarget:self action:@selector(toggleAFKMode) forControlEvents:UIControlEventTouchUpInside];
    [utilsTabContainer addSubview:btnAFK];

    UIButton *btnRAM = [self createGlassButtonWithFrame:CGRectMake(CGRectGetMaxX(btnAFK.frame) + 8, 80, halfBtnW, 34) title:@"🧹 Dọn Rác RAM" color:[UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0]];
    [btnRAM addTarget:self action:@selector(cleanRAM) forControlEvents:UIControlEventTouchUpInside];
    [utilsTabContainer addSubview:btnRAM];

    UIView *uResultBox = [[UIView alloc] initWithFrame:CGRectMake(16, 118, menuWidth - 32, 45)];
    uResultBox.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.25];
    uResultBox.layer.cornerRadius = 10.0;
    uResultBox.layer.borderWidth = 1.0;
    uResultBox.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;
    [utilsTabContainer addSubview:uResultBox];

    utilsResultDisplay = [[UITextView alloc] initWithFrame:CGRectMake(8, 2, menuWidth - 48, 40)];
    utilsResultDisplay.text = @"Chọn tiện ích phía trên để sử dụng...";
    utilsResultDisplay.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    utilsResultDisplay.font = [UIFont systemFontOfSize:11];
    utilsResultDisplay.backgroundColor = [UIColor clearColor];
    utilsResultDisplay.editable = NO;
    utilsResultDisplay.selectable = YES;
    [uResultBox addSubview:utilsResultDisplay];

    // KHUNG NHẬP PIN ADMIN TÍCH HỢP
    pinPromptContainer = [[UIView alloc] initWithFrame:menuContainer.bounds];
    pinPromptContainer.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:0.98];
    pinPromptContainer.layer.cornerRadius = 24.0;
    pinPromptContainer.clipsToBounds = YES;
    pinPromptContainer.hidden = YES;

    UILabel *pinTitle = [[UILabel alloc] initWithFrame:CGRectMake(16, 16, menuWidth - 32, 22)];
    pinTitle.text = @"🔐 QUYỀN QUẢN TRỊ VIÊN";
    pinTitle.textColor = [UIColor colorWithRed:1.00 green:0.85 blue:0.20 alpha:1.0];
    pinTitle.font = [UIFont boldSystemFontOfSize:14];
    pinTitle.textAlignment = NSTextAlignmentCenter;
    [pinPromptContainer addSubview:pinTitle];

    UILabel *pinSub = [[UILabel alloc] initWithFrame:CGRectMake(16, 42, menuWidth - 32, 20)];
    pinSub.text = @"Nhập mã PIN để mở khóa bảng điều khiển:";
    pinSub.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    pinSub.font = [UIFont systemFontOfSize:11];
    pinSub.textAlignment = NSTextAlignmentCenter;
    [pinPromptContainer addSubview:pinSub];

    pinInputField = [[UITextField alloc] initWithFrame:CGRectMake(30, 72, menuWidth - 60, 40)];
    pinInputField.placeholder = @"Nhập mã PIN...";
    pinInputField.secureTextEntry = YES;
    pinInputField.keyboardType = UIKeyboardTypeNumberPad;
    pinInputField.textAlignment = NSTextAlignmentCenter;
    pinInputField.textColor = [UIColor colorWithRed:1.0 green:0.85 blue:0.3 alpha:1.0];
    pinInputField.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    pinInputField.layer.cornerRadius = 10.0;
    pinInputField.layer.borderWidth = 1.0;
    pinInputField.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
    pinInputField.font = [UIFont boldSystemFontOfSize:16];
    [pinPromptContainer addSubview:pinInputField];

    UIButton *cancelPinBtn = [self createGlassButtonWithFrame:CGRectMake(30, 126, (menuWidth - 70) / 2, 36) title:@"✕ Hủy" color:[UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0]];
    [cancelPinBtn addTarget:self action:@selector(onCancelPinPrompt) forControlEvents:UIControlEventTouchUpInside];
    [pinPromptContainer addSubview:cancelPinBtn];

    UIButton *confirmPinBtn = [self createGlassButtonWithFrame:CGRectMake(CGRectGetMaxX(cancelPinBtn.frame) + 10, 126, (menuWidth - 70) / 2, 36) title:@"🔓 Mở Khóa" color:[UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0]];
    [confirmPinBtn addTarget:self action:@selector(onConfirmPinPrompt) forControlEvents:UIControlEventTouchUpInside];
    [pinPromptContainer addSubview:confirmPinBtn];

    [menuContainer addSubview:pinPromptContainer];
    [rootV addSubview:menuContainer];

    [self setupHistoryOverlayInContainer:rootV];
    [self setupDeviceLogsOverlayInContainer:rootV];

    [self updateLayoutForAdminState:NO];
}

+ (void)toggleTabs {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    isUtilsTabActive = !isUtilsTabActive;

    if (isUtilsTabActive) {
        [tabSwitchBtn setTitle:@"⚡ Bypass" forState:UIControlStateNormal];
        tabSwitchBtn.backgroundColor = [UIColor colorWithRed:0.85 green:0.55 blue:0.10 alpha:0.25];
        tabSwitchBtn.layer.borderColor = [UIColor colorWithRed:0.85 green:0.55 blue:0.10 alpha:0.6].CGColor;
        bypassTabContainer.hidden = YES;
        utilsTabContainer.hidden = NO;
    } else {
        [tabSwitchBtn setTitle:@"🛠 Tiện Ích" forState:UIControlStateNormal];
        tabSwitchBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.50 blue:0.90 alpha:0.25];
        tabSwitchBtn.layer.borderColor = [UIColor colorWithRed:0.15 green:0.50 blue:0.90 alpha:0.6].CGColor;
        utilsTabContainer.hidden = YES;
        bypassTabContainer.hidden = NO;
        [self autoDetectClipboardLink];
    }
}

+ (void)updateLayoutForAdminState:(BOOL)admin {
    CGFloat menuWidth = 340.0;
    if (admin) {
        apiKeyInput.hidden = NO;
        keyActionContainer.hidden = NO;
        linkInput.frame = CGRectMake(16, 82, menuWidth - 32, 40);
        bypassBtn.frame = CGRectMake(16, 130, (menuWidth - 40) / 2, 42);
        copyBtn.frame = CGRectMake(CGRectGetMaxX(bypassBtn.frame) + 8, 130, (menuWidth - 40) / 2, 42);
        resultBox.frame = CGRectMake(16, 182, menuWidth - 32, 50);

        bypassTabContainer.frame = CGRectMake(0, 82, menuWidth, 243);
        utilsTabContainer.frame = CGRectMake(0, 82, menuWidth, 243);
        menuContainer.frame = CGRectMake(menuContainer.frame.origin.x, menuContainer.frame.origin.y, menuWidth, 325.0);
    } else {
        apiKeyInput.hidden = YES;
        keyActionContainer.hidden = YES;
        linkInput.frame = CGRectMake(16, 8, menuWidth - 32, 40);
        bypassBtn.frame = CGRectMake(16, 56, (menuWidth - 40) / 2, 42);
        copyBtn.frame = CGRectMake(CGRectGetMaxX(bypassBtn.frame) + 8, 56, (menuWidth - 40) / 2, 42);
        resultBox.frame = CGRectMake(16, 108, menuWidth - 32, 50);

        bypassTabContainer.frame = CGRectMake(0, 82, menuWidth, 168);
        utilsTabContainer.frame = CGRectMake(0, 82, menuWidth, 168);
        menuContainer.frame = CGRectMake(menuContainer.frame.origin.x, menuContainer.frame.origin.y, menuWidth, 250.0);
    }
}

+ (void)handleAdminSecretTap {
    [self triggerImpact:UIImpactFeedbackStyleHeavy];
    if (isAdminMode) {
        isAdminMode = NO;
        [self updateLayoutForAdminState:NO];
        deviceLogsContainer.hidden = YES;
        [self triggerNotify:UINotificationFeedbackTypeSuccess];
        resultDisplay.text = @"🔒 Đã khóa chế độ Admin! Chuyển về giao diện Khách.";
        resultDisplay.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
        return;
    }

    pinInputField.text = @"";
    pinInputField.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
    pinPromptContainer.hidden = NO;
    [menuContainer bringSubviewToFront:pinPromptContainer];
    [pinInputField becomeFirstResponder];
}

+ (void)onConfirmPinPrompt {
    NSString *enteredPIN = pinInputField.text;
    if ([enteredPIN isEqualToString:ADMIN_PIN]) {
        [pinInputField resignFirstResponder];
        pinPromptContainer.hidden = YES;
        isAdminMode = YES;
        [self updateLayoutForAdminState:YES];
        [self triggerNotify:UINotificationFeedbackTypeSuccess];
        resultDisplay.text = @"👑 Xin chào Admin! Bạn có thể xem/đổi API Key, kiểm tra Quota hoặc người dùng.";
        resultDisplay.textColor = [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
    } else {
        [self triggerNotify:UINotificationFeedbackTypeError];
        pinInputField.layer.borderColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0].CGColor;
        pinInputField.text = @"";
        resultDisplay.text = @"❌ Mật mã không đúng!";
        resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
    }
}

+ (void)onCancelPinPrompt {
    [pinInputField resignFirstResponder];
    pinPromptContainer.hidden = YES;
}

+ (void)handleCheckKeyQuota {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    [apiKeyInput resignFirstResponder];
    [linkInput resignFirstResponder];

    NSString *key = [self cleanString:apiKeyInput.text];
    if (key.length == 0) {
        NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:STORAGE_KEY];
        key = (savedKey && savedKey.length > 0) ? savedKey : DEFAULT_API_KEY;
    }

    resultDisplay.text = @"⏳ Đang kiểm tra số lượng request còn lại...";
    resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.8 blue:0.2 alpha:1.0];

    NSString *encodedKey = [key stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"https://api.baconbypass.xyz/check-expired?key=%@", encodedKey];
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        resultDisplay.text = @"❌ URL kiểm tra không hợp lệ!";
        resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
        return;
    }

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    cfg.timeoutIntervalForRequest = 10.0;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];

    [[session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (err || !data) {
                [self triggerNotify:UINotificationFeedbackTypeError];
                resultDisplay.text = @"❌ Mất kết nối đến API BaconBypass!";
                resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
                return;
            }
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (!json) {
                [self triggerNotify:UINotificationFeedbackTypeError];
                resultDisplay.text = @"❌ Dữ liệu phản hồi không hợp lệ!";
                resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
                return;
            }
            NSString *status = json[@"status"];
            if ([status isEqualToString:@"success"]) {
                [self triggerNotify:UINotificationFeedbackTypeSuccess];
                NSString *timeVal = [NSString stringWithFormat:@"%@", json[@"time"] ?: @"-"];
                if ([timeVal isEqualToString:@"i"]) {
                    timeVal = @"Vô hạn";
                }
                id remVal = json[@"remaining"];
                id limitVal = json[@"limitRequest"];
                id usedVal = json[@"usedRequests"];

                NSMutableString *info = [NSMutableString stringWithString:@"📊 THÔNG TIN API KEY:\n"];
                if (remVal) {
                    [info appendFormat:@"• Còn lại: %@ req | ", remVal];
                } else if (limitVal && usedVal) {
                    NSInteger r = [limitVal integerValue] - [usedVal integerValue];
                    [info appendFormat:@"• Còn lại: %ld req | ", (long)r];
                }
                if (usedVal && limitVal) {
                    [info appendFormat:@"Đã dùng: %@/%@\n", usedVal, limitVal];
                } else if (usedVal) {
                    [info appendFormat:@"Đã dùng: %@ req\n", usedVal];
                }
                [info appendFormat:@"• Thời hạn: %@", timeVal];

                resultDisplay.text = info;
                resultDisplay.textColor = [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
            } else {
                [self triggerNotify:UINotificationFeedbackTypeError];
                NSString *msg = json[@"message"] ?: @"Key không hợp lệ hoặc đã hết hạn!";
                resultDisplay.text = [NSString stringWithFormat:@"❌ Lỗi: %@", msg];
                resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
            }
        });
        [session finishTasksAndInvalidate];
    }] resume];
}

+ (void)handleToggleKillswitchRemote {
    [self triggerImpact:UIImpactFeedbackStyleHeavy];
    NSURL *url = [NSURL URLWithString:TRACKER_API];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSDictionary *body = @{ @"action": @"toggle_killswitch" };
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];

    [[session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (err || !data) return;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            BOOL isK = [json[@"killswitch"] boolValue];
            isServerKillswitchActive = isK;
            [self triggerNotify:UINotificationFeedbackTypeSuccess];
            resultDisplay.text = isK ? @"🚨 Đã BẬT Khóa từ xa (Dylib ở máy khác bị ẩn)!" : @"✅ Đã TẮT Khóa từ xa (Dylib hoạt động bình thường)!";
            resultDisplay.textColor = isK ? [UIColor colorWithRed:1.0 green:0.4 blue:0.3 alpha:1.0] : [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
        });
        [session finishTasksAndInvalidate];
    }] resume];
}

+ (void)setupDeviceLogsOverlayInContainer:(UIView *)rootV {
    CGFloat dWidth = 320.0;
    CGFloat dHeight = 300.0;
    deviceLogsContainer = [[UIView alloc] initWithFrame:CGRectMake((rootV.bounds.size.width - dWidth)/2, 80, dWidth, dHeight)];
    deviceLogsContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    deviceLogsContainer.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:0.98];
    deviceLogsContainer.layer.cornerRadius = 12.0;
    deviceLogsContainer.layer.borderWidth = 1.0;
    deviceLogsContainer.layer.borderColor = [UIColor colorWithRed:0.4 green:0.25 blue:0.55 alpha:1.0].CGColor;
    deviceLogsContainer.clipsToBounds = YES;
    deviceLogsContainer.hidden = YES;

    UIView *dHeader = [[UIView alloc] initWithFrame:CGRectMake(0, 0, dWidth, 36)];
    dHeader.backgroundColor = [UIColor colorWithRed:0.14 green:0.10 blue:0.20 alpha:1.0];
    [deviceLogsContainer addSubview:dHeader];

    UILabel *dTitle = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, 180, 36)];
    dTitle.text = @"👥 Thiết Bị & Đặt Tên Máy";
    dTitle.textColor = [UIColor colorWithRed:0.85 green:0.55 blue:1.0 alpha:1.0];
    dTitle.font = [UIFont boldSystemFontOfSize:12];
    [dHeader addSubview:dTitle];

    UIButton *reloadLogsBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    reloadLogsBtn.frame = CGRectMake(dWidth - 66, 5, 28, 26);
    reloadLogsBtn.backgroundColor = [UIColor colorWithRed:0.35 green:0.20 blue:0.45 alpha:1.0];
    reloadLogsBtn.layer.cornerRadius = 5.0;
    [reloadLogsBtn setTitle:@"🔄" forState:UIControlStateNormal];
    [reloadLogsBtn addTarget:self action:@selector(fetchDeviceLogsFromServer) forControlEvents:UIControlEventTouchUpInside];
    [dHeader addSubview:reloadLogsBtn];

    UIButton *closeDBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeDBtn.frame = CGRectMake(dWidth - 34, 5, 26, 26);
    closeDBtn.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
    closeDBtn.layer.cornerRadius = 5.0;
    [closeDBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeDBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeDBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [closeDBtn addTarget:self action:@selector(toggleDeviceLogs) forControlEvents:UIControlEventTouchUpInside];
    [dHeader addSubview:closeDBtn];

    deviceLogsScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 36, dWidth, dHeight - 36)];
    [deviceLogsContainer addSubview:deviceLogsScrollView];

    nickPromptContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 36, dWidth, dHeight - 36)];
    nickPromptContainer.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:0.98];
    nickPromptContainer.hidden = YES;

    UILabel *nLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 20, dWidth - 32, 20)];
    nLbl.text = @"🏷️ Nhập biệt danh mới cho thiết bị:";
    nLbl.textColor = [UIColor whiteColor];
    nLbl.font = [UIFont boldSystemFontOfSize:12];
    nLbl.textAlignment = NSTextAlignmentCenter;
    [nickPromptContainer addSubview:nLbl];

    nickInputField = [[UITextField alloc] initWithFrame:CGRectMake(24, 52, dWidth - 48, 36)];
    nickInputField.placeholder = @"Ví dụ: Máy chính của Đạt...";
    nickInputField.textColor = [UIColor whiteColor];
    nickInputField.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    nickInputField.layer.cornerRadius = 8.0;
    nickInputField.layer.borderWidth = 1.0;
    nickInputField.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
    nickInputField.font = [UIFont systemFontOfSize:13];
    nickInputField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 36)];
    nickInputField.leftViewMode = UITextFieldViewModeAlways;
    [nickPromptContainer addSubview:nickInputField];

    UIButton *cancelNBtn = [self createGlassButtonWithFrame:CGRectMake(24, 104, (dWidth - 58)/2, 34) title:@"Hủy" color:[UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0]];
    [cancelNBtn addTarget:self action:@selector(onCancelNickPrompt) forControlEvents:UIControlEventTouchUpInside];
    [nickPromptContainer addSubview:cancelNBtn];

    UIButton *saveNBtn = [self createGlassButtonWithFrame:CGRectMake(CGRectGetMaxX(cancelNBtn.frame) + 10, 104, (dWidth - 58)/2, 34) title:@"Lưu Tên" color:[UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0]];
    [saveNBtn addTarget:self action:@selector(onConfirmNickPrompt) forControlEvents:UIControlEventTouchUpInside];
    [nickPromptContainer addSubview:saveNBtn];

    [deviceLogsContainer addSubview:nickPromptContainer];
    [rootV addSubview:deviceLogsContainer];
}

+ (void)toggleDeviceLogs {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    deviceLogsContainer.hidden = !deviceLogsContainer.hidden;
    if (!deviceLogsContainer.hidden) {
        [baconOverlayView bringSubviewToFront:deviceLogsContainer];
        [self fetchDeviceLogsFromServer];
    } else {
        [nickInputField resignFirstResponder];
        nickPromptContainer.hidden = YES;
    }
}

+ (void)fetchDeviceLogsFromServer {
    for (UIView *v in deviceLogsScrollView.subviews) [v removeFromSuperview];

    UILabel *loadingLbl = [[UILabel alloc] initWithFrame:CGRectMake(10, 40, deviceLogsContainer.bounds.size.width - 20, 30)];
    loadingLbl.text = @"⏳ Đang tải danh sách từ server...";
    loadingLbl.textColor = [UIColor lightGrayColor];
    loadingLbl.textAlignment = NSTextAlignmentCenter;
    loadingLbl.font = [UIFont systemFontOfSize:12];
    [deviceLogsScrollView addSubview:loadingLbl];

    NSURL *url = [NSURL URLWithString:TRACKER_API];
    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];

    [[session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            for (UIView *v in deviceLogsScrollView.subviews) [v removeFromSuperview];

            if (err || !data) {
                loadingLbl.text = @"❌ Lỗi kết nối đến máy chủ Tracker!";
                loadingLbl.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
                [deviceLogsScrollView addSubview:loadingLbl];
                return;
            }

            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSArray *devices = json[@"data"];
            if (!devices || devices.count == 0) {
                loadingLbl.text = @"Chưa có ai mở file dylib này.";
                loadingLbl.textColor = [UIColor grayColor];
                [deviceLogsScrollView addSubview:loadingLbl];
                return;
            }

            CGFloat y = 8.0;
            CGFloat rowWidth = deviceLogsContainer.bounds.size.width - 20;

            for (NSDictionary *dev in devices) {
                UIView *card = [[UIView alloc] initWithFrame:CGRectMake(10, y, rowWidth, 54)];
                card.backgroundColor = [UIColor colorWithRed:0.14 green:0.12 blue:0.18 alpha:1.0];
                card.layer.cornerRadius = 6.0;

                NSString *nick = dev[@"nickname"];
                NSString *titleStr = (nick && nick.length > 0) ? [NSString stringWithFormat:@"🏷️ %@ (%@)", nick, dev[@"model"] ?: @"iPhone"] : [NSString stringWithFormat:@"📱 %@ (%@)", dev[@"model"] ?: @"iPhone", dev[@"ios"] ?: @"iOS"];

                UILabel *nameLbl = [[UILabel alloc] initWithFrame:CGRectMake(8, 4, rowWidth - 76, 18)];
                nameLbl.text = titleStr;
                nameLbl.textColor = [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
                nameLbl.font = [UIFont boldSystemFontOfSize:11];
                [card addSubview:nameLbl];

                UILabel *subLbl = [[UILabel alloc] initWithFrame:CGRectMake(8, 24, rowWidth - 76, 24)];
                subLbl.numberOfLines = 2;
                subLbl.text = [NSString stringWithFormat:@"ID: %@ • Lúc: %@", dev[@"id"] ?: @"-", dev[@"last_seen"] ?: @"-"];
                subLbl.textColor = [UIColor colorWithRed:0.7 green:0.7 blue:0.8 alpha:1.0];
                subLbl.font = [UIFont systemFontOfSize:9.5];
                [card addSubview:subLbl];

                UIButton *nickBtn = [UIButton buttonWithType:UIButtonTypeSystem];
                nickBtn.frame = CGRectMake(rowWidth - 68, 12, 62, 28);
                nickBtn.backgroundColor = [UIColor colorWithRed:0.30 green:0.55 blue:0.85 alpha:1.0];
                nickBtn.layer.cornerRadius = 5.0;
                [nickBtn setTitle:@"🏷️ Đặt Tên" forState:UIControlStateNormal];
                [nickBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                nickBtn.titleLabel.font = [UIFont boldSystemFontOfSize:10];
                objc_setAssociatedObject(nickBtn, "targetDevID", dev[@"id"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                [nickBtn addTarget:self action:@selector(promptEditNickname:) forControlEvents:UIControlEventTouchUpInside];
                [card addSubview:nickBtn];

                [deviceLogsScrollView addSubview:card];
                y += 60.0;
            }
            deviceLogsScrollView.contentSize = CGSizeMake(deviceLogsContainer.bounds.size.width, y);
        });
        [session finishTasksAndInvalidate];
    }] resume];
}

+ (void)promptEditNickname:(UIButton *)sender {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    NSString *devID = objc_getAssociatedObject(sender, "targetDevID");
    if (!devID) return;
    editingDeviceID = devID;
    nickInputField.text = @"";
    nickPromptContainer.hidden = NO;
    [deviceLogsContainer bringSubviewToFront:nickPromptContainer];
    [nickInputField becomeFirstResponder];
}

+ (void)onConfirmNickPrompt {
    [nickInputField resignFirstResponder];
    nickPromptContainer.hidden = YES;
    if (editingDeviceID) {
        [self sendSaveNicknameToServer:editingDeviceID nickname:nickInputField.text];
    }
}

+ (void)onCancelNickPrompt {
    [nickInputField resignFirstResponder];
    nickPromptContainer.hidden = YES;
}

+ (void)sendSaveNicknameToServer:(NSString *)devID nickname:(NSString *)name {
    NSURL *url = [NSURL URLWithString:TRACKER_API];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSDictionary *body = @{ @"action": @"set_nickname", @"device_id": devID, @"nickname": name ?: @"" };
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];

    [[session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self triggerNotify:UINotificationFeedbackTypeSuccess];
            [self fetchDeviceLogsFromServer];
        });
        [session finishTasksAndInvalidate];
    }] resume];
}

+ (void)setupHistoryOverlayInContainer:(UIView *)rootV {
    CGFloat hWidth = 310.0;
    CGFloat hHeight = 240.0;
    historyContainer = [[UIView alloc] initWithFrame:CGRectMake((rootV.bounds.size.width - hWidth)/2, 100, hWidth, hHeight)];
    historyContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    historyContainer.backgroundColor = [UIColor colorWithRed:0.09 green:0.09 blue:0.12 alpha:0.98];
    historyContainer.layer.cornerRadius = 12.0;
    historyContainer.layer.borderWidth = 1.0;
    historyContainer.layer.borderColor = [UIColor colorWithRed:0.35 green:0.35 blue:0.45 alpha:1.0].CGColor;
    historyContainer.clipsToBounds = YES;
    historyContainer.hidden = YES;

    UIView *hHeader = [[UIView alloc] initWithFrame:CGRectMake(0, 0, hWidth, 36)];
    hHeader.backgroundColor = [UIColor colorWithRed:0.14 green:0.10 blue:0.20 alpha:1.0];
    [historyContainer addSubview:hHeader];

    UILabel *hTitle = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, 180, 36)];
    hTitle.text = @"📜 Lịch Sử 5 Link Gần Nhất";
    hTitle.textColor = [UIColor colorWithRed:1.0 green:0.7 blue:0.2 alpha:1.0];
    hTitle.font = [UIFont boldSystemFontOfSize:12];
    [hHeader addSubview:hTitle];

    UIButton *closeHBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeHBtn.frame = CGRectMake(hWidth - 34, 5, 26, 26);
    closeHBtn.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
    closeHBtn.layer.cornerRadius = 6.0;
    [closeHBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeHBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeHBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [closeHBtn addTarget:self action:@selector(toggleHistory) forControlEvents:UIControlEventTouchUpInside];
    [hHeader addSubview:closeHBtn];

    historyScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 36, hWidth, hHeight - 36)];
    [historyContainer addSubview:historyScrollView];

    [rootV addSubview:historyContainer];
}

+ (void)saveLinkToHistory:(NSString *)link {
    if (!link || link.length == 0) return;
    NSMutableArray *arr = [[[NSUserDefaults standardUserDefaults] arrayForKey:HISTORY_KEY] mutableCopy] ?: [NSMutableArray array];
    [arr removeObject:link];
    [arr insertObject:link atIndex:0];
    while (arr.count > 5) [arr removeLastObject];
    [[NSUserDefaults standardUserDefaults] setObject:arr forKey:HISTORY_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)toggleHistory {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    historyContainer.hidden = !historyContainer.hidden;
    if (!historyContainer.hidden) {
        [baconOverlayView bringSubviewToFront:historyContainer];
        [self reloadHistoryList];
    }
}

+ (void)reloadHistoryList {
    for (UIView *v in historyScrollView.subviews) [v removeFromSuperview];

    NSArray *items = [[NSUserDefaults standardUserDefaults] arrayForKey:HISTORY_KEY] ?: @[];
    if (items.count == 0) {
        UILabel *empty = [[UILabel alloc] initWithFrame:CGRectMake(10, 30, historyContainer.bounds.size.width - 20, 30)];
        empty.text = @"Chưa có link nào trong lịch sử!";
        empty.textColor = [UIColor grayColor];
        empty.textAlignment = NSTextAlignmentCenter;
        empty.font = [UIFont systemFontOfSize:12];
        [historyScrollView addSubview:empty];
        return;
    }

    CGFloat y = 8.0;
    CGFloat rowWidth = historyContainer.bounds.size.width - 20;

    for (int i = 0; i < items.count; i++) {
        NSString *linkItem = items[i];
        UIView *card = [[UIView alloc] initWithFrame:CGRectMake(10, y, rowWidth, 34)];
        card.backgroundColor = [UIColor colorWithRed:0.14 green:0.12 blue:0.18 alpha:1.0];
        card.layer.cornerRadius = 6.0;

        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(8, 0, rowWidth - 60, 34)];
        lbl.text = [NSString stringWithFormat:@"%d. %@", i + 1, linkItem];
        lbl.textColor = [UIColor whiteColor];
        lbl.font = [UIFont systemFontOfSize:10];
        lbl.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [card addSubview:lbl];

        UIButton *cBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        cBtn.frame = CGRectMake(rowWidth - 50, 4, 44, 26);
        cBtn.backgroundColor = [UIColor colorWithRed:0.25 green:0.55 blue:0.35 alpha:1.0];
        cBtn.layer.cornerRadius = 4.0;
        [cBtn setTitle:@"Chép" forState:UIControlStateNormal];
        [cBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        cBtn.titleLabel.font = [UIFont boldSystemFontOfSize:10];
        objc_setAssociatedObject(cBtn, "targetLink", linkItem, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [cBtn addTarget:self action:@selector(copyHistoryItem:) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:cBtn];

        [historyScrollView addSubview:card];
        y += 40.0;
    }
    historyScrollView.contentSize = CGSizeMake(historyContainer.bounds.size.width, y);
}

+ (void)copyHistoryItem:(UIButton *)sender {
    NSString *link = objc_getAssociatedObject(sender, "targetLink");
    if (link && link.length > 0) {
        [UIPasteboard generalPasteboard].string = link;
        [self triggerNotify:UINotificationFeedbackTypeSuccess];
        resultDisplay.text = [NSString stringWithFormat:@"✅ Đã chép lại từ Lịch sử:\n%@", link];
        resultDisplay.textColor = [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
        [self toggleHistory];
    }
}

+ (void)openMenu {
    [self triggerImpact:UIImpactFeedbackStyleMedium];
    if (baconOverlayView && baconOverlayView.superview) {
        [baconOverlayView.superview bringSubviewToFront:baconOverlayView];
    }
    menuContainer.hidden = NO;
    floatingCircleBtn.hidden = YES;
    [baconOverlayView bringSubviewToFront:menuContainer];
    if (renderLoop) renderLoop.paused = NO;
    currentAppRamMB = [self getAppMemoryUsageMB];
    [self updateDashboardHUD];
    [self measureNetworkPing];
    if (!isUtilsTabActive) [self autoDetectClipboardLink];
}

+ (void)minimizeMenu {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    [linkInput resignFirstResponder];
    [apiKeyInput resignFirstResponder];
    [pinInputField resignFirstResponder];
    [nickInputField resignFirstResponder];
    pinPromptContainer.hidden = YES;
    nickPromptContainer.hidden = YES;
    menuContainer.hidden = YES;
    historyContainer.hidden = YES;
    deviceLogsContainer.hidden = YES;
    floatingCircleBtn.hidden = NO;
    if (renderLoop) renderLoop.paused = YES;
    [baconOverlayView bringSubviewToFront:floatingCircleBtn];
}

+ (NSString *)cleanString:(NSString *)str {
    if (!str) return @"";
    NSString *cleaned = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    cleaned = [cleaned stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    cleaned = [cleaned stringByReplacingOccurrencesOfString:@"'" withString:@""];
    return cleaned;
}

+ (void)onApiKeyEditingBegan { keyActionContainer.hidden = NO; }
+ (void)onApiKeyEditingChanged { keyActionContainer.hidden = NO; }

+ (void)onConfirmSaveKey {
    [self triggerNotify:UINotificationFeedbackTypeSuccess];
    [apiKeyInput resignFirstResponder];
    NSString *newKey = [self cleanString:apiKeyInput.text];
    if (newKey.length > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:newKey forKey:STORAGE_KEY];
        [[NSUserDefaults standardUserDefaults] synchronize];
        resultDisplay.text = @"✅ Đã lưu API Key mới vào hệ thống!";
        resultDisplay.textColor = [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
    }
}

+ (void)onDiscardKey {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    [apiKeyInput resignFirstResponder];
    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:STORAGE_KEY];
    if (!savedKey || savedKey.length == 0) savedKey = DEFAULT_API_KEY;
    apiKeyInput.text = savedKey;
    resultDisplay.text = @"↩️ Đã hủy và khôi phục Key trước đó.";
    resultDisplay.textColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0];
}

+ (void)handleBypass {
    [self triggerImpact:UIImpactFeedbackStyleMedium];
    [linkInput resignFirstResponder];
    [apiKeyInput resignFirstResponder];

    if (isServerKillswitchActive && !isAdminMode) {
        [self triggerNotify:UINotificationFeedbackTypeError];
        resultDisplay.text = @"🚨 Hệ thống đang bảo trì từ xa!";
        resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
        return;
    }

    NSString *key = [self cleanString:apiKeyInput.text];
    if (key.length == 0) {
        NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:STORAGE_KEY];
        key = (savedKey && savedKey.length > 0) ? savedKey : DEFAULT_API_KEY;
    }

    NSString *url = [self cleanString:linkInput.text];
    if (url.length == 0) {
        [self triggerNotify:UINotificationFeedbackTypeError];
        resultDisplay.text = @"❌ Hãy dán link trước!";
        resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
        return;
    }

    resultDisplay.text = @"⏳ Đang gửi request tới Bacon API...";
    resultDisplay.textColor = [UIColor colorWithRed:1.00 green:0.67 blue:0.00 alpha:1.0];

    NSURL *endpoint = [NSURL URLWithString:@"https://api.baconbypass.xyz/bypass"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:endpoint];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSDictionary *body = @{ @"url": url, @"apikey": key };
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    cfg.timeoutIntervalForRequest = 15.0;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];

    [[session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (err || !data) {
                [self triggerNotify:UINotificationFeedbackTypeError];
                resultDisplay.text = @"❌ Mất kết nối API!";
                resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
                return;
            }
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (json && [json[@"status"] isEqualToString:@"success"] && json[@"result"]) {
                [self triggerNotify:UINotificationFeedbackTypeSuccess];
                extractedLink = [[NSString alloc] initWithFormat:@"%@", json[@"result"]];
                resultDisplay.text = [NSString stringWithFormat:@"✅ %@", extractedLink];
                resultDisplay.textColor = [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
                [self saveLinkToHistory:extractedLink];
            } else {
                [self triggerNotify:UINotificationFeedbackTypeError];
                NSString *msg = json[@"message"] ?: @"Thất bại!";
                resultDisplay.text = [NSString stringWithFormat:@"❌ %@", msg];
                resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
            }
        });
        [session finishTasksAndInvalidate];
    }] resume];
}

+ (void)handleCopy {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            NSString *targetText = nil;
            if (extractedLink && extractedLink.length > 0) {
                targetText = [extractedLink copy];
            } else if (resultDisplay.text.length > 0 && [resultDisplay.text hasPrefix:@"✅ "]) {
                targetText = [[resultDisplay.text substringFromIndex:2] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            }

            if (!targetText || targetText.length == 0) {
                [self triggerNotify:UINotificationFeedbackTypeWarning];
                resultDisplay.text = @"❌ Chưa có kết quả để sao chép!";
                resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
                return;
            }

            UIPasteboard *board = [UIPasteboard generalPasteboard];
            if (board) [board setString:targetText];

            [self triggerNotify:UINotificationFeedbackTypeSuccess];
            resultDisplay.text = @"✅ Đã chép vào bộ nhớ đệm!";
            resultDisplay.textColor = [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
            linkInput.text = @"";
        } @catch (NSException *e) {
            [self triggerNotify:UINotificationFeedbackTypeError];
            resultDisplay.text = @"❌ Lỗi sao chép! Hãy nhấn giữ text để copy.";
            resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
        }
    });
}

+ (void)handleDragCircle:(UIPanGestureRecognizer *)g {
    CGPoint trans = [g translationInView:floatingCircleBtn.superview];
    floatingCircleBtn.center = CGPointMake(floatingCircleBtn.center.x + trans.x, floatingCircleBtn.center.y + trans.y);
    [g setTranslation:CGPointZero inView:floatingCircleBtn.superview];

    if (g.state == UIGestureRecognizerStateEnded) {
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        [defs setFloat:floatingCircleBtn.center.x forKey:@"BaconBypass_CirclePosX"];
        [defs setFloat:floatingCircleBtn.center.y forKey:@"BaconBypass_CirclePosY"];
        [defs synchronize];
    }
}

+ (void)handleDragMenu:(UIPanGestureRecognizer *)g {
    CGPoint trans = [g translationInView:menuContainer.superview];
    menuContainer.center = CGPointMake(menuContainer.center.x + trans.x, menuContainer.center.y + trans.y);
    [g setTranslation:CGPointZero inView:menuContainer.superview];

    if (g.state == UIGestureRecognizerStateEnded) {
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        [defs setFloat:menuContainer.center.x forKey:@"BaconBypass_MenuPosX"];
        [defs setFloat:menuContainer.center.y forKey:@"BaconBypass_MenuPosY"];
        [defs synchronize];
    }
}

@end
