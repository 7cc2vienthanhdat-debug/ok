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
static UILabel *hudInfoLabel = nil; // Thay thế cho infoWidgetLabel ngoài màn hình
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
static NSString *extractedLink = nil;

// --- Chức Năng Ẩn Stream Thông Minh ---
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

// Các Gesture để ghi âm ngầm (Không làm đơ app)
static UILongPressGestureRecognizer *macroTapRecorder = nil;
static UIPanGestureRecognizer *macroPanRecorder = nil;

// --- Trạng thái Admin & Killswitch ---
static BOOL isAdminMode = NO;
static BOOL isServerKillswitchActive = NO;

// --- Performance, RAM, Nhiệt Độ & RGB Engine ---
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
// KHỞI CHẠY HỆ THỐNG
// ============================================================
+ (void)load {
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    targetMarkers = [NSMutableArray array];
    recordedMacroSteps = [NSMutableArray array];
    
    // Theo dõi trạng thái Quay màn hình của iOS
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
    [self setupViewsInWindow:robloxWindow];
    [self startDisplayLoop];
}

// ============================================================
// CƠ CHẾ ẨN STREAM THÔNG MINH (AUTO-HIDE ON RECORD)
// ============================================================
+ (void)handleScreenCaptureStateChange {
    if (!isStreamHiddenMode) return;
    
    BOOL isCaptured = [UIScreen mainScreen].isCaptured;
    if (isCaptured) {
        // Tàng hình toàn bộ UI khi đang quay
        menuContainer.alpha = 0.0;
        floatingCircleBtn.alpha = 0.0;
        for (AutoClickTarget *t in targetMarkers) t.markerView.alpha = 0.0;
    } else {
        // Hiện lại khi tắt quay
        menuContainer.alpha = 1.0;
        floatingCircleBtn.alpha = 1.0;
        for (AutoClickTarget *t in targetMarkers) t.markerView.alpha = 1.0;
    }
}

+ (void)toggleStreamHideMode {
    [self triggerImpact:UIImpactFeedbackStyleHeavy];
    isStreamHiddenMode = !isStreamHiddenMode;

    if (isStreamHiddenMode) {
        [streamHideBtn setTitle:@"🛡️ Stream: TỰ ẨN" forState:UIControlStateNormal];
        streamHideBtn.backgroundColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.25 alpha:1.0];
        [self triggerNotify:UINotificationFeedbackTypeSuccess];
        resultDisplay.text = @"🛡️ Đã bật Ẩn Stream! Khi phát hiện quay màn hình, toàn bộ Menu sẽ tự tàng hình.";
        resultDisplay.textColor = [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
        [self handleScreenCaptureStateChange]; // Kích hoạt ngay nếu đang quay
    } else {
        [streamHideBtn setTitle:@"👁️ Stream: HIỆN" forState:UIControlStateNormal];
        streamHideBtn.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.35 alpha:1.0];
        [self triggerNotify:UINotificationFeedbackTypeWarning];
        resultDisplay.text = @"👁️ Đã tắt Ẩn Stream. Menu sẽ hiển thị trên video/livestream.";
        resultDisplay.textColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0];
        
        // Trả lại độ hiển thị
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
    // 1. Nút tròn nổi RGB
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

    // 2. Khung Menu Chính (Glassmorphism)
    CGFloat menuWidth = 340.0;
    CGFloat menuHeight = 285.0;
    menuContainer = [[UIView alloc] initWithFrame:CGRectMake((targetWindow.bounds.size.width - menuWidth) / 2, 80, menuWidth, menuHeight)];
    menuContainer.backgroundColor = [UIColor clearColor];
    menuContainer.layer.cornerRadius = 16.0;
    menuContainer.clipsToBounds = YES;
    menuContainer.hidden = YES;

    // Lớp Blur Kính mờ cực đẹp
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *menuBlurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    menuBlurView.frame = menuContainer.bounds;
    menuBlurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [menuContainer addSubview:menuBlurView];
    
    // Viền sáng nhẹ
    UIView *borderOverlay = [[UIView alloc] initWithFrame:menuContainer.bounds];
    borderOverlay.layer.cornerRadius = 16.0;
    borderOverlay.layer.borderWidth = 1.0;
    borderOverlay.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.15].CGColor;
    borderOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [menuContainer addSubview:borderOverlay];

    UIPanGestureRecognizer *panMenu = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragMenu:)];
    [menuContainer addGestureRecognizer:panMenu];

    // Header Menu
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, menuWidth, 42)];
    header.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    [menuContainer addSubview:header];

    // TIÊU ĐỀ
    UILabel *headerTitle = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, 85, 42)];
    headerTitle.text = @"⚡ T_Dat";
    headerTitle.textColor = [UIColor colorWithRed:1.00 green:0.80 blue:0.10 alpha:1.0];
    headerTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightHeavy];
    headerTitle.userInteractionEnabled = YES;

    UITapGestureRecognizer *adminTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleAdminSecretTap)];
    adminTap.numberOfTapsRequired = 5;
    [headerTitle addGestureRecognizer:adminTap];
    [header addSubview:headerTitle];

    // Tab Buttons
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

    // HUD (Dashboard Thanh thông tin phần cứng nằm trong menu)
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
    [bypassTabContainer addSubview:apiKeyInput];

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

    // Khởi tạo các module mở rộng
    [self setupMiniBrowserInWindow:targetWindow];
    [self setupHistoryOverlayInWindow:targetWindow];

    [self updateLayoutForAdminState:NO];
}

+ (void)onAlphaSliderChanged:(UISlider *)slider {
    menuContainer.alpha = slider.value;
}

// ============================================================
// CHUYỂN ĐỔI TAB
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
// LOGIC AUTO CLICK (Đã Fix độ nhạy & lỗi kẹt giữ)
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

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"⏱ Cài Đặt Điểm #%ld", (long)target.index]
                                                                   message:@"Nhập delay (giây) tối thiểu 0.05s:"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = [NSString stringWithFormat:@"%.2f", target.delaySeconds];
        textField.keyboardType = UIKeyboardTypeDecimalPad;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Lưu" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        CGFloat val = [alert.textFields.firstObject.text floatValue];
        if (val < 0.05) val = 0.05; // Đảm bảo đủ delay để chạm và thả ra
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
// GHI LẠI THAO TÁC (MACRO RECORDER) - ĐÃ FIX KHÔNG LÀM ĐƠ APP
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

        // Lắng nghe Touch bằng Gesture ngầm (Không chặn cảm ứng của game)
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
    // Chống chạm nhầm menu
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
    toggleAutoRunBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.75 infractions:0.35 alpha:1.0];
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
// BẮN CẢM ỨNG VÀO GAME (ĐÃ SỬA LỖI GIỮ CHUỘT)
// ============================================================
+ (void)simulateTapAtPoint:(CGPoint)screenPoint {
    // Chạm xuống
    [self simulateDirectTouchAtPoint:screenPoint phase:UITouchPhaseBegan];
    
    // Nhấc lên ngay sau 15ms (Cực ngắn để nhận diện là Tap)
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
// HỆ THỐNG BYPASS VÀ CÁC CHỨC NĂNG KHÁC (GIỮ NGUYÊN)
// ============================================================
// (Phần này chứa các hàm openMenu, toggleDeviceLogs, Cloudflare... đã hoàn thiện từ trước)

+ (void)updateLayoutForAdminState:(BOOL)admin {
    // ... [GIỮ NGUYÊN NHƯ CODE TRƯỚC ĐÓ]
}
+ (void)handleAdminSecretTap { /* GIỮ NGUYÊN */ }
+ (void)sendDeviceTelemetry { /* GIỮ NGUYÊN */ }
+ (void)setupDeviceLogsOverlayInWindow:(UIWindow *)window { /* GIỮ NGUYÊN */ }
+ (void)toggleDeviceLogs { /* GIỮ NGUYÊN */ }
+ (void)fetchDeviceLogsFromServer { /* GIỮ NGUYÊN */ }
+ (void)setupMiniBrowserInWindow:(UIWindow *)window { /* GIỮ NGUYÊN */ }
+ (void)openGoogle { /* GIỮ NGUYÊN */ }
+ (void)openBaconSite { /* GIỮ NGUYÊN */ }
+ (void)toggleMiniBrowser { /* GIỮ NGUYÊN */ }
+ (void)reloadBrowser { /* GIỮ NGUYÊN */ }
+ (void)setupHistoryOverlayInWindow:(UIWindow *)window { /* GIỮ NGUYÊN */ }
+ (void)saveLinkToHistory:(NSString *)link { /* GIỮ NGUYÊN */ }
+ (void)toggleHistory { /* GIỮ NGUYÊN */ }
+ (void)reloadHistoryList { /* GIỮ NGUYÊN */ }
+ (void)copyHistoryItem:(UIButton *)sender { /* GIỮ NGUYÊN */ }
+ (void)openMenu {
    [self triggerImpact:UIImpactFeedbackStyleMedium];
    menuContainer.hidden = NO;
    floatingCircleBtn.hidden = YES;
    [robloxWindow bringSubviewToFront:menuContainer];
    if (!isAutoClickTabActive) [self autoDetectClipboardLink];
}
+ (void)minimizeMenu {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    [linkInput resignFirstResponder];
    [apiKeyInput resignFirstResponder];
    menuContainer.hidden = YES;
    miniBrowserContainer.hidden = YES;
    historyContainer.hidden = YES;
    floatingCircleBtn.hidden = NO;
    [robloxWindow bringSubviewToFront:floatingCircleBtn];
}
+ (NSString *)cleanString:(NSString *)str {
    if (!str) return @"";
    NSString *c = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    c = [c stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    return [c stringByReplacingOccurrencesOfString:@"'" withString:@""];
}
+ (void)onApiKeyEditingBegan { keyActionContainer.hidden = NO; }
+ (void)onApiKeyEditingChanged { keyActionContainer.hidden = NO; }
+ (void)onConfirmSaveKey { /* GIỮ NGUYÊN */ }
+ (void)onDiscardKey { /* GIỮ NGUYÊN */ }
+ (void)handleBypass { /* GIỮ NGUYÊN */ }
+ (void)handleCopy { /* GIỮ NGUYÊN */ }
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

@end
