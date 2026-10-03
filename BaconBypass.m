#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import <sys/utsname.h>

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
@property (nonatomic, assign) NSInteger phase; // 0: began, 1: moved, 2: ended
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

// --- CẤU HÌNH ADMIN, API & TRACKER SERVER ---
#define ADMIN_PIN @"151009"
#define DEFAULT_API_KEY @"Bacon-68e61ca9d455d316a50c-b4328879cadc0a77f8a5"
#define TRACKER_API @"https://ok.tdat1510009.workers.dev"
#define STORAGE_KEY @"BaconBypass_CustomAPIKey"
#define HISTORY_KEY @"BaconBypass_HistoryLinks"

// --- UI Components Chung ---
static UIWindow *robloxWindow = nil;
static UIButton *floatingCircleBtn = nil;
static UILabel *infoWidgetLabel = nil;
static UIView *menuContainer = nil;
static UIView *miniBrowserContainer = nil;
static WKWebView *miniWebView = nil;
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
static NSString *extractedLink = nil;

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
static MacroRecorderOverlayView *macroRecorderView = nil;
static NSInteger currentRunningTargetIdx = 0;

// --- Trạng thái Admin ---
static BOOL isAdminMode = NO;

// --- Performance & RGB Engine ---
static CADisplayLink *renderLoop = nil;
static CGFloat currentHue = 0.0;
static NSInteger frameCount = 0;
static CFTimeInterval lastFpsTime = 0;
static NSInteger currentFPS = 60;

// ============================================================
// HAPTIC FEEDBACK (RUNG XÚC GIÁC TAPTIC ENGINE)
// ============================================================
+ (void)triggerImpact:(UIImpactFeedbackStyle)style {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
        [generator prepare];
        [generator impactOccurred];
    });
}

+ (void)triggerNotify:(UINotificationFeedbackType)type {
    dispatch_async(dispatch_get_main_queue(), ^{
        UINotificationFeedbackGenerator *generator = [[UINotificationFeedbackGenerator alloc] init];
        [generator prepare];
        [generator notificationOccurred:type];
    });
}

// ============================================================
// HÀM TỰ ĐỘNG BẮT LINK TỪ CLIPBOARD (BỘ NHỚ TẠM)
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
// HÀM NHẬN DIỆN THÔNG TIN THIẾT BỊ (DEVICE & IOS VERSION)
// ============================================================
+ (NSString *)getDeviceModelName {
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *code = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];

    static NSDictionary *modelDict = nil;
    if (!modelDict) {
        modelDict = @{
            // iPhone Models
            @"iPhone10,1" : @"iPhone 8", @"iPhone10,4" : @"iPhone 8",
            @"iPhone10,2" : @"iPhone 8 Plus", @"iPhone10,5" : @"iPhone 8 Plus",
            @"iPhone10,3" : @"iPhone X", @"iPhone10,6" : @"iPhone X",
            @"iPhone11,2" : @"iPhone XS", @"iPhone11,4" : @"iPhone XS Max", @"iPhone11,6" : @"iPhone XS Max",
            @"iPhone11,8" : @"iPhone XR",
            @"iPhone12,1" : @"iPhone 11", @"iPhone12,3" : @"iPhone 11 Pro", @"iPhone12,5" : @"iPhone 11 Pro Max",
            @"iPhone12,8" : @"iPhone SE (2nd Gen)",
            @"iPhone13,1" : @"iPhone 12 mini", @"iPhone13,2" : @"iPhone 12",
            @"iPhone13,3" : @"iPhone 12 Pro", @"iPhone13,4" : @"iPhone 12 Pro Max",
            @"iPhone14,4" : @"iPhone 13 mini", @"iPhone14,5" : @"iPhone 13",
            @"iPhone14,2" : @"iPhone 13 Pro", @"iPhone14,3" : @"iPhone 13 Pro Max",
            @"iPhone14,6" : @"iPhone SE (3rd Gen)",
            @"iPhone14,7" : @"iPhone 14", @"iPhone14,8" : @"iPhone 14 Plus",
            @"iPhone15,2" : @"iPhone 14 Pro", @"iPhone15,3" : @"iPhone 14 Pro Max",
            @"iPhone15,4" : @"iPhone 15", @"iPhone15,5" : @"iPhone 15 Plus",
            @"iPhone16,1" : @"iPhone 15 Pro", @"iPhone16,2" : @"iPhone 15 Pro Max",
            @"iPhone17,1" : @"iPhone 16 Pro", @"iPhone17,2" : @"iPhone 16 Pro Max",
            @"iPhone17,3" : @"iPhone 16", @"iPhone17,4" : @"iPhone 16 Plus",
            // iPad Models
            @"iPad8,1"  : @"iPad Pro 11-inch", @"iPad8,3"  : @"iPad Pro 11-inch",
            @"iPad8,5"  : @"iPad Pro 12.9-inch", @"iPad8,7"  : @"iPad Pro 12.9-inch",
            @"iPad13,1" : @"iPad Air (4th Gen)", @"iPad13,2" : @"iPad Air (4th Gen)",
            @"iPad13,4" : @"iPad Pro 11-inch (3rd Gen)", @"iPad13,8" : @"iPad Pro 12.9-inch (5th Gen)",
            @"iPad13,16": @"iPad Air (5th Gen)", @"iPad13,17": @"iPad Air (5th Gen)",
            @"iPad14,1" : @"iPad mini (6th Gen)", @"iPad14,2" : @"iPad mini (6th Gen)"
        };
    }
    NSString *friendlyName = modelDict[code];
    return friendlyName ? friendlyName : code;
}

// Gửi ngầm thông tin thiết bị lên Cloudflare Worker khi mở app
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
        [[[NSURLSession sharedSession] dataTaskWithRequest:req] resume];
    });
}

// ============================================================
// KHỞI CHẠY OVERLAY
// ============================================================
+ (void)load {
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    targetMarkers = [NSMutableArray array];
    recordedMacroSteps = [NSMutableArray array];
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

    [self setupViewsInWindow:robloxWindow];
    [self startDisplayLoop];
}

// ============================================================
// VÒNG LẶP RENDER: RGB GLOW & ĐO FPS / PIN / GIỜ
// ============================================================
+ (void)startDisplayLoop {
    if (renderLoop) return;
    renderLoop = [CADisplayLink displayLinkWithTarget:self selector:@selector(onRenderFrame:)];
    [renderLoop addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

+ (void)onRenderFrame:(CADisplayLink *)link {
    currentHue += 0.006;
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
        [self updateInfoWidgetText];
    }
}

+ (void)updateInfoWidgetText {
    if (!infoWidgetLabel || infoWidgetLabel.hidden) return;

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"HH:mm"];
    NSString *timeStr = [df stringFromDate:[NSDate date]];

    float bat = [UIDevice currentDevice].batteryLevel;
    int batPct = (bat < 0) ? 100 : (int)(bat * 100.0f);

    infoWidgetLabel.text = [NSString stringWithFormat:@"%@ • %d%% • %ld FPS", timeStr, batPct, (long)currentFPS];
}

+ (void)syncWidgetPosition {
    if (!floatingCircleBtn || !infoWidgetLabel) return;
    infoWidgetLabel.center = CGPointMake(floatingCircleBtn.center.x, floatingCircleBtn.center.y + 28);
}

// ============================================================
// KHỞI TẠO CÁC GIAO DIỆN CHÍNH
// ============================================================
+ (void)setupViewsInWindow:(UIWindow *)targetWindow {
    // 1. Nút tròn nổi RGB (42x42)
    floatingCircleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    floatingCircleBtn.frame = CGRectMake(25, 120, 42, 42);
    floatingCircleBtn.backgroundColor = [UIColor colorWithRed:0.10 green:0.10 blue:0.14 alpha:0.92];
    floatingCircleBtn.layer.cornerRadius = 21.0;
    floatingCircleBtn.layer.borderWidth = 2.0;
    floatingCircleBtn.layer.shadowColor = [UIColor blackColor].CGColor;
    floatingCircleBtn.layer.shadowOffset = CGSizeMake(0, 3);
    floatingCircleBtn.layer.shadowOpacity = 0.5;
    floatingCircleBtn.layer.shadowRadius = 4.0;
    [floatingCircleBtn setTitle:@"⚡" forState:UIControlStateNormal];
    floatingCircleBtn.titleLabel.font = [UIFont systemFontOfSize:18];
    [floatingCircleBtn addTarget:self action:@selector(openMenu) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *panBtn = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragCircle:)];
    [floatingCircleBtn addGestureRecognizer:panBtn];
    [targetWindow addSubview:floatingCircleBtn];

    // 2. Widget thông tin: Giờ | Pin | FPS
    infoWidgetLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 110, 16)];
    infoWidgetLabel.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.75];
    infoWidgetLabel.textColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.95 alpha:1.0];
    infoWidgetLabel.font = [UIFont boldSystemFontOfSize:9];
    infoWidgetLabel.textAlignment = NSTextAlignmentCenter;
    infoWidgetLabel.layer.cornerRadius = 8.0;
    infoWidgetLabel.clipsToBounds = YES;
    [self syncWidgetPosition];
    [self updateInfoWidgetText];
    [targetWindow addSubview:infoWidgetLabel];

    // 3. Khung Menu Chính
    CGFloat menuWidth = 320.0;
    CGFloat menuHeight = 235.0;
    menuContainer = [[UIView alloc] initWithFrame:CGRectMake((targetWindow.bounds.size.width - menuWidth) / 2, 100, menuWidth, menuHeight)];
    menuContainer.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:0.97];
    menuContainer.layer.cornerRadius = 14.0;
    menuContainer.layer.borderWidth = 1.0;
    menuContainer.layer.borderColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.32 alpha:1.0].CGColor;
    menuContainer.clipsToBounds = YES;
    menuContainer.hidden = YES;

    UIPanGestureRecognizer *panMenu = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragMenu:)];
    [menuContainer addGestureRecognizer:panMenu];

    // Header Menu
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, menuWidth, 38)];
    header.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.16 alpha:1.0];
    [menuContainer addSubview:header];

    // TIÊU ĐỀ: "⚡ T_Dat"
    UILabel *headerTitle = [[UILabel alloc] initWithFrame:CGRectMake(8, 0, 85, 38)];
    headerTitle.text = @"⚡ T_Dat";
    headerTitle.textColor = [UIColor colorWithRed:1.00 green:0.67 blue:0.00 alpha:1.0];
    headerTitle.font = [UIFont boldSystemFontOfSize:13];
    headerTitle.userInteractionEnabled = YES;

    // GÕ 5 LẦN ĐỂ MỞ PANEL ADMIN
    UITapGestureRecognizer *adminTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleAdminSecretTap)];
    adminTapGesture.numberOfTapsRequired = 5;
    [headerTitle addGestureRecognizer:adminTapGesture];
    [header addSubview:headerTitle];

    // NÚT CHUYỂN TAB: BYPASS <-> AUTO CLICK
    tabSwitchBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    tabSwitchBtn.frame = CGRectMake(95, 6, 68, 26);
    tabSwitchBtn.backgroundColor = [UIColor colorWithRed:0.22 green:0.55 blue:0.85 alpha:1.0];
    tabSwitchBtn.layer.cornerRadius = 5.0;
    [tabSwitchBtn setTitle:@"🎯 Auto" forState:UIControlStateNormal];
    [tabSwitchBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    tabSwitchBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [tabSwitchBtn addTarget:self action:@selector(toggleTabs) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:tabSwitchBtn];

    // Nút mở Web In-App
    UIButton *webBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    webBtn.frame = CGRectMake(168, 6, 46, 26);
    webBtn.backgroundColor = [UIColor colorWithRed:0.20 green:0.40 blue:0.75 alpha:1.0];
    webBtn.layer.cornerRadius = 5.0;
    [webBtn setTitle:@"🌐 Web" forState:UIControlStateNormal];
    [webBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    webBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [webBtn addTarget:self action:@selector(toggleMiniBrowser) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:webBtn];

    // Nút Lịch Sử
    UIButton *histBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    histBtn.frame = CGRectMake(218, 6, 28, 26);
    histBtn.backgroundColor = [UIColor colorWithRed:0.30 green:0.30 blue:0.40 alpha:1.0];
    histBtn.layer.cornerRadius = 5.0;
    [histBtn setTitle:@"📜" forState:UIControlStateNormal];
    [histBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    histBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    [histBtn addTarget:self action:@selector(toggleHistory) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:histBtn];

    // Nút Thu nhỏ (−)
    UIButton *minBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    minBtn.frame = CGRectMake(250, 6, 28, 26);
    minBtn.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.35 alpha:1.0];
    minBtn.layer.cornerRadius = 5.0;
    [minBtn setTitle:@"−" forState:UIControlStateNormal];
    [minBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    minBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [minBtn addTarget:self action:@selector(minimizeMenu) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:minBtn];

    // Nút Đóng (✕)
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(282, 6, 28, 26);
    closeBtn.backgroundColor = [UIColor colorWithRed:0.80 green:0.20 blue:0.20 alpha:1.0];
    closeBtn.layer.cornerRadius = 5.0;
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [closeBtn addTarget:self action:@selector(minimizeMenu) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];

    // ==========================================
    // KHUNG TAB 1: BYPASS LINK
    // ==========================================
    bypassTabContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 38, menuWidth, menuHeight - 38)];
    [menuContainer addSubview:bypassTabContainer];

    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:STORAGE_KEY];
    if (!savedKey || savedKey.length == 0) savedKey = DEFAULT_API_KEY;

    apiKeyInput = [[UITextField alloc] initWithFrame:CGRectMake(12, 6, menuWidth - 24, 28)];
    apiKeyInput.text = savedKey;
    apiKeyInput.placeholder = @"Nhập Bacon API Key...";
    apiKeyInput.backgroundColor = [UIColor colorWithRed:0.13 green:0.13 blue:0.17 alpha:1.0];
    apiKeyInput.textColor = [UIColor colorWithRed:1.00 green:0.80 blue:0.30 alpha:1.0];
    apiKeyInput.font = [UIFont systemFontOfSize:11];
    apiKeyInput.layer.cornerRadius = 6.0;
    apiKeyInput.autocorrectionType = UITextAutocorrectionTypeNo;
    apiKeyInput.autocapitalizationType = UITextAutocapitalizationTypeNone;
    apiKeyInput.clearButtonMode = UITextFieldViewModeWhileEditing;
    UIView *padKey = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 28)];
    apiKeyInput.leftView = padKey;
    apiKeyInput.leftViewMode = UITextFieldViewModeAlways;
    [apiKeyInput addTarget:self action:@selector(onApiKeyEditingChanged) forControlEvents:UIControlEventEditingChanged];
    [apiKeyInput addTarget:self action:@selector(onApiKeyEditingBegan) forControlEvents:UIControlEventEditingDidBegin];
    apiKeyInput.hidden = YES;
    [bypassTabContainer addSubview:apiKeyInput];

    keyActionContainer = [[UIView alloc] initWithFrame:CGRectMake(12, 37, menuWidth - 24, 26)];
    keyActionContainer.backgroundColor = [UIColor clearColor];
    keyActionContainer.hidden = YES;

    UIButton *saveKeyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    saveKeyBtn.frame = CGRectMake(0, 0, 95, 26);
    saveKeyBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.60 blue:0.30 alpha:1.0];
    saveKeyBtn.layer.cornerRadius = 5.0;
    [saveKeyBtn setTitle:@"💾 Lưu Key" forState:UIControlStateNormal];
    [saveKeyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    saveKeyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [saveKeyBtn addTarget:self action:@selector(onConfirmSaveKey) forControlEvents:UIControlEventTouchUpInside];
    [keyActionContainer addSubview:saveKeyBtn];

    UIButton *discardKeyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    discardKeyBtn.frame = CGRectMake(101, 0, 85, 26);
    discardKeyBtn.backgroundColor = [UIColor colorWithRed:0.40 green:0.40 blue:0.45 alpha:1.0];
    discardKeyBtn.layer.cornerRadius = 5.0;
    [discardKeyBtn setTitle:@"✕ Bỏ qua" forState:UIControlStateNormal];
    [discardKeyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    discardKeyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [discardKeyBtn addTarget:self action:@selector(onDiscardKey) forControlEvents:UIControlEventTouchUpInside];
    [keyActionContainer addSubview:discardKeyBtn];

    viewDevicesBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    viewDevicesBtn.frame = CGRectMake(192, 0, menuWidth - 24 - 192, 26);
    viewDevicesBtn.backgroundColor = [UIColor colorWithRed:0.65 green:0.25 blue:0.75 alpha:1.0];
    viewDevicesBtn.layer.cornerRadius = 5.0;
    [viewDevicesBtn setTitle:@"👥 Thiết Bị" forState:UIControlStateNormal];
    [viewDevicesBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    viewDevicesBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [viewDevicesBtn addTarget:self action:@selector(toggleDeviceLogs) forControlEvents:UIControlEventTouchUpInside];
    [keyActionContainer addSubview:viewDevicesBtn];
    [bypassTabContainer addSubview:keyActionContainer];

    linkInput = [[UITextField alloc] initWithFrame:CGRectMake(12, 8, menuWidth - 24, 32)];
    linkInput.placeholder = @"Dán link cần Bypass vào đây...";
    linkInput.backgroundColor = [UIColor colorWithRed:0.16 green:0.16 blue:0.22 alpha:1.0];
    linkInput.textColor = [UIColor whiteColor];
    linkInput.font = [UIFont systemFontOfSize:12];
    linkInput.layer.cornerRadius = 6.0;
    linkInput.autocorrectionType = UITextAutocorrectionTypeNo;
    linkInput.autocapitalizationType = UITextAutocapitalizationTypeNone;
    linkInput.clearButtonMode = UITextFieldViewModeWhileEditing;
    UIView *padLink = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 32)];
    linkInput.leftView = padLink;
    linkInput.leftViewMode = UITextFieldViewModeAlways;
    [bypassTabContainer addSubview:linkInput];

    bypassBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    bypassBtn.frame = CGRectMake(12, 48, (menuWidth - 30) / 2, 34);
    bypassBtn.backgroundColor = [UIColor colorWithRed:1.00 green:0.67 blue:0.00 alpha:1.0];
    bypassBtn.layer.cornerRadius = 6.0;
    [bypassBtn setTitle:@"Bypass Ngay" forState:UIControlStateNormal];
    [bypassBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    bypassBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [bypassBtn addTarget:self action:@selector(handleBypass) forControlEvents:UIControlEventTouchUpInside];
    [bypassTabContainer addSubview:bypassBtn];

    copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyBtn.frame = CGRectMake(CGRectGetMaxX(bypassBtn.frame) + 6, 48, (menuWidth - 30) / 2, 34);
    copyBtn.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.35 alpha:1.0];
    copyBtn.layer.cornerRadius = 6.0;
    [copyBtn setTitle:@"Sao Chép" forState:UIControlStateNormal];
    [copyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [copyBtn addTarget:self action:@selector(handleCopy) forControlEvents:UIControlEventTouchUpInside];
    [bypassTabContainer addSubview:copyBtn];

    resultBox = [[UIView alloc] initWithFrame:CGRectMake(12, 90, menuWidth - 24, 95)];
    resultBox.backgroundColor = [UIColor colorWithRed:0.04 green:0.04 blue:0.06 alpha:1.0];
    resultBox.layer.cornerRadius = 6.0;
    [bypassTabContainer addSubview:resultBox];

    resultDisplay = [[UITextView alloc] initWithFrame:CGRectMake(6, 4, menuWidth - 36, 87)];
    resultDisplay.text = @"Dán link rồi ấn Bypass Ngay...";
    resultDisplay.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.65 alpha:1.0];
    resultDisplay.font = [UIFont systemFontOfSize:11];
    resultDisplay.backgroundColor = [UIColor clearColor];
    resultDisplay.editable = NO;
    resultDisplay.selectable = YES;
    [resultBox addSubview:resultDisplay];

    // ==========================================
    // KHUNG TAB 2: AUTO CLICK & MACRO
    // ==========================================
    autoClickTabContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 38, menuWidth, 222)];
    autoClickTabContainer.hidden = YES;
    [menuContainer addSubview:autoClickTabContainer];

    // Nút 1: Thêm Điểm
    addPointBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    addPointBtn.frame = CGRectMake(10, 8, 96, 32);
    addPointBtn.backgroundColor = [UIColor colorWithRed:0.18 green:0.55 blue:0.90 alpha:1.0];
    addPointBtn.layer.cornerRadius = 6.0;
    [addPointBtn setTitle:@"➕ Thêm Điểm" forState:UIControlStateNormal];
    [addPointBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    addPointBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [addPointBtn addTarget:self action:@selector(addNewTargetMarker) forControlEvents:UIControlEventTouchUpInside];
    [autoClickTabContainer addSubview:addPointBtn];

    // Nút 2: Xóa Điểm
    clearPointsBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearPointsBtn.frame = CGRectMake(112, 8, 96, 32);
    clearPointsBtn.backgroundColor = [UIColor colorWithRed:0.40 green:0.40 blue:0.48 alpha:1.0];
    clearPointsBtn.layer.cornerRadius = 6.0;
    [clearPointsBtn setTitle:@"🗑️ Xóa Hết" forState:UIControlStateNormal];
    [clearPointsBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    clearPointsBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [clearPointsBtn addTarget:self action:@selector(clearAllTargetMarkers) forControlEvents:UIControlEventTouchUpInside];
    [autoClickTabContainer addSubview:clearPointsBtn];

    // Nút 3: Ghi Lại Thao Tác (Macro)
    recordMacroBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    recordMacroBtn.frame = CGRectMake(214, 8, 96, 32);
    recordMacroBtn.backgroundColor = [UIColor colorWithRed:0.85 green:0.40 blue:0.10 alpha:1.0];
    recordMacroBtn.layer.cornerRadius = 6.0;
    [recordMacroBtn setTitle:@"⏺️ Ghi Thao Tác" forState:UIControlStateNormal];
    [recordMacroBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    recordMacroBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [recordMacroBtn addTarget:self action:@selector(toggleMacroRecording) forControlEvents:UIControlEventTouchUpInside];
    [autoClickTabContainer addSubview:recordMacroBtn];

    // Bảng trạng thái Auto Click
    UIView *statusBox = [[UIView alloc] initWithFrame:CGRectMake(10, 48, menuWidth - 20, 80)];
    statusBox.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.08 alpha:1.0];
    statusBox.layer.cornerRadius = 8.0;
    statusBox.layer.borderWidth = 1.0;
    statusBox.layer.borderColor = [UIColor colorWithRed:0.20 green:0.20 blue:0.28 alpha:1.0].CGColor;
    [autoClickTabContainer addSubview:statusBox];

    autoStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 6, menuWidth - 36, 68)];
    autoStatusLabel.numberOfLines = 0;
    autoStatusLabel.textColor = [UIColor colorWithRed:0.85 green:0.85 blue:0.90 alpha:1.0];
    autoStatusLabel.font = [UIFont systemFontOfSize:11];
    autoStatusLabel.text = @"🎯 Số điểm: 0\n⏱️ Chạm vào hình tròn để chỉnh giây\n🔄 Tự động lặp lại liên tục\n🛡️ An toàn: Không click trúng Menu";
    [statusBox addSubview:autoStatusLabel];

    // Nút Play / Stop ở đáy menu
    toggleAutoRunBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    toggleAutoRunBtn.frame = CGRectMake(12, 136, menuWidth - 24, 38);
    toggleAutoRunBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.65 blue:0.30 alpha:1.0];
    toggleAutoRunBtn.layer.cornerRadius = 8.0;
    [toggleAutoRunBtn setTitle:@"▶ BẮT ĐẦU" forState:UIControlStateNormal];
    toggleAutoRunBtn.setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    toggleAutoRunBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [toggleAutoRunBtn addTarget:self action:@selector(toggleAutoClickExecution) forControlEvents:UIControlEventTouchUpInside];
    [autoClickTabContainer addSubview:toggleAutoRunBtn];

    [targetWindow addSubview:menuContainer];

    // Khởi tạo các module mở rộng
    [self setupMiniBrowserInWindow:targetWindow];
    [self setupHistoryOverlayInWindow:targetWindow];
    [self setupDeviceLogsOverlayInWindow:targetWindow];

    [self updateLayoutForAdminState:NO];

    // Bắt sự kiện quay lại app để tự động lấy link
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        if (robloxWindow) {
            [robloxWindow bringSubviewToFront:floatingCircleBtn];
            [robloxWindow bringSubviewToFront:infoWidgetLabel];
            [robloxWindow bringSubviewToFront:menuContainer];
        }
        if (menuContainer && !menuContainer.hidden && !isAutoClickTabActive) {
            [self autoDetectClipboardLink];
        }
    }];
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
        menuContainer.frame = CGRectMake(menuContainer.frame.origin.x, menuContainer.frame.origin.y, 320.0, 225.0);
    } else {
        [tabSwitchBtn setTitle:@"🎯 Auto" forState:UIControlStateNormal];
        tabSwitchBtn.backgroundColor = [UIColor colorWithRed:0.22 green:0.55 blue:0.85 alpha:1.0];
        autoClickTabContainer.hidden = YES;
        bypassTabContainer.hidden = NO;
        [self updateLayoutForAdminState:isAdminMode];
        [self autoDetectClipboardLink];
    }
}

// ============================================================
// LOGIC AUTO CLICK: THÊM ĐIỂM, CHỈNH GIÂY & KÉO THẢ
// ============================================================
+ (void)addNewTargetMarker {
    [self triggerImpact:UIImpactFeedbackStyleMedium];
    NSInteger newIndex = targetMarkers.count + 1;

    CGFloat size = 38.0;
    CGFloat startX = 60.0 + (newIndex * 20.0);
    CGFloat startY = 220.0 + (newIndex * 15.0);
    if (startX > robloxWindow.bounds.size.width - 50) startX = 60.0;
    if (startY > robloxWindow.bounds.size.height - 100) startY = 220.0;

    UIView *mView = [[UIView alloc] initWithFrame:CGRectMake(startX, startY, size, size)];
    mView.backgroundColor = [UIColor colorWithRed:0.0 green:0.55 blue:1.0 alpha:0.75];
    mView.layer.cornerRadius = size / 2.0;
    mView.layer.borderWidth = 2.0;
    mView.layer.borderColor = [UIColor whiteColor].CGColor;
    mView.layer.shadowColor = [UIColor blackColor].CGColor;
    mView.layer.shadowOpacity = 0.5;
    mView.layer.shadowOffset = CGSizeMake(0, 2);
    mView.layer.shadowRadius = 3.0;
    mView.userInteractionEnabled = YES;

    // Số thứ tự ở giữa
    UILabel *numLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 2, size, 18)];
    numLbl.text = [NSString stringWithFormat:@"%ld", (long)newIndex];
    numLbl.textColor = [UIColor whiteColor];
    numLbl.font = [UIFont boldSystemFontOfSize:14];
    numLbl.textAlignment = NSTextAlignmentCenter;
    [mView addSubview:numLbl];

    // Nhãn thời gian chờ bên dưới
    UILabel *dlyLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 18, size, 16)];
    dlyLbl.text = @"0.5s";
    dlyLbl.textColor = [UIColor colorWithRed:1.0 green:0.9 blue:0.3 alpha:1.0];
    dlyLbl.font = [UIFont boldSystemFontOfSize:9];
    dlyLbl.textAlignment = NSTextAlignmentCenter;
    [mView addSubview:dlyLbl];

    AutoClickTarget *target = [[AutoClickTarget alloc] init];
    target.index = newIndex;
    target.markerView = mView;
    target.numberLabel = numLbl;
    target.delayLabel = dlyLbl;
    target.delaySeconds = 0.5;
    target.screenPoint = mView.center;

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragTargetMarker:)];
    [mView addGestureRecognizer:pan];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapTargetMarker:)];
    [mView addGestureRecognizer:tap];

    [robloxWindow addSubview:mView];
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
    if (!topVC) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"⏱️️ Cài Đặt Điểm #%ld", (long)target.index]
                                                                   message:@"Nhập thời gian chờ cho điểm này (giây):\n(Ví dụ: 0.1, 0.5, 1, 2...)"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = [NSString stringWithFormat:@"%.2f", target.delaySeconds];
        textField.keyboardType = UIKeyboardTypeDecimalPad;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Lưu" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *txt = alert.textFields.firstObject.text;
        CGFloat val = [txt floatValue];
        if (val < 0.02) val = 0.02;
        target.delaySeconds = val;
        target.delayLabel.text = [NSString stringWithFormat:@"%.1fs", val];
        [self triggerNotify:UINotificationFeedbackTypeSuccess];
        [self updateAutoStatusText];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [topVC presentViewController:alert animated:YES completion:nil];
}

+ (void)clearAllTargetMarkers {
    [self triggerImpact:UIImpactFeedbackStyleMedium];
    for (AutoClickTarget *t in targetMarkers) {
        [t.markerView removeFromSuperview];
    }
    [targetMarkers removeAllObjects];
    [self updateAutoStatusText];
}

+ (void)updateAutoStatusText {
    if (isRecordingMacro) {
        autoStatusLabel.text = [NSString stringWithFormat:@"🔴 ĐANG GHI THAO TÁC...\nĐã ghi: %lu bước chạm\nBấm [Lưu Ghi] để hoàn tất.", (unsigned long)recordedMacroSteps.count];
        autoStatusLabel.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0];
        return;
    }

    NSString *macroStatus = (recordedMacroSteps.count > 0) ? [NSString stringWithFormat:@"Đã có Macro (%lu bước)", (unsigned long)recordedMacroSteps.count] : @"Chưa có Macro";
    autoStatusLabel.text = [NSString stringWithFormat:@"🎯 Số điểm click: %lu\n📹 Macro: %@\n⚡ Trạng thái: %@\n🛡️ An toàn: Tự động tránh Menu",
                            (unsigned long)targetMarkers.count,
                            macroStatus,
                            isAutoRunning ? @"ĐANG CHẠY" : @"ĐANG DỪNG"];
    autoStatusLabel.textColor = isAutoRunning ? [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0] : [UIColor colorWithRed:0.85 green:0.85 blue:0.90 alpha:1.0];
}

// ============================================================
// GHI LẠI THAO TÁC (MACRO RECORDER)
// ============================================================
+ (void)toggleMacroRecording {
    [self triggerImpact:UIImpactFeedbackStyleHeavy];
    if (isAutoRunning) {
        [self stopAutoClick];
    }

    isRecordingMacro = !isRecordingMacro;

    if (isRecordingMacro) {
        [recordedMacroSteps removeAllObjects];
        recordStartTime = [NSDate timeIntervalSinceReferenceDate];
        [recordMacroBtn setTitle:@"⏹️ Lưu Ghi" forState:UIControlStateNormal];
        recordMacroBtn.backgroundColor = [UIColor colorWithRed:0.85 green:0.20 blue:0.20 alpha:1.0];

        if (!macroRecorderView) {
            macroRecorderView = [[MacroRecorderOverlayView alloc] initWithFrame:robloxWindow.bounds];
            macroRecorderView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.01];
            __weak typeof(self) weakSelf = self;
            macroRecorderView.onTouchEvent = ^(CGPoint pt, NSInteger phase) {
                [weakSelf recordTouchAtPoint:pt phase:phase];
            };
        }
        [robloxWindow addSubview:macroRecorderView];
        [robloxWindow bringSubviewToFront:menuContainer];
        [self updateAutoStatusText];
    } else {
        [recordMacroBtn setTitle:@"⏺️ Ghi Thao Tác" forState:UIControlStateNormal];
        recordMacroBtn.backgroundColor = [UIColor colorWithRed:0.85 green:0.40 blue:0.10 alpha:1.0];
        if (macroRecorderView) {
            [macroRecorderView removeFromSuperview];
        }
        [self triggerNotify:UINotificationFeedbackTypeSuccess];
        [self updateAutoStatusText];
    }
}

+ (void)recordTouchAtPoint:(CGPoint)pt phase:(NSInteger)phase {
    if (!isRecordingMacro) return;
    if (menuContainer && !menuContainer.hidden && CGRectContainsPoint(menuContainer.frame, pt)) {
        return;
    }

    NSTimeInterval current = [NSDate timeIntervalSinceReferenceDate];
    MacroTouchStep *step = [[MacroTouchStep alloc] init];
    step.point = pt;
    step.timeOffset = current - recordStartTime;
    step.phase = phase;
    [recordedMacroSteps addObject:step];

    [self simulateDirectTouchAtPoint:pt phase:(phase == 2 ? UITouchPhaseEnded : UITouchPhaseBegan)];
}

// ============================================================
// BẬT / TẮT THỰC THI AUTO CLICK & MACRO
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
        autoStatusLabel.text = @"⚠️ Hãy thêm ít nhất 1 điểm click hoặc ghi lại thao tác trước!";
        autoStatusLabel.textColor = [UIColor colorWithRed:1.0 green:0.8 blue:0.2 alpha:1.0];
        return;
    }

    isAutoRunning = YES;
    [toggleAutoRunBtn setTitle:@"⏹ DỪNG LẠI" forState:UIControlStateNormal];
    toggleAutoRunBtn.backgroundColor = [UIColor colorWithRed:0.85 green:0.20 blue:0.20 alpha:1.0];
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
    toggleAutoRunBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.65 blue:0.30 alpha:1.0];
    [self updateAutoStatusText];
}

// Vòng lặp các điểm đã đặt
+ (void)executeTargetMarkerLoop {
    if (!isAutoRunning || targetMarkers.count == 0) return;

    if (currentRunningTargetIdx >= targetMarkers.count) {
        currentRunningTargetIdx = 0;
    }

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

// Vòng lặp phát lại Macro đã ghi
+ (void)executeMacroLoopIndex:(NSInteger)idx {
    if (!isAutoRunning || recordedMacroSteps.count == 0) return;

    if (idx >= recordedMacroSteps.count) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self executeMacroLoopIndex:0];
        });
        return;
    }

    MacroTouchStep *currentStep = recordedMacroSteps[idx];
    [self simulateDirectTouchAtPoint:currentStep.point phase:(currentStep.phase == 2 ? UITouchPhaseEnded : UITouchPhaseBegan)];

    NSTimeInterval nextDelay = 0.05;
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
// CƠ CHẾ BẮN CẢM ỨNG ẢO VÀO GAME (SYNTHETIC TOUCH INJECTION)
// ============================================================
+ (void)simulateTapAtPoint:(CGPoint)screenPoint {
    [self simulateDirectTouchAtPoint:screenPoint phase:UITouchPhaseBegan];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.035 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self simulateDirectTouchAtPoint:screenPoint phase:UITouchPhaseEnded];
    });
}

+ (void)simulateDirectTouchAtPoint:(CGPoint)screenPoint phase:(UITouchPhase)phase {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (AutoClickTarget *t in targetMarkers) t.markerView.userInteractionEnabled = NO;

        UIView *hit = [robloxWindow hitTest:screenPoint withEvent:nil];

        for (AutoClickTarget *t in targetMarkers) t.markerView.userInteractionEnabled = YES;

        if (!hit || hit == menuContainer || [hit isDescendantOfView:menuContainer] || hit == floatingCircleBtn) {
            return;
        }

        CGPoint local = [hit convertPoint:screenPoint fromView:robloxWindow];
        UITouch *touch = [[NSClassFromString(@"UITouch") alloc] init];

        Ivar ivarLoc = class_getInstanceVariable([UITouch class], "_locationInWindow");
        if (ivarLoc) {
            ptrdiff_t offset = ivar_getOffset(ivarLoc);
            *(CGPoint *)((uintptr_t)(__bridge void *)touch + offset) = local;
        }

        Ivar ivarPhase = class_getInstanceVariable([UITouch class], "_phase");
        if (ivarPhase) {
            ptrdiff_t offset = ivar_getOffset(ivarPhase);
            *(NSInteger *)((uintptr_t)(__bridge void *)touch + offset) = phase;
        }

        Ivar ivarView = class_getInstanceVariable([UITouch class], "_view");
        if (ivarView) object_setIvar(touch, ivarView, hit);

        Ivar ivarWin = class_getInstanceVariable([UITouch class], "_window");
        if (ivarWin) object_setIvar(touch, ivarWin, robloxWindow);

        NSSet *touchSet = [NSSet setWithObject:touch];

        if (phase == UITouchPhaseBegan) {
            if ([hit respondsToSelector:@selector(touchesBegan:withEvent:)]) {
                [hit touchesBegan:touchSet withEvent:nil];
            }
        } else if (phase == UITouchPhaseEnded) {
            if ([hit respondsToSelector:@selector(touchesEnded:withEvent:)]) {
                [hit touchesEnded:touchSet withEvent:nil];
            }
        }
    });
}

// ============================================================
// ĐIỀU CHỈNH LAYOUT GIỮA CHẾ ĐỘ KHÁCH VÀ ADMIN (TAB BYPASS)
// ============================================================
+ (void)updateLayoutForAdminState:(BOOL)admin {
    CGFloat menuWidth = 320.0;
    if (admin) {
        apiKeyInput.hidden = NO;
        keyActionContainer.hidden = NO;
        linkInput.frame = CGRectMake(12, 68, menuWidth - 24, 32);
        bypassBtn.frame = CGRectMake(12, 106, (menuWidth - 30) / 2, 34);
        copyBtn.frame = CGRectMake(CGRectGetMaxX(bypassBtn.frame) + 6, 106, (menuWidth - 30) / 2, 34);
        resultBox.frame = CGRectMake(12, 148, menuWidth - 24, 102);
        resultDisplay.frame = CGRectMake(6, 4, menuWidth - 36, 94);
        bypassTabContainer.frame = CGRectMake(0, 38, menuWidth, 262.0);
        if (!isAutoClickTabActive) menuContainer.frame = CGRectMake(menuContainer.frame.origin.x, menuContainer.frame.origin.y, menuWidth, 300.0);

        baconWebBtn.hidden = NO;
        googleWebBtn.frame = CGRectMake(139, 6, 74, 26);
    } else {
        apiKeyInput.hidden = YES;
        keyActionContainer.hidden = YES;
        linkInput.frame = CGRectMake(12, 8, menuWidth - 24, 32);
        bypassBtn.frame = CGRectMake(12, 48, (menuWidth - 30) / 2, 34);
        copyBtn.frame = CGRectMake(CGRectGetMaxX(bypassBtn.frame) + 6, 48, (menuWidth - 30) / 2, 34);
        resultBox.frame = CGRectMake(12, 90, menuWidth - 24, 95);
        resultDisplay.frame = CGRectMake(6, 4, menuWidth - 36, 87);
        bypassTabContainer.frame = CGRectMake(0, 38, menuWidth, 197.0);
        if (!isAutoClickTabActive) menuContainer.frame = CGRectMake(menuContainer.frame.origin.x, menuContainer.frame.origin.y, menuWidth, 235.0);

        baconWebBtn.hidden = YES;
        googleWebBtn.frame = CGRectMake(60, 6, 90, 26);
    }
}

// ============================================================
// CỬ CHỈ BÍ MẬT & HỘP THOẠI XÁC NHẬN PIN (151009)
// ============================================================
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

// ============================================================
// BẢNG QUẢN LÝ THIẾT BỊ ĐÃ DÙNG DYLIB (DEVICE LOGS)
// ============================================================
+ (void)setupDeviceLogsOverlayInWindow:(UIWindow *)window {
    CGFloat dWidth = 320.0;
    CGFloat dHeight = 280.0;
    deviceLogsContainer = [[UIView alloc] initWithFrame:CGRectMake((window.bounds.size.width - dWidth)/2, 130, dWidth, dHeight)];
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
    dTitle.text = @"👥 Thiết Bị Đã Dùng Dylib";
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
        [robloxWindow bringSubviewToFront:deviceLogsContainer];
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
                UIView *card = [[UIView alloc] initWithFrame:CGRectMake(10, y, rowWidth, 46)];
                card.backgroundColor = [UIColor colorWithRed:0.14 green:0.12 blue:0.18 alpha:1.0];
                card.layer.cornerRadius = 6.0;

                UILabel *nameLbl = [[UILabel alloc] initWithFrame:CGRectMake(8, 4, rowWidth - 16, 18)];
                nameLbl.text = [NSString stringWithFormat:@"📱 %@ (%@)", dev[@"model"] ?: @"iPhone", dev[@"ios"] ?: @"iOS"];
                nameLbl.textColor = [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
                nameLbl.font = [UIFont boldSystemFontOfSize:11];
                [card addSubview:nameLbl];

                UILabel *subLbl = [[UILabel alloc] initWithFrame:CGRectMake(8, 22, rowWidth - 16, 18)];
                subLbl.text = [NSString stringWithFormat:@"ID: %@ • Lúc: %@", dev[@"id"] ?: @"-", dev[@"last_seen"] ?: @"-"];
                subLbl.textColor = [UIColor colorWithRed:0.7 green:0.7 blue:0.8 alpha:1.0];
                subLbl.font = [UIFont systemFontOfSize:10];
                [card addSubview:subLbl];

                [deviceLogsScrollView addSubview:card];
                y += 52.0;
            }
            deviceLogsScrollView.contentSize = CGSizeMake(deviceLogsContainer.bounds.size.width, y);
        });
    }] resume];
}

// ============================================================
// TRÌNH DUYỆT MINI IN-APP
// ============================================================
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
        [robloxWindow bringSubviewToFront:miniBrowserContainer];
        if (!miniWebView.URL) {
            [self openGoogle];
        }
    }
}

+ (void)reloadBrowser {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    [miniWebView reload];
}

// ============================================================
// BẢNG LỊCH SỬ LINK (HISTORY LOG)
// ============================================================
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
        [robloxWindow bringSubviewToFront:historyContainer];
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

// ============================================================
// QUẢN LÝ MENU CHÍNH
// ============================================================
+ (void)openMenu {
    [self triggerImpact:UIImpactFeedbackStyleMedium];
    menuContainer.hidden = NO;
    floatingCircleBtn.hidden = YES;
    infoWidgetLabel.hidden = YES;
    [robloxWindow bringSubviewToFront:menuContainer];

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
    infoWidgetLabel.hidden = NO;
    [self syncWidgetPosition];
    [robloxWindow bringSubviewToFront:floatingCircleBtn];
    [robloxWindow bringSubviewToFront:infoWidgetLabel];
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

// ============================================================
// KÉO THẢ GIAO DIỆN
// ============================================================
+ (void)handleDragCircle:(UIPanGestureRecognizer *)g {
    CGPoint trans = [g translationInView:floatingCircleBtn.superview];
    floatingCircleBtn.center = CGPointMake(floatingCircleBtn.center.x + trans.x, floatingCircleBtn.center.y + trans.y);
    [self syncWidgetPosition];
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
