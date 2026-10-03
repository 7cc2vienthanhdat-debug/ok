#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import <sys/utsname.h>
#import <mach/mach.h>

@interface BaconBypassOverlay : NSObject <WKNavigationDelegate>
+ (void)load;
@end

// Model lưu trữ dữ liệu điểm click
@interface AutoClickTarget : NSObject
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, strong) UIView *markerView;
@property (nonatomic, strong) UILabel *numberLabel;
@property (nonatomic, strong) UILabel *delayLabel;
@property (nonatomic, assign) CGFloat delaySeconds;
@property (nonatomic, assign) CGPoint screenPoint;
@end
@implementation AutoClickTarget
@end

// Model lưu bước thao tác ghi lại (Macro)
@interface MacroTouchStep : NSObject
@property (nonatomic, assign) CGPoint point;
@property (nonatomic, assign) NSTimeInterval timeOffset;
@property (nonatomic, assign) UITouchPhase phase;
@end
@implementation MacroTouchStep
@end

// View trong suốt ghi lại cử chỉ ngón tay
@interface MacroRecorderOverlayView : UIView
@property (nonatomic, copy) void (^onTouchEvent)(CGPoint pt, NSInteger phase);
@end
@implementation MacroRecorderOverlayView
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *t = [touches anyObject];
    if (self.onTouchEvent) self.onTouchEvent([t locationInView:self], 0);
    [super touchesBegan:touches withEvent:event];
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *t = [touches anyObject];
    if (self.onTouchEvent) self.onTouchEvent([t locationInView:self], 1);
    [super touchesMoved:touches withEvent:event];
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *t = [touches anyObject];
    if (self.onTouchEvent) self.onTouchEvent([t locationInView:self], 2);
    [super touchesEnded:touches withEvent:event];
}
@end

@implementation BaconBypassOverlay

// --- CẤU HÌNH ADMIN & API ---
#define ADMIN_PIN @"151009"
#define DEFAULT_API_KEY @"Bacon-68e61ca9d455d316a50c-b4328879cadc0a77f8a5"
#define TRACKER_API @"https://ok.tdat1510009.workers.dev"
#define STORAGE_KEY @"BaconBypass_CustomAPIKey"
#define HISTORY_KEY @"BaconBypass_HistoryLinks"

// --- UI Components Chung ---
static UIWindow *robloxWindow = nil;
static UIButton *floatingCircleBtn = nil;
static UIView *menuContainer = nil;
static UIView *menuDashboardBar = nil;
static UILabel *hudInfoLabel = nil;
static WKWebView *miniWebView = nil;
static UIView *miniBrowserContainer = nil;
static UIView *historyContainer = nil;
static UIScrollView *historyScrollView = nil;
static UIView *deviceLogsContainer = nil;
static UIScrollView *deviceLogsScrollView = nil;

// --- Tab Controls ---
static UIButton *tabSwitchBtn = nil;
static BOOL isAutoClickTabActive = NO;
static UIView *bypassTabContainer = nil;
static UIView *autoClickTabContainer = nil;

// --- Form Controls Bypass ---
static UITextField *apiKeyInput = nil;
static UIView *keyActionContainer = nil;
static UITextField *linkInput = nil;
static UIButton *bypassBtn = nil;
static UIButton *copyBtn = nil;
static UIView *resultBox = nil;
static UITextView *resultDisplay = nil;
static UIButton *baconWebBtn = nil;
static UIButton *googleWebBtn = nil;
static UIButton *viewDevicesBtn = nil;
static UIButton *killswitchBtn = nil;
static NSString *extractedLink = nil;

// --- Chức Năng Ẩn Stream ---
static UITextField *streamSecureTextField = nil;
static UIView *streamSecureContainer = nil;
static BOOL isStreamHiddenMode = NO;
static UIButton *streamHideBtn = nil;

// --- UI Controls Auto Click ---
static UIButton *addPointBtn = nil;
static UIButton *clearPointsBtn = nil;
static UIButton *recordMacroBtn = nil;
static UILabel *autoStatusLabel = nil;
static UIButton *toggleAutoRunBtn = nil;

// --- Dữ liệu Auto Click & Macro ---
static NSMutableArray<AutoClickTarget *> *targetMarkers = nil;
static NSMutableArray<MacroTouchStep *> *recordedMacroSteps = nil;
static BOOL isAutoRunning = NO;
static BOOL isRecordingMacro = NO;
static NSTimeInterval recordStartTime = 0;
static NSInteger currentRunningTargetIdx = 0;

static UILongPressGestureRecognizer *macroTapRecorder = nil;
static UIPanGestureRecognizer *macroPanRecorder = nil;

// --- Trạng thái Admin & Killswitch ---
static BOOL isAdminMode = NO;
static BOOL isServerKillswitchActive = NO;

// --- Performance, RAM, Nhiệt Độ ---
static CADisplayLink *renderLoop = nil;
static CGFloat currentHue = 0.0;
static NSInteger frameCount = 0;
static CFTimeInterval lastFpsTime = 0;
static NSInteger currentFPS = 60;
static long currentAppRamMB = 0;
static NSString *currentThermalStatus = @"❄️ Mát";

// ============================================================
// HAPTIC FEEDBACK
// ============================================================
+ (void)triggerImpact:(UIImpactFeedbackStyle)style {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
        [gen prepare];
        [gen impactOccurred];
    });
}

+ (void)triggerNotify:(UINotificationFeedbackType)type {
    dispatch_async(dispatch_get_main_queue(), ^{
        UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
        [gen prepare];
        [gen notificationOccurred:type];
    });
}

// ============================================================
// HÀM TỰ ĐỘNG BẮT LINK TỪ BỘ NHỚ TẠM
// ============================================================
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

// ============================================================
// ĐO RAM THỰC TẾ & TRẠNG THÁI NHIỆT MÁY
// ============================================================
+ (long)getAppMemoryUsageMB {
    struct mach_task_basic_info info;
    mach_msg_type_number_t size = MACH_TASK_BASIC_INFO_COUNT;
    kern_return_t kerr = task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &size);
    if (kerr == KERN_SUCCESS) {
        return (long)(info.resident_size / (1024 * 1024));
    }
    return 0;
}

+ (NSString *)getDeviceThermalStateDescription {
    if (@available(iOS 11.0, *)) {
        NSProcessInfoThermalState state = [NSProcessInfo processInfo].thermalState;
        switch (state) {
            case NSProcessInfoThermalStateNominal:  return @"❄️ Mát";
            case NSProcessInfoThermalStateFair:     return @"🌤 Ấm";
            case NSProcessInfoThermalStateSerious:  return @"🔥 Nóng";
            case NSProcessInfoThermalStateCritical: return @"🚨 Quá nhiệt";
            default: return @"❄️ Mát";
        }
    }
    return @"❄️ Mát";
}

// ============================================================
// THÔNG TIN THIẾT BỊ VÀ TELEMETRY
// ============================================================
+ (NSString *)getDeviceModelName {
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *code = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];

    static NSDictionary *modelDict = nil;
    if (!modelDict) {
        modelDict = @{
            @"iPhone10,1" : @"iPhone 8", @"iPhone10,4" : @"iPhone 8",
            @"iPhone10,2" : @"iPhone 8 Plus", @"iPhone10,5" : @"iPhone 8 Plus",
            @"iPhone10,3" : @"iPhone X", @"iPhone10,6" : @"iPhone X",
            @"iPhone11,2" : @"iPhone XS", @"iPhone11,4" : @"iPhone XS Max", @"iPhone11,6" : @"iPhone XS Max",
            @"iPhone11,8" : @"iPhone XR",
            @"iPhone12,1" : @"iPhone 11", @"iPhone12,3" : @"iPhone 11 Pro", @"iPhone12,5" : @"iPhone 11 Pro Max",
            @"iPhone12,8" : @"iPhone SE (2nd)",
            @"iPhone13,1" : @"iPhone 12 mini", @"iPhone13,2" : @"iPhone 12",
            @"iPhone13,3" : @"iPhone 12 Pro", @"iPhone13,4" : @"iPhone 12 Pro Max",
            @"iPhone14,4" : @"iPhone 13 mini", @"iPhone14,5" : @"iPhone 13",
            @"iPhone14,2" : @"iPhone 13 Pro", @"iPhone14,3" : @"iPhone 13 Pro Max",
            @"iPhone14,6" : @"iPhone SE (3rd)",
            @"iPhone14,7" : @"iPhone 14", @"iPhone14,8" : @"iPhone 14 Plus",
            @"iPhone15,2" : @"iPhone 14 Pro", @"iPhone15,3" : @"iPhone 14 Pro Max",
            @"iPhone15,4" : @"iPhone 15", @"iPhone15,5" : @"iPhone 15 Plus",
            @"iPhone16,1" : @"iPhone 15 Pro", @"iPhone16,2" : @"iPhone 15 Pro Max",
            @"iPhone17,1" : @"iPhone 16 Pro", @"iPhone17,2" : @"iPhone 16 Pro Max",
            @"iPhone17,3" : @"iPhone 16", @"iPhone17,4" : @"iPhone 16 Plus"
        };
    }
    return modelDict[code] ? modelDict[code] : code;
}

+ (void)sendDeviceTelemetry {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSString *model = [self getDeviceModelName];
        NSString *iosVer = [[UIDevice currentDevice] systemVersion];
        NSString *vendorId = [[[UIDevice currentDevice] identifierForVendor] UUIDString] ?: @"Unknown-UUID";

        NSURL *url = [NSURL URLWithString:TRACKER_API];
        if (!url) return;

        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
        req.HTTPMethod = @"POST";
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

        NSDictionary *payload = @{
            @"action": @"log",
            @"device_id": vendorId,
            @"model": model,
            @"ios": [NSString stringWithFormat:@"iOS %@", iosVer]
        };

        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
        [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
            if (!err && data) {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if (json && json[@"killswitch"]) {
                    isServerKillswitchActive = [json[@"killswitch"] boolValue];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self applyKillswitchState];
                    });
                }
            }
        }] resume];
    });
}

+ (void)applyKillswitchState {
    if (isServerKillswitchActive && !isAdminMode) {
        menuContainer.hidden = YES;
        floatingCircleBtn.hidden = YES;
        [self stopAutoClick];
    } else {
        if (floatingCircleBtn && menuContainer.hidden) {
            floatingCircleBtn.hidden = NO;
        }
    }
}

// ============================================================
// KHỞI CHẠY HỆ THỐNG
// ============================================================
+ (void)load {
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    targetMarkers = [NSMutableArray array];
    recordedMacroSteps = [NSMutableArray array];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIScreenCapturedDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        [self handleScreenCaptureStateChange];
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self tryInjectOverlay];
        [self sendDeviceTelemetry];
    });
}

+ (UIWindow *)findRobloxWindow {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *win in windowScene.windows) {
                if (win.rootViewController != nil && !win.hidden) return win;
            }
        }
    }
    for (UIWindow *win in [UIApplication sharedApplication].windows) {
        if (win.rootViewController != nil && !win.hidden) return win;
    }
    return nil;
}

+ (void)tryInjectOverlay {
    if (floatingCircleBtn != nil) return;
    robloxWindow = [self findRobloxWindow];
    if (!robloxWindow || !robloxWindow.rootViewController) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self tryInjectOverlay];
        });
        return;
    }
    [self setupStreamProtectionInWindow:robloxWindow];
    [self setupViewsInWindow:robloxWindow];
    [self startDisplayLoop];
}

// ============================================================
// CƠ CHẾ ẨN STREAM THÔNG MINH (AUTO-HIDE ON RECORD)
// ============================================================
+ (void)setupStreamProtectionInWindow:(UIWindow *)window {
    streamSecureTextField = [[UITextField alloc] initWithFrame:window.bounds];
    streamSecureTextField.secureTextEntry = YES;
    streamSecureTextField.userInteractionEnabled = NO;
    [window addSubview:streamSecureTextField];
    streamSecureContainer = streamSecureTextField.subviews.firstObject;
    streamSecureContainer.userInteractionEnabled = YES;
}

+ (void)handleScreenCaptureStateChange {
    if (!isStreamHiddenMode) return;
    
    BOOL isCaptured = [UIScreen mainScreen].isCaptured;
    if (isCaptured) {
        menuContainer.alpha = 0.0;
        floatingCircleBtn.alpha = 0.0;
        for (AutoClickTarget *t in targetMarkers) t.markerView.alpha = 0.0;
    } else {
        menuContainer.alpha = 1.0;
        floatingCircleBtn.alpha = 1.0;
        for (AutoClickTarget *t in targetMarkers) t.markerView.alpha = 1.0;
    }
}

+ (void)toggleStreamHideMode {
    [self triggerImpact:UIImpactFeedbackStyleHeavy];
    isStreamHiddenMode = !isStreamHiddenMode;

    UIView *destinationParent = isStreamHiddenMode ? streamSecureContainer : robloxWindow;

    [destinationParent addSubview:floatingCircleBtn];
    [destinationParent addSubview:menuContainer];
    [destinationParent addSubview:miniBrowserContainer];
    [destinationParent addSubview:historyContainer];
    [destinationParent addSubview:deviceLogsContainer];

    for (AutoClickTarget *t in targetMarkers) {
        [destinationParent addSubview:t.markerView];
    }

    if (isStreamHiddenMode) {
        [streamHideBtn setTitle:@"🛡️ Stream: TỰ ẨN" forState:UIControlStateNormal];
        streamHideBtn.backgroundColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.25 alpha:1.0];
        [self triggerNotify:UINotificationFeedbackTypeSuccess];
        resultDisplay.text = @"🛡️ Đã bật Ẩn Stream! Khi phát hiện quay màn hình, toàn bộ Menu sẽ tự tàng hình.";
        resultDisplay.textColor = [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
        [self handleScreenCaptureStateChange];
    } else {
        [streamHideBtn setTitle:@"👁️ Stream: HIỆN" forState:UIControlStateNormal];
        streamHideBtn.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.35 alpha:1.0];
        [self triggerNotify:UINotificationFeedbackTypeWarning];
        resultDisplay.text = @"👁️ Đã tắt Ẩn Stream. Menu sẽ hiển thị trên video/livestream.";
        resultDisplay.textColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0];
        menuContainer.alpha = 1.0;
        floatingCircleBtn.alpha = 1.0;
        for (AutoClickTarget *t in targetMarkers) t.markerView.alpha = 1.0;
    }
}

// ============================================================
// VÒNG LẶP RENDER: RGB & DASHBOARD HUD BÊN TRONG MENU
// ============================================================
+ (void)startDisplayLoop {
    if (renderLoop) return;
    renderLoop = [CADisplayLink displayLinkWithTarget:self selector:@selector(onRenderFrame:)];
    [renderLoop addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

+ (void)onRenderFrame:(CADisplayLink *)link {
    currentHue += 0.005;
    if (currentHue > 1.0) currentHue = 0.0;
    UIColor *rainbowColor = [UIColor colorWithHue:currentHue saturation:0.95 brightness:1.0 alpha:1.0];
    floatingCircleBtn.layer.borderColor = rainbowColor.CGColor;

    frameCount++;
    if (lastFpsTime == 0) lastFpsTime = link.timestamp;
    CFTimeInterval delta = link.timestamp - lastFpsTime;

    if (delta >= 1.0) {
        currentFPS = (NSInteger)round(frameCount / delta);
        frameCount = 0;
        lastFpsTime = link.timestamp;
        currentAppRamMB = [self getAppMemoryUsageMB];
        currentThermalStatus = [self getDeviceThermalStateDescription];
        [self updateDashboardHUD];
    }
}

+ (void)updateDashboardHUD {
    if (!hudInfoLabel) return;
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"HH:mm"];
    NSString *timeStr = [df stringFromDate:[NSDate date]];

    float bat = [UIDevice currentDevice].batteryLevel;
    int batPct = (bat < 0) ? 100 : (int)(bat * 100.0f);

    hudInfoLabel.text = [NSString stringWithFormat:@"⏱ %@  |  🔋 %d%%  |  ⚡ %ld FPS  |  💾 %ld MB  |  %@",
                            timeStr, batPct, (long)currentFPS, currentAppRamMB, currentThermalStatus];
}

// ============================================================
// THIẾT KẾ GIAO DIỆN (UI) MỚI
// ============================================================
+ (void)setupViewsInWindow:(UIWindow *)targetWindow {
    floatingCircleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    floatingCircleBtn.frame = CGRectMake(25, 120, 42, 42);
    floatingCircleBtn.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:0.95];
    floatingCircleBtn.layer.cornerRadius = 21.0;
    floatingCircleBtn.layer.borderWidth = 2.0;
    floatingCircleBtn.layer.shadowColor = [UIColor blackColor].CGColor;
    floatingCircleBtn.layer.shadowOffset = CGSizeMake(0, 4);
    floatingCircleBtn.layer.shadowOpacity = 0.6;
    floatingCircleBtn.layer.shadowRadius = 5.0;
    [floatingCircleBtn setTitle:@"⚡" forState:UIControlStateNormal];
    floatingCircleBtn.titleLabel.font = [UIFont systemFontOfSize:18];
    [floatingCircleBtn addTarget:self action:@selector(openMenu) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *panBtn = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragCircle:)];
    [floatingCircleBtn addGestureRecognizer:panBtn];
    [targetWindow addSubview:floatingCircleBtn];

    CGFloat menuWidth = 340.0;
    CGFloat menuHeight = 285.0;
    menuContainer = [[UIView alloc] initWithFrame:CGRectMake((targetWindow.bounds.size.width - menuWidth) / 2, 80, menuWidth, menuHeight)];
    menuContainer.backgroundColor = [UIColor clearColor];
    menuContainer.layer.cornerRadius = 16.0;
    menuContainer.clipsToBounds = YES;
    menuContainer.hidden = YES;

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *menuBlurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    menuBlurView.frame = menuContainer.bounds;
    menuBlurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [menuContainer addSubview:menuBlurView];
    
    UIView *borderOverlay = [[UIView alloc] initWithFrame:menuContainer.bounds];
    borderOverlay.layer.cornerRadius = 16.0;
    borderOverlay.layer.borderWidth = 1.0;
    borderOverlay.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.15].CGColor;
    borderOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [menuContainer addSubview:borderOverlay];

    UIPanGestureRecognizer *panMenu = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragMenu:)];
    [menuContainer addGestureRecognizer:panMenu];

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, menuWidth, 42)];
    header.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    [menuContainer addSubview:header];

    UILabel *headerTitle = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, 85, 42)];
    headerTitle.text = @"⚡ T_Dat";
    headerTitle.textColor = [UIColor colorWithRed:1.00 green:0.80 blue:0.10 alpha:1.0];
    headerTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightHeavy];
    headerTitle.userInteractionEnabled = YES;

    UITapGestureRecognizer *adminTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleAdminSecretTap)];
    adminTap.numberOfTapsRequired = 5;
    [headerTitle addGestureRecognizer:adminTap];
    [header addSubview:headerTitle];

    tabSwitchBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    tabSwitchBtn.frame = CGRectMake(95, 8, 72, 26);
    tabSwitchBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.50 blue:0.90 alpha:1.0];
    tabSwitchBtn.layer.cornerRadius = 6.0;
    [tabSwitchBtn setTitle:@"🎯 Auto" forState:UIControlStateNormal];
    [tabSwitchBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    tabSwitchBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [tabSwitchBtn addTarget:self action:@selector(toggleTabs) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:tabSwitchBtn];

    UIButton *webBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    webBtn.frame = CGRectMake(175, 8, 50, 26);
    webBtn.backgroundColor = [UIColor colorWithRed:0.20 green:0.35 blue:0.65 alpha:1.0];
    webBtn.layer.cornerRadius = 6.0;
    [webBtn setTitle:@"🌐 Web" forState:UIControlStateNormal];
    [webBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    webBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [webBtn addTarget:self action:@selector(toggleMiniBrowser) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:webBtn];

    UIButton *histBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    histBtn.frame = CGRectMake(233, 8, 30, 26);
    histBtn.backgroundColor = [UIColor colorWithRed:0.30 green:0.30 blue:0.40 alpha:1.0];
    histBtn.layer.cornerRadius = 6.0;
    [histBtn setTitle:@"📜" forState:UIControlStateNormal];
    [histBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    histBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    [histBtn addTarget:self action:@selector(toggleHistory) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:histBtn];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(menuWidth - 40, 8, 30, 26);
    closeBtn.backgroundColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.25 alpha:1.0];
    closeBtn.layer.cornerRadius = 6.0;
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [closeBtn addTarget:self action:@selector(minimizeMenu) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];

    menuDashboardBar = [[UIView alloc] initWithFrame:CGRectMake(0, 42, menuWidth, 22)];
    menuDashboardBar.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
    [menuContainer addSubview:menuDashboardBar];

    hudInfoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, menuWidth, 22)];
    hudInfoLabel.textColor = [UIColor colorWithRed:0.8 green:0.9 blue:1.0 alpha:1.0];
    hudInfoLabel.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightBold];
    hudInfoLabel.textAlignment = NSTextAlignmentCenter;
    [menuDashboardBar addSubview:hudInfoLabel];

    // ==========================================
    // KHUNG TAB 1: BYPASS
    // ==========================================
    CGFloat tabYOffset = 64; 
    bypassTabContainer = [[UIView alloc] initWithFrame:CGRectMake(0, tabYOffset, menuWidth, menuHeight - tabYOffset - 36)];
    [menuContainer addSubview:bypassTabContainer];

    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:STORAGE_KEY];
    apiKeyInput = [[UITextField alloc] initWithFrame:CGRectMake(12, 6, menuWidth - 24, 30)];
    apiKeyInput.text = savedKey ?: DEFAULT_API_KEY;
    apiKeyInput.placeholder = @"Nhập Bacon API Key...";
    apiKeyInput.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    apiKeyInput.textColor = [UIColor colorWithRed:1.00 green:0.80 blue:0.30 alpha:1.0];
    apiKeyInput.font = [UIFont systemFontOfSize:11];
    apiKeyInput.layer.cornerRadius = 6.0;
    apiKeyInput.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 30)];
    apiKeyInput.leftViewMode = UITextFieldViewModeAlways;
    apiKeyInput.hidden = YES;
    [apiKeyInput addTarget:self action:@selector(onApiKeyEditingChanged) forControlEvents:UIControlEventEditingChanged];
    [apiKeyInput addTarget:self action:@selector(onApiKeyEditingBegan) forControlEvents:UIControlEventEditingDidBegin];
    [bypassTabContainer addSubview:apiKeyInput];

    keyActionContainer = [[UIView alloc] initWithFrame:CGRectMake(12, 40, menuWidth - 24, 26)];
    keyActionContainer.backgroundColor = [UIColor clearColor];
    keyActionContainer.hidden = YES;

    UIButton *saveKeyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    saveKeyBtn.frame = CGRectMake(0, 0, 72, 26);
    saveKeyBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.60 blue:0.30 alpha:1.0];
    saveKeyBtn.layer.cornerRadius = 5.0;
    [saveKeyBtn setTitle:@"💾 Lưu" forState:UIControlStateNormal];
    [saveKeyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    saveKeyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [saveKeyBtn addTarget:self action:@selector(onConfirmSaveKey) forControlEvents:UIControlEventTouchUpInside];
    [keyActionContainer addSubview:saveKeyBtn];

    viewDevicesBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    viewDevicesBtn.frame = CGRectMake(76, 0, 82, 26);
    viewDevicesBtn.backgroundColor = [UIColor colorWithRed:0.65 green:0.25 blue:0.75 alpha:1.0];
    viewDevicesBtn.layer.cornerRadius = 5.0;
    [viewDevicesBtn setTitle:@"👥 Thiết Bị" forState:UIControlStateNormal];
    [viewDevicesBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    viewDevicesBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [viewDevicesBtn addTarget:self action:@selector(toggleDeviceLogs) forControlEvents:UIControlEventTouchUpInside];
    [keyActionContainer addSubview:viewDevicesBtn];

    killswitchBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    killswitchBtn.frame = CGRectMake(162, 0, 68, 26);
    killswitchBtn.backgroundColor = [UIColor colorWithRed:0.85 green:0.35 blue:0.15 alpha:1.0];
    killswitchBtn.layer.cornerRadius = 5.0;
    [killswitchBtn setTitle:@"🚨 Khóa" forState:UIControlStateNormal];
    [killswitchBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    killswitchBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [killswitchBtn addTarget:self action:@selector(handleToggleKillswitchRemote) forControlEvents:UIControlEventTouchUpInside];
    [keyActionContainer addSubview:killswitchBtn];

    UIButton *discardKeyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    discardKeyBtn.frame = CGRectMake(234, 0, menuWidth - 24 - 234, 26);
    discardKeyBtn.backgroundColor = [UIColor colorWithRed:0.40 green:0.40 blue:0.45 alpha:1.0];
    discardKeyBtn.layer.cornerRadius = 5.0;
    [discardKeyBtn setTitle:@"✕" forState:UIControlStateNormal];
    [discardKeyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    discardKeyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [discardKeyBtn addTarget:self action:@selector(onDiscardKey) forControlEvents:UIControlEventTouchUpInside];
    [keyActionContainer addSubview:discardKeyBtn];
    [bypassTabContainer addSubview:keyActionContainer];

    linkInput = [[UITextField alloc] initWithFrame:CGRectMake(12, 8, menuWidth - 24, 34)];
    linkInput.placeholder = @"Dán link cần Bypass vào đây...";
    linkInput.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
    linkInput.textColor = [UIColor whiteColor];
    linkInput.font = [UIFont systemFontOfSize:12];
    linkInput.layer.cornerRadius = 8.0;
    linkInput.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 34)];
    linkInput.leftViewMode = UITextFieldViewModeAlways;
    [bypassTabContainer addSubview:linkInput];

    bypassBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    bypassBtn.frame = CGRectMake(12, 50, (menuWidth - 30) / 2, 36);
    bypassBtn.backgroundColor = [UIColor colorWithRed:1.00 green:0.75 blue:0.10 alpha:1.0];
    bypassBtn.layer.cornerRadius = 8.0;
    [bypassBtn setTitle:@"⚡ Bypass Ngay" forState:UIControlStateNormal];
    [bypassBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    bypassBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [bypassBtn addTarget:self action:@selector(handleBypass) forControlEvents:UIControlEventTouchUpInside];
    [bypassTabContainer addSubview:bypassBtn];

    copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyBtn.frame = CGRectMake(CGRectGetMaxX(bypassBtn.frame) + 6, 50, (menuWidth - 30) / 2, 36);
    copyBtn.backgroundColor = [UIColor colorWithWhite:0.3 alpha:0.8];
    copyBtn.layer.cornerRadius = 8.0;
    [copyBtn setTitle:@"📋 Sao Chép" forState:UIControlStateNormal];
    [copyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [copyBtn addTarget:self action:@selector(handleCopy) forControlEvents:UIControlEventTouchUpInside];
    [bypassTabContainer addSubview:copyBtn];

    resultBox = [[UIView alloc] initWithFrame:CGRectMake(12, 94, menuWidth - 24, 85)];
    resultBox.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    resultBox.layer.cornerRadius = 8.0;
    resultBox.layer.borderWidth = 1.0;
    resultBox.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.1].CGColor;
    [bypassTabContainer addSubview:resultBox];

    resultDisplay = [[UITextView alloc] initWithFrame:CGRectMake(8, 4, menuWidth - 40, 77)];
    resultDisplay.text = @"Dán link rồi ấn Bypass Ngay...";
    resultDisplay.textColor = [UIColor colorWithRed:0.7 green:0.7 blue:0.75 alpha:1.0];
    resultDisplay.font = [UIFont systemFontOfSize:11];
    resultDisplay.backgroundColor = [UIColor clearColor];
    resultDisplay.editable = NO;
    resultDisplay.selectable = YES;
    [resultBox addSubview:resultDisplay];

    // ==========================================
    // KHUNG TAB 2: AUTO CLICK & MACRO
    // ==========================================
    autoClickTabContainer = [[UIView alloc] initWithFrame:CGRectMake(0, tabYOffset, menuWidth, 185)];
    autoClickTabContainer.hidden = YES;
    [menuContainer addSubview:autoClickTabContainer];

    addPointBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    addPointBtn.frame = CGRectMake(12, 8, 100, 34);
    addPointBtn.backgroundColor = [UIColor colorWithRed:0.18 green:0.55 blue:0.90 alpha:1.0];
    addPointBtn.layer.cornerRadius = 8.0;
    [addPointBtn setTitle:@"➕ Thêm Điểm" forState:UIControlStateNormal];
    [addPointBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    addPointBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [addPointBtn addTarget:self action:@selector(addNewTargetMarker) forControlEvents:UIControlEventTouchUpInside];
    [autoClickTabContainer addSubview:addPointBtn];

    clearPointsBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearPointsBtn.frame = CGRectMake(120, 8, 100, 34);
    clearPointsBtn.backgroundColor = [UIColor colorWithWhite:0.3 alpha:0.8];
    clearPointsBtn.layer.cornerRadius = 8.0;
    [clearPointsBtn setTitle:@"🗑️ Xóa Hết" forState:UIControlStateNormal];
    [clearPointsBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    clearPointsBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [clearPointsBtn addTarget:self action:@selector(clearAllTargetMarkers) forControlEvents:UIControlEventTouchUpInside];
    [autoClickTabContainer addSubview:clearPointsBtn];

    recordMacroBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    recordMacroBtn.frame = CGRectMake(228, 8, menuWidth - 240, 34);
    recordMacroBtn.backgroundColor = [UIColor colorWithRed:0.85 green:0.40 blue:0.10 alpha:1.0];
    recordMacroBtn.layer.cornerRadius = 8.0;
    [recordMacroBtn setTitle:@"⏺ Ghi Macro" forState:UIControlStateNormal];
    [recordMacroBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    recordMacroBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [recordMacroBtn addTarget:self action:@selector(toggleMacroRecording) forControlEvents:UIControlEventTouchUpInside];
    [autoClickTabContainer addSubview:recordMacroBtn];

    UIView *statusBox = [[UIView alloc] initWithFrame:CGRectMake(12, 50, menuWidth - 24, 76)];
    statusBox.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    statusBox.layer.cornerRadius = 8.0;
    statusBox.layer.borderWidth = 1.0;
    statusBox.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.1].CGColor;
    [autoClickTabContainer addSubview:statusBox];

    autoStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 4, menuWidth - 44, 68)];
    autoStatusLabel.numberOfLines = 0;
    autoStatusLabel.textColor = [UIColor colorWithRed:0.85 green:0.85 blue:0.90 alpha:1.0];
    autoStatusLabel.font = [UIFont systemFontOfSize:11];
    autoStatusLabel.text = @"🎯 Số điểm: 0\n⏱️ Chạm vào hình tròn để chỉnh giây\n🔄 Tự động lặp lại liên tục\n🛡️ An toàn: Không click trúng Menu";
    [statusBox addSubview:autoStatusLabel];

    toggleAutoRunBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    toggleAutoRunBtn.frame = CGRectMake(12, 136, menuWidth - 24, 40);
    toggleAutoRunBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.75 blue:0.35 alpha:1.0];
    toggleAutoRunBtn.layer.cornerRadius = 10.0;
    [toggleAutoRunBtn setTitle:@"▶ BẮT ĐẦU" forState:UIControlStateNormal];
    [toggleAutoRunBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    toggleAutoRunBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [toggleAutoRunBtn addTarget:self action:@selector(toggleAutoClickExecution) forControlEvents:UIControlEventTouchUpInside];
    [autoClickTabContainer addSubview:toggleAutoRunBtn];

    // ==========================================
    // FOOTER: ẨN STREAM & THANH TRƯỢT ĐỘ TRONG SUỐT
    // ==========================================
    UIView *bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, menuHeight - 38, menuWidth, 38)];
    bottomBar.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
    bottomBar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [menuContainer addSubview:bottomBar];

    streamHideBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    streamHideBtn.frame = CGRectMake(12, 6, 120, 26);
    streamHideBtn.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.4 alpha:1.0];
    streamHideBtn.layer.cornerRadius = 6.0;
    [streamHideBtn setTitle:@"👁️ Stream: HIỆN" forState:UIControlStateNormal];
    [streamHideBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    streamHideBtn.titleLabel.font = [UIFont boldSystemFontOfSize:10.5];
    [streamHideBtn addTarget:self action:@selector(toggleStreamHideMode) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:streamHideBtn];

    UILabel *alphaLbl = [[UILabel alloc] initWithFrame:CGRectMake(142, 6, 45, 26)];
    alphaLbl.text = @"Mờ:";
    alphaLbl.textColor = [UIColor lightGrayColor];
    alphaLbl.font = [UIFont systemFontOfSize:11];
    [bottomBar addSubview:alphaLbl];

    UISlider *alphaSlider = [[UISlider alloc] initWithFrame:CGRectMake(170, 6, menuWidth - 182, 26)];
    alphaSlider.minimumValue = 0.15;
    alphaSlider.maximumValue = 1.0;
    alphaSlider.value = 1.0;
    alphaSlider.minimumTrackTintColor = [UIColor colorWithRed:0.3 green:0.7 blue:1.0 alpha:1.0];
    [alphaSlider addTarget:self action:@selector(onAlphaSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [bottomBar addSubview:alphaSlider];

    [targetWindow addSubview:menuContainer];

    [self setupMiniBrowserInWindow:targetWindow];
    [self setupHistoryOverlayInWindow:targetWindow];
    [self setupDeviceLogsOverlayInWindow:targetWindow];

    [self updateLayoutForAdminState:NO];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        if (robloxWindow) {
            UIView *parent = isStreamHiddenMode ? streamSecureContainer : robloxWindow;
            [parent bringSubviewToFront:floatingCircleBtn];
            [parent bringSubviewToFront:menuContainer];
        }
        if (menuContainer && !menuContainer.hidden && !isAutoClickTabActive) {
            [self autoDetectClipboardLink];
        }
    }];
}

+ (void)onAlphaSliderChanged:(UISlider *)slider {
    menuContainer.alpha = slider.value;
}

// ============================================================
// CHUYỂN ĐỔI TAB (BYPASS <-> AUTO CLICK)
// ============================================================
+ (void)toggleTabs {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    isAutoClickTabActive = !isAutoClickTabActive;

    if (isAutoClickTabActive) {
        [tabSwitchBtn setTitle:@"⚡ Bypass" forState:UIControlStateNormal];
        tabSwitchBtn.backgroundColor = [UIColor colorWithRed:0.85 green:0.55 blue:0.10 alpha:1.0];
        bypassTabContainer.hidden = YES;
        autoClickTabContainer.hidden = NO;
        menuContainer.frame = CGRectMake(menuContainer.frame.origin.x, menuContainer.frame.origin.y, 340.0, 285.0);
    } else {
        [tabSwitchBtn setTitle:@"🎯 Auto" forState:UIControlStateNormal];
        tabSwitchBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.50 blue:0.90 alpha:1.0];
        autoClickTabContainer.hidden = YES;
        bypassTabContainer.hidden = NO;
        [self updateLayoutForAdminState:isAdminMode];
        [self autoDetectClipboardLink];
    }
}

// ============================================================
// LOGIC AUTO CLICK
// ============================================================
+ (void)addNewTargetMarker {
    [self triggerImpact:UIImpactFeedbackStyleMedium];
    NSInteger newIndex = targetMarkers.count + 1;
    CGFloat size = 42.0;
    CGFloat startX = 60.0 + (newIndex * 20.0);
    CGFloat startY = 220.0 + (newIndex * 15.0);
    if (startX > robloxWindow.bounds.size.width - 50) startX = 60.0;
    if (startY > robloxWindow.bounds.size.height - 100) startY = 220.0;

    UIView *mView = [[UIView alloc] initWithFrame:CGRectMake(startX, startY, size, size)];
    mView.backgroundColor = [UIColor colorWithRed:0.1 green:0.6 blue:1.0 alpha:0.85];
    mView.layer.cornerRadius = size / 2.0;
    mView.layer.borderWidth = 2.0;
    mView.layer.borderColor = [UIColor whiteColor].CGColor;
    mView.layer.shadowColor = [UIColor blackColor].CGColor;
    mView.layer.shadowOpacity = 0.5;
    mView.layer.shadowOffset = CGSizeMake(0, 2);
    mView.userInteractionEnabled = YES;

    UILabel *numLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 4, size, 18)];
    numLbl.text = [NSString stringWithFormat:@"%ld", (long)newIndex];
    numLbl.textColor = [UIColor whiteColor];
    numLbl.font = [UIFont boldSystemFontOfSize:15];
    numLbl.textAlignment = NSTextAlignmentCenter;
    [mView addSubview:numLbl];

    UILabel *dlyLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 22, size, 16)];
    dlyLbl.text = @"0.5s";
    dlyLbl.textColor = [UIColor colorWithRed:1.0 green:0.9 blue:0.1 alpha:1.0];
    dlyLbl.font = [UIFont boldSystemFontOfSize:9.5];
    dlyLbl.textAlignment = NSTextAlignmentCenter;
    [mView addSubview:dlyLbl];

    AutoClickTarget *target = [[AutoClickTarget alloc] init];
    target.index = newIndex;
    target.markerView = mView;
    target.delayLabel = dlyLbl;
    target.delaySeconds = 0.5;
    target.screenPoint = mView.center;

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragTargetMarker:)];
    [mView addGestureRecognizer:pan];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapTargetMarker:)];
    [mView addGestureRecognizer:tap];

    UIView *parent = isStreamHiddenMode ? streamSecureContainer : robloxWindow;
    [parent addSubview:mView];
    [targetMarkers addObject:target];
    [self updateAutoStatusText];
}

+ (void)handleDragTargetMarker:(UIPanGestureRecognizer *)g {
    UIView *v = g.view;
    CGPoint trans = [g translationInView:robloxWindow];
    v.center = CGPointMake(v.center.x + trans.x, v.center.y + trans.y);
    [g setTranslation:CGPointZero inView:robloxWindow];

    for (AutoClickTarget *t in targetMarkers) {
        if (t.markerView == v) {
            t.screenPoint = v.center;
            break;
        }
    }
}

+ (void)handleTapTargetMarker:(UITapGestureRecognizer *)g {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    UIView *v = g.view;
    AutoClickTarget *target = nil;
    for (AutoClickTarget *t in targetMarkers) {
        if (t.markerView == v) { target = t; break; }
    }
    if (!target) return;

    UIViewController *topVC = robloxWindow.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"⏱ Cài Đặt Điểm #%ld", (long)target.index]
                                                                   message:@"Nhập delay (giây) tối thiểu 0.05s:"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = [NSString stringWithFormat:@"%.2f", target.delaySeconds];
        textField.keyboardType = UIKeyboardTypeDecimalPad;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Lưu" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        CGFloat val = [alert.textFields.firstObject.text floatValue];
        if (val < 0.05) val = 0.05;
        target.delaySeconds = val;
        target.delayLabel.text = [NSString stringWithFormat:@"%.1fs", val];
        [self triggerNotify:UINotificationFeedbackTypeSuccess];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [topVC presentViewController:alert animated:YES completion:nil];
}

+ (void)clearAllTargetMarkers {
    [self triggerImpact:UIImpactFeedbackStyleMedium];
    for (AutoClickTarget *t in targetMarkers) { [t.markerView removeFromSuperview]; }
    [targetMarkers removeAllObjects];
    [self updateAutoStatusText];
}

// ============================================================
// GHI LẠI THAO TÁC (MACRO RECORDER)
// ============================================================
+ (void)toggleMacroRecording {
    [self triggerImpact:UIImpactFeedbackStyleHeavy];
    if (isAutoRunning) [self stopAutoClick];

    isRecordingMacro = !isRecordingMacro;

    if (isRecordingMacro) {
        [recordedMacroSteps removeAllObjects];
        recordStartTime = [NSDate timeIntervalSinceReferenceDate];
        [recordMacroBtn setTitle:@"⏹️ Lưu Macro" forState:UIControlStateNormal];
        recordMacroBtn.backgroundColor = [UIColor colorWithRed:0.85 green:0.20 blue:0.20 alpha:1.0];

        if (!macroTapRecorder) {
            macroTapRecorder = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleMacroGesture:)];
            macroTapRecorder.minimumPressDuration = 0;
            macroTapRecorder.cancelsTouchesInView = NO;
        }
        if (!macroPanRecorder) {
            macroPanRecorder = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleMacroGesture:)];
            macroPanRecorder.cancelsTouchesInView = NO;
        }
        [robloxWindow addGestureRecognizer:macroTapRecorder];
        [robloxWindow addGestureRecognizer:macroPanRecorder];

        [self triggerNotify:UINotificationFeedbackTypeSuccess];
        [self updateAutoStatusText];
    } else {
        [recordMacroBtn setTitle:@"⏺ Ghi Macro" forState:UIControlStateNormal];
        recordMacroBtn.backgroundColor = [UIColor colorWithRed:0.85 green:0.40 blue:0.10 alpha:1.0];
        if (macroTapRecorder) [robloxWindow removeGestureRecognizer:macroTapRecorder];
        if (macroPanRecorder) [robloxWindow removeGestureRecognizer:macroPanRecorder];
        
        [self triggerNotify:UINotificationFeedbackTypeSuccess];
        [self updateAutoStatusText];
    }
}

+ (void)handleMacroGesture:(UIGestureRecognizer *)g {
    if (!isRecordingMacro) return;
    
    CGPoint pt = [g locationInView:robloxWindow];
    if (menuContainer && !menuContainer.hidden && CGRectContainsPoint(menuContainer.frame, pt)) return;

    UITouchPhase phase = UITouchPhaseMoved;
    if (g.state == UIGestureRecognizerStateBegan) phase = UITouchPhaseBegan;
    else if (g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled) phase = UITouchPhaseEnded;

    NSTimeInterval current = [NSDate timeIntervalSinceReferenceDate];
    MacroTouchStep *step = [[MacroTouchStep alloc] init];
    step.point = pt;
    step.timeOffset = current - recordStartTime;
    step.phase = phase;
    [recordedMacroSteps addObject:step];
}

+ (void)updateAutoStatusText {
    if (isRecordingMacro) {
        autoStatusLabel.text = [NSString stringWithFormat:@"🔴 ĐANG GHI MACRO...\nBạn cứ chơi bình thường, hệ thống đang ngầm ghi lại!\nĐã lưu: %lu điểm chạm.", (unsigned long)recordedMacroSteps.count];
        autoStatusLabel.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0];
        return;
    }
    NSString *macroStatus = (recordedMacroSteps.count > 0) ? [NSString stringWithFormat:@"Đã có Macro (%lu bước)", (unsigned long)recordedMacroSteps.count] : @"Chưa có Macro";
    autoStatusLabel.text = [NSString stringWithFormat:@"🎯 Số điểm click: %lu\n📹 Macro: %@\n⚡ Trạng thái: %@\n🛡️ An toàn: Tự động tránh Menu",
                            (unsigned long)targetMarkers.count, macroStatus, isAutoRunning ? @"ĐANG CHẠY" : @"ĐANG DỪNG"];
    autoStatusLabel.textColor = isAutoRunning ? [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0] : [UIColor colorWithRed:0.85 green:0.85 blue:0.90 alpha:1.0];
}

// ============================================================
// CHẠY AUTO CLICK VÀ MACRO
// ============================================================
+ (void)toggleAutoClickExecution {
    [self triggerImpact:UIImpactFeedbackStyleHeavy];
    if (isAutoRunning) {
        [self stopAutoClick];
    } else {
        [self startAutoClick];
    }
}

+ (void)startAutoClick {
    if (targetMarkers.count == 0 && recordedMacroSteps.count == 0) {
        [self triggerNotify:UINotificationFeedbackTypeWarning];
        autoStatusLabel.text = @"⚠️ Cần thêm 1 điểm click hoặc Ghi Macro trước!";
        autoStatusLabel.textColor = [UIColor colorWithRed:1.0 green:0.8 blue:0.2 alpha:1.0];
        return;
    }
    isAutoRunning = YES;
    [toggleAutoRunBtn setTitle:@"⏹ DỪNG LẠI" forState:UIControlStateNormal];
    toggleAutoRunBtn.backgroundColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.25 alpha:1.0];
    [self updateAutoStatusText];

    if (recordedMacroSteps.count > 0) {
        [self executeMacroLoopIndex:0];
    } else {
        currentRunningTargetIdx = 0;
        [self executeTargetMarkerLoop];
    }
}

+ (void)stopAutoClick {
    isAutoRunning = NO;
    [toggleAutoRunBtn setTitle:@"▶ BẮT ĐẦU" forState:UIControlStateNormal];
    // Đã Fix lỗi typo 'infractions:' thành 'blue:'
    toggleAutoRunBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.75 blue:0.35 alpha:1.0];
    [self updateAutoStatusText];
}

+ (void)executeTargetMarkerLoop {
    if (!isAutoRunning || targetMarkers.count == 0) return;
    if (currentRunningTargetIdx >= targetMarkers.count) currentRunningTargetIdx = 0;

    AutoClickTarget *target = targetMarkers[currentRunningTargetIdx];
    CGPoint pt = target.screenPoint;

    if (!(menuContainer && !menuContainer.hidden && CGRectContainsPoint(menuContainer.frame, pt))) {
        [self simulateTapAtPoint:pt];
    }

    currentRunningTargetIdx++;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(target.delaySeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self executeTargetMarkerLoop];
    });
}

+ (void)executeMacroLoopIndex:(NSInteger)idx {
    if (!isAutoRunning || recordedMacroSteps.count == 0) return;
    if (idx >= recordedMacroSteps.count) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self executeMacroLoopIndex:0];
        });
        return;
    }

    MacroTouchStep *currentStep = recordedMacroSteps[idx];
    [self simulateDirectTouchAtPoint:currentStep.point phase:currentStep.phase];

    NSTimeInterval nextDelay = 0.03;
    if (idx + 1 < recordedMacroSteps.count) {
        MacroTouchStep *nextStep = recordedMacroSteps[idx + 1];
        nextDelay = nextStep.timeOffset - currentStep.timeOffset;
        if (nextDelay < 0.01) nextDelay = 0.01;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(nextDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self executeMacroLoopIndex:idx + 1];
    });
}

// ============================================================
// BẮN CẢM ỨNG VÀO GAME
// ============================================================
+ (void)simulateTapAtPoint:(CGPoint)screenPoint {
    [self simulateDirectTouchAtPoint:screenPoint phase:UITouchPhaseBegan];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.015 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self simulateDirectTouchAtPoint:screenPoint phase:UITouchPhaseEnded];
    });
}

+ (void)simulateDirectTouchAtPoint:(CGPoint)screenPoint phase:(UITouchPhase)phase {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (AutoClickTarget *t in targetMarkers) t.markerView.userInteractionEnabled = NO;
        UIView *hit = [robloxWindow hitTest:screenPoint withEvent:nil];
        for (AutoClickTarget *t in targetMarkers) t.markerView.userInteractionEnabled = YES;

        if (!hit || hit == menuContainer || [hit isDescendantOfView:menuContainer] || hit == floatingCircleBtn) return;

        CGPoint local = [hit convertPoint:screenPoint fromView:robloxWindow];
        UITouch *touch = [[NSClassFromString(@"UITouch") alloc] init];

        Ivar ivarLoc = class_getInstanceVariable([UITouch class], "_locationInWindow");
        if (ivarLoc) *(CGPoint *)((uintptr_t)(__bridge void *)touch + ivar_getOffset(ivarLoc)) = local;
        Ivar ivarPhase = class_getInstanceVariable([UITouch class], "_phase");
        if (ivarPhase) *(NSInteger *)((uintptr_t)(__bridge void *)touch + ivar_getOffset(ivarPhase)) = phase;
        Ivar ivarView = class_getInstanceVariable([UITouch class], "_view");
        if (ivarView) object_setIvar(touch, ivarView, hit);
        Ivar ivarWin = class_getInstanceVariable([UITouch class], "_window");
        if (ivarWin) object_setIvar(touch, ivarWin, robloxWindow);

        NSSet *touchSet = [NSSet setWithObject:touch];

        if (phase == UITouchPhaseBegan) {
            if ([hit respondsToSelector:@selector(touchesBegan:withEvent:)]) [hit touchesBegan:touchSet withEvent:nil];
        } else if (phase == UITouchPhaseMoved) {
            if ([hit respondsToSelector:@selector(touchesMoved:withEvent:)]) [hit touchesMoved:touchSet withEvent:nil];
        } else if (phase == UITouchPhaseEnded || phase == UITouchPhaseCancelled) {
            if ([hit respondsToSelector:@selector(touchesEnded:withEvent:)]) [hit touchesEnded:touchSet withEvent:nil];
        }
    });
}

// ============================================================
// HỆ THỐNG GIAO DIỆN (UI) ADMIN & CÁC CHỨC NĂNG KHÁC
// ============================================================
+ (void)updateLayoutForAdminState:(BOOL)admin {
    CGFloat menuWidth = 340.0;
    if (admin) {
        apiKeyInput.hidden = NO;
        keyActionContainer.hidden = NO;
        linkInput.frame = CGRectMake(12, 74, menuWidth - 24, 34);
        bypassBtn.frame = CGRectMake(12, 116, (menuWidth - 30) / 2, 36);
        copyBtn.frame = CGRectMake(CGRectGetMaxX(bypassBtn.frame) + 6, 116, (menuWidth - 30) / 2, 36);
        resultBox.frame = CGRectMake(12, 160, menuWidth - 24, 85);
        resultDisplay.frame = CGRectMake(8, 4, menuWidth - 40, 77);
        bypassTabContainer.frame = CGRectMake(0, 64, menuWidth, 255.0);
        if (!isAutoClickTabActive) menuContainer.frame = CGRectMake(menuContainer.frame.origin.x, menuContainer.frame.origin.y, menuWidth, 350.0);
        baconWebBtn.hidden = NO;
        googleWebBtn.frame = CGRectMake(175, 8, 50, 26);
    } else {
        apiKeyInput.hidden = YES;
        keyActionContainer.hidden = YES;
        linkInput.frame = CGRectMake(12, 8, menuWidth - 24, 34);
        bypassBtn.frame = CGRectMake(12, 50, (menuWidth - 30) / 2, 36);
        copyBtn.frame = CGRectMake(CGRectGetMaxX(bypassBtn.frame) + 6, 50, (menuWidth - 30) / 2, 36);
        resultBox.frame = CGRectMake(12, 94, menuWidth - 24, 85);
        resultDisplay.frame = CGRectMake(8, 4, menuWidth - 40, 77);
        bypassTabContainer.frame = CGRectMake(0, 64, menuWidth, 185.0);
        if (!isAutoClickTabActive) menuContainer.frame = CGRectMake(menuContainer.frame.origin.x, menuContainer.frame.origin.y, menuWidth, 285.0);
        baconWebBtn.hidden = YES;
        googleWebBtn.frame = CGRectMake(120, 8, 105, 26);
    }
}

+ (void)handleAdminSecretTap {
    [self triggerImpact:UIImpactFeedbackStyleHeavy];
    UIViewController *topVC = robloxWindow.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;
    if (!topVC) return;

    if (isAdminMode) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🛡️ Quản Trị Viên"
                                                                       message:@"Bạn muốn khóa lại chế độ Quản Trị Viên?"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Khóa ngay" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            isAdminMode = NO;
            [self updateLayoutForAdminState:NO];
            deviceLogsContainer.hidden = YES;
            [self triggerNotify:UINotificationFeedbackTypeSuccess];
            resultDisplay.text = @"🔒 Đã khóa chế độ Admin! Chuyển về giao diện Khách.";
            resultDisplay.textColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
        [topVC presentViewController:alert animated:YES completion:nil];
        return;
    }

    UIAlertController *pinAlert = [UIAlertController alertControllerWithTitle:@"🔐 Quyền Admin"
                                                                      message:@"Nhập mật mã để mở bảng quản trị:"
                                                               preferredStyle:UIAlertControllerStyleAlert];
    [pinAlert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Nhập mật mã...";
        textField.secureTextEntry = YES;
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];

    [pinAlert addAction:[UIAlertAction actionWithTitle:@"Mở khóa" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *enteredPIN = pinAlert.textFields.firstObject.text;
        if ([enteredPIN isEqualToString:ADMIN_PIN]) {
            isAdminMode = YES;
            [self updateLayoutForAdminState:YES];
            [self triggerNotify:UINotificationFeedbackTypeSuccess];
            resultDisplay.text = @"👑 Xin chào Admin! Bạn có thể xem/đổi API Key hoặc kiểm tra người dùng.";
            resultDisplay.textColor = [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
        } else {
            [self triggerNotify:UINotificationFeedbackTypeError];
            resultDisplay.text = @"❌ Mật mã không đúng!";
            resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
        }
    }]];

    [pinAlert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [topVC presentViewController:pinAlert animated:YES completion:nil];
}

+ (void)handleToggleKillswitchRemote {
    [self triggerImpact:UIImpactFeedbackStyleHeavy];
    NSURL *url = [NSURL URLWithString:TRACKER_API];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSDictionary *body = @{ @"action": @"toggle_killswitch" };
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (err || !data) return;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            BOOL isK = [json[@"killswitch"] boolValue];
            isServerKillswitchActive = isK;
            [self triggerNotify:UINotificationFeedbackTypeSuccess];
            resultDisplay.text = isK ? @"🚨 Đã BẬT Khóa từ xa (Dylib ở máy khác bị ẩn)!" : @"✅ Đã TẮT Khóa từ xa (Dylib hoạt động bình thường)!";
            resultDisplay.textColor = isK ? [UIColor colorWithRed:1.0 green:0.4 blue:0.3 alpha:1.0] : [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
        });
    }] resume];
}

+ (void)setupDeviceLogsOverlayInWindow:(UIWindow *)window {
    CGFloat dWidth = 320.0;
    CGFloat dHeight = 300.0;
    deviceLogsContainer = [[UIView alloc] initWithFrame:CGRectMake((window.bounds.size.width - dWidth)/2, 110, dWidth, dHeight)];
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

    [window addSubview:deviceLogsContainer];
}

+ (void)toggleDeviceLogs {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    deviceLogsContainer.hidden = !deviceLogsContainer.hidden;
    if (!deviceLogsContainer.hidden) {
        UIView *parent = isStreamHiddenMode ? streamSecureContainer : robloxWindow;
        [parent bringSubviewToFront:deviceLogsContainer];
        [self fetchDeviceLogsFromServer];
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
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
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
                NSString *titleStr = (nick && nick.length > 0) ?
                    [NSString stringWithFormat:@"🏷️ %@ (%@)", nick, dev[@"model"] ?: @"iPhone"] :
                    [NSString stringWithFormat:@"📱 %@ (%@)", dev[@"model"] ?: @"iPhone", dev[@"ios"] ?: @"iOS"];

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
    }] resume];
}

+ (void)promptEditNickname:(UIButton *)sender {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    NSString *devID = objc_getAssociatedObject(sender, "targetDevID");
    if (!devID) return;

    UIViewController *topVC = robloxWindow.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;
    if (!topVC) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🏷️ Đặt Biệt Danh Thiết Bị"
                                                                   message:[NSString stringWithFormat:@"Nhập tên gợi nhớ cho máy (ID: %@):", devID]
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Ví dụ: Máy phụ của Đạt, Máy Nam...";
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Lưu tên" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *name = alert.textFields.firstObject.text;
        [self sendSaveNicknameToServer:devID nickname:name];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [topVC presentViewController:alert animated:YES completion:nil];
}

+ (void)sendSaveNicknameToServer:(NSString *)devID nickname:(NSString *)name {
    NSURL *url = [NSURL URLWithString:TRACKER_API];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSDictionary *body = @{ @"action": @"set_nickname", @"device_id": devID, @"nickname": name ?: @"" };
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self triggerNotify:UINotificationFeedbackTypeSuccess];
            [self fetchDeviceLogsFromServer];
        });
    }] resume];
}

+ (void)setupMiniBrowserInWindow:(UIWindow *)window {
    CGFloat bWidth = MIN(window.bounds.size.width - 24, 360.0);
    CGFloat bHeight = 440.0;
    miniBrowserContainer = [[UIView alloc] initWithFrame:CGRectMake((window.bounds.size.width - bWidth)/2, 60, bWidth, bHeight)];
    miniBrowserContainer.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:0.98];
    miniBrowserContainer.layer.cornerRadius = 12.0;
    miniBrowserContainer.layer.borderWidth = 1.0;
    miniBrowserContainer.layer.borderColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.4 alpha:1.0].CGColor;
    miniBrowserContainer.clipsToBounds = YES;
    miniBrowserContainer.hidden = YES;

    UIView *bHeader = [[UIView alloc] initWithFrame:CGRectMake(0, 0, bWidth, 38)];
    bHeader.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.18 alpha:1.0];
    UIPanGestureRecognizer *panWeb = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragBrowser:)];
    [bHeader addGestureRecognizer:panWeb];
    [miniBrowserContainer addSubview:bHeader];

    UILabel *bTitle = [[UILabel alloc] initWithFrame:CGRectMake(8, 0, 50, 38)];
    bTitle.text = @"🌐 Web";
    bTitle.textColor = [UIColor whiteColor];
    bTitle.font = [UIFont boldSystemFontOfSize:12];
    [bHeader addSubview:bTitle];

    baconWebBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    baconWebBtn.frame = CGRectMake(60, 6, 74, 26);
    baconWebBtn.backgroundColor = [UIColor colorWithRed:0.85 green:0.55 blue:0.10 alpha:1.0];
    baconWebBtn.layer.cornerRadius = 5.0;
    [baconWebBtn setTitle:@"🔑 Bacon" forState:UIControlStateNormal];
    [baconWebBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    baconWebBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [baconWebBtn addTarget:self action:@selector(openBaconSite) forControlEvents:UIControlEventTouchUpInside];
    [bHeader addSubview:baconWebBtn];

    googleWebBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    googleWebBtn.frame = CGRectMake(139, 6, 74, 26);
    googleWebBtn.backgroundColor = [UIColor colorWithRed:0.20 green:0.55 blue:0.90 alpha:1.0];
    googleWebBtn.layer.cornerRadius = 5.0;
    [googleWebBtn setTitle:@"🔍 Google" forState:UIControlStateNormal];
    [googleWebBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    googleWebBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [googleWebBtn addTarget:self action:@selector(openGoogle) forControlEvents:UIControlEventTouchUpInside];
    [bHeader addSubview:googleWebBtn];

    UIButton *reloadBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    reloadBtn.frame = CGRectMake(bWidth - 66, 6, 28, 26);
    reloadBtn.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.35 alpha:1.0];
    reloadBtn.layer.cornerRadius = 5.0;
    [reloadBtn setTitle:@"🔄" forState:UIControlStateNormal];
    [reloadBtn addTarget:self action:@selector(reloadBrowser) forControlEvents:UIControlEventTouchUpInside];
    [bHeader addSubview:reloadBtn];

    UIButton *closeWebBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeWebBtn.frame = CGRectMake(bWidth - 34, 6, 28, 26);
    closeWebBtn.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
    closeWebBtn.layer.cornerRadius = 5.0;
    [closeWebBtn setTitle:@"✕" forState:UIControlStateNormal];
    closeWebBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [closeWebBtn addTarget:self action:@selector(toggleMiniBrowser) forControlEvents:UIControlEventTouchUpInside];
    [bHeader addSubview:closeWebBtn];

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.allowsInlineMediaPlayback = YES;
    if (@available(iOS 10.0, *)) {
        config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    }

    NSString *inlineVideoScript = @"(function() { "
                                   "  function setInline(v) { "
                                   "    v.setAttribute('playsinline', ''); "
                                   "    v.setAttribute('webkit-playsinline', ''); "
                                   "  } "
                                   "  document.addEventListener('play', function(e) { "
                                   "    if (e.target && e.target.tagName === 'VIDEO') setInline(e.target); "
                                   "  }, true); "
                                   "  var observer = new MutationObserver(function(mutations) { "
                                   "    mutations.forEach(function(mutation) { "
                                   "      mutation.addedNodes.forEach(function(node) { "
                                   "        if (node.tagName === 'VIDEO') setInline(node); "
                                   "        else if (node.getElementsByTagName) { "
                                   "          var vids = node.getElementsByTagName('video'); "
                                   "          for (var i = 0; i < vids.length; i++) setInline(vids[i]); "
                                   "        } "
                                   "      }); "
                                   "    }); "
                                   "  }); "
                                   "  observer.observe(document.documentElement, { childList: true, subtree: true }); "
                                   "})();";
    WKUserScript *userScript = [[WKUserScript alloc] initWithSource:inlineVideoScript
                                                      injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                                                   forMainFrameOnly:NO];
    [config.userContentController addUserScript:userScript];

    miniWebView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 38, bWidth, bHeight - 38) configuration:config];
    miniWebView.backgroundColor = [UIColor whiteColor];
    [miniBrowserContainer addSubview:miniWebView];

    [window addSubview:miniBrowserContainer];
}

+ (void)openGoogle {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    NSURL *url = [NSURL URLWithString:@"https://www.google.com"];
    [miniWebView loadRequest:[NSURLRequest requestWithURL:url]];
}

+ (void)openBaconSite {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    NSURL *url = [NSURL URLWithString:@"https://baconbypass.online"];
    [miniWebView loadRequest:[NSURLRequest requestWithURL:url]];
}

+ (void)toggleMiniBrowser {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    miniBrowserContainer.hidden = !miniBrowserContainer.hidden;
    if (!miniBrowserContainer.hidden) {
        UIView *parent = isStreamHiddenMode ? streamSecureContainer : robloxWindow;
        [parent bringSubviewToFront:miniBrowserContainer];
        if (!miniWebView.URL) {
            [self openGoogle];
        }
    }
}

+ (void)reloadBrowser {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    [miniWebView reload];
}

+ (void)setupHistoryOverlayInWindow:(UIWindow *)window {
    CGFloat hWidth = 310.0;
    CGFloat hHeight = 240.0;
    historyContainer = [[UIView alloc] initWithFrame:CGRectMake((window.bounds.size.width - hWidth)/2, 140, hWidth, hHeight)];
    historyContainer.backgroundColor = [UIColor colorWithRed:0.09 green:0.09 blue:0.12 alpha:0.98];
    historyContainer.layer.cornerRadius = 12.0;
    historyContainer.layer.borderWidth = 1.0;
    historyContainer.layer.borderColor = [UIColor colorWithRed:0.35 green:0.35 blue:0.45 alpha:1.0].CGColor;
    historyContainer.clipsToBounds = YES;
    historyContainer.hidden = YES;

    UIView *hHeader = [[UIView alloc] initWithFrame:CGRectMake(0, 0, hWidth, 36)];
    hHeader.backgroundColor = [UIColor colorWithRed:0.14 green:0.14 blue:0.18 alpha:1.0];
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
    closeHBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [closeHBtn addTarget:self action:@selector(toggleHistory) forControlEvents:UIControlEventTouchUpInside];
    [hHeader addSubview:closeHBtn];

    historyScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 36, hWidth, hHeight - 36)];
    [historyContainer addSubview:historyScrollView];

    [window addSubview:historyContainer];
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
        UIView *parent = isStreamHiddenMode ? streamSecureContainer : robloxWindow;
        [parent bringSubviewToFront:historyContainer];
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
    menuContainer.hidden = NO;
    floatingCircleBtn.hidden = YES;
    UIView *parent = isStreamHiddenMode ? streamSecureContainer : robloxWindow;
    [parent bringSubviewToFront:menuContainer];

    if (!isAutoClickTabActive) {
        [self autoDetectClipboardLink];
    }
}

+ (void)minimizeMenu {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    [linkInput resignFirstResponder];
    [apiKeyInput resignFirstResponder];
    menuContainer.hidden = YES;
    miniBrowserContainer.hidden = YES;
    historyContainer.hidden = YES;
    deviceLogsContainer.hidden = YES;
    floatingCircleBtn.hidden = NO;
    
    UIView *parent = isStreamHiddenMode ? streamSecureContainer : robloxWindow;
    [parent bringSubviewToFront:floatingCircleBtn];
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

    NSURL *endpoint = [NSURL URLWithString:@"https://baconbypass.online/bypass"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:endpoint];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSDictionary *body = @{ @"url": url, @"apikey": key };
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (err || !data) {
                [self triggerNotify:UINotificationFeedbackTypeError];
                resultDisplay.text = @"❌ Mất kết nối API!";
                resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
                return;
            }
            NSError *jsonErr = nil;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
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
}

+ (void)handleDragMenu:(UIPanGestureRecognizer *)g {
    CGPoint trans = [g translationInView:menuContainer.superview];
    menuContainer.center = CGPointMake(menuContainer.center.x + trans.x, menuContainer.center.y + trans.y);
    [g setTranslation:CGPointZero inView:menuContainer.superview];
}

+ (void)handleDragBrowser:(UIPanGestureRecognizer *)g {
    CGPoint trans = [g translationInView:miniBrowserContainer.superview];
    miniBrowserContainer.center = CGPointMake(miniBrowserContainer.center.x + trans.x, miniBrowserContainer.center.y + trans.y);
    [g setTranslation:CGPointZero inView:miniBrowserContainer.superview];
}

@end
