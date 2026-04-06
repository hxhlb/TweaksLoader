#import "LFPanelController.h"
#import "../Model/LFPrefs.h"
#import <objc/runtime.h>
#import "LFWindowManager.h"
#import "../Views/LFClockView.h"

// Google Fonts — LFGoogleFonts.m
extern void LFGFPresent(UIViewController *parentVC, void(^onApply)(NSString *family, NSString *psName));
extern BOOL LFGFIsActive(void);

#define ROWH 44.0f
#define AC_CLOCK  [UIColor colorWithRed:.22f green:.55f blue:1 alpha:1]
#define AC_DATE   [UIColor colorWithRed:.2f green:.8f blue:.4f alpha:1]
#define AC_FONT   [UIColor colorWithRed:.9f green:.6f blue:.1f alpha:1]
#define AC_NOTIF  [UIColor colorWithRed:1 green:.55f blue:.2f alpha:1]
#define AC_SAVE   [UIColor colorWithRed:0 green:.5f blue:1 alpha:.75f]

// ─── Glass panel (idéntico a ALGMakeGlassPanel) ───────────────────────────────
static UIView *LFMakeGlass(CGRect frame) {
    UIView *p = [[UIView alloc] initWithFrame:frame];
    p.backgroundColor = [UIColor clearColor];
    p.layer.cornerRadius = 28; p.clipsToBounds = YES;
    if (@available(iOS 13.0,*)) p.layer.cornerCurve = kCACornerCurveContinuous;
    UIBlurEffect *bl;
    if (@available(iOS 13.0,*)) bl=[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    else bl=[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *bv=[[UIVisualEffectView alloc] initWithEffect:bl];
    bv.frame=p.bounds; bv.userInteractionEnabled=NO; [p addSubview:bv];
    UIView *t=[[UIView alloc] initWithFrame:p.bounds];
    t.backgroundColor=[UIColor colorWithRed:0.03f green:0.03f blue:0.11f alpha:0.60f];
    t.userInteractionEnabled=NO; [p addSubview:t];
    CAGradientLayer *sp=[CAGradientLayer layer]; sp.frame=p.bounds;
    sp.colors=@[(id)[UIColor colorWithWhite:1 alpha:0.09f].CGColor,(id)[UIColor colorWithWhite:1 alpha:0].CGColor];
    sp.locations=@[@0,@0.4f]; [p.layer addSublayer:sp];
    CAGradientLayer *bd=[CAGradientLayer layer]; bd.frame=p.bounds;
    bd.colors=@[(id)[UIColor colorWithWhite:1 alpha:0.35f].CGColor,(id)[UIColor colorWithWhite:1 alpha:0.05f].CGColor,(id)[UIColor colorWithWhite:1 alpha:0.12f].CGColor];
    bd.locations=@[@0,@0.5f,@1];
    CAShapeLayer *bm=[CAShapeLayer layer];
    UIBezierPath *bo=[UIBezierPath bezierPathWithRoundedRect:p.bounds cornerRadius:28];
    UIBezierPath *bi=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(p.bounds,0.6f,0.6f) cornerRadius:27.4f];
    [bo appendPath:bi]; bo.usesEvenOddFillRule=YES;
    bm.path=bo.CGPath; bm.fillRule=kCAFillRuleEvenOdd;
    bd.mask=bm; [p.layer addSublayer:bd];
    return p;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
static UILabel *LFLbl(NSString *text, CGFloat sz, UIFontWeight w, UIColor *col, CGRect f) {
    UILabel *l = [[UILabel alloc] initWithFrame:f];
    l.text=text; l.font=[UIFont systemFontOfSize:sz weight:w];
    l.textColor=col; l.userInteractionEnabled=NO;
    return l;
}
static UIView *LFSep(CGFloat x, CGFloat y, CGFloat w) {
    UIView *v=[[UIView alloc]initWithFrame:CGRectMake(x,y,w,0.5f)];
    v.backgroundColor=[UIColor colorWithWhite:1 alpha:0.1f];
    return v;
}
static UILabel *LFSecHdr(UIView *p, NSString *t, CGFloat x, CGFloat y, CGFloat w) {
    UILabel *l=LFLbl([t uppercaseString],10,UIFontWeightSemibold,[UIColor colorWithWhite:1 alpha:.35f],CGRectMake(x,y,w,14));
    [p addSubview:l]; return l;
}
static UISwitch *LFToggle(UIView *p, NSString *t, BOOL on, CGFloat x, CGFloat y, CGFloat w) {
    UILabel *l=LFLbl(t,14,UIFontWeightRegular,[UIColor whiteColor],CGRectMake(x,y+12,w-60,20));
    [p addSubview:l];
    UISwitch *sw=[[UISwitch alloc]init];
    sw.on=on; sw.onTintColor=[UIColor colorWithRed:.46f green:.83f blue:1 alpha:1];
    sw.center=CGPointMake(x+w-30,y+ROWH/2); [p addSubview:sw]; return sw;
}

// Card de sección (idéntico a LSCd)
static UIButton *LFCard(NSString *t, NSString *ic, NSString *sub, CGFloat y, CGFloat w, UIColor *col) {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeCustom];
    b.frame=CGRectMake(12,y,w-24,58);
    b.backgroundColor=[UIColor colorWithWhite:1 alpha:.045f];
    b.layer.cornerRadius=14;
    if (@available(iOS 13.0,*)) b.layer.cornerCurve=kCACornerCurveContinuous;
    if (@available(iOS 13.0,*)) {
        UIImageSymbolConfiguration *cfg=[UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
        UIImageView *iv=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:ic withConfiguration:cfg]];
        iv.frame=CGRectMake(16,18,22,22); iv.tintColor=col; iv.userInteractionEnabled=NO;
        [b addSubview:iv];
    }
    UILabel *l=[[UILabel alloc]initWithFrame:CGRectMake(48,sub?10:0,w-24-80,sub?22:58)];
    l.text=t; l.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    l.textColor=[UIColor whiteColor]; l.userInteractionEnabled=NO; [b addSubview:l];
    if (sub) {
        UILabel *s=[[UILabel alloc]initWithFrame:CGRectMake(48,30,w-24-80,16)];
        s.text=sub; s.font=[UIFont systemFontOfSize:11];
        s.textColor=[UIColor colorWithWhite:1 alpha:.38f]; s.userInteractionEnabled=NO; [b addSubview:s];
    }
    if (@available(iOS 13.0,*)) {
        UIImageSymbolConfiguration *cfg=[UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightMedium];
        UIImageView *cv=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"chevron.right" withConfiguration:cfg]];
        cv.frame=CGRectMake(w-24-28,21,14,14); cv.tintColor=[UIColor colorWithWhite:1 alpha:.22f]; cv.userInteractionEnabled=NO; [b addSubview:cv];
    }
    return b;
}

// Gradient button (idéntico a LSGBtn)
static UIButton *LFGBtn(NSString *t, NSString *sf, NSArray *gc, CGRect fr) {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeCustom]; b.frame=fr;
    b.layer.cornerRadius=14; if (@available(iOS 13.0,*)) b.layer.cornerCurve=kCACornerCurveContinuous;
    b.layer.borderWidth=.5f; b.layer.borderColor=[UIColor colorWithWhite:1 alpha:.18f].CGColor;
    UIVisualEffectView *bv=[[UIVisualEffectView alloc]initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    bv.frame=CGRectMake(0,0,fr.size.width,fr.size.height); bv.layer.cornerRadius=14;
    if (@available(iOS 13.0,*)) bv.layer.cornerCurve=kCACornerCurveContinuous;
    bv.layer.masksToBounds=YES; bv.userInteractionEnabled=NO; [b addSubview:bv];
    CAGradientLayer *gl=[CAGradientLayer layer]; gl.frame=CGRectMake(0,0,fr.size.width,fr.size.height);
    gl.cornerRadius=14; NSMutableArray *cg=[NSMutableArray array];
    for (UIColor *c in gc) [cg addObject:(id)c.CGColor];
    gl.colors=cg; gl.startPoint=CGPointMake(0,0); gl.endPoint=CGPointMake(1,1); [b.layer addSublayer:gl];
    UILabel *l=[[UILabel alloc]init]; l.text=t;
    l.font=[UIFont systemFontOfSize:12 weight:UIFontWeightSemibold]; l.textColor=[UIColor whiteColor]; l.userInteractionEnabled=NO; [l sizeToFit];
    if (@available(iOS 13.0,*)) {
        UIImageSymbolConfiguration *cfg=[UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightMedium];
        UIImageView *iv=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:sf withConfiguration:cfg]];
        iv.tintColor=[UIColor whiteColor]; iv.userInteractionEnabled=NO;
        CGFloat tw=16+5+l.bounds.size.width, sx=(fr.size.width-tw)/2;
        iv.frame=CGRectMake(sx,(fr.size.height-16)/2,16,16);
        l.frame=CGRectMake(sx+21,(fr.size.height-l.bounds.size.height)/2,l.bounds.size.width,l.bounds.size.height);
        [b addSubview:iv];
    }
    [b addSubview:l]; return b;
}

// Page header con back button
static UIView *LFPgHdr(NSString *t, CGFloat w) {
    UIView *h=[[UIView alloc]initWithFrame:CGRectMake(0,0,w,48)];
    CAGradientLayer *s=[CAGradientLayer layer]; s.frame=CGRectMake(0,47.5f,w,.5f);
    s.colors=@[(id)[UIColor colorWithWhite:1 alpha:0].CGColor,(id)[UIColor colorWithWhite:1 alpha:.18f].CGColor,(id)[UIColor colorWithWhite:1 alpha:0].CGColor];
    s.startPoint=CGPointMake(0,.5f); s.endPoint=CGPointMake(1,.5f); [h.layer addSublayer:s];
    UILabel *l=[[UILabel alloc]initWithFrame:CGRectMake(60,6,w-120,36)];
    l.text=t; l.font=[UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    l.textColor=[UIColor whiteColor]; l.textAlignment=NSTextAlignmentCenter; l.userInteractionEnabled=NO; [h addSubview:l];
    // back button will be wired by caller
    h.tag = 7700;
    return h;
}

// Font row — botones de familia de fuente
static void LFFontRow(UIScrollView *sc, CGFloat pad, CGFloat *y, CGFloat cw, NSInteger cur, NSInteger tagBase) {
    NSArray *fams=@[@"System",@"Helvetica",@"Avenir",@"Futura",@"Menlo",@"Courier",@"Georgia",@"Gill Sans"];
    CGFloat bw=cw/4.f;
    for (NSInteger i=0;i<(NSInteger)fams.count;i++) {
        UIButton *b=[UIButton buttonWithType:UIButtonTypeCustom];
        b.frame=CGRectMake(pad+(i%4)*bw,*y+(i/4)*34,bw-3,28);
        [b setTitle:fams[i] forState:UIControlStateNormal];
        b.titleLabel.font=[UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        b.titleLabel.adjustsFontSizeToFitWidth=YES;
        b.layer.cornerRadius=8;
        b.backgroundColor=cur==i?[UIColor colorWithRed:.22f green:.55f blue:1 alpha:1]:[UIColor colorWithWhite:1 alpha:.1f];
        [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        b.tag=tagBase+i;
        objc_setAssociatedObject(b,"idx",@(i),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [sc addSubview:b];
    }
    *y += (fams.count/4)*34 + 8;
}

// ─── Panel ───────────────────────────────────────────────────────────────────
@interface LFPanelController () <UIColorPickerViewControllerDelegate>
@property (strong) UIView     *panel;
@property (strong) UIView     *navContainer;
@property CGFloat pw, ph;
@property NSInteger navDepth;
// Notif / Velvet state
@property CGFloat notifRadius, notifAlpha, notifScale;
@property BOOL notifEnabled, notifBlur, notifBold, notifIcon;
// Border
@property BOOL    borderEnabled;
@property CGFloat borderWidth, borderAlpha;
@property (strong) UIColor *borderColor;
// Background tint
@property BOOL    bgEnabled;
@property CGFloat bgAlpha;
@property (strong) UIColor *bgColor;
// Glow / shadow
@property BOOL    shadowEnabled;
@property CGFloat shadowWidth;
@property (strong) UIColor *shadowColor;
// Line accent
@property BOOL    lineEnabled;
@property CGFloat lineWidth;
@property NSInteger linePosition;
@property (strong) UIColor *lineColor;
@end

@implementation LFPanelController

+ (instancetype)panel { return [[LFPanelController alloc] init]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self buildPanel];
}

- (void)buildPanel {
    for (UIView *v in [self.view.subviews copy]) [v removeFromSuperview];
    LFPrefs *p = LFPrefs.shared;

    CGFloat sw=[UIScreen mainScreen].bounds.size.width;
    CGFloat sh=[UIScreen mainScreen].bounds.size.height;
    _pw=MIN(sw-32,340); _ph=MIN(sh*.72f,560);
    CGFloat px=(sw-_pw)/2, py=(sh-_ph)/2;

    // Dim
    UIView *dim=[[UIView alloc]initWithFrame:[UIScreen mainScreen].bounds];
    dim.backgroundColor=[UIColor colorWithWhite:0 alpha:.35f]; dim.alpha=0; dim.tag=9998;
    UIButton *db=[UIButton buttonWithType:UIButtonTypeCustom]; db.frame=dim.bounds;
    [db addTarget:self action:@selector(dismiss:) forControlEvents:UIControlEventTouchUpInside];
    [dim addSubview:db]; [self.view addSubview:dim];

    // Shadow
    UIView *shd=[[UIView alloc]initWithFrame:CGRectMake(px,py,_pw,_ph)];
    shd.backgroundColor=[UIColor clearColor]; shd.layer.cornerRadius=28;
    shd.layer.shadowColor=[UIColor colorWithRed:.3f green:.1f blue:.7f alpha:.5f].CGColor;
    shd.layer.shadowOpacity=.8f; shd.layer.shadowRadius=28; shd.layer.shadowOffset=CGSizeMake(0,10);
    shd.userInteractionEnabled=NO; shd.tag=8800; [self.view addSubview:shd];

    // Panel glass
    _panel = LFMakeGlass(CGRectMake(px,py,_pw,_ph));
    _panel.tag=9999; [self.view addSubview:_panel];

    // Nav container (slides para las páginas)
    _navContainer=[[UIView alloc]initWithFrame:CGRectMake(0,0,_pw,_ph)];
    _navContainer.clipsToBounds=YES; _navContainer.userInteractionEnabled=YES;
    [_panel addSubview:_navContainer];
    _navDepth=0;

    // Load notif / velvet state from prefs
    NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:LF_SUITE];
    [ud synchronize];
    _notifEnabled   = [ud objectForKey:@"notifEnabled"]   ? [ud boolForKey:@"notifEnabled"]   : YES;
    _notifRadius    = [ud objectForKey:@"notifRadius"]    ? [ud floatForKey:@"notifRadius"]   : 16.f;
    _notifAlpha     = [ud objectForKey:@"notifAlpha"]     ? [ud floatForKey:@"notifAlpha"]    : .95f;
    _notifScale     = 1;
    _notifBlur      = [ud objectForKey:@"notifBlur"]      ? [ud boolForKey:@"notifBlur"]      : YES;
    _notifBold      = [ud objectForKey:@"notifTitleBold"] ? [ud boolForKey:@"notifTitleBold"] : YES;
    _notifIcon      = [ud objectForKey:@"notifShowIcon"]  ? [ud boolForKey:@"notifShowIcon"]  : YES;
    _borderEnabled  = [ud objectForKey:@"borderEnabled"]  ? [ud boolForKey:@"borderEnabled"]  : YES;
    _borderWidth    = [ud objectForKey:@"borderWidth"]    ? [ud floatForKey:@"borderWidth"]   : 2.f;
    _borderAlpha    = [ud objectForKey:@"borderAlpha"]    ? [ud floatForKey:@"borderAlpha"]   : .85f;
    _bgEnabled      = [ud objectForKey:@"bgEnabled"]      ? [ud boolForKey:@"bgEnabled"]      : YES;
    _bgAlpha        = [ud objectForKey:@"bgAlpha"]        ? [ud floatForKey:@"bgAlpha"]       : .22f;
    _shadowEnabled  = [ud objectForKey:@"shadowEnabled"]  ? [ud boolForKey:@"shadowEnabled"]  : YES;
    _shadowWidth    = [ud objectForKey:@"shadowWidth"]    ? [ud floatForKey:@"shadowWidth"]   : 10.f;
    _lineEnabled    = [ud objectForKey:@"lineEnabled"]    ? [ud boolForKey:@"lineEnabled"]    : YES;
    _lineWidth      = [ud objectForKey:@"lineWidth"]      ? [ud floatForKey:@"lineWidth"]     : 3.f;
    _linePosition   = 0;

    // Home page
    [self buildHome:p];

    // Animate in
    _panel.alpha=0; dim.alpha=0;
    _panel.transform=CGAffineTransformConcat(CGAffineTransformMakeScale(.9f,.9f),CGAffineTransformMakeTranslation(0,12));
    [UIView animateWithDuration:.38f delay:0 usingSpringWithDamping:.78f initialSpringVelocity:.6f
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{ self->_panel.alpha=1; self->_panel.transform=CGAffineTransformIdentity; dim.alpha=1; }
                     completion:nil];

    // Drag panel
    __weak UIView *wp=_panel; __weak UIView *wr=self.view;
    UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panPanel:)];
    objc_setAssociatedObject(_panel,"panGR",pan,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [_panel addGestureRecognizer:pan];
    (void)wp;(void)wr;
}

- (void)panPanel:(UIPanGestureRecognizer*)g {
    UIView *r=self.view;
    CGPoint d=[g translationInView:r];
    CGRect f=_panel.frame;
    f.origin.x=MAX(4,MIN(f.origin.x+d.x,r.bounds.size.width-f.size.width-4));
    f.origin.y=MAX(20,MIN(f.origin.y+d.y,r.bounds.size.height-f.size.height-20));
    _panel.frame=f;
    UIView *shd=[r viewWithTag:8800]; if(shd) shd.frame=f;
    [g setTranslation:CGPointZero inView:r];
}

- (void)buildHome:(LFPrefs*)p {
    UIView *home=[[UIView alloc]initWithFrame:CGRectMake(0,0,_pw,_ph)];
    home.tag=8900; home.userInteractionEnabled=YES;

    // Pill
    UIView *pill=[[UIView alloc]initWithFrame:CGRectMake((_pw-36)/2,8,36,4)];
    pill.backgroundColor=[UIColor colorWithWhite:1 alpha:.2f]; pill.layer.cornerRadius=2;
    [home addSubview:pill];

    // Title
    UILabel *ttl=LFLbl(@"LockFlow",18,UIFontWeightBold,[UIColor whiteColor],CGRectMake(0,20,_pw,24));
    ttl.textAlignment=NSTextAlignmentCenter; [home addSubview:ttl];
    UILabel *sub=LFLbl(@"by AldazDev",11,UIFontWeightRegular,[UIColor colorWithWhite:1 alpha:.3f],CGRectMake(0,44,_pw,14));
    sub.textAlignment=NSTextAlignmentCenter; [home addSubview:sub];

    // Sep gradient
    CAGradientLayer *hs=[CAGradientLayer layer]; hs.frame=CGRectMake(0,65,_pw,.5f);
    hs.colors=@[(id)[UIColor colorWithWhite:1 alpha:0].CGColor,(id)[UIColor colorWithWhite:1 alpha:.18f].CGColor,(id)[UIColor colorWithWhite:1 alpha:0].CGColor];
    hs.startPoint=CGPointMake(0,.5f); hs.endPoint=CGPointMake(1,.5f); [home.layer addSublayer:hs];

    // Close X
    UIButton *xBtn=[UIButton buttonWithType:UIButtonTypeCustom];
    xBtn.frame=CGRectMake(_pw-44,12,34,34); xBtn.layer.cornerRadius=17;
    xBtn.backgroundColor=[UIColor colorWithWhite:1 alpha:.08f];
    UILabel *xL=LFLbl(@"✕",13,UIFontWeightMedium,[UIColor colorWithWhite:1 alpha:.45f],CGRectMake(0,0,34,34));
    xL.textAlignment=NSTextAlignmentCenter; [xBtn addSubview:xL];
    [xBtn addTarget:self action:@selector(dismiss:) forControlEvents:UIControlEventTouchUpInside];
    [home addSubview:xBtn];

    CGFloat cy=80;
    __weak LFPanelController *ws=self;

    // ── Clock ──
    UIButton *c1=LFCard(@"Clock",@"clock.fill",@"Size, position, gradient color",cy,_pw,AC_CLOCK);
    [c1 addTarget:self action:@selector(openClock) forControlEvents:UIControlEventTouchUpInside];
    [home addSubview:c1]; cy+=66;

    // ── Date ──
    UIButton *c2=LFCard(@"Date",@"calendar",@"Format, position, gradient color",cy,_pw,AC_DATE);
    [c2 addTarget:self action:@selector(openDate) forControlEvents:UIControlEventTouchUpInside];
    [home addSubview:c2]; cy+=66;

    // ── Font ──
    UIButton *c3=LFCard(@"Font",@"textformat",@"Family and weight",cy,_pw,AC_FONT);
    [c3 addTarget:self action:@selector(openFont) forControlEvents:UIControlEventTouchUpInside];
    [home addSubview:c3]; cy+=66;

    // ── Notifications ──
    UIButton *c4=LFCard(@"Notifications",@"bell.badge.fill",@"Velvet style — border, glow, tint",cy,_pw,AC_NOTIF);
    [c4 addTarget:self action:@selector(openNotif) forControlEvents:UIControlEventTouchUpInside];
    [home addSubview:c4]; cy+=66;

    // ── MobileGestalt ──
    UIColor *acGestalt=[UIColor colorWithRed:1 green:.55f blue:.2f alpha:1];
    UIButton *c5=LFCard(@"MobileGestalt",@"cpu",@"Dynamic Island, AOD, AI & more",cy,_pw,acGestalt);
    [c5 addAction:[UIAction actionWithHandler:^(UIAction*a){
        extern void LFShowGestaltEditor(void);
        LFShowGestaltEditor();
    }] forControlEvents:UIControlEventTouchUpInside];
    [home addSubview:c5]; cy+=66;

    // ── Icon Themes ──
    UIColor *acTheme=[UIColor colorWithRed:.55f green:.3f blue:1 alpha:1];
    UIButton *c6=LFCard(@"Icon Themes",@"paintpalette.fill",@"Download & apply free icon packs",cy,_pw,acTheme);
    [c6 addAction:[UIAction actionWithHandler:^(UIAction*a){
        [ws openThemes];
    }] forControlEvents:UIControlEventTouchUpInside];
    [home addSubview:c6]; cy+=66;

    // ── Wallpaper ──
    UIColor *acWall=[UIColor colorWithRed:.10f green:.75f blue:.55f alpha:1];
    UIButton *c7=LFCard(@"Wallpaper",@"sparkles",@"Animated gradient wallpaper",cy,_pw,acWall);
    [c7 addAction:[UIAction actionWithHandler:^(UIAction*a){
        [ws openWallpaper];
    }] forControlEvents:UIControlEventTouchUpInside];
    [home addSubview:c7]; cy+=66;

    // ── Battery % toggle ──
    UIView *battRow=[[UIView alloc]initWithFrame:CGRectMake(12,cy,_pw-24,46)];
    battRow.backgroundColor=[UIColor colorWithWhite:1 alpha:.045f];
    battRow.layer.cornerRadius=14;
    if(@available(iOS 13.0,*))battRow.layer.cornerCurve=kCACornerCurveContinuous;
    if(@available(iOS 13.0,*)){
        UIImageSymbolConfiguration *cfg=[UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
        UIImageView *iv=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"battery.100" withConfiguration:cfg]];
        iv.frame=CGRectMake(16,13,22,22);iv.tintColor=[UIColor colorWithRed:.2f green:.8f blue:.4f alpha:1];
        iv.contentMode=UIViewContentModeScaleAspectFit;iv.userInteractionEnabled=NO;[battRow addSubview:iv];
    }
    UILabel *battLbl=[[UILabel alloc]initWithFrame:CGRectMake(48,5,_pw-24-110,20)];
    battLbl.text=@"Battery % Icon";battLbl.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    battLbl.textColor=[UIColor whiteColor];battLbl.userInteractionEnabled=NO;[battRow addSubview:battLbl];
    UILabel *battSub=[[UILabel alloc]initWithFrame:CGRectMake(48,25,_pw-24-110,14)];
    battSub.text=@"Show percent inside battery";battSub.font=[UIFont systemFontOfSize:11];
    battSub.textColor=[UIColor colorWithWhite:1 alpha:.38f];battSub.userInteractionEnabled=NO;[battRow addSubview:battSub];
    NSUserDefaults *bud=[[NSUserDefaults alloc]initWithSuiteName:@"com.aldazdev.lf2"];
    UISwitch *battSw=[[UISwitch alloc]init];
    battSw.on=[bud boolForKey:@"batteryPercentIcon"];
    battSw.onTintColor=[UIColor colorWithRed:.2f green:.8f blue:.4f alpha:1];
    battSw.center=CGPointMake(_pw-24-36,23);
    [battSw addAction:[UIAction actionWithHandler:^(UIAction*a){
        extern void LFSetBatteryPercentEnabled(BOOL);
        LFSetBatteryPercentEnabled(battSw.on);
    }] forControlEvents:UIControlEventValueChanged];
    [battRow addSubview:battSw];
    [home addSubview:battRow]; cy+=54;

    // Save button
    cy+=4;
    CAGradientLayer *bs=[CAGradientLayer layer]; bs.frame=CGRectMake(20,cy,_pw-40,.5f);
    bs.colors=@[(id)[UIColor colorWithWhite:1 alpha:0].CGColor,(id)[UIColor colorWithWhite:1 alpha:.15f].CGColor,(id)[UIColor colorWithWhite:1 alpha:0].CGColor];
    bs.startPoint=CGPointMake(0,.5f); bs.endPoint=CGPointMake(1,.5f); [home.layer addSublayer:bs];
    cy+=12;
    UIButton *sBtn=LFGBtn(@"Save & Apply",@"checkmark.circle.fill",
        @[[UIColor colorWithRed:0 green:.5f blue:1 alpha:.75f],[UIColor colorWithRed:0 green:.3f blue:.75f alpha:.6f]],
        CGRectMake(16,cy,_pw-32,44));
    [sBtn addTarget:self action:@selector(saveAll) forControlEvents:UIControlEventTouchUpInside];
    [home addSubview:sBtn]; cy+=56;

    // Wrappear el home en un scroll para que quepa todo aunque el panel sea más pequeño
    CGFloat headerH = 68; // pill + title + subtitle + sep
    UIScrollView *homeScroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0,headerH,_pw,_ph-headerH)];
    homeScroll.showsVerticalScrollIndicator = NO;
    homeScroll.bounces = YES;
    // Mover todos los subviews del home (excepto los del header) al scroll
    for (UIView *v in [home.subviews copy]) {
        if (v.frame.origin.y >= headerH) {
            CGRect f = v.frame;
            f.origin.y -= headerH;
            v.frame = f;
            [homeScroll addSubview:v];
        }
    }
    // Mover también los CALayers del home que estén en zona de contenido
    homeScroll.contentSize = CGSizeMake(_pw, cy - headerH + 12);
    [home addSubview:homeScroll];

    [_navContainer addSubview:home];
    (void)ws;
}

// ─── Navigation ───────────────────────────────────────────────────────────────
- (void)pushPage:(UIView*)pg {
    CGFloat pw=_pw;
    pg.frame=CGRectMake(pw,0,_navContainer.bounds.size.width,_navContainer.bounds.size.height);
    pg.tag=8900+(++_navDepth);
    pg.backgroundColor=[UIColor colorWithRed:.02f green:.02f blue:.08f alpha:1];
    [_navContainer addSubview:pg];
    [UIView animateWithDuration:.32f delay:0 usingSpringWithDamping:.88f initialSpringVelocity:.5f
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        for (UIView *v in self->_navContainer.subviews)
            if (v.tag>=8900 && v.tag<pg.tag)
                v.frame=CGRectMake(-pw*.3f,0,v.bounds.size.width,v.bounds.size.height);
        pg.frame=CGRectMake(0,0,self->_navContainer.bounds.size.width,self->_navContainer.bounds.size.height);
    } completion:^(BOOL d) {
        for (UIView *v in self->_navContainer.subviews)
            if (v.tag>=8900 && v.tag<pg.tag) v.hidden=YES;
    }];
}

- (void)popPage {
    CGFloat pw=_pw;
    UIView *cur=nil;
    for (UIView *v in _navContainer.subviews)
        if (v.tag==8900+_navDepth) { cur=v; break; }
    if (!cur) return;
    _navDepth--;
    UIView *prev=nil;
    for (UIView *v in _navContainer.subviews)
        if (v.tag==8900+_navDepth) { prev=v; break; }
    prev.hidden=NO;
    prev.frame=CGRectMake(-pw*.3f,0,pw,_ph);
    [UIView animateWithDuration:.28f delay:0 usingSpringWithDamping:.88f initialSpringVelocity:.5f
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        cur.frame=CGRectMake(pw,0,pw,self->_ph);
        prev.frame=CGRectMake(0,0,pw,self->_ph);
    } completion:^(BOOL d) { [cur removeFromSuperview]; }];
}

- (UIView*)makePage:(NSString*)title scrollView:(UIScrollView**)outScroll {
    UIView *pg=[[UIView alloc]initWithFrame:CGRectMake(0,0,_pw,_ph)];
    pg.userInteractionEnabled=YES;
    UIView *hdr=LFPgHdr(title,_pw);
    // Back button
    UIButton *back=[UIButton buttonWithType:UIButtonTypeCustom];
    back.frame=CGRectMake(4,6,60,36);
    if (@available(iOS 13.0,*)) {
        UIImageSymbolConfiguration *cfg=[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
        UIImageView *cv=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"chevron.left" withConfiguration:cfg]];
        cv.frame=CGRectMake(12,10,14,16); cv.tintColor=[UIColor colorWithRed:.6f green:.2f blue:1 alpha:1];
        cv.userInteractionEnabled=NO; [back addSubview:cv];
    }
    [back addTarget:self action:@selector(popPage) forControlEvents:UIControlEventTouchUpInside];
    [hdr addSubview:back];
    [pg addSubview:hdr];
    UIScrollView *sc=[[UIScrollView alloc]initWithFrame:CGRectMake(0,48,_pw,_ph-48)];
    sc.showsVerticalScrollIndicator=NO; sc.bounces=YES; [pg addSubview:sc];
    if (outScroll) *outScroll=sc;
    return pg;
}

// ─── Clock page ───────────────────────────────────────────────────────────────
- (void)openThemes {
    UIView *pg = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _pw, _ph)];
    pg.userInteractionEnabled = YES;
    pg.backgroundColor = [UIColor colorWithRed:.02f green:.02f blue:.08f alpha:1];

    // Header con back button
    UIView *hdr = LFPgHdr(@"Icon Themes", _pw);
    UIButton *back = [UIButton buttonWithType:UIButtonTypeCustom];
    back.frame = CGRectMake(10, 8, 36, 36);
    back.layer.cornerRadius = 18;
    back.backgroundColor = [UIColor colorWithWhite:1 alpha:.08f];
    if (@available(iOS 13,*)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration
            configurationWithPointSize:13 weight:UIImageSymbolWeightMedium];
        [back setImage:[[UIImage systemImageNamed:@"chevron.left"
                         withConfiguration:cfg]
                         imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
              forState:UIControlStateNormal];
        back.tintColor = [UIColor colorWithWhite:1 alpha:.7f];
    }
    [back addTarget:self action:@selector(popPage) forControlEvents:UIControlEventTouchUpInside];
    [hdr addSubview:back];
    [pg addSubview:hdr];

    // Contenido: scroll con las cards de temas
    extern UIScrollView *LFIPBuildThemesPage(CGFloat pageWidth);
    UIScrollView *sc = LFIPBuildThemesPage(_pw);
    sc.frame = CGRectMake(0, 48, _pw, _ph - 48);
    [pg addSubview:sc];

    [self pushPage:pg];
}

- (void)openWallpaper {
    UIView *pg = [[UIView alloc] initWithFrame:CGRectMake(0,0,_pw,_ph)];

    // Header
    UIView *hdr = [[UIView alloc] initWithFrame:CGRectMake(0,0,_pw,48)];
    UILabel *ttl = [[UILabel alloc] initWithFrame:CGRectMake(48,14,_pw-96,22)];
    ttl.text = @"Wallpaper"; ttl.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    ttl.textColor = [UIColor whiteColor]; ttl.textAlignment = NSTextAlignmentCenter;
    [hdr addSubview:ttl];
    UIButton *back = [UIButton buttonWithType:UIButtonTypeCustom];
    back.frame = CGRectMake(8,10,32,28);
    if (@available(iOS 13,*)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration
            configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
        [back setImage:[[UIImage systemImageNamed:@"chevron.left" withConfiguration:cfg]
            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        back.tintColor = [UIColor colorWithWhite:1 alpha:.7f];
    }
    [back addTarget:self action:@selector(popPage) forControlEvents:UIControlEventTouchUpInside];
    [hdr addSubview:back];
    [pg addSubview:hdr];

    extern UIScrollView *LFWallBuildPage(CGFloat pageWidth);
    UIScrollView *sc = LFWallBuildPage(_pw);
    sc.frame = CGRectMake(0, 48, _pw, _ph - 48);
    [pg addSubview:sc];

    [self pushPage:pg];
}

- (void)openClock {
    LFPrefs *p=LFPrefs.shared;
    UIScrollView *sc; UIView *pg=[self makePage:@"Clock" scrollView:&sc];
    CGFloat y=12,pad=16,cw=_pw-pad*2;
    UIColor *ac=AC_CLOCK;
    CGFloat sw2=[UIScreen mainScreen].bounds.size.width;
    CGFloat sh=[UIScreen mainScreen].bounds.size.height;

    // ── SIZE ──
    LFSecHdr(sc,@"SIZE",pad,y,cw);y+=22;
    UISlider *slSz=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];
    slSz.minimumValue=30;slSz.maximumValue=120;slSz.value=p.clockSize;slSz.minimumTrackTintColor=ac;
    [slSz addTarget:self action:@selector(clockSizeChanged:) forControlEvents:UIControlEventValueChanged];
    [sc addSubview:slSz];y+=38;

    // ── LAYOUT ──
    [sc addSubview:LFSep(pad,y,cw)];y+=10;
    LFSecHdr(sc,@"LAYOUT",pad,y,cw);y+=22;
    UISwitch *swSp=LFToggle(sc,@"Split hours / minutes",p.splitMode,pad,y,cw);y+=ROWH;
    [swSp addTarget:self action:@selector(splitChanged:) forControlEvents:UIControlEventValueChanged];
    NSArray *als=@[@"Center",@"Left",@"Right"]; CGFloat abw=cw/3;
    for (NSInteger i=0;i<3;i++){
        UIButton *ab=[UIButton buttonWithType:UIButtonTypeCustom];
        ab.frame=CGRectMake(pad+i*abw,y,abw-3,26);
        [ab setTitle:als[i] forState:UIControlStateNormal];
        ab.titleLabel.font=[UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        ab.layer.cornerRadius=8; ab.backgroundColor=[UIColor colorWithWhite:1 alpha:.1f];
        [ab setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        ab.tag=300+i; [sc addSubview:ab];
    }y+=34;

    // ── POSITION ──
    [sc addSubview:LFSep(pad,y,cw)];y+=10;
    LFSecHdr(sc,@"POSITION",pad,y,cw);y+=22;
    [sc addSubview:LFLbl(@"Horizontal (X)",10,UIFontWeightRegular,[UIColor colorWithWhite:1 alpha:.4f],CGRectMake(pad,y,cw,12))];y+=14;
    UISlider *slX=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];
    slX.minimumValue=0;slX.maximumValue=sw2;slX.value=p.clockPX>0?p.clockPX:sw2*.5f;slX.minimumTrackTintColor=ac;
    [slX addTarget:self action:@selector(clockXChanged:) forControlEvents:UIControlEventValueChanged];
    [sc addSubview:slX];y+=36;
    [sc addSubview:LFLbl(@"Vertical (Y)",10,UIFontWeightRegular,[UIColor colorWithWhite:1 alpha:.4f],CGRectMake(pad,y,cw,12))];y+=14;
    UISlider *slY=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];
    slY.minimumValue=60;slY.maximumValue=sh*.78f;slY.value=p.clockPY>0?p.clockPY:sh*.38f;slY.minimumTrackTintColor=ac;
    [slY addTarget:self action:@selector(clockYChanged:) forControlEvents:UIControlEventValueChanged];
    [sc addSubview:slY];y+=36;
    UIButton *resetBtn=[UIButton buttonWithType:UIButtonTypeCustom];
    resetBtn.frame=CGRectMake(pad,y,cw,32); resetBtn.backgroundColor=[UIColor colorWithWhite:1 alpha:.07f];
    resetBtn.layer.cornerRadius=9;
    [resetBtn setTitle:@"↺  Reset positions to default" forState:UIControlStateNormal];
    resetBtn.titleLabel.font=[UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [resetBtn setTitleColor:[UIColor colorWithWhite:1 alpha:.55f] forState:UIControlStateNormal];
    [resetBtn addAction:[UIAction actionWithHandler:^(UIAction *a){
        LFPrefs.shared.clockPX=-1;LFPrefs.shared.clockPY=-1;
        LFPrefs.shared.datePX=-1; LFPrefs.shared.datePY=-1;
        [LFPrefs.shared save]; slX.value=sw2*.5f; slY.value=sh*.38f; [LFClockPatcher refreshAll];
    }] forControlEvents:UIControlEventTouchUpInside];
    [sc addSubview:resetBtn];y+=44;

    // ── COLOR & GRADIENT ──
    [sc addSubview:LFSep(pad,y,cw)];y+=10;
    LFSecHdr(sc,@"COLOR",pad,y,cw);y+=22;

    // Solid color picker (iOS 14+)
    UIButton *clrBtn=[UIButton buttonWithType:UIButtonTypeCustom];
    clrBtn.frame=CGRectMake(pad,y,cw,40); clrBtn.backgroundColor=[UIColor colorWithWhite:1 alpha:.06f];
    clrBtn.layer.cornerRadius=11;
    UIView *clrSwatch=[[UIView alloc]initWithFrame:CGRectMake(cw-36,10,20,20)];
    clrSwatch.backgroundColor=p.clockColor; clrSwatch.layer.cornerRadius=6; clrSwatch.tag=6601;
    [clrBtn addSubview:clrSwatch];
    [clrBtn addSubview:LFLbl(@"Solid color",13,UIFontWeightMedium,[UIColor whiteColor],CGRectMake(14,10,cw-70,20))];
    clrBtn.tag=5001;
    [clrBtn addTarget:self action:@selector(colorBtnTap:) forControlEvents:UIControlEventTouchUpInside];
    [sc addSubview:clrBtn];y+=48;

    // Gradient toggle
    [sc addSubview:LFSep(pad,y,cw)];y+=10;
    LFSecHdr(sc,@"GRADIENT",pad,y,cw);y+=22;
    UISwitch *swG=LFToggle(sc,@"Enable gradient",p.clockGradient,pad,y,cw);y+=ROWH;
    [swG addAction:[UIAction actionWithHandler:^(UIAction *a){
        LFPrefs.shared.clockGradient=swG.on; [LFPrefs.shared save]; [LFClockPatcher refreshAll];
    }] forControlEvents:UIControlEventValueChanged];

    // Gradient preset buttons
    NSArray *gNames=@[@"Sunset",@"Ocean",@"Neon",@"Fire",@"Ice",@"Gold"];
    NSArray *gColors=@[
        [UIColor colorWithRed:1 green:.3f blue:.4f alpha:.9f],
        [UIColor colorWithRed:.1f green:.6f blue:1 alpha:.9f],
        [UIColor colorWithRed:.6f green:.1f blue:1 alpha:.9f],
        [UIColor colorWithRed:1 green:.4f blue:0 alpha:.9f],
        [UIColor colorWithRed:.5f green:.85f blue:1 alpha:.9f],
        [UIColor colorWithRed:1 green:.78f blue:.2f alpha:.9f],
    ];
    CGFloat gbw=cw/3;
    for (NSInteger i=0;i<6;i++){
        UIButton *gb=[UIButton buttonWithType:UIButtonTypeCustom];
        gb.frame=CGRectMake(pad+(i%3)*gbw,y+(i/3)*34,gbw-4,28);
        [gb setTitle:gNames[i] forState:UIControlStateNormal];
        gb.titleLabel.font=[UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        gb.layer.cornerRadius=8; gb.backgroundColor=gColors[i];
        gb.layer.borderWidth=p.clockGradientStyle==i?2:0;
        gb.layer.borderColor=[UIColor whiteColor].CGColor;
        [gb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        gb.tag=4000+i;
        NSInteger gi=i;
        [gb addAction:[UIAction actionWithHandler:^(UIAction *a){
            for(NSInteger j=0;j<6;j++){UIButton*o=(UIButton*)[sc viewWithTag:4000+j];o.layer.borderWidth=(j==gi)?2:0;}
            LFPrefs.shared.clockGradientStyle=(NSInteger)gi;
            LFPrefs.shared.clockGradient=YES; swG.on=YES;
            [LFPrefs.shared save]; [LFClockPatcher refreshAll];
        }] forControlEvents:UIControlEventTouchUpInside];
        [sc addSubview:gb];
    }y+=76;

    // Custom gradient color pickers
    UIButton *gc1=[UIButton buttonWithType:UIButtonTypeCustom];
    gc1.frame=CGRectMake(pad,y,(cw-8)/2,40); gc1.backgroundColor=[UIColor colorWithWhite:1 alpha:.06f];
    gc1.layer.cornerRadius=11;
    UIView *gc1s=[[UIView alloc]initWithFrame:CGRectMake((cw-8)/2-36,10,20,20)];
    gc1s.layer.cornerRadius=6; gc1s.tag=6611;
    gc1s.backgroundColor=p.clockGradColor1?:[UIColor colorWithRed:1 green:.3f blue:.4f alpha:1];
    [gc1 addSubview:gc1s];
    [gc1 addSubview:LFLbl(@"Color 1",12,UIFontWeightMedium,[UIColor whiteColor],CGRectMake(12,10,(cw-8)/2-50,20))];
    gc1.tag=5011;
    [gc1 addTarget:self action:@selector(colorBtnTap:) forControlEvents:UIControlEventTouchUpInside];
    [sc addSubview:gc1];

    UIButton *gc2=[UIButton buttonWithType:UIButtonTypeCustom];
    gc2.frame=CGRectMake(pad+(cw-8)/2+8,y,(cw-8)/2,40); gc2.backgroundColor=[UIColor colorWithWhite:1 alpha:.06f];
    gc2.layer.cornerRadius=11;
    UIView *gc2s=[[UIView alloc]initWithFrame:CGRectMake((cw-8)/2-36,10,20,20)];
    gc2s.layer.cornerRadius=6; gc2s.tag=6612;
    gc2s.backgroundColor=p.clockGradColor2?:[UIColor colorWithRed:.1f green:.6f blue:1 alpha:1];
    [gc2 addSubview:gc2s];
    [gc2 addSubview:LFLbl(@"Color 2",12,UIFontWeightMedium,[UIColor whiteColor],CGRectMake(12,10,(cw-8)/2-50,20))];
    gc2.tag=5012;
    [gc2 addTarget:self action:@selector(colorBtnTap:) forControlEvents:UIControlEventTouchUpInside];
    [sc addSubview:gc2];
    y+=48;

    sc.contentSize=CGSizeMake(_pw,y+20);
    [self pushPage:pg];
}

- (void)clockSizeChanged:(UISlider*)s { LFPrefs.shared.clockSize=roundf(s.value); [LFPrefs.shared save]; [LFClockPatcher refreshAll]; }
- (void)splitChanged:(UISwitch*)s     { LFPrefs.shared.splitMode=s.on;             [LFPrefs.shared save]; [LFClockPatcher refreshAll]; }
- (void)clockXChanged:(UISlider*)s    { LFPrefs.shared.clockPX=s.value;            [LFPrefs.shared save]; [LFClockPatcher refreshAll]; }
- (void)clockYChanged:(UISlider*)s    { LFPrefs.shared.clockPY=s.value;            [LFPrefs.shared save]; [LFClockPatcher refreshAll]; }



// ─── Date page ───────────────────────────────────────────────────────────────
- (void)openDate {
    LFPrefs *p=LFPrefs.shared;
    UIScrollView *sc; UIView *pg=[self makePage:@"Date" scrollView:&sc];
    CGFloat y=12,pad=16,cw=_pw-pad*2;
    UIColor *ac=AC_DATE;
    CGFloat sw2=[UIScreen mainScreen].bounds.size.width;
    CGFloat sh=[UIScreen mainScreen].bounds.size.height;

    // ── FORMAT ──
    LFSecHdr(sc,@"FORMAT",pad,y,cw);y+=22;
    NSArray *fmts=[LFPrefs dateFormatPreviews];
    CGFloat fbw=(cw-4)/2;
    for (NSInteger i=0;i<(NSInteger)fmts.count;i++){
        UIButton *fb=[UIButton buttonWithType:UIButtonTypeCustom];
        fb.frame=CGRectMake(pad+(i%2)*(fbw+4),y+(i/2)*34,fbw,28);
        [fb setTitle:fmts[i] forState:UIControlStateNormal];
        fb.titleLabel.font=[UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        fb.titleLabel.adjustsFontSizeToFitWidth=YES;
        fb.layer.cornerRadius=8;
        fb.backgroundColor=p.dateFormat==i?ac:[UIColor colorWithWhite:1 alpha:.1f];
        [fb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        fb.tag=500+i;
        [fb addTarget:self action:@selector(dateFmtTap:) forControlEvents:UIControlEventTouchUpInside];
        [sc addSubview:fb];
    }
    y+=((NSInteger)(fmts.count+1)/2)*34+12;

    // ── POSITION ──
    [sc addSubview:LFSep(pad,y,cw)];y+=10;
    LFSecHdr(sc,@"POSITION",pad,y,cw);y+=22;
    [sc addSubview:LFLbl(@"Horizontal (X)",10,UIFontWeightRegular,[UIColor colorWithWhite:1 alpha:.4f],CGRectMake(pad,y,cw,12))];y+=14;
    UISlider *slDX=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];
    slDX.minimumValue=0; slDX.maximumValue=sw2;
    slDX.value=p.datePX>0?p.datePX:sw2*.5f; slDX.minimumTrackTintColor=ac;
    [slDX addAction:[UIAction actionWithHandler:^(UIAction *a){
        LFPrefs.shared.datePX=slDX.value; [LFPrefs.shared save]; [LFClockPatcher refreshAll];
    }] forControlEvents:UIControlEventValueChanged];
    [sc addSubview:slDX];y+=36;
    [sc addSubview:LFLbl(@"Vertical (Y)",10,UIFontWeightRegular,[UIColor colorWithWhite:1 alpha:.4f],CGRectMake(pad,y,cw,12))];y+=14;
    UISlider *slDY=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];
    slDY.minimumValue=60; slDY.maximumValue=sh*.88f;
    slDY.value=p.datePY>0?p.datePY:sh*.44f; slDY.minimumTrackTintColor=ac;
    [slDY addAction:[UIAction actionWithHandler:^(UIAction *a){
        LFPrefs.shared.datePY=slDY.value; [LFPrefs.shared save]; [LFClockPatcher refreshAll];
    }] forControlEvents:UIControlEventValueChanged];
    [sc addSubview:slDY];y+=44;

    // ── COLOR & GRADIENT ──
    [sc addSubview:LFSep(pad,y,cw)];y+=10;
    LFSecHdr(sc,@"COLOR",pad,y,cw);y+=22;

    UIButton *dclr=[UIButton buttonWithType:UIButtonTypeCustom];
    dclr.frame=CGRectMake(pad,y,cw,40); dclr.backgroundColor=[UIColor colorWithWhite:1 alpha:.06f];
    dclr.layer.cornerRadius=11;
    UIView *dsw=[[UIView alloc]initWithFrame:CGRectMake(cw-36,10,20,20)];
    dsw.backgroundColor=p.dateColor; dsw.layer.cornerRadius=6;
    [dclr addSubview:dsw];
    [dclr addSubview:LFLbl(@"Solid color",13,UIFontWeightMedium,[UIColor whiteColor],CGRectMake(14,10,cw-70,20))];
    dclr.tag=5002;
    [dclr addTarget:self action:@selector(colorBtnTap:) forControlEvents:UIControlEventTouchUpInside];
    [sc addSubview:dclr];y+=48;

    // Gradient — usa el mismo gradient que el reloj (clockGradient / clockGradientStyle)
    [sc addSubview:LFSep(pad,y,cw)];y+=10;
    LFSecHdr(sc,@"GRADIENT (same as clock)",pad,y,cw);y+=22;
    UISwitch *swG=LFToggle(sc,@"Enable gradient",p.clockGradient,pad,y,cw);y+=ROWH;
    [swG addAction:[UIAction actionWithHandler:^(UIAction *a){
        LFPrefs.shared.clockGradient=swG.on; [LFPrefs.shared save]; [LFClockPatcher refreshAll];
    }] forControlEvents:UIControlEventValueChanged];
    UILabel *gNote=LFLbl(@"Configure gradient colors in the Clock page.",11,UIFontWeightRegular,
                         [UIColor colorWithWhite:1 alpha:.35f],CGRectMake(pad,y,cw,28));
    gNote.numberOfLines=2; [sc addSubview:gNote];y+=36;

    sc.contentSize=CGSizeMake(_pw,y+20);
    [self pushPage:pg];
}

- (void)dateFmtTap:(UIButton*)b {
    NSInteger i=b.tag-500;
    LFPrefs.shared.dateFormat=(LFDateFormat)i;
    UIScrollView *sc=(UIScrollView*)b.superview;
    NSArray *fmts=[LFPrefs dateFormatPreviews];
    for (NSInteger j=0;j<(NSInteger)fmts.count;j++) {
        UIButton *fb=(UIButton*)[sc viewWithTag:500+j];
        fb.backgroundColor=j==i?AC_DATE:[UIColor colorWithWhite:1 alpha:.1f];
    }
    [[LFWindowManager shared] refreshClock];
}

// ─── Font page ───────────────────────────────────────────────────────────────
- (void)openFont {
    LFPrefs *p=LFPrefs.shared;
    UIScrollView *sc; UIView *pg=[self makePage:@"Font" scrollView:&sc];
    CGFloat y=12,pad=16,cw=_pw-pad*2;

    LFSecHdr(sc,@"FAMILY",pad,y,cw);y+=22;
    LFFontRow(sc,pad,&y,cw,p.fontFamily,800);
    for (NSInteger i=0;i<8;i++) {
        UIButton *fb=(UIButton*)[sc viewWithTag:800+i];
        [fb addTarget:self action:@selector(fontFamTap:) forControlEvents:UIControlEventTouchUpInside];
    }

    [sc addSubview:LFSep(pad,y,cw)];y+=10;
    LFSecHdr(sc,@"WEIGHT",pad,y,cw);y+=22;
    NSArray *wts=@[@"Thin",@"Light",@"Regular",@"Medium",@"Bold"];
    CGFloat wbw=cw/5;
    for (NSInteger i=0;i<5;i++) {
        UIButton *wb=[UIButton buttonWithType:UIButtonTypeCustom];
        wb.frame=CGRectMake(pad+i*wbw,y,wbw-3,26);
        [wb setTitle:wts[i] forState:UIControlStateNormal];
        wb.titleLabel.font=[UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        wb.layer.cornerRadius=8;
        wb.backgroundColor=p.fontWeight==i?AC_FONT:[UIColor colorWithWhite:1 alpha:.1f];
        [wb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        wb.tag=900+i;
        [wb addTarget:self action:@selector(fontWeightTap:) forControlEvents:UIControlEventTouchUpInside];
        [sc addSubview:wb];
    }y+=34;

    [sc addSubview:LFSep(pad,y,cw)];y+=14;

    // ── Google Fonts ─────────────────────────────────────────────────────────
    LFSecHdr(sc,@"GOOGLE FONTS",pad,y,cw);y+=22;

    // Card de estado / botón de abrir el browser
    BOOL gfActive = LFGFIsActive();
    UIButton *gfBtn=[UIButton buttonWithType:UIButtonTypeCustom];
    gfBtn.frame=CGRectMake(pad,y,cw,54);
    gfBtn.backgroundColor=[UIColor colorWithWhite:1 alpha:gfActive?.10f:.04f];
    gfBtn.layer.cornerRadius=14;
    if(@available(iOS 13,*)) gfBtn.layer.cornerCurve=kCACornerCurveContinuous;
    gfBtn.layer.borderWidth=gfActive?2.f:0.f;
    gfBtn.layer.borderColor=[UIColor colorWithRed:.22f green:.55f blue:1 alpha:1].CGColor;
    if(@available(iOS 13,*)){
        UIImageSymbolConfiguration *cfg=[UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
        UIImageView *iv=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"textformat.alt" withConfiguration:cfg]];
        iv.frame=CGRectMake(16,15,22,22); iv.tintColor=[UIColor colorWithRed:.22f green:.55f blue:1 alpha:1]; iv.userInteractionEnabled=NO;
        [gfBtn addSubview:iv];
    }
    UILabel *gfLbl=[[UILabel alloc]initWithFrame:CGRectMake(48,8,cw-80,20)];
    gfLbl.text=@"Google Fonts Browser";
    gfLbl.font=[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    gfLbl.textColor=[UIColor whiteColor]; gfLbl.userInteractionEnabled=NO;
    [gfBtn addSubview:gfLbl];
    UILabel *gfSub=[[UILabel alloc]initWithFrame:CGRectMake(48,30,cw-80,16)];
    gfSub.text=gfActive?@"Google Font active — tap to change":@"Download any font from Google Fonts";
    gfSub.font=[UIFont systemFontOfSize:11];
    gfSub.textColor=gfActive?[UIColor colorWithRed:.2f green:.8f blue:.4f alpha:1]:[UIColor colorWithWhite:1 alpha:.35f];
    gfSub.userInteractionEnabled=NO;
    [gfBtn addSubview:gfSub];
    if(@available(iOS 13,*)){
        UIImageSymbolConfiguration *cfg=[UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightMedium];
        UIImageView *cv=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"chevron.right" withConfiguration:cfg]];
        cv.frame=CGRectMake(cw-28,20,14,14); cv.tintColor=[UIColor colorWithWhite:1 alpha:.22f]; cv.userInteractionEnabled=NO;
        [gfBtn addSubview:cv];
    }
    [gfBtn addTarget:self action:@selector(_openGoogleFonts) forControlEvents:UIControlEventTouchUpInside];
    [sc addSubview:gfBtn]; y+=64;

    sc.contentSize=CGSizeMake(_pw,y+20);
    [self pushPage:pg];
}

- (void)_openGoogleFonts {
    __weak typeof(self) ws = self;
    LFGFPresent(self, ^(NSString *family, NSString *ps) {
        // Re-render la font page para actualizar el estado
        dispatch_async(dispatch_get_main_queue(), ^{
            [ws popPage]; // vuelve al menú principal
            [ws openFont];    // re-abre Font con estado actualizado
        });
    });
}

- (void)fontFamTap:(UIButton*)b {
    NSInteger i=[objc_getAssociatedObject(b,"idx") integerValue];
    LFPrefs.shared.fontFamily=(LFFontFamily)i;
    UIScrollView *sc=(UIScrollView*)b.superview;
    for (NSInteger j=0;j<8;j++) {
        UIButton *fb=(UIButton*)[sc viewWithTag:800+j];
        fb.backgroundColor=j==i?AC_CLOCK:[UIColor colorWithWhite:1 alpha:.1f];
    }
    [[LFWindowManager shared] refreshClock];
}
- (void)fontWeightTap:(UIButton*)b {
    NSInteger i=b.tag-900;
    LFPrefs.shared.fontWeight=(NSInteger)i;
    UIScrollView *sc=(UIScrollView*)b.superview;
    for (NSInteger j=0;j<5;j++) {
        UIButton *fb=(UIButton*)[sc viewWithTag:900+j];
        fb.backgroundColor=j==i?AC_FONT:[UIColor colorWithWhite:1 alpha:.1f];
    }
    [[LFWindowManager shared] refreshClock];
}

// ─── Notif page — Velvet2 style ───────────────────────────────────────────────
- (void)openNotif {
    UIScrollView *sc; UIView *pg=[self makePage:@"Notifications" scrollView:&sc];
    CGFloat y=12, pad=16, cw=_pw-pad*2;
    UIColor *ac=AC_NOTIF;
    NSArray *presetColors = @[
        [UIColor colorWithWhite:1 alpha:0],                                    // Auto
        [UIColor colorWithRed:1   green:1   blue:1   alpha:1],                 // White
        [UIColor colorWithRed:.95f green:.25f blue:.3f  alpha:1],              // Red
        [UIColor colorWithRed:.2f  green:.6f  blue:1   alpha:1],               // Blue
        [UIColor colorWithRed:.15f green:.9f  blue:.5f  alpha:1],              // Green
        [UIColor colorWithRed:1   green:.8f  blue:0   alpha:1],                // Gold
        [UIColor colorWithRed:.75f green:.2f  blue:1   alpha:1],               // Purple
        [UIColor colorWithRed:1   green:.45f blue:.1f  alpha:1],               // Orange
    ];
    NSArray *presetNames = @[@"Auto",@"White",@"Red",@"Blue",@"Green",@"Gold",@"Purple",@"Orange"];

    // Helper: dibuja una fila de color swatches
    void (^colorRow)(UIScrollView*, NSString*, NSInteger, UIColor* __strong*, SEL) =
        ^(UIScrollView *s, NSString *title, NSInteger tagBase, UIColor * __strong *gRef, SEL colorSel) {
        UILabel *cap = LFLbl(title, 10, UIFontWeightSemibold,
                             [UIColor colorWithWhite:1 alpha:.38f], CGRectMake(pad,y,cw,12));
        [s addSubview:cap];
        CGFloat bw2 = cw / (CGFloat)presetColors.count;
        for (NSInteger i=0; i<(NSInteger)presetColors.count; i++) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            btn.frame = CGRectMake(pad + i*bw2, y+14, bw2-2, 24);
            btn.layer.cornerRadius = 7;
            if (@available(iOS 13.0,*)) btn.layer.cornerCurve = kCACornerCurveContinuous;
            if (i==0) {
                btn.backgroundColor = [UIColor colorWithWhite:1 alpha:.12f];
                btn.layer.borderWidth=.8f;
                btn.layer.borderColor=[UIColor colorWithWhite:1 alpha:.3f].CGColor;
                UILabel *al=LFLbl(@"A",10,UIFontWeightBold,[UIColor whiteColor],CGRectMake(0,0,bw2-2,24));
                al.textAlignment=NSTextAlignmentCenter; [btn addSubview:al];
            } else {
                btn.backgroundColor = [presetColors[i] colorWithAlphaComponent:.85f];
            }
            btn.tag = tagBase + i;
            UIColor *sel = presetColors[i];
            UIColor * __strong *ref = gRef;
            __weak UIScrollView *wsc = s;
            NSInteger tb = tagBase;
            [btn addAction:[UIAction actionWithHandler:^(UIAction *a) {
                for (NSInteger j=0; j<(NSInteger)presetColors.count; j++) {
                    UIView *o = [wsc viewWithTag:tb+j];
                    o.layer.borderWidth = (j==i)?2:.0f;
                    o.layer.borderColor = [UIColor whiteColor].CGColor;
                }
                if (ref) *ref = (i==0) ? nil : sel;
            }] forControlEvents:UIControlEventTouchUpInside];
            [s addSubview:btn];
        }
    };
    (void)colorRow; // suppress unused warning — used via block below

    // ── Enable ──
    LFSecHdr(sc, @"GENERAL", pad, y, cw); y+=22;
    UISwitch *swE = LFToggle(sc, @"Enable Velvet style", _notifEnabled, pad, y, cw); y+=ROWH;
    [swE addTarget:self action:@selector(notifEnChanged:) forControlEvents:UIControlEventValueChanged];

    UISwitch *swBd = LFToggle(sc, @"Bold title", _notifBold, pad, y, cw); y+=ROWH;
    [swBd addTarget:self action:@selector(notifBoldChanged:) forControlEvents:UIControlEventValueChanged];
    UISwitch *swI  = LFToggle(sc, @"Show app icon", _notifIcon, pad, y, cw); y+=ROWH;
    [swI addTarget:self action:@selector(notifIconChanged:) forControlEvents:UIControlEventValueChanged];

    [sc addSubview:LFSep(pad,y,cw)]; y+=12;
    LFSecHdr(sc, @"SIZE", pad, y, cw); y+=22;
    [sc addSubview:LFLbl(@"Corner radius",10,UIFontWeightRegular,[UIColor colorWithWhite:1 alpha:.4f],CGRectMake(pad,y,cw,12))]; y+=14;
    UISlider *slR=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];
    slR.minimumValue=4; slR.maximumValue=28; slR.value=_notifRadius; slR.minimumTrackTintColor=ac;
    [slR addTarget:self action:@selector(notifRadChanged:) forControlEvents:UIControlEventValueChanged];
    [sc addSubview:slR]; y+=38;
    [sc addSubview:LFLbl(@"Opacity",10,UIFontWeightRegular,[UIColor colorWithWhite:1 alpha:.4f],CGRectMake(pad,y,cw,12))]; y+=14;
    UISlider *slA=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];
    slA.minimumValue=.3f; slA.maximumValue=1; slA.value=_notifAlpha; slA.minimumTrackTintColor=ac;
    [slA addTarget:self action:@selector(notifAlphaChanged:) forControlEvents:UIControlEventValueChanged];
    [sc addSubview:slA]; y+=44;

    // ── BORDER ──
    [sc addSubview:LFSep(pad,y,cw)]; y+=12;
    LFSecHdr(sc,@"BORDER",pad,y,cw); y+=22;
    UISwitch *swBo = LFToggle(sc,@"Enable border",_borderEnabled,pad,y,cw); y+=ROWH;
    [swBo addTarget:self action:@selector(borderEnChanged:) forControlEvents:UIControlEventValueChanged];
    [sc addSubview:LFLbl(@"Thickness",10,UIFontWeightRegular,[UIColor colorWithWhite:1 alpha:.4f],CGRectMake(pad,y,cw,12))]; y+=14;
    UISlider *slBW=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];
    slBW.minimumValue=.5f; slBW.maximumValue=5; slBW.value=_borderWidth; slBW.minimumTrackTintColor=ac;
    [slBW addTarget:self action:@selector(borderWChanged:) forControlEvents:UIControlEventValueChanged];
    [sc addSubview:slBW]; y+=38;
    // Color swatches border
    [sc addSubview:LFLbl(@"COLOR — auto = icon color",10,UIFontWeightSemibold,[UIColor colorWithWhite:1 alpha:.38f],CGRectMake(pad,y,cw,12))]; y+=14;
    CGFloat sw2 = cw/(CGFloat)presetColors.count;
    for (NSInteger i=0;i<(NSInteger)presetColors.count;i++){
        UIButton *btn=[UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame=CGRectMake(pad+i*sw2,y,sw2-2,24); btn.layer.cornerRadius=7;
        if (i==0){btn.backgroundColor=[UIColor colorWithWhite:1 alpha:.12f];btn.layer.borderWidth=.8f;btn.layer.borderColor=[UIColor colorWithWhite:1 alpha:.3f].CGColor;UILabel*al=LFLbl(@"A",10,UIFontWeightBold,[UIColor whiteColor],CGRectMake(0,0,sw2-2,24));al.textAlignment=NSTextAlignmentCenter;[btn addSubview:al];}
        else{btn.backgroundColor=[presetColors[i] colorWithAlphaComponent:.85f];}
        btn.tag=2100+i;
        UIColor *sel=presetColors[i]; __weak LFPanelController *ws2=self; __weak UIScrollView *wsc=sc;
        [btn addAction:[UIAction actionWithHandler:^(UIAction*a){
            for(NSInteger j=0;j<(NSInteger)presetColors.count;j++){UIView*o=[wsc viewWithTag:2100+j];o.layer.borderWidth=(j==i)?2:0;o.layer.borderColor=[UIColor whiteColor].CGColor;}
            ws2.borderColor=(i==0)?nil:sel; [ws2 postVelvetUpdate];
        }] forControlEvents:UIControlEventTouchUpInside];
        [sc addSubview:btn];
    } y+=32;

    // ── BACKGROUND TINT ──
    [sc addSubview:LFSep(pad,y,cw)]; y+=12;
    LFSecHdr(sc,@"BACKGROUND TINT",pad,y,cw); y+=22;
    UISwitch *swBg=LFToggle(sc,@"Enable tint",_bgEnabled,pad,y,cw); y+=ROWH;
    [swBg addTarget:self action:@selector(bgEnChanged:) forControlEvents:UIControlEventValueChanged];
    [sc addSubview:LFLbl(@"Intensity",10,UIFontWeightRegular,[UIColor colorWithWhite:1 alpha:.4f],CGRectMake(pad,y,cw,12))]; y+=14;
    UISlider *slBgA=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];
    slBgA.minimumValue=.05f;slBgA.maximumValue=.7f;slBgA.value=_bgAlpha;slBgA.minimumTrackTintColor=ac;
    [slBgA addTarget:self action:@selector(bgAlphaChanged:) forControlEvents:UIControlEventValueChanged];
    [sc addSubview:slBgA]; y+=38;
    [sc addSubview:LFLbl(@"COLOR",10,UIFontWeightSemibold,[UIColor colorWithWhite:1 alpha:.38f],CGRectMake(pad,y,cw,12))]; y+=14;
    for (NSInteger i=0;i<(NSInteger)presetColors.count;i++){
        UIButton *btn=[UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame=CGRectMake(pad+i*sw2,y,sw2-2,24);btn.layer.cornerRadius=7;
        if(i==0){btn.backgroundColor=[UIColor colorWithWhite:1 alpha:.12f];btn.layer.borderWidth=.8f;btn.layer.borderColor=[UIColor colorWithWhite:1 alpha:.3f].CGColor;UILabel*al=LFLbl(@"A",10,UIFontWeightBold,[UIColor whiteColor],CGRectMake(0,0,sw2-2,24));al.textAlignment=NSTextAlignmentCenter;[btn addSubview:al];}
        else{btn.backgroundColor=[presetColors[i] colorWithAlphaComponent:.85f];}
        btn.tag=2200+i;
        UIColor *sel=presetColors[i];__weak LFPanelController *ws2=self;__weak UIScrollView *wsc=sc;
        [btn addAction:[UIAction actionWithHandler:^(UIAction*a){
            for(NSInteger j=0;j<(NSInteger)presetColors.count;j++){UIView*o=[wsc viewWithTag:2200+j];o.layer.borderWidth=(j==i)?2:0;o.layer.borderColor=[UIColor whiteColor].CGColor;}
            ws2.bgColor=(i==0)?nil:sel;[ws2 postVelvetUpdate];
        }] forControlEvents:UIControlEventTouchUpInside];
        [sc addSubview:btn];
    } y+=32;

    // ── GLOW ──
    [sc addSubview:LFSep(pad,y,cw)]; y+=12;
    LFSecHdr(sc,@"GLOW",pad,y,cw); y+=22;
    UISwitch *swSh=LFToggle(sc,@"Enable glow",_shadowEnabled,pad,y,cw); y+=ROWH;
    [swSh addTarget:self action:@selector(shadowEnChanged:) forControlEvents:UIControlEventValueChanged];
    [sc addSubview:LFLbl(@"Radius",10,UIFontWeightRegular,[UIColor colorWithWhite:1 alpha:.4f],CGRectMake(pad,y,cw,12))]; y+=14;
    UISlider *slSW=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];
    slSW.minimumValue=2;slSW.maximumValue=20;slSW.value=_shadowWidth;slSW.minimumTrackTintColor=ac;
    [slSW addTarget:self action:@selector(shadowWChanged:) forControlEvents:UIControlEventValueChanged];
    [sc addSubview:slSW]; y+=38;
    [sc addSubview:LFLbl(@"COLOR",10,UIFontWeightSemibold,[UIColor colorWithWhite:1 alpha:.38f],CGRectMake(pad,y,cw,12))]; y+=14;
    for (NSInteger i=0;i<(NSInteger)presetColors.count;i++){
        UIButton *btn=[UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame=CGRectMake(pad+i*sw2,y,sw2-2,24);btn.layer.cornerRadius=7;
        if(i==0){btn.backgroundColor=[UIColor colorWithWhite:1 alpha:.12f];btn.layer.borderWidth=.8f;btn.layer.borderColor=[UIColor colorWithWhite:1 alpha:.3f].CGColor;UILabel*al=LFLbl(@"A",10,UIFontWeightBold,[UIColor whiteColor],CGRectMake(0,0,sw2-2,24));al.textAlignment=NSTextAlignmentCenter;[btn addSubview:al];}
        else{btn.backgroundColor=[presetColors[i] colorWithAlphaComponent:.85f];}
        btn.tag=2300+i;
        UIColor *sel=presetColors[i];__weak LFPanelController *ws2=self;__weak UIScrollView *wsc=sc;
        [btn addAction:[UIAction actionWithHandler:^(UIAction*a){
            for(NSInteger j=0;j<(NSInteger)presetColors.count;j++){UIView*o=[wsc viewWithTag:2300+j];o.layer.borderWidth=(j==i)?2:0;o.layer.borderColor=[UIColor whiteColor].CGColor;}
            ws2.shadowColor=(i==0)?nil:sel;[ws2 postVelvetUpdate];
        }] forControlEvents:UIControlEventTouchUpInside];
        [sc addSubview:btn];
    } y+=32;

    // ── LINE ──
    [sc addSubview:LFSep(pad,y,cw)]; y+=12;
    LFSecHdr(sc,@"LINE ACCENT",pad,y,cw); y+=22;
    UISwitch *swLn=LFToggle(sc,@"Enable line",_lineEnabled,pad,y,cw); y+=ROWH;
    [swLn addTarget:self action:@selector(lineEnChanged:) forControlEvents:UIControlEventValueChanged];
    NSArray *lpos=@[@"Left",@"Right",@"Top",@"Bottom"];
    CGFloat lpw=cw/4;
    for (NSInteger i=0;i<4;i++){
        UIButton *lb=[UIButton buttonWithType:UIButtonTypeCustom];
        lb.frame=CGRectMake(pad+i*lpw,y,lpw-3,26);[lb setTitle:lpos[i] forState:UIControlStateNormal];
        lb.titleLabel.font=[UIFont systemFontOfSize:11 weight:UIFontWeightMedium];lb.layer.cornerRadius=8;
        lb.backgroundColor=_linePosition==i?ac:[UIColor colorWithWhite:1 alpha:.1f];
        [lb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];lb.tag=2400+i;
        NSInteger li=i;__weak LFPanelController *ws2=self;__weak UIScrollView *wsc=sc;
        [lb addAction:[UIAction actionWithHandler:^(UIAction*a){
            for(NSInteger j=0;j<4;j++)((UIButton*)[wsc viewWithTag:2400+j]).backgroundColor=[UIColor colorWithWhite:1 alpha:.1f];
            ((UIButton*)[wsc viewWithTag:2400+li]).backgroundColor=ac;
            ws2.linePosition=li;[ws2 postVelvetUpdate];
        }] forControlEvents:UIControlEventTouchUpInside];
        [sc addSubview:lb];
    } y+=34;
    [sc addSubview:LFLbl(@"Thickness",10,UIFontWeightRegular,[UIColor colorWithWhite:1 alpha:.4f],CGRectMake(pad,y,cw,12))]; y+=14;
    UISlider *slLW=[[UISlider alloc]initWithFrame:CGRectMake(pad,y,cw,28)];
    slLW.minimumValue=1;slLW.maximumValue=8;slLW.value=_lineWidth;slLW.minimumTrackTintColor=ac;
    [slLW addTarget:self action:@selector(lineWChanged:) forControlEvents:UIControlEventValueChanged];
    [sc addSubview:slLW]; y+=38;
    [sc addSubview:LFLbl(@"COLOR",10,UIFontWeightSemibold,[UIColor colorWithWhite:1 alpha:.38f],CGRectMake(pad,y,cw,12))]; y+=14;
    for (NSInteger i=0;i<(NSInteger)presetColors.count;i++){
        UIButton *btn=[UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame=CGRectMake(pad+i*sw2,y,sw2-2,24);btn.layer.cornerRadius=7;
        if(i==0){btn.backgroundColor=[UIColor colorWithWhite:1 alpha:.12f];btn.layer.borderWidth=.8f;btn.layer.borderColor=[UIColor colorWithWhite:1 alpha:.3f].CGColor;UILabel*al=LFLbl(@"A",10,UIFontWeightBold,[UIColor whiteColor],CGRectMake(0,0,sw2-2,24));al.textAlignment=NSTextAlignmentCenter;[btn addSubview:al];}
        else{btn.backgroundColor=[presetColors[i] colorWithAlphaComponent:.85f];}
        btn.tag=2500+i;
        UIColor *sel=presetColors[i];__weak LFPanelController *ws2=self;__weak UIScrollView *wsc=sc;
        [btn addAction:[UIAction actionWithHandler:^(UIAction*a){
            for(NSInteger j=0;j<(NSInteger)presetColors.count;j++){UIView*o=[wsc viewWithTag:2500+j];o.layer.borderWidth=(j==i)?2:0;o.layer.borderColor=[UIColor whiteColor].CGColor;}
            ws2.lineColor=(i==0)?nil:sel;[ws2 postVelvetUpdate];
        }] forControlEvents:UIControlEventTouchUpInside];
        [sc addSubview:btn];
    } y+=40;

    sc.contentSize=CGSizeMake(_pw,y+20);
    [self pushPage:pg];
}

- (void)postVelvetUpdate {
    // "ALGVelvetUpdateStyle" es el nombre que observan los hooks en Tweak.m
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ALGVelvetUpdateStyle" object:nil];
}

- (void)notifEnChanged:(UISwitch*)s    { _notifEnabled=s.on;  [self postVelvetUpdate]; }
- (void)notifRadChanged:(UISlider*)s   { _notifRadius=s.value; [self postVelvetUpdate]; }
- (void)notifAlphaChanged:(UISlider*)s { _notifAlpha=s.value;  [self postVelvetUpdate]; }
- (void)notifScaleChanged:(UISlider*)s { _notifScale=s.value; }
- (void)notifBlurChanged:(UISwitch*)s  { _notifBlur=s.on; }
- (void)notifBoldChanged:(UISwitch*)s  { _notifBold=s.on;  [self postVelvetUpdate]; }
- (void)notifIconChanged:(UISwitch*)s  { _notifIcon=s.on;  [self postVelvetUpdate]; }
- (void)borderEnChanged:(UISwitch*)s   { _borderEnabled=s.on; [self postVelvetUpdate]; }
- (void)borderWChanged:(UISlider*)s    { _borderWidth=s.value; [self postVelvetUpdate]; }
- (void)bgEnChanged:(UISwitch*)s       { _bgEnabled=s.on;     [self postVelvetUpdate]; }
- (void)bgAlphaChanged:(UISlider*)s    { _bgAlpha=s.value;    [self postVelvetUpdate]; }
- (void)shadowEnChanged:(UISwitch*)s   { _shadowEnabled=s.on; [self postVelvetUpdate]; }
- (void)shadowWChanged:(UISlider*)s    { _shadowWidth=s.value;[self postVelvetUpdate]; }
- (void)lineEnChanged:(UISwitch*)s     { _lineEnabled=s.on;   [self postVelvetUpdate]; }
- (void)lineWChanged:(UISlider*)s      { _lineWidth=s.value;  [self postVelvetUpdate]; }

// ─── Color picker ────────────────────────────────────────────────────────────
- (void)colorBtnTap:(UIButton*)b {
    if (@available(iOS 14.0,*)) {
        UIColorPickerViewController *cp=[[UIColorPickerViewController alloc]init];
        NSInteger t=b.tag;
        if      (t==5001) cp.selectedColor=LFPrefs.shared.clockColor;
        else if (t==5002) cp.selectedColor=LFPrefs.shared.dateColor;
        else if (t==5011) cp.selectedColor=LFPrefs.shared.clockGradColor1?:[UIColor colorWithRed:1 green:.3f blue:.4f alpha:1];
        else if (t==5012) cp.selectedColor=LFPrefs.shared.clockGradColor2?:[UIColor colorWithRed:.1f green:.6f blue:1 alpha:1];
        cp.supportsAlpha = NO;
        cp.delegate = self;
        objc_setAssociatedObject(self,"colorTarget",@(t),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self presentViewController:cp animated:YES completion:nil];
    }
}

// Llamado en tiempo real mientras el usuario mueve el selector
- (void)colorPickerViewController:(id)vc didSelectColor:(UIColor*)color continuously:(BOOL)continuously API_AVAILABLE(ios(14.0)) {
    [self applySelectedColor:color];
}

// Llamado al cerrar el picker
- (void)colorPickerViewControllerDidFinish:(id)vc {
    if (@available(iOS 14.0,*)) {
        UIColorPickerViewController *cp=(UIColorPickerViewController*)vc;
        [self applySelectedColor:cp.selectedColor];
    }
}

- (void)applySelectedColor:(UIColor*)color {
    NSInteger t=[objc_getAssociatedObject(self,"colorTarget") integerValue];
    if      (t==5001) { LFPrefs.shared.clockColor=color; }
    else if (t==5002) { LFPrefs.shared.dateColor=color; }
    else if (t==5011) { LFPrefs.shared.clockGradColor1=color; LFPrefs.shared.clockGradientStyle=6; LFPrefs.shared.clockGradient=YES; }
    else if (t==5012) { LFPrefs.shared.clockGradColor2=color; LFPrefs.shared.clockGradientStyle=6; LFPrefs.shared.clockGradient=YES; }
    [LFPrefs.shared save];
    [LFClockPatcher refreshAll];
}

// ─── Edit layout / Save ──────────────────────────────────────────────────────
- (void)editLayout {
    [[LFWindowManager shared] enterEditMode];
    [self dismiss:nil];
}

- (void)saveAll {
    [LFPrefs.shared save];

    NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:LF_SUITE];
    [ud setBool:_notifEnabled   forKey:@"notifEnabled"];
    [ud setFloat:_notifRadius   forKey:@"notifRadius"];
    [ud setFloat:_notifAlpha    forKey:@"notifAlpha"];
    [ud setBool:_notifBold      forKey:@"notifTitleBold"];
    [ud setBool:_notifIcon      forKey:@"notifShowIcon"];
    [ud setBool:_borderEnabled  forKey:@"borderEnabled"];
    [ud setFloat:_borderWidth   forKey:@"borderWidth"];
    [ud setFloat:_borderAlpha   forKey:@"borderAlpha"];
    [ud setBool:_bgEnabled      forKey:@"bgEnabled"];
    [ud setFloat:_bgAlpha       forKey:@"bgAlpha"];
    [ud setBool:_shadowEnabled  forKey:@"shadowEnabled"];
    [ud setFloat:_shadowWidth   forKey:@"shadowWidth"];
    [ud setBool:_lineEnabled    forKey:@"lineEnabled"];
    [ud setFloat:_lineWidth     forKey:@"lineWidth"];
    NSArray *lpos=@[@"left",@"right",@"top",@"bottom"];
    if (_linePosition>=0&&_linePosition<(NSInteger)lpos.count)
        [ud setObject:lpos[_linePosition] forKey:@"linePosition"];
    if (_borderColor){CGFloat r,g,b,a;[_borderColor getRed:&r green:&g blue:&b alpha:&a];[ud setFloat:r forKey:@"borderColorR"];[ud setFloat:g forKey:@"borderColorG"];[ud setFloat:b forKey:@"borderColorB"];}
    if (_bgColor){CGFloat r,g,b,a;[_bgColor getRed:&r green:&g blue:&b alpha:&a];[ud setFloat:r forKey:@"bgColorR"];[ud setFloat:g forKey:@"bgColorG"];[ud setFloat:b forKey:@"bgColorB"];}
    if (_shadowColor){CGFloat r,g,b,a;[_shadowColor getRed:&r green:&g blue:&b alpha:&a];[ud setFloat:r forKey:@"shadowColorR"];[ud setFloat:g forKey:@"shadowColorG"];[ud setFloat:b forKey:@"shadowColorB"];}
    if (_lineColor){CGFloat r,g,b,a;[_lineColor getRed:&r green:&g blue:&b alpha:&a];[ud setFloat:r forKey:@"lineColorR"];[ud setFloat:g forKey:@"lineColorG"];[ud setFloat:b forKey:@"lineColorB"];}
    [ud synchronize];

    if (@available(iOS 10.0,*)) [[UIImpactFeedbackGenerator new] impactOccurred];
    [[LFWindowManager shared] refreshClock];
    [self postVelvetUpdate];
    [self dismiss:nil];
}

// ─── Dismiss ─────────────────────────────────────────────────────────────────
- (void)dismiss:(id)s {
    UIView *dim=[self.view viewWithTag:9998];
    [UIView animateWithDuration:.22f animations:^{
        self->_panel.alpha=0;
        self->_panel.transform=CGAffineTransformMakeScale(.9f,.9f);
        dim.alpha=0;
    } completion:^(BOOL f) {
        [self.delegate panelDidDismiss];
    }];
}
@end
