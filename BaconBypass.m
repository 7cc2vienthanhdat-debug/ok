#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import <sys/utsname.h>
#import <mach/mach.h>

@interface BaconBypassOverlay : NSObject <WKNavigationDelegate>
+ (void)load;
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

// Menu chính
static UIView *menuContainer = nil;
static UIVisualEffectView *menuBlurView = nil;
static UIView *menuDashboardBar = nil;
static UILabel *hudInfoLabel = nil;

// Web & Lịch sử & Logs
static WKWebView *miniWebView = nil;
static UIView *miniBrowserContainer = nil;
static UIView *historyContainer = nil;
static UIScrollView *historyScrollView = nil;
static UIView *deviceLogsContainer = nil;
static UIScrollView *deviceLogsScrollView = nil;

// --- Form Controls Bypass ---
static UIView *bypassTabContainer = nil;
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
// BẮT LINK TỰ ĐỘNG TỪ BỘ NHỚ TẠM
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
// ĐO RAM & NHIỆT ĐỘ
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
// THÔNG TIN THIẾT BỊ VÀ TELEMETRY CLOUDFLARE
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
            @"iPhone13,2" : @"iPhone 12", @"iPhone13,3" : @"iPhone 12 Pro", @"iPhone13,4" : @"iPhone 12 Pro Max",
            @"iPhone14,5" : @"iPhone 13", @"iPhone14,2" : @"iPhone 13 Pro", @"iPhone14,3" : @"iPhone 13 Pro Max",
            @"iPhone14,7" : @"iPhone 14", @"iPhone15,2" : @"iPhone 14 Pro", @"iPhone15,3" : @"iPhone 14 Pro Max",
            @"iPhone15,4" : @"iPhone 15", @"iPhone16,1" : @"iPhone 15 Pro", @"iPhone16,2" : @"iPhone 15 Pro Max",
            @"iPhone17,3" : @"iPhone 16", @"iPhone17,1" : @"iPhone 16 Pro", @"iPhone17,2" : @"iPhone 16 Pro Max"
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

    hudInfoLabel.text = [NSString stringWithFormat:@"⏱ %@   |   🔋 %d%%   |   ⚡ %ld FPS   |   💾 %ld MB   |   %@",
                            timeStr, batPct, (long)currentFPS, currentAppRamMB, currentThermalStatus];
}

// ============================================================
// HÀM TẠO NÚT BẤM (GLASSMORPHISM STYLE)
// ============================================================
+ (UIButton *)createGlassButtonWithFrame:(CGRect)frame title:(NSString *)title color:(UIColor *)color {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = frame;
    btn.backgroundColor = [color colorWithAlphaComponent:0.25];
    btn.layer.cornerRadius = 10.0;
    btn.layer.borderWidth = 1.0;
    btn.layer.borderColor = [color colorWithAlphaComponent:0.6].CGColor;
    
    // Smooth corners iOS 13+
    if (@available(iOS 13.0, *)) { btn.layer.cornerCurve = kCACornerCurveContinuous; }
    
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    return btn;
}

// ============================================================
// THIẾT KẾ GIAO DIỆN (UI LIQUID GLASS IOS 16+)
// ============================================================
+ (void)setupViewsInWindow:(UIWindow *)targetWindow {
    // 1. NÚT TRÒN NỔI RGB
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
    floatingCircleBtn.layer.shadowColor = [UIColor blackColor].CGColor;
    floatingCircleBtn.layer.shadowOffset = CGSizeMake(0, 4);
    floatingCircleBtn.layer.shadowOpacity = 0.5;
    floatingCircleBtn.layer.shadowRadius = 6.0;
    
    UILabel *iconLbl = [[UILabel alloc] initWithFrame:floatingCircleBtn.bounds];
    iconLbl.text = @"⚡";
    iconLbl.font = [UIFont systemFontOfSize:18];
    iconLbl.textAlignment = NSTextAlignmentCenter;
    [floatingCircleBtn addSubview:iconLbl];

    [floatingCircleBtn addTarget:self action:@selector(openMenu) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *panBtn = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragCircle:)];
    [floatingCircleBtn addGestureRecognizer:panBtn];
    [targetWindow addSubview:floatingCircleBtn];

    // 2. KHUNG MENU CHÍNH (LIQUID GLASS)
    CGFloat menuWidth = 340.0;
    CGFloat menuHeight = 250.0; // Thu gọn vì đã xóa tab Auto Click
    menuContainer = [[UIView alloc] initWithFrame:CGRectMake((targetWindow.bounds.size.width - menuWidth) / 2, 80, menuWidth, menuHeight)];
    menuContainer.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.15]; // Trong suốt cao
    menuContainer.layer.cornerRadius = 24.0;
    menuContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    menuContainer.layer.shadowOffset = CGSizeMake(0, 10);
    menuContainer.layer.shadowOpacity = 0.4;
    menuContainer.layer.shadowRadius = 15.0;
    
    if (@available(iOS 13.0, *)) { menuContainer.layer.cornerCurve = kCACornerCurveContinuous; }
    menuContainer.hidden = YES;

    // Lớp Blur Thủy Tinh
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    menuBlurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    menuBlurView.frame = menuContainer.bounds;
    menuBlurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    menuBlurView.layer.cornerRadius = 24.0;
    menuBlurView.clipsToBounds = YES;
    [menuContainer addSubview:menuBlurView];
    
    // Viền sáng bóng nhẹ (Glass reflection)
    UIView *borderOverlay = [[UIView alloc] initWithFrame:menuContainer.bounds];
    borderOverlay.layer.cornerRadius = 24.0;
    borderOverlay.layer.borderWidth = 1.0;
    borderOverlay.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
    borderOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    borderOverlay.userInteractionEnabled = NO;
    if (@available(iOS 13.0, *)) { borderOverlay.layer.cornerCurve = kCACornerCurveContinuous; }
    [menuContainer addSubview:borderOverlay];

    UIPanGestureRecognizer *panMenu = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragMenu:)];
    [menuContainer addGestureRecognizer:panMenu];

    // HEADER KHÔNG NỀN
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, menuWidth, 46)];
    [menuContainer addSubview:header];

    // TIÊU ĐỀ
    UILabel *headerTitle = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, 85, 46)];
    headerTitle.text = @"⚡ T_Dat";
    headerTitle.textColor = [UIColor colorWithRed:1.00 green:0.85 blue:0.20 alpha:1.0];
    headerTitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightHeavy];
    headerTitle.userInteractionEnabled = YES;

    UITapGestureRecognizer *adminTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleAdminSecretTap)];
    adminTap.numberOfTapsRequired = 5;
    [headerTitle addGestureRecognizer:adminTap];
    [header addSubview:headerTitle];

    // CÁC NÚT ĐIỀU HƯỚNG BÊN PHẢI (Glass Style)
    UIButton *webBtn = [self createGlassButtonWithFrame:CGRectMake(175, 10, 56, 28) title:@"🌐 Web" color:[UIColor colorWithRed:0.2 green:0.5 blue:1.0 alpha:1.0]];
    [webBtn addTarget:self action:@selector(toggleMiniBrowser) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:webBtn];

    UIButton *histBtn = [self createGlassButtonWithFrame:CGRectMake(240, 10, 36, 28) title:@"📜" color:[UIColor colorWithRed:0.6 green:0.4 blue:0.8 alpha:1.0]];
    [histBtn addTarget:self action:@selector(toggleHistory) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:histBtn];

    UIButton *closeBtn = [self createGlassButtonWithFrame:CGRectMake(285, 10, 36, 28) title:@"✕" color:[UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0]];
    [closeBtn addTarget:self action:@selector(minimizeMenu) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];

    // ĐƯỜNG PHÂN CÁCH NGANG (Seperator)
    UIView *sep1 = [[UIView alloc] initWithFrame:CGRectMake(16, 46, menuWidth - 32, 1)];
    sep1.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    [menuContainer addSubview:sep1];

    // HUD (Dashboard Thanh thông tin phần cứng nằm trong menu)
    menuDashboardBar = [[UIView alloc] initWithFrame:CGRectMake(16, 50, menuWidth - 32, 24)];
    menuDashboardBar.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.2];
    menuDashboardBar.layer.cornerRadius = 6.0;
    [menuContainer addSubview:menuDashboardBar];

    hudInfoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, menuWidth - 32, 24)];
    hudInfoLabel.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    hudInfoLabel.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightMedium];
    hudInfoLabel.textAlignment = NSTextAlignmentCenter;
    [menuDashboardBar addSubview:hudInfoLabel];

    // ==========================================
    // KHUNG BYPASS CHÍNH
    // ==========================================
    CGFloat bodyY = 82; 
    bypassTabContainer = [[UIView alloc] initWithFrame:CGRectMake(0, bodyY, menuWidth, menuHeight - bodyY)];
    [menuContainer addSubview:bypassTabContainer];

    // 1. Ô NHẬP API KEY (Chỉ hiện khi là Admin)
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
    [apiKeyInput addTarget:self action:@selector(onApiKeyEditingChanged) forControlEvents:UIControlEventEditingChanged];
    [apiKeyInput addTarget:self action:@selector(onApiKeyEditingBegan) forControlEvents:UIControlEventEditingDidBegin];
    [bypassTabContainer addSubview:apiKeyInput];

    // 2. KHUNG NÚT ADMIN
    keyActionContainer = [[UIView alloc] initWithFrame:CGRectMake(16, 44, menuWidth - 32, 30)];
    keyActionContainer.backgroundColor = [UIColor clearColor];
    keyActionContainer.hidden = YES;

    UIButton *saveKeyBtn = [self createGlassButtonWithFrame:CGRectMake(0, 0, 72, 30) title:@"💾 Lưu" color:[UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0]];
    [saveKeyBtn addTarget:self action:@selector(onConfirmSaveKey) forControlEvents:UIControlEventTouchUpInside];
    [keyActionContainer addSubview:saveKeyBtn];

    viewDevicesBtn = [self createGlassButtonWithFrame:CGRectMake(78, 0, 90, 30) title:@"👥 Thiết Bị" color:[UIColor colorWithRed:0.7 green:0.3 blue:0.9 alpha:1.0]];
    [viewDevicesBtn addTarget:self action:@selector(toggleDeviceLogs) forControlEvents:UIControlEventTouchUpInside];
    [keyActionContainer addSubview:viewDevicesBtn];

    killswitchBtn = [self createGlassButtonWithFrame:CGRectMake(174, 0, 76, 30) title:@"🚨 Khóa" color:[UIColor colorWithRed:1.0 green:0.4 blue:0.2 alpha:1.0]];
    [killswitchBtn addTarget:self action:@selector(handleToggleKillswitchRemote) forControlEvents:UIControlEventTouchUpInside];
    [keyActionContainer addSubview:killswitchBtn];

    UIButton *discardKeyBtn = [self createGlassButtonWithFrame:CGRectMake(256, 0, keyActionContainer.bounds.size.width - 256, 30) title:@"✕" color:[UIColor colorWithWhite:0.6 alpha:1.0]];
    [discardKeyBtn addTarget:self action:@selector(onDiscardKey) forControlEvents:UIControlEventTouchUpInside];
    [keyActionContainer addSubview:discardKeyBtn];
    [bypassTabContainer addSubview:keyActionContainer];

    // 3. Ô NHẬP LINK BYPASS
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

    // 4. HAI NÚT HÀNH ĐỘNG LỚN
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

    // 5. KHUNG HIỂN THỊ KẾT QUẢ
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

    [targetWindow addSubview:menuContainer];

    // Khởi tạo MiniBrowser, History, Logs (giao diện ẩn)
    [self setupMiniBrowserInWindow:targetWindow];
    [self setupHistoryOverlayInWindow:targetWindow];
    [self setupDeviceLogsOverlayInWindow:targetWindow];

    [self updateLayoutForAdminState:NO];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        if (robloxWindow) {
            [robloxWindow bringSubviewToFront:floatingCircleBtn];
            [robloxWindow bringSubviewToFront:menuContainer];
        }
        if (menuContainer && !menuContainer.hidden) {
            [self autoDetectClipboardLink];
        }
    }];
}

// ============================================================
// HỆ THỐNG GIAO DIỆN (UI) ADMIN & UPDATE LAYOUT
// ============================================================
+ (void)updateLayoutForAdminState:(BOOL)admin {
    CGFloat menuWidth = 340.0;
    if (admin) {
        apiKeyInput.hidden = NO;
        keyActionContainer.hidden = NO;
        linkInput.frame = CGRectMake(16, 82, menuWidth - 32, 40);
        bypassBtn.frame = CGRectMake(16, 130, (menuWidth - 40) / 2, 42);
        copyBtn.frame = CGRectMake(CGRectGetMaxX(bypassBtn.frame) + 8, 130, (menuWidth - 40) / 2, 42);
        resultBox.frame = CGRectMake(16, 182, menuWidth - 32, 50);
        
        menuContainer.frame = CGRectMake(menuContainer.frame.origin.x, menuContainer.frame.origin.y, menuWidth, 325.0);
        baconWebBtn.hidden = NO;
        googleWebBtn.frame = CGRectMake(175, 8, 50, 26);
    } else {
        apiKeyInput.hidden = YES;
        keyActionContainer.hidden = YES;
        linkInput.frame = CGRectMake(16, 8, menuWidth - 32, 40);
        bypassBtn.frame = CGRectMake(16, 56, (menuWidth - 40) / 2, 42);
        copyBtn.frame = CGRectMake(CGRectGetMaxX(bypassBtn.frame) + 8, 56, (menuWidth - 40) / 2, 42);
        resultBox.frame = CGRectMake(16, 108, menuWidth - 32, 50);
        
        menuContainer.frame = CGRectMake(menuContainer.frame.origin.x, menuContainer.frame.origin.y, menuWidth, 250.0);
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
            resultDisplay.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
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

// ============================================================
// BẢNG THIẾT BỊ LOGS
// ============================================================
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
                                                                   message:[NSString stringWithFormat:@"Nhập tên cho máy (ID: %@):", devID]
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Ví dụ: Máy phụ của Đạt...";
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Lưu" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
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
    if (@available(iOS 10.0, *)) { config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone; }

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
        if (!miniWebView.URL) [self openGoogle];
    }
}

+ (void)reloadBrowser {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    [miniWebView reload];
}

// ============================================================
// BẢNG LỊCH SỬ LINK
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
// XỬ LÝ SỰ KIỆN MENU
// ============================================================
+ (void)openMenu {
    [self triggerImpact:UIImpactFeedbackStyleMedium];
    menuContainer.hidden = NO;
    floatingCircleBtn.hidden = YES;
    [robloxWindow bringSubviewToFront:menuContainer];
    [self autoDetectClipboardLink];
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
    [robloxWindow bringSubviewToFront:floatingCircleBtn];
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
