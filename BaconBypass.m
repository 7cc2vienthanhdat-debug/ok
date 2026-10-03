#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface BaconBypassOverlay : NSObject <WKNavigationDelegate>
+ (void)load;
@end

@implementation BaconBypassOverlay

// --- CẤU HÌNH ADMIN & API KEY MẶC ĐỊNH ---
#define ADMIN_PIN @"151009"
#define DEFAULT_API_KEY @"Bacon-68e61ca9d455d316a50c-b4328879cadc0a77f8a5"
#define STORAGE_KEY @"BaconBypass_CustomAPIKey"
#define HISTORY_KEY @"BaconBypass_HistoryLinks"

// --- UI Components ---
static UIWindow *robloxWindow = nil;
static UIButton *floatingCircleBtn = nil;
static UILabel *infoWidgetLabel = nil;
static UIView *menuContainer = nil;
static UIView *miniBrowserContainer = nil;
static WKWebView *miniWebView = nil;
static UIView *historyContainer = nil;
static UIScrollView *historyScrollView = nil;

// --- Form Controls & Buttons ---
static UITextField *apiKeyInput = nil;
static UIView *keyActionContainer = nil;
static UITextField *linkInput = nil;
static UIButton *bypassBtn = nil;
static UIButton *copyBtn = nil;
static UIView *resultBox = nil;
static UITextView *resultDisplay = nil;
static UIButton *baconWebBtn = nil;
static UIButton *googleWebBtn = nil;
static NSString *extractedLink = nil;

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
// KHỞI CHẠY OVERLAY
// ============================================================
+ (void)load {
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self tryInjectOverlay];
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
// KHỞI TẠO CÁC GIAO DIỆN
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

    // 3. Khung Menu Chính (Mặc định ở chế độ Khách: gọn gàng 235px)
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

    UILabel *headerTitle = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, 120, 38)];
    headerTitle.text = @"⚡ BACON PRO";
    headerTitle.textColor = [UIColor colorWithRed:1.00 green:0.67 blue:0.00 alpha:1.0];
    headerTitle.font = [UIFont boldSystemFontOfSize:13];
    headerTitle.userInteractionEnabled = YES;

    // CỬ CHỈ BÍ MẬT: BẤM 5 LẦN ĐỂ MỞ / KHÓA ADMIN
    UITapGestureRecognizer *adminTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleAdminSecretTap)];
    adminTapGesture.numberOfTapsRequired = 5;
    [headerTitle addGestureRecognizer:adminTapGesture];
    [header addSubview:headerTitle];

    // Nút mở Web In-App
    UIButton *webBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    webBtn.frame = CGRectMake(menuWidth - 145, 6, 48, 26);
    webBtn.backgroundColor = [UIColor colorWithRed:0.20 green:0.40 blue:0.75 alpha:1.0];
    webBtn.layer.cornerRadius = 6.0;
    [webBtn setTitle:@"🌐 Web" forState:UIControlStateNormal];
    [webBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    webBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [webBtn addTarget:self action:@selector(toggleMiniBrowser) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:webBtn];

    // Nút mở Lịch Sử
    UIButton *histBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    histBtn.frame = CGRectMake(menuWidth - 92, 6, 32, 26);
    histBtn.backgroundColor = [UIColor colorWithRed:0.30 green:0.30 blue:0.40 alpha:1.0];
    histBtn.layer.cornerRadius = 6.0;
    [histBtn setTitle:@"📜" forState:UIControlStateNormal];
    [histBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    histBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    [histBtn addTarget:self action:@selector(toggleHistory) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:histBtn];

    // Nút Thu nhỏ (−)
    UIButton *minBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    minBtn.frame = CGRectMake(menuWidth - 56, 6, 24, 26);
    minBtn.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.35 alpha:1.0];
    minBtn.layer.cornerRadius = 6.0;
    [minBtn setTitle:@"−" forState:UIControlStateNormal];
    [minBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    minBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [minBtn addTarget:self action:@selector(minimizeMenu) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:minBtn];

    // Nút Đóng (✕)
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(menuWidth - 28, 6, 24, 26);
    closeBtn.backgroundColor = [UIColor colorWithRed:0.80 green:0.20 blue:0.20 alpha:1.0];
    closeBtn.layer.cornerRadius = 6.0;
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [closeBtn addTarget:self action:@selector(minimizeMenu) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];

    // Ô nhập API Key (Mặc định ẩn)
    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:STORAGE_KEY];
    if (!savedKey || savedKey.length == 0) savedKey = DEFAULT_API_KEY;

    apiKeyInput = [[UITextField alloc] initWithFrame:CGRectMake(12, 44, menuWidth - 24, 28)];
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
    [menuContainer addSubview:apiKeyInput];

    // Khung nút Lưu / Hủy Key (Mặc định ẩn)
    keyActionContainer = [[UIView alloc] initWithFrame:CGRectMake(12, 75, menuWidth - 24, 26)];
    keyActionContainer.backgroundColor = [UIColor clearColor];
    keyActionContainer.hidden = YES;

    UIButton *saveKeyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    saveKeyBtn.frame = CGRectMake(0, 0, (menuWidth - 30) / 2, 26);
    saveKeyBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.60 blue:0.30 alpha:1.0];
    saveKeyBtn.layer.cornerRadius = 5.0;
    [saveKeyBtn setTitle:@"💾 Lưu Key" forState:UIControlStateNormal];
    [saveKeyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    saveKeyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [saveKeyBtn addTarget:self action:@selector(onConfirmSaveKey) forControlEvents:UIControlEventTouchUpInside];
    [keyActionContainer addSubview:saveKeyBtn];

    UIButton *discardKeyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    discardKeyBtn.frame = CGRectMake(CGRectGetMaxX(saveKeyBtn.frame) + 6, 0, (menuWidth - 30) / 2, 26);
    discardKeyBtn.backgroundColor = [UIColor colorWithRed:0.40 green:0.40 blue:0.45 alpha:1.0];
    discardKeyBtn.layer.cornerRadius = 5.0;
    [discardKeyBtn setTitle:@"✕ Không lưu" forState:UIControlStateNormal];
    [discardKeyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    discardKeyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [discardKeyBtn addTarget:self action:@selector(onDiscardKey) forControlEvents:UIControlEventTouchUpInside];
    [keyActionContainer addSubview:discardKeyBtn];
    [menuContainer addSubview:keyActionContainer];

    // Ô nhập link cần bypass
    linkInput = [[UITextField alloc] initWithFrame:CGRectMake(12, 46, menuWidth - 24, 32)];
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
    [menuContainer addSubview:linkInput];

    // Nút Bypass
    bypassBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    bypassBtn.frame = CGRectMake(12, 86, (menuWidth - 30) / 2, 34);
    bypassBtn.backgroundColor = [UIColor colorWithRed:1.00 green:0.67 blue:0.00 alpha:1.0];
    bypassBtn.layer.cornerRadius = 6.0;
    [bypassBtn setTitle:@"Bypass Ngay" forState:UIControlStateNormal];
    [bypassBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    bypassBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [bypassBtn addTarget:self action:@selector(handleBypass) forControlEvents:UIControlEventTouchUpInside];
    [menuContainer addSubview:bypassBtn];

    // Nút Sao chép
    copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyBtn.frame = CGRectMake(CGRectGetMaxX(bypassBtn.frame) + 6, 86, (menuWidth - 30) / 2, 34);
    copyBtn.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.35 alpha:1.0];
    copyBtn.layer.cornerRadius = 6.0;
    [copyBtn setTitle:@"Sao Chép" forState:UIControlStateNormal];
    [copyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [copyBtn addTarget:self action:@selector(handleCopy) forControlEvents:UIControlEventTouchUpInside];
    [menuContainer addSubview:copyBtn];

    // Hộp kết quả
    resultBox = [[UIView alloc] initWithFrame:CGRectMake(12, 128, menuWidth - 24, 95)];
    resultBox.backgroundColor = [UIColor colorWithRed:0.04 green:0.04 blue:0.06 alpha:1.0];
    resultBox.layer.cornerRadius = 6.0;
    [menuContainer addSubview:resultBox];

    resultDisplay = [[UITextView alloc] initWithFrame:CGRectMake(6, 4, menuWidth - 36, 87)];
    resultDisplay.text = @"Dán link rồi ấn Bypass Ngay...";
    resultDisplay.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.65 alpha:1.0];
    resultDisplay.font = [UIFont systemFontOfSize:11];
    resultDisplay.backgroundColor = [UIColor clearColor];
    resultDisplay.editable = NO;
    resultDisplay.selectable = YES;
    [resultBox addSubview:resultDisplay];

    [targetWindow addSubview:menuContainer];

    // Khởi tạo Trình duyệt Mini & Lịch Sử
    [self setupMiniBrowserInWindow:targetWindow];
    [self setupHistoryOverlayInWindow:targetWindow];

    // Khởi tạo ở chế độ Khách (Guest Layout)
    [self updateLayoutForAdminState:NO];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        if (robloxWindow) {
            [robloxWindow bringSubviewToFront:floatingCircleBtn];
            [robloxWindow bringSubviewToFront:infoWidgetLabel];
            [robloxWindow bringSubviewToFront:menuContainer];
        }
    }];
}

// ============================================================
// ĐIỀU CHỈNH LAYOUT GIỮA CHẾ ĐỘ KHÁCH VÀ ADMIN
// ============================================================
+ (void)updateLayoutForAdminState:(BOOL)admin {
    CGFloat menuWidth = 320.0;
    if (admin) {
        apiKeyInput.hidden = NO;
        linkInput.frame = CGRectMake(12, 106, menuWidth - 24, 32);
        bypassBtn.frame = CGRectMake(12, 144, (menuWidth - 30) / 2, 34);
        copyBtn.frame = CGRectMake(CGRectGetMaxX(bypassBtn.frame) + 6, 144, (menuWidth - 30) / 2, 34);
        resultBox.frame = CGRectMake(12, 186, menuWidth - 24, 102);
        resultDisplay.frame = CGRectMake(6, 4, menuWidth - 36, 94);
        menuContainer.frame = CGRectMake(menuContainer.frame.origin.x, menuContainer.frame.origin.y, menuWidth, 300.0);

        baconWebBtn.hidden = NO;
        googleWebBtn.frame = CGRectMake(139, 6, 74, 26);
    } else {
        apiKeyInput.hidden = YES;
        keyActionContainer.hidden = YES;
        linkInput.frame = CGRectMake(12, 46, menuWidth - 24, 32);
        bypassBtn.frame = CGRectMake(12, 86, (menuWidth - 30) / 2, 34);
        copyBtn.frame = CGRectMake(CGRectGetMaxX(bypassBtn.frame) + 6, 86, (menuWidth - 30) / 2, 34);
        resultBox.frame = CGRectMake(12, 128, menuWidth - 24, 95);
        resultDisplay.frame = CGRectMake(6, 4, menuWidth - 36, 87);
        menuContainer.frame = CGRectMake(menuContainer.frame.origin.x, menuContainer.frame.origin.y, menuWidth, 235.0);

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
            [self triggerNotify:UINotificationFeedbackTypeSuccess];
            resultDisplay.text = @"🔒 Đã khóa chế độ Admin! Chuyển về giao diện Khách.";
            resultDisplay.textColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
        [topVC presentViewController:alert animated:YES completion:nil];
        return;
    }

    UIAlertController *pinAlert = [UIAlertController alertControllerWithTitle:@"🔐 Quyền Admin"
                                                                      message:@"Nhập mật mã để mở bảng quản lý API Key:"
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
            resultDisplay.text = @"👑 Xin chào Admin! Bạn có thể xem và thay đổi API Key phía trên.";
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

    // Header Browser
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

    // Nút Bacon (Chỉ hiện khi là Admin)
    baconWebBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    baconWebBtn.frame = CGRectMake(60, 6, 74, 26);
    baconWebBtn.backgroundColor = [UIColor colorWithRed:0.85 green:0.55 blue:0.10 alpha:1.0];
    baconWebBtn.layer.cornerRadius = 5.0;
    [baconWebBtn setTitle:@"🔑 Bacon" forState:UIControlStateNormal];
    [baconWebBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    baconWebBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [baconWebBtn addTarget:self action:@selector(openBaconSite) forControlEvents:UIControlEventTouchUpInside];
    [bHeader addSubview:baconWebBtn];

    // Nút Google
    googleWebBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    googleWebBtn.frame = CGRectMake(139, 6, 74, 26);
    googleWebBtn.backgroundColor = [UIColor colorWithRed:0.20 green:0.55 blue:0.90 alpha:1.0];
    googleWebBtn.layer.cornerRadius = 5.0;
    [googleWebBtn setTitle:@"🔍 Google" forState:UIControlStateNormal];
    [googleWebBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    googleWebBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [googleWebBtn addTarget:self action:@selector(openGoogle) forControlEvents:UIControlEventTouchUpInside];
    [bHeader addSubview:googleWebBtn];

    // Nút Tải lại trang (Reload)
    UIButton *reloadBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    reloadBtn.frame = CGRectMake(bWidth - 66, 6, 28, 26);
    reloadBtn.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.35 alpha:1.0];
    reloadBtn.layer.cornerRadius = 5.0;
    [reloadBtn setTitle:@"🔄" forState:UIControlStateNormal];
    [reloadBtn addTarget:self action:@selector(reloadBrowser) forControlEvents:UIControlEventTouchUpInside];
    [bHeader addSubview:reloadBtn];

    // Nút Đóng Web
    UIButton *closeWebBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeWebBtn.frame = CGRectMake(bWidth - 34, 6, 28, 26);
    closeWebBtn.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
    closeWebBtn.layer.cornerRadius = 5.0;
    [closeWebBtn setTitle:@"✕" forState:UIControlStateNormal];
    closeWebBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [closeWebBtn addTarget:self action:@selector(toggleMiniBrowser) forControlEvents:UIControlEventTouchUpInside];
    [bHeader addSubview:closeWebBtn];

    // WKWebView chống bung toàn màn hình
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
        card.backgroundColor = [UIColor colorWithRed:0.14 green:0.14 blue:0.18 alpha:1.0];
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
}

+ (void)minimizeMenu {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    [linkInput resignFirstResponder];
    [apiKeyInput resignFirstResponder];
    menuContainer.hidden = YES;
    miniBrowserContainer.hidden = YES;
    historyContainer.hidden = YES;
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
    keyActionContainer.hidden = YES;
}

+ (void)onDiscardKey {
    [self triggerImpact:UIImpactFeedbackStyleLight];
    [apiKeyInput resignFirstResponder];
    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:STORAGE_KEY];
    if (!savedKey || savedKey.length == 0) savedKey = DEFAULT_API_KEY;
    apiKeyInput.text = savedKey;
    resultDisplay.text = @"↩️ Đã hủy và khôi phục Key trước đó.";
    resultDisplay.textColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0];
    keyActionContainer.hidden = YES;
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
