#import <UIKit/UIKit.h>

// ============================================================
// LỚP WINDOW XUYÊN CẢM ỨNG (PASSTHROUGH TOUCH)
// ============================================================
@interface PassthroughWindow : UIWindow
@end

@implementation PassthroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    // Nếu điểm chạm rơi vào vùng trống của Window/RootView thì bỏ qua để game nhận cảm ứng
    if (hitView == self || hitView == self.rootViewController.view) {
        return nil;
    }
    return hitView;
}
@end

// ============================================================
// OVERLAY QUẢN LÝ GIAO DIỆN VÀ LOGIC BYPASS
// ============================================================
@interface BaconBypassOverlay : NSObject
+ (void)load;
@end

@implementation BaconBypassOverlay

static PassthroughWindow *overlayWindow = nil;
static UIView *menuContainer = nil;
static UITextField *apiKeyInput = nil;
static UITextField *linkInput = nil;
static UILabel *resultDisplay = nil;
static UIButton *floatingCircleBtn = nil;
static NSString *extractedLink = @"";

#define DEFAULT_API_KEY @"Bacon-440724857a7206c7a2d2-6bcdc55374f77bd35806"
#define STORAGE_KEY @"BaconBypass_CustomAPIKey"

+ (void)load {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self initFloatingOverlay];
        });
    }];
}

+ (void)initFloatingOverlay {
    if (overlayWindow) return;

    UIWindowScene *activeScene = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
            activeScene = (UIWindowScene *)scene;
            break;
        }
    }

    // Khởi tạo Window xuyên cảm ứng
    if (activeScene) {
        overlayWindow = [[PassthroughWindow alloc] initWithWindowScene:activeScene];
    } else {
        overlayWindow = [[PassthroughWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }

    UIViewController *rootVC = [[UIViewController alloc] init];
    rootVC.view.backgroundColor = [UIColor clearColor];
    overlayWindow.rootViewController = rootVC;
    overlayWindow.windowLevel = UIWindowLevelAlert + 100.0;
    overlayWindow.backgroundColor = [UIColor clearColor];
    overlayWindow.hidden = NO;

    // ==========================================
    // 1. NÚT TRÒN THU NHỎ
    // ==========================================
    floatingCircleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    floatingCircleBtn.frame = CGRectMake(25, 120, 42, 42);
    floatingCircleBtn.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.16 alpha:0.85];
    floatingCircleBtn.layer.cornerRadius = 21.0;
    floatingCircleBtn.layer.borderWidth = 1.5;
    floatingCircleBtn.layer.borderColor = [UIColor colorWithRed:1.00 green:0.67 blue:0.00 alpha:0.9].CGColor;
    floatingCircleBtn.layer.shadowColor = [UIColor blackColor].CGColor;
    floatingCircleBtn.layer.shadowOffset = CGSizeMake(0, 2);
    floatingCircleBtn.layer.shadowOpacity = 0.4;
    floatingCircleBtn.layer.shadowRadius = 4.0;
    [floatingCircleBtn setTitle:@"⚡" forState:UIControlStateNormal];
    floatingCircleBtn.titleLabel.font = [UIFont systemFontOfSize:18];
    [floatingCircleBtn addTarget:self action:@selector(openMenu) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *panBtn = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragCircle:)];
    [floatingCircleBtn addGestureRecognizer:panBtn];
    [rootVC.view addSubview:floatingCircleBtn];

    // ==========================================
    // 2. BẢNG MENU CHI TIẾT
    // ==========================================
    CGFloat menuWidth = 310.0;
    CGFloat menuHeight = 265.0;
    menuContainer = [[UIView alloc] initWithFrame:CGRectMake((rootVC.view.bounds.size.width - menuWidth) / 2, 120, menuWidth, menuHeight)];
    menuContainer.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:0.96];
    menuContainer.layer.cornerRadius = 12.0;
    menuContainer.layer.borderWidth = 1.0;
    menuContainer.layer.borderColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.32 alpha:1.0].CGColor;
    menuContainer.clipsToBounds = YES;
    menuContainer.hidden = YES;

    UIPanGestureRecognizer *panMenu = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragMenu:)];
    [menuContainer addGestureRecognizer:panMenu];

    // Thanh Header
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, menuWidth, 38)];
    header.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.16 alpha:1.0];
    [menuContainer addSubview:header];

    UILabel *headerTitle = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, 180, 38)];
    headerTitle.text = @"⚡ BACON BYPASS";
    headerTitle.textColor = [UIColor colorWithRed:1.00 green:0.67 blue:0.00 alpha:1.0];
    headerTitle.font = [UIFont boldSystemFontOfSize:13];
    [header addSubview:headerTitle];

    // Nút Thu nhỏ (−)
    UIButton *minBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    minBtn.frame = CGRectMake(menuWidth - 62, 6, 26, 26);
    minBtn.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.35 alpha:1.0];
    minBtn.layer.cornerRadius = 6.0;
    [minBtn setTitle:@"−" forState:UIControlStateNormal];
    [minBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    minBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [minBtn addTarget:self action:@selector(minimizeMenu) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:minBtn];

    // Nút Đóng (✕)
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(menuWidth - 32, 6, 26, 26);
    closeBtn.backgroundColor = [UIColor colorWithRed:0.80 green:0.20 blue:0.20 alpha:1.0];
    closeBtn.layer.cornerRadius = 6.0;
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [closeBtn addTarget:self action:@selector(minimizeMenu) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];

    // Ô nhập API Key
    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:STORAGE_KEY];
    if (!savedKey || savedKey.length == 0) {
        savedKey = DEFAULT_API_KEY;
    }

    apiKeyInput = [[UITextField alloc] initWithFrame:CGRectMake(12, 46, menuWidth - 24, 30)];
    apiKeyInput.text = savedKey;
    apiKeyInput.placeholder = @"Nhập Bacon API Key...";
    apiKeyInput.backgroundColor = [UIColor colorWithRed:0.13 green:0.13 blue:0.17 alpha:1.0];
    apiKeyInput.textColor = [UIColor colorWithRed:1.00 green:0.80 blue:0.30 alpha:1.0];
    apiKeyInput.font = [UIFont systemFontOfSize:11];
    apiKeyInput.layer.cornerRadius = 6.0;
    apiKeyInput.autocorrectionType = UITextAutocorrectionTypeNo;
    apiKeyInput.autocapitalizationType = UITextAutocapitalizationTypeNone;
    UIView *padKey = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 30)];
    apiKeyInput.leftView = padKey;
    apiKeyInput.leftViewMode = UITextFieldViewModeAlways;
    [apiKeyInput addTarget:self action:@selector(saveKeyLocally) forControlEvents:UIControlEventEditingDidEnd];
    [menuContainer addSubview:apiKeyInput];

    // Ô nhập Link
    linkInput = [[UITextField alloc] initWithFrame:CGRectMake(12, 84, menuWidth - 24, 32)];
    linkInput.placeholder = @"Dán link cần Bypass vào đây...";
    linkInput.backgroundColor = [UIColor colorWithRed:0.16 green:0.16 blue:0.22 alpha:1.0];
    linkInput.textColor = [UIColor whiteColor];
    linkInput.font = [UIFont systemFontOfSize:12];
    linkInput.layer.cornerRadius = 6.0;
    linkInput.autocorrectionType = UITextAutocorrectionTypeNo;
    linkInput.autocapitalizationType = UITextAutocapitalizationTypeNone;
    UIView *padLink = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 32)];
    linkInput.leftView = padLink;
    linkInput.leftViewMode = UITextFieldViewModeAlways;
    [menuContainer addSubview:linkInput];

    // Nút Bypass
    UIButton *bypassBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    bypassBtn.frame = CGRectMake(12, 124, (menuWidth - 30) / 2, 34);
    bypassBtn.backgroundColor = [UIColor colorWithRed:1.00 green:0.67 blue:0.00 alpha:1.0];
    bypassBtn.layer.cornerRadius = 6.0;
    [bypassBtn setTitle:@"Bypass Ngay" forState:UIControlStateNormal];
    [bypassBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    bypassBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [bypassBtn addTarget:self action:@selector(handleBypass) forControlEvents:UIControlEventTouchUpInside];
    [menuContainer addSubview:bypassBtn];

    // Nút Sao chép
    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyBtn.frame = CGRectMake(CGRectGetMaxX(bypassBtn.frame) + 6, 124, (menuWidth - 30) / 2, 34);
    copyBtn.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.35 alpha:1.0];
    copyBtn.layer.cornerRadius = 6.0;
    [copyBtn setTitle:@"Sao Chép" forState:UIControlStateNormal];
    [copyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [copyBtn addTarget:self action:@selector(handleCopy) forControlEvents:UIControlEventTouchUpInside];
    [menuContainer addSubview:copyBtn];

    // Hộp kết quả
    UIView *resultBox = [[UIView alloc] initWithFrame:CGRectMake(12, 166, menuWidth - 24, 88)];
    resultBox.backgroundColor = [UIColor colorWithRed:0.04 green:0.04 blue:0.06 alpha:1.0];
    resultBox.layer.cornerRadius = 6.0;
    [menuContainer addSubview:resultBox];

    resultDisplay = [[UILabel alloc] initWithFrame:CGRectMake(8, 6, menuWidth - 40, 76)];
    resultDisplay.text = @"Kết quả bypass sẽ hiển thị ở đây...";
    resultDisplay.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.65 alpha:1.0];
    resultDisplay.font = [UIFont systemFontOfSize:11];
    resultDisplay.numberOfLines = 0;
    resultDisplay.lineBreakMode = NSLineBreakByWordWrapping;
    [resultBox addSubview:resultDisplay];

    [rootVC.view addSubview:menuContainer];
}

+ (void)openMenu {
    menuContainer.hidden = NO;
    floatingCircleBtn.hidden = YES;
}

+ (void)minimizeMenu {
    [linkInput resignFirstResponder];
    [apiKeyInput resignFirstResponder];
    menuContainer.hidden = YES;
    floatingCircleBtn.hidden = NO;
}

+ (void)saveKeyLocally {
    NSString *key = [apiKeyInput.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (key.length > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:key forKey:STORAGE_KEY];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

+ (void)handleBypass {
    [linkInput resignFirstResponder];
    [apiKeyInput resignFirstResponder];
    [self saveKeyLocally];

    NSString *key = [apiKeyInput.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (key.length == 0) key = DEFAULT_API_KEY;

    NSString *url = [linkInput.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (url.length == 0) {
        resultDisplay.text = @"❌ Hãy dán link trước!";
        resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
        return;
    }

    resultDisplay.text = @"⏳ Đang gửi request...";
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
                resultDisplay.text = @"❌ Mất kết nối API!";
                resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
                return;
            }
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (json && [json[@"status"] isEqualToString:@"success"] && json[@"result"]) {
                extractedLink = [NSString stringWithFormat:@"%@", json[@"result"]];
                resultDisplay.text = [NSString stringWithFormat:@"✅ %@", extractedLink];
                resultDisplay.textColor = [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
            } else {
                resultDisplay.text = [NSString stringWithFormat:@"❌ %@", json[@"message"] ?: @"Thất bại!"];
                resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
            }
        });
    }] resume];
}

+ (void)handleCopy {
    if (extractedLink.length > 0) {
        [UIPasteboard generalPasteboard].string = extractedLink;
        resultDisplay.text = @"✅ Đã chép vào bộ nhớ đệm!";
        resultDisplay.textColor = [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
        linkInput.text = @"";
    }
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

@end
