#import <UIKit/UIKit.h>

@interface BaconBypassOverlay : NSObject
+ (void)load;
@end

@implementation BaconBypassOverlay

static UIView *menuContainer = nil;
static UITextField *apiKeyInput = nil;
static UITextField *linkInput = nil;
static UILabel *resultDisplay = nil;
static UIButton *toggleFloatButton = nil;
static NSString *extractedLink = @"";

#define DEFAULT_API_KEY @"Bacon-440724857a7206c7a2d2-6bcdc55374f77bd35806"
#define STORAGE_KEY @"BaconBypass_CustomAPIKey"

+ (void)load {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self setupUI];
    });
}

+ (UIWindow *)fetchActiveWindow {
    UIWindow *targetWindow = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *window in scene.windows) {
                if (window.isKeyWindow) {
                    targetWindow = window;
                    break;
                }
            }
        }
    }
    if (!targetWindow) {
        targetWindow = [UIApplication sharedApplication].keyWindow;
    }
    return targetWindow;
}

+ (void)setupUI {
    UIWindow *window = [self fetchActiveWindow];
    if (!window) return;

    // ==========================================
    // 1. NÚT TRÒN NỔI (MỞ / ĐÓNG MENU)
    // ==========================================
    toggleFloatButton = [UIButton buttonWithType:UIButtonTypeCustom];
    toggleFloatButton.frame = CGRectMake(20, 120, 48, 48);
    toggleFloatButton.backgroundColor = [UIColor colorWithRed:1.00 green:0.67 blue:0.00 alpha:1.0];
    toggleFloatButton.layer.cornerRadius = 24.0;
    toggleFloatButton.layer.shadowColor = [UIColor blackColor].CGColor;
    toggleFloatButton.layer.shadowOffset = CGSizeMake(0, 3);
    toggleFloatButton.layer.shadowOpacity = 0.5;
    toggleFloatButton.layer.shadowRadius = 4.0;
    [toggleFloatButton setTitle:@"🔗" forState:UIControlStateNormal];
    toggleFloatButton.titleLabel.font = [UIFont systemFontOfSize:22];
    [toggleFloatButton addTarget:self action:@selector(toggleMenuVisibility) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *panBtn = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragButton:)];
    [toggleFloatButton addGestureRecognizer:panBtn];
    [window addSubview:toggleFloatButton];

    // ==========================================
    // 2. BẢNG MENU CHÍNH
    // ==========================================
    CGFloat menuWidth = 310.0;
    CGFloat menuHeight = 265.0;
    menuContainer = [[UIView alloc] initWithFrame:CGRectMake((window.bounds.size.width - menuWidth) / 2, 100, menuWidth, menuHeight)];
    menuContainer.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:0.96];
    menuContainer.layer.cornerRadius = 12.0;
    menuContainer.layer.borderWidth = 1.0;
    menuContainer.layer.borderColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.32 alpha:1.0].CGColor;
    menuContainer.clipsToBounds = YES;
    menuContainer.hidden = YES;

    UIPanGestureRecognizer *panMenu = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragMenu:)];
    [menuContainer addGestureRecognizer:panMenu];

    // Header bar
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, menuWidth, 38)];
    header.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.16 alpha:1.0];
    [menuContainer addSubview:header];

    UILabel *headerTitle = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, 220, 38)];
    headerTitle.text = @"⚡ BACON BYPASS";
    headerTitle.textColor = [UIColor colorWithRed:1.00 green:0.67 blue:0.00 alpha:1.0];
    headerTitle.font = [UIFont boldSystemFontOfSize:13];
    [header addSubview:headerTitle];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(menuWidth - 36, 6, 26, 26);
    closeBtn.backgroundColor = [UIColor colorWithRed:0.80 green:0.20 blue:0.20 alpha:1.0];
    closeBtn.layer.cornerRadius = 6.0;
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [closeBtn addTarget:self action:@selector(toggleMenuVisibility) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];

    // Ô NHẬP VÀ ĐỔI API KEY (Lưu vĩnh viễn vào bộ nhớ)
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
    apiKeyInput.clearButtonMode = UITextFieldViewModeWhileEditing;
    UIView *leftPaddingKey = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 30)];
    apiKeyInput.leftView = leftPaddingKey;
    apiKeyInput.leftViewMode = UITextFieldViewModeAlways;
    [apiKeyInput addTarget:self action:@selector(handleKeyChange) forControlEvents:UIControlEventEditingDidEnd];
    [menuContainer addSubview:apiKeyInput];

    // Ô NHẬP LINK CẦN BYPASS
    linkInput = [[UITextField alloc] initWithFrame:CGRectMake(12, 84, menuWidth - 24, 32)];
    linkInput.placeholder = @"Dán link cần Bypass vào đây...";
    linkInput.backgroundColor = [UIColor colorWithRed:0.16 green:0.16 blue:0.22 alpha:1.0];
    linkInput.textColor = [UIColor whiteColor];
    linkInput.font = [UIFont systemFontOfSize:12];
    linkInput.layer.cornerRadius = 6.0;
    linkInput.autocorrectionType = UITextAutocorrectionTypeNo;
    linkInput.autocapitalizationType = UITextAutocapitalizationTypeNone;
    linkInput.clearButtonMode = UITextFieldViewModeWhileEditing;
    UIView *leftPaddingLink = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 32)];
    linkInput.leftView = leftPaddingLink;
    linkInput.leftViewMode = UITextFieldViewModeAlways;
    [menuContainer addSubview:linkInput];

    // NÚT BẤM BYPASS
    UIButton *bypassBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    bypassBtn.frame = CGRectMake(12, 124, (menuWidth - 30) / 2, 34);
    bypassBtn.backgroundColor = [UIColor colorWithRed:1.00 green:0.67 blue:0.00 alpha:1.0];
    bypassBtn.layer.cornerRadius = 6.0;
    [bypassBtn setTitle:@"Bypass Ngay" forState:UIControlStateNormal];
    [bypassBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    bypassBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [bypassBtn addTarget:self action:@selector(triggerBypassAction) forControlEvents:UIControlEventTouchUpInside];
    [menuContainer addSubview:bypassBtn];

    // NÚT BẤM SAO CHÉP
    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyBtn.frame = CGRectMake(CGRectGetMaxX(bypassBtn.frame) + 6, 124, (menuWidth - 30) / 2, 34);
    copyBtn.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.35 alpha:1.0];
    copyBtn.layer.cornerRadius = 6.0;
    [copyBtn setTitle:@"Sao Chép" forState:UIControlStateNormal];
    [copyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [copyBtn addTarget:self action:@selector(triggerCopyAction) forControlEvents:UIControlEventTouchUpInside];
    [menuContainer addSubview:copyBtn];

    // KHUNG HIỂN THỊ LINK KẾT QUẢ
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

    [window addSubview:menuContainer];
}

+ (void)handleKeyChange {
    NSString *currentKey = [apiKeyInput.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (currentKey.length > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:currentKey forKey:STORAGE_KEY];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

+ (void)toggleMenuVisibility {
    menuContainer.hidden = !menuContainer.hidden;
    if (menuContainer.hidden) {
        [linkInput resignFirstResponder];
        [apiKeyInput resignFirstResponder];
    }
}

+ (void)triggerBypassAction {
    [linkInput resignFirstResponder];
    [apiKeyInput resignFirstResponder];

    [self handleKeyChange];

    NSString *activeKey = [apiKeyInput.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (activeKey.length == 0) {
        activeKey = DEFAULT_API_KEY;
    }

    NSString *inputUrl = [linkInput.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (inputUrl.length == 0) {
        resultDisplay.text = @"❌ Vui lòng dán link trước khi bấm Bypass!";
        resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
        return;
    }

    resultDisplay.text = @"⏳ Đang xử lý Bypass...";
    resultDisplay.textColor = [UIColor colorWithRed:1.00 green:0.67 blue:0.00 alpha:1.0];

    NSURL *apiEndpoint = [NSURL URLWithString:@"https://baconbypass.online/bypass"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:apiEndpoint];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSDictionary *jsonBody = @{
        @"url": inputUrl,
        @"apikey": activeKey
    };

    NSError *jsonError;
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:jsonBody options:0 error:&jsonError];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !data) {
                resultDisplay.text = @"❌ Lỗi kết nối mạng đến máy chủ!";
                resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
                return;
            }

            NSError *parseError;
            NSDictionary *resJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];

            if (resJson && [resJson[@"status"] isEqualToString:@"success"] && resJson[@"result"]) {
                extractedLink = [NSString stringWithFormat:@"%@", resJson[@"result"]];
                resultDisplay.text = [NSString stringWithFormat:@"✅ %@", extractedLink];
                resultDisplay.textColor = [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
            } else {
                NSString *msg = resJson[@"message"] ?: @"Key hết hạn hoặc link không hỗ trợ!";
                resultDisplay.text = [NSString stringWithFormat:@"❌ %@", msg];
                resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
            }
        });
    }];
    [task resume];
}

+ (void)triggerCopyAction {
    if (extractedLink.length > 0) {
        [UIPasteboard generalPasteboard].string = extractedLink;
        resultDisplay.text = @"✅ Đã sao chép vào Clipboard!";
        resultDisplay.textColor = [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
        linkInput.text = @"";
    } else {
        resultDisplay.text = @"❌ Chưa có kết quả để sao chép!";
        resultDisplay.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
    }
}

+ (void)handleDragButton:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:toggleFloatButton.superview];
    toggleFloatButton.center = CGPointMake(toggleFloatButton.center.X + translation.x, toggleFloatButton.center.Y + translation.y);
    [gesture setTranslation:CGPointZero inView:toggleFloatButton.superview];
}

+ (void)handleDragMenu:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:menuContainer.superview];
    menuContainer.center = CGPointMake(menuContainer.center.X + translation.x, menuContainer.center.Y + translation.y);
    [gesture setTranslation:CGPointZero inView:menuContainer.superview];
}

@end
