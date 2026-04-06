#import "LFWindowManager.h"
#import "LFPanelController.h"
#import "../Views/LFClockView.h"
#import "../Views/LFButton.h"
#import "../Model/LFPrefs.h"
#import <objc/runtime.h>

// ─── Ventana del botón — hitTest preciso, exacto al de referencia (ALGLSButtonWindow) ───
@interface LFBtnWindow : UIWindow
@property (nonatomic, weak) LFButton *btn;
@end
@implementation LFBtnWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.btn) {
        CGPoint p = [self.btn convertPoint:point fromView:self];
        if ([self.btn pointInside:p withEvent:event])
            return [self.btn hitTest:p withEvent:event];
    }
    return nil;
}
@end

@interface LFWindowManager () <LFButtonDelegate, LFPanelDelegate>
@property (strong) LFBtnWindow       *btnWin;
@property (strong) UIWindow          *panelWin;
@property (strong) LFButton          *button;
@property (strong) LFPanelController *panel;
@property (strong) NSTimer           *timer;
@property BOOL panelVisible;
@end

@implementation LFWindowManager

+ (instancetype)shared {
    static LFWindowManager *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [[LFWindowManager alloc] init]; });
    return s;
}

- (void)setup {
    if (_btnWin) return;
    [LFPrefs.shared load];

    UIWindowScene *scene = nil;
    for (UIScene *sc in UIApplication.sharedApplication.connectedScenes)
        if ([sc isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene*)sc; break; }

    CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;

    // Panel window
    if (@available(iOS 13.0,*))
        _panelWin = [[UIWindow alloc] initWithWindowScene:scene];
    else
        _panelWin = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _panelWin.windowLevel = UIWindowLevelAlert + 499;
    _panelWin.backgroundColor = [UIColor clearColor];
    _panel = [LFPanelController panel];
    _panel.delegate = self;
    _panelWin.rootViewController = _panel;
    _panelWin.hidden = YES;

    // Button window — windowLevel encima del lockscreen, sin makeKeyAndVisible
    if (@available(iOS 13.0,*))
        _btnWin = [[LFBtnWindow alloc] initWithWindowScene:scene];
    else
        _btnWin = [[LFBtnWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

    _btnWin.windowLevel = UIWindowLevelAlert + 500;
    _btnWin.backgroundColor = [UIColor clearColor];

    UIViewController *bvc = [[UIViewController alloc] init];
    bvc.view.backgroundColor = [UIColor clearColor];
    bvc.view.userInteractionEnabled = YES;
    _btnWin.rootViewController = bvc;

    CGFloat size = 54.0f;
    _button = [[LFButton alloc] initWithFrame:CGRectMake(screenW - size - 12, screenH * 0.72f, size, size)];
    _button.delegate = self;
    _button.userInteractionEnabled = YES;
    [bvc.view addSubview:_button];
    _btnWin.btn = _button;

    // CRÍTICO: makeKeyAndVisible registra la window en el sistema de rendering.
    // Sin esto en iOS 15+, la window existe en memoria pero nunca aparece en pantalla.
    // Luego resignKeyWindow para no interferir con el lockscreen.
    [_btnWin makeKeyAndVisible];
    [_btnWin resignKeyWindow];
    _btnWin.hidden = YES;   // oculto hasta que aparezca el lockscreen
    _button.alpha  = 0;

    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
        [LFClockPatcher refreshAll];
    }];

    NSLog(@"[LF2] WindowManager setup OK");
}

- (void)patchLockscreenView:(UIView *)view {
    [LFClockPatcher patchDateView:view];
}

- (void)lockscreenDidAppear {
    _btnWin.hidden = NO;
    [UIView animateWithDuration:0.5f delay:0.2f options:0
                     animations:^{ self->_button.alpha = 1.0f; }
                     completion:nil];
    [LFClockPatcher refreshAll];
}

- (void)lockscreenDidDisappear {
    if (_panelVisible) return;
    [UIView animateWithDuration:0.2f animations:^{ self->_button.alpha = 0; } completion:^(BOOL d) {
        self->_btnWin.hidden = YES;
    }];
}

- (void)refreshClock {
    [LFClockPatcher refreshAll];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ALGVelvetUpdateStyle" object:nil];
}

- (void)togglePanel {
    if (_panelVisible) {
        [_panel dismiss:nil];
    } else {
        _panelVisible = YES;
        _panelWin.hidden = NO;
        [_panelWin makeKeyAndVisible];
        [_panel viewWillAppear:YES];
    }
}

- (void)lockFlowButtonTapped { [self togglePanel]; }

- (void)panelDidApply {
    [LFPrefs.shared load];
    [LFClockPatcher refreshAll];
}

- (void)panelDidDismiss {
    _panelVisible = NO;
    _panelWin.hidden = YES;
}

- (void)enterEditMode {
    extern void LFTweakSetEditMode(BOOL editing);
    LFTweakSetEditMode(YES);
    NSLog(@"[LF2] Edit mode ON");
}

@end
