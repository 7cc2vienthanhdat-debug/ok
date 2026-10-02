#import <UIKit/UIKit.h>

@interface BaconBypassOverlay : NSObject
+ (void)load;
@end

@implementation BaconBypassOverlay

static UIView *menuContainer = nil;
static UITextField *apiKeyInput = nil;
static UIView *keyActionContainer = nil;
static UITextField *linkInput = nil;
static UITextView *resultDisplay = nil;
static UIButton *floatingCircleBtn = nil;
static NSString *extractedLink = nil;
static UIWindow *robloxWindow = nil;

#define DEFAULT_API_KEY @"Bacon-68e61ca9d455d316a50c-b4328879cadc0a77f8a5"
#define STORAGE_KEY @"BaconBypass_CustomAPIKey"

+ (void)load {
    // Đợi 3.5 giây để Roblox khởi tạo xong engine đồ họa và vượt qua Splash Screen
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self tryInjectOverlay];
    });
}

+ (UIWindow *)findRobloxWindow {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *win in windowScene.windows) {
                if (win.rootViewController != nil && !win.hidden) {
                    return win;
                }
            }
        }
    }
    for (UIWindow *win in [UIApplication sharedApplication].windows) {
        if (win.rootViewController != nil && !win.hidden) {
            return win;
        }
    }
    return nil;
}

+ (void)tryInjectOverlay {
    if (floatingCircleBtn != nil) return;

    robloxWindow = [self findRobloxWindow];
    if (!robloxWindow || !robloxWindow.rootViewController) {
        // Nếu Roblox chưa nạp xong Window, thử lại sau 1 giây
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self tryInjectOverlay];
        });
        return;
    }

    [self setupViewsInWindow:robloxWindow];
}

+ (void)setupViewsInWindow:(UIWindow *)targetWindow {
    // ==========================================
    // 1. NÚT TRÒN THU NHỎ (42x42)
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
    [targetWindow addSubview:floatingCircleBtn];

    // ==========================================
    // 2. BẢNG MENU CHÍNH
    // ==========================================
    CGFloat menuWidth = 310.0;
    CGFloat menuHeight = 300.0;
    menuContainer = [[UIView alloc] initWithFrame:CGRectMake((targetWindow.bounds.size.width - menuWidth) / 2, 100, menuWidth, menuHeight)];
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
    [menuContainer addSubview:apiKeyInput];

    // Nút xác nhận: [Lưu] / [Không lưu] API Key
    keyActionContainer = [[UIView alloc] initWithFrame:CGRectMake(12, 75, menuWidth - 24, 26)];
    keyActionContainer.backgroundColor = [UIColor clearColor];
    keyActionContainer.hidden = YES;

    UIButton *saveKeyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    saveKeyBtn.frame = CGRectMake(0, 0, (menuWidth - 30) / 2, 26);
    saveKeyBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.60 blue:0.30 alpha:1.0];
    saveKeyBtn.layer.cornerRadius = 5.0;
    [saveKeyBtn setTitle:@"💾 Lưu API Key" forState:UIControlStateNormal];
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

    // Ô nhập Link cần bypass
    linkInput = [[UITextField alloc] initWithFrame:CGRectMake(12, 106, menuWidth - 24, 32)];
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
    UIButton *bypassBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    bypassBtn.frame = CGRectMake(12, 144, (menuWidth - 30) / 2, 34);
    bypassBtn.backgroundColor = [UIColor colorWithRed:1.00 green:0.67 blue:0.00 alpha:1.0];
    bypassBtn.layer.cornerRadius = 6.0;
    [bypassBtn setTitle:@"Bypass Ngay" forState:UIControlStateNormal];
    [bypassBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    bypassBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [bypassBtn addTarget:self action:@selector(handleBypass) forControlEvents:UIControlEventTouchUpInside];
    [menuContainer addSubview:bypassBtn];

    // Nút Sao chép
    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyBtn.frame = CGRectMake(CGRectGetMaxX(bypassBtn.frame) + 6, 144, (menuWidth - 30) / 2, 34);
    copyBtn.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.35 alpha:1.0];
    copyBtn.layer.cornerRadius = 6.0;
    [copyBtn setTitle:@"Sao Chép" forState:UIControlStateNormal];
    [copyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [copyBtn addTarget:self action:@selector(handleCopy) forControlEvents:UIControlEventTouchUpInside];
    [menuContainer addSubview:copyBtn];

    // Hộp kết quả
    UIView *resultBox = [[UIView alloc] initWithFrame:CGRectMake(12, 186, menuWidth - 24, 102)];
    resultBox.backgroundColor = [UIColor colorWithRed:0.04 green:0.04 blue:0.06 alpha:1.0];
    resultBox.layer.cornerRadius = 6.0;
    [menuContainer addSubview:resultBox];

    resultDisplay = [[UITextView alloc] initWithFrame:CGRectMake(6, 4, menuWidth - 36, 94)];
    resultDisplay.text = @"Dán link rồi ấn Bypass Ngay...";
    resultDisplay.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.65 alpha:1.0];
    resultDisplay.font = [UIFont systemFontOfSize:11];
    resultDisplay.backgroundColor = [UIColor clearColor];
    resultDisplay.editable = NO;
    resultDisplay.selectable = YES;
    [resultBox addSubview:resultDisplay];

    [targetWindow addSubview:menuContainer];

    // Theo dõi thay đổi trạng thái ứng dụng để luôn đưa nút lên trên cùng
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        if (robloxWindow) {
            [robloxWindow bringSubviewToFront:floatingCircleBtn];
            [robloxWindow bringSubviewToFront:menuContainer];
        }
    }];
}

+ (void)openMenu {
    menuContainer.hidden = NO;
    floatingCircleBtn.hidden = YES;
    [robloxWindow bringSubviewToFront:menuContainer];
}

+ (void)minimizeMenu {
    [linkInput resignFirstResponder];
    [apiKeyInput resignFirstResponder];
    menuContainer.hidden = YES;
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

+ (void)onApiKeyEditingBegan {
    keyActionContainer.hidden = NO;
}

+ (void)onApiKeyEditingChanged {
    keyActionContainer.hidden = NO;
}

+ (void)onConfirmSaveKey {
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
    [apiKeyInput resignFirstResponder];
    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:STORAGE_KEY];
    if (!savedKey || savedKey.length == 0) {
        savedKey = DEFAULT_API_KEY;
    }
    apiKeyInput.text = savedKey;
    resultDisplay.text = @"↩️ Đã hủy và khôi phục lại Key trước đó.";
    resultDisplay.textColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0];
    keyActionContainer.hidden = YES;
}

+ (void)handleBypass {
    [linkInput resignFirstResponder];
    [apiKeyInput resignFirstResponder];

    NSString *key = [self cleanString:apiKeyInput.text];
    if (key.length == 0) {
        NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:STORAGE_KEY];
        key = (savedKey && savedKey.length > 0) ? savedKey : DEFAULT_API_KEY;
    }

    NSString *url = [self cleanString:linkInput.text];
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
            NSError *jsonErr = nil;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
            if (json && [json[@"status"] isEqualToString:@"success"] && json[@"result"]) {
                extractedLink = [[NSString alloc] initWithFormat:@"%@", json[@"result"]];
                resultDisplay.text = [NSString stringWithFormat:@"✅ %@", extractedLink];
                resultDisplay.textColor = [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
            } else {
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
                resultDisplay.text = @"❌ Chưa có kết quả để sao chép!";
                resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
                return;
            }

            UIPasteboard *board = [UIPasteboard generalPasteboard];
            if (board) {
                [board setString:targetText];
            }
            resultDisplay.text = @"✅ Đã chép vào bộ nhớ đệm!";
            resultDisplay.textColor = [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
            linkInput.text = @"";
        } @catch (NSException *e) {
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

@end
