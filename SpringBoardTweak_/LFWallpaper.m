// LFWallpaper.m — LockFlow2
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <CoreFoundation/CoreFoundation.h>
#define LF_SUITE @"com.aldazdev.lf2"

typedef struct { CGFloat r, g, b; } LFColor3;
typedef struct {
    const char *id; const char *title;
    LFColor3 colors[5]; LFColor3 bg;
} LFWallPreset;

static const LFWallPreset kLFPresets[] = {
    // Purple — violeta profundo, SIN blanco
    { "purple","Purple",
      {{0.55f,0.20f,0.80f},{0.70f,0.35f,0.88f},{0.48f,0.15f,0.75f},{0.65f,0.28f,0.85f},{0.58f,0.22f,0.82f}},
      {0.30f,0.08f,0.52f} },
    // Aurora — teal/verde oscuro
    { "aurora","Aurora",
      {{0.00f,0.58f,0.58f},{0.00f,0.68f,0.62f},{0.02f,0.50f,0.55f},{0.00f,0.72f,0.60f},{0.04f,0.55f,0.60f}},
      {0.00f,0.25f,0.30f} },
    // Starry — azul marino profundo
    { "starry","Starry",
      {{0.10f,0.18f,0.55f},{0.15f,0.25f,0.65f},{0.08f,0.14f,0.48f},{0.18f,0.28f,0.60f},{0.12f,0.20f,0.58f}},
      {0.04f,0.06f,0.25f} },
    // Neon — magenta/cyan profundo
    { "neon","Neon",
      {{0.75f,0.00f,0.75f},{0.00f,0.75f,0.72f},{0.60f,0.00f,0.80f},{0.00f,0.60f,0.80f},{0.80f,0.00f,0.60f}},
      {0.08f,0.00f,0.20f} },
    // Sunset — naranja/magenta
    { "sunset","Sunset",
      {{0.90f,0.30f,0.10f},{0.85f,0.15f,0.35f},{0.92f,0.50f,0.05f},{0.75f,0.10f,0.45f},{0.88f,0.35f,0.20f}},
      {0.35f,0.04f,0.10f} },
    // Ocean — azul profundo
    { "ocean","Ocean",
      {{0.05f,0.40f,0.85f},{0.05f,0.60f,0.88f},{0.03f,0.30f,0.75f},{0.08f,0.65f,0.82f},{0.04f,0.48f,0.88f}},
      {0.02f,0.12f,0.42f} },
    // Sakura — rosa profundo
    { "sakura","Sakura",
      {{0.88f,0.35f,0.58f},{0.82f,0.28f,0.65f},{0.90f,0.42f,0.55f},{0.85f,0.30f,0.62f},{0.88f,0.38f,0.60f}},
      {0.40f,0.08f,0.28f} },
    // Forest — verde profundo
    { "forest","Forest",
      {{0.10f,0.55f,0.25f},{0.08f,0.48f,0.35f},{0.15f,0.60f,0.20f},{0.06f,0.45f,0.30f},{0.12f,0.52f,0.28f}},
      {0.02f,0.18f,0.08f} },
    // Midnight — indigo oscuro
    { "midnight","Midnight",
      {{0.25f,0.15f,0.65f},{0.35f,0.20f,0.72f},{0.20f,0.10f,0.60f},{0.30f,0.18f,0.68f},{0.28f,0.14f,0.64f}},
      {0.06f,0.04f,0.24f} },
    // Lava — rojo volcánico
    { "lava","Lava",
      {{0.85f,0.15f,0.05f},{0.90f,0.35f,0.02f},{0.80f,0.10f,0.08f},{0.88f,0.28f,0.04f},{0.84f,0.20f,0.06f}},
      {0.28f,0.03f,0.02f} },
    // Winter — azul frio oscuro
    { "winter","Winter",
      {{0.40f,0.58f,0.90f},{0.50f,0.70f,0.95f},{0.35f,0.52f,0.88f},{0.55f,0.72f,0.92f},{0.42f,0.62f,0.90f}},
      {0.12f,0.20f,0.50f} },
    // China Red — rojo intenso
    { "chinared","China Red",
      {{0.88f,0.10f,0.10f},{0.92f,0.20f,0.08f},{0.82f,0.08f,0.15f},{0.90f,0.25f,0.10f},{0.85f,0.12f,0.12f}},
      {0.30f,0.02f,0.02f} },
};
static const int kLFPresetCount = (int)(sizeof(kLFPresets)/sizeof(kLFPresets[0]));

static BOOL     gWallEnabled    = NO;
static NSString *gWallPresetID  = nil;
static CGFloat  gWallSpeed      = 1.0f;
static BOOL     gWallHomescreen = YES;
static BOOL     gWallLockscreen = YES;

static void LFWallLoadPrefs(void) {
    NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:LF_SUITE];
    gWallEnabled    = [ud objectForKey:@"wallEnabled"]  ? [ud boolForKey:@"wallEnabled"]  : NO;
    gWallPresetID   = [ud stringForKey:@"wallPresetID"] ?: @"aurora";
    gWallSpeed      = [ud objectForKey:@"wallSpeed"]    ? [ud floatForKey:@"wallSpeed"]   : 1.0f;
    gWallHomescreen = [ud objectForKey:@"wallHome"]     ? [ud boolForKey:@"wallHome"]     : YES;
    gWallLockscreen = [ud objectForKey:@"wallLock"]     ? [ud boolForKey:@"wallLock"]     : YES;
}
static void LFWallSavePrefs(void) {
    NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:LF_SUITE];
    [ud setBool:gWallEnabled forKey:@"wallEnabled"];
    [ud setObject:gWallPresetID forKey:@"wallPresetID"];
    [ud setFloat:gWallSpeed forKey:@"wallSpeed"];
    [ud setBool:gWallHomescreen forKey:@"wallHome"];
    [ud setBool:gWallLockscreen forKey:@"wallLock"];
    [ud synchronize];
}
static const LFWallPreset *LFWallFindPreset(NSString *pid) {
    if (!pid) return &kLFPresets[0];
    for (int i=0;i<kLFPresetCount;i++)
        if (strcmp(kLFPresets[i].id,pid.UTF8String)==0) return &kLFPresets[i];
    return &kLFPresets[0];
}

// ─── LFLiquidView ────────────────────────────────────────────────────────────
#define LF_BLOB_N 5

@interface LFLiquidView : UIView {
    CAGradientLayer    *_blobs[LF_BLOB_N];
    const LFWallPreset *_preset;
    CGFloat             _speed;
}
- (void)applyPreset:(const LFWallPreset *)preset speed:(CGFloat)spd;
- (void)stopAnimation;
@end

@implementation LFLiquidView

- (instancetype)initWithFrame:(CGRect)frame {
    self=[super initWithFrame:frame]; if(!self) return nil;
    self.clipsToBounds=YES;
    for(int i=0;i<LF_BLOB_N;i++){
        CAGradientLayer *gl=[CAGradientLayer layer];
        gl.type=kCAGradientLayerRadial;
        gl.startPoint=CGPointMake(0.5f,0.5f);
        gl.endPoint=CGPointMake(1.0f,1.0f);
        [self.layer addSublayer:gl];
        _blobs[i]=gl;
    }
    return self;
}

- (void)applyPreset:(const LFWallPreset *)preset speed:(CGFloat)spd {
    _preset=preset; _speed=spd;
    CGFloat w=self.bounds.size.width, h=self.bounds.size.height;
    if(w<10) w=[UIScreen mainScreen].bounds.size.width;
    if(h<10) h=[UIScreen mainScreen].bounds.size.height;

    // Fondo oscuro/saturado del preset — NUNCA blanco
    self.backgroundColor=[UIColor colorWithRed:preset->bg.r green:preset->bg.g blue:preset->bg.b alpha:1.0f];

    // Blobs enormes (120-150% pantalla) — se superponen formando la mezcla líquida
    static const CGFloat scales[LF_BLOB_N]={1.40f,1.28f,1.50f,1.22f,1.35f};
    // Alpha alto en centro + fade suave a 0 → blob visible sobre fondo oscuro
    // Alpha reducido → el fondo oscuro se ve más entre blobs = efecto líquido profundo
    static const float   aCenter[LF_BLOB_N]={0.78f,0.72f,0.75f,0.70f,0.74f};
    static const float   aMid[LF_BLOB_N]   ={0.30f,0.26f,0.28f,0.24f,0.27f};

    for(int i=0;i<LF_BLOB_N;i++){
        LFColor3 c=preset->colors[i];
        CGFloat dim=MAX(w,h)*scales[i];
        [CATransaction begin]; [CATransaction setDisableActions:YES];
        _blobs[i].frame=CGRectMake(w*.5f-dim*.5f, h*.5f-dim*.5f, dim, dim);
        // 4 stops → nube suave sin borde duro
        UIColor *c0=[UIColor colorWithRed:c.r green:c.g blue:c.b alpha:aCenter[i]];
        UIColor *c1=[UIColor colorWithRed:c.r green:c.g blue:c.b alpha:aMid[i]];
        UIColor *c2=[UIColor colorWithRed:c.r green:c.g blue:c.b alpha:0.05f];
        UIColor *c3=[UIColor colorWithRed:c.r green:c.g blue:c.b alpha:0.00f];
        _blobs[i].colors=@[(id)c0.CGColor,(id)c1.CGColor,(id)c2.CGColor,(id)c3.CGColor];
        _blobs[i].locations=@[@0.0f,@0.28f,@0.62f,@1.0f];
        [CATransaction commit];
        [_blobs[i] removeAllAnimations];
        [self _startBlob:i w:w h:h];
    }
}

- (void)_startBlob:(int)idx w:(CGFloat)w h:(CGFloat)h {
    // Trayectorias lissajous con frecuencias irracionales → movimiento orgánico nunca repetitivo
    static const CGFloat fX[LF_BLOB_N]={1.00f,0.83f,1.17f,0.67f,1.33f};
    static const CGFloat fY[LF_BLOB_N]={0.91f,1.13f,0.77f,1.29f,0.87f};
    static const CGFloat bX[LF_BLOB_N]={0.50f,0.22f,0.78f,0.38f,0.65f};
    static const CGFloat bY[LF_BLOB_N]={0.42f,0.68f,0.28f,0.20f,0.78f};
    CGFloat phase=idx*(M_PI*2.0f/LF_BLOB_N);
    CGFloat ampX=w*0.45f, ampY=h*0.42f;
    CGFloat cx=w*bX[idx], cy=h*bY[idx];
    int K=16;
    NSMutableArray *pos=[NSMutableArray arrayWithCapacity:K+1];
    for(int k=0;k<K;k++){
        CGFloat t=(CGFloat)k/K*M_PI*2.0f;
        CGFloat px=cx+ampX*sinf(fX[idx]*t+phase);
        CGFloat py=cy+ampY*cosf(fY[idx]*t+phase*0.7f);
        [pos addObject:[NSValue valueWithCGPoint:CGPointMake(px,py)]];
    }
    [pos addObject:pos.firstObject];
    CAKeyframeAnimation *aPos=[CAKeyframeAnimation animationWithKeyPath:@"position"];
    aPos.values=pos;
    aPos.duration=(28.0+idx*6.0)/_speed;
    aPos.repeatCount=HUGE_VALF;
    aPos.calculationMode=kCAAnimationCubicPaced;
    aPos.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    CAKeyframeAnimation *aS=[CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    aS.values=@[@1.0f,@1.08f,@0.94f,@1.05f,@0.97f,@1.0f];
    aS.duration=(18.0+idx*4.0)/_speed;
    aS.repeatCount=HUGE_VALF;
    aS.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_blobs[idx] addAnimation:aPos forKey:@"pos"];
    [_blobs[idx] addAnimation:aS   forKey:@"scale"];
}

- (void)stopAnimation { for(int i=0;i<LF_BLOB_N;i++) [_blobs[i] removeAllAnimations]; }

- (void)layoutSubviews {
    [super layoutSubviews];
    if(_preset && self.bounds.size.width>10) [self applyPreset:_preset speed:_speed];
}

@end

// ─── Gestor de instancias ────────────────────────────────────────────────────
static NSMutableArray *gWallViews=nil;

static LFLiquidView *LFWallFindIn(UIView *v){
    for(UIView *sv in v.subviews)
        if([sv isKindOfClass:[LFLiquidView class]]) return (LFLiquidView*)sv;
    return nil;
}

static void LFWallInstall(UIView *targetView){
    if(!targetView || targetView.bounds.size.width<10) return;
    LFLiquidView *lv=LFWallFindIn(targetView);
    if(!gWallEnabled){
        if(lv){[lv stopAnimation];[lv removeFromSuperview];[gWallViews removeObject:lv];}
        return;
    }
    if(!lv){
        lv=[[LFLiquidView alloc] initWithFrame:targetView.bounds];
        lv.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        lv.userInteractionEnabled=NO;
        [targetView insertSubview:lv atIndex:0];
        if(!gWallViews) gWallViews=[NSMutableArray array];
        [gWallViews addObject:lv];
    }
    [lv applyPreset:LFWallFindPreset(gWallPresetID) speed:gWallSpeed];
}

static void LFWallRemoveAll(void){
    for(LFLiquidView *v in gWallViews){[v stopAnimation];[v removeFromSuperview];}
    [gWallViews removeAllObjects];
}

static void LFWallRefreshAll(void){
    LFWallLoadPrefs();
    if(!gWallEnabled){LFWallRemoveAll();return;}
    const LFWallPreset *p=LFWallFindPreset(gWallPresetID);
    for(LFLiquidView *v in gWallViews) [v applyPreset:p speed:gWallSpeed];
}

// ─── Hooks ───────────────────────────────────────────────────────────────────
//
// LOCKSCREEN → NSNotification "LFWallApplyLS" → LFLiquidView atIndex:0 en self.view LS VC.
//
// HOMESCREEN → UIWindow dedicada con windowLevel = -2.
//              SpringBoard renderiza sus windows en orden de windowLevel.
//              El wallpaper nativo vive en una window con level muy negativo.
//              Nuestra window con level -2 se inserta ENCIMA del wallpaper nativo
//              pero DEBAJO de la window de iconos (level 0+).
//              backgroundColor = clearColor → el blur/material de SpringBoard
//              aplica normalmente por encima.
//              NO llamamos SBSUIWallpaperSetImages en loop (causa flash).

// ─── HS: igual que Stellar tweak — SBIconController.view.layer ───────────────
// SBIconController es el VC que maneja todos los iconos del homescreen.
// Su self.view ES la vista sobre el wallpaper. Insertamos LFLiquidView
// atIndex:0 para que quede DETRÁS de los iconos pero ENCIMA del wallpaper nativo.
// Mismo patrón que Stellar usa para su CAEmitterLayer de nieve.

static LFLiquidView *gWallHSView   = nil;
static UIView       *gWallHSCanvas = nil;

static void LFWallInstallHS(void) {
    if (!gWallEnabled || !gWallHomescreen) return;
    if (!gWallHSCanvas) return;
    
    // Buscar si ya existe una instancia
    LFLiquidView *existing = nil;
    for (UIView *sv in gWallHSCanvas.subviews)
        if ([sv isKindOfClass:[LFLiquidView class]]) { existing=(LFLiquidView*)sv; break; }

    if (!existing) {
        gWallHSView = [[LFLiquidView alloc] initWithFrame:gWallHSCanvas.bounds];
        gWallHSView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        gWallHSView.userInteractionEnabled = NO;
        [gWallHSCanvas insertSubview:gWallHSView atIndex:0];
        NSLog(@"[LF2:Wall] HS LFLiquidView installed in %@", gWallHSCanvas.class);
    } else {
        gWallHSView = existing;
    }
    const LFWallPreset *p = LFWallFindPreset(gWallPresetID);
    [gWallHSView applyPreset:p speed:gWallSpeed];
}

static void LFWallRemoveHS(void) {
    if (gWallHSView) {
        [gWallHSView stopAnimation];
        [gWallHSView removeFromSuperview];
        gWallHSView = nil;
    }
    gWallHSCanvas = nil;
}

// LS: via NSNotification desde Tweak.m
static void LFWallHandleLSNotif(NSNotification *n){
    if(!gWallEnabled||!gWallLockscreen) return;
    UIView *v=n.object;
    if(![v isKindOfClass:[UIView class]]) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.05*NSEC_PER_SEC)),
                   dispatch_get_main_queue(),^{ LFWallInstall(v); });
}

// ─── SBIconController hooks (mismo patrón que Stellar) ───────────────────────
static IMP orig_iconCtrlLoad    = NULL;
static IMP orig_iconCtrlAppear  = NULL;
static IMP orig_iconCtrlDisappear = NULL;

static void hooked_iconCtrlLoad(UIViewController *self, SEL _cmd) {
    if (orig_iconCtrlLoad) ((void(*)(id,SEL))orig_iconCtrlLoad)(self, _cmd);
    // Guardar la view del SBIconController — es el canvas correcto
    gWallHSCanvas = self.view;
    NSLog(@"[LF2:Wall] SBIconController viewDidLoad, canvas=%@", self.view.class);
    if (!gWallEnabled || !gWallHomescreen) return;
    LFWallInstallHS();
}

static void hooked_iconCtrlAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_iconCtrlAppear) ((void(*)(id,SEL,BOOL))orig_iconCtrlAppear)(self, _cmd, animated);
    gWallHSCanvas = self.view;
    if (!gWallEnabled || !gWallHomescreen) return;
    // Reanudar animación si fue pausada (igual que Stellar resume)
    if (gWallHSView) [gWallHSView applyPreset:LFWallFindPreset(gWallPresetID) speed:gWallSpeed];
    else LFWallInstallHS();
}

static void hooked_iconCtrlDisappear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_iconCtrlDisappear) ((void(*)(id,SEL,BOOL))orig_iconCtrlDisappear)(self, _cmd, animated);
    // Pausar animaciones para ahorrar batería (igual que Stellar pause)
    if (gWallHSView) [gWallHSView stopAnimation];
}

static void LFWallDarwinCB(CFNotificationCenterRef c,void *o,CFStringRef n,const void *ob,CFDictionaryRef u){
    dispatch_async(dispatch_get_main_queue(),^{
        LFWallLoadPrefs();
        if (!gWallEnabled) {
            LFWallRemoveAll();
            LFWallRemoveHS();
            return;
        }
        LFWallRefreshAll();
        if (gWallHomescreen) {
            if (gWallHSView) {
                [gWallHSView applyPreset:LFWallFindPreset(gWallPresetID) speed:gWallSpeed];
            } else {
                LFWallInstallHS();
            }
        } else {
            LFWallRemoveHS();
        }
    });
}

void LFWallInit(void){
    LFWallLoadPrefs();
    if (!gWallViews) gWallViews = [NSMutableArray array];

    // LS via NSNotification
    [[NSNotificationCenter defaultCenter]
        addObserverForName:@"LFWallApplyLS" object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *n){ LFWallHandleLSNotif(n); }];

    // HS — hookear SBIconController igual que Stellar hookea para su nieve
    // SBIconController maneja la vista de iconos del homescreen en todos los iOS 13-17
    const char *iconCtrlClasses[] = {"SBIconController", NULL};
    for (int i = 0; iconCtrlClasses[i]; i++) {
        Class cls = objc_getClass(iconCtrlClasses[i]); if (!cls) continue;

        // viewDidLoad — primer setup (como Stellar)
        Method mLoad = class_getInstanceMethod(cls, @selector(viewDidLoad));
        if (mLoad && !orig_iconCtrlLoad) {
            orig_iconCtrlLoad = method_getImplementation(mLoad);
            method_setImplementation(mLoad, (IMP)hooked_iconCtrlLoad);
        }
        // viewWillAppear — resume (como Stellar)
        Method mAppear = class_getInstanceMethod(cls, @selector(viewWillAppear:));
        if (mAppear && !orig_iconCtrlAppear) {
            orig_iconCtrlAppear = method_getImplementation(mAppear);
            method_setImplementation(mAppear, (IMP)hooked_iconCtrlAppear);
        }
        // viewWillDisappear — pause (como Stellar)
        Method mDisappear = class_getInstanceMethod(cls, @selector(viewWillDisappear:));
        if (mDisappear && !orig_iconCtrlDisappear) {
            orig_iconCtrlDisappear = method_getImplementation(mDisappear);
            method_setImplementation(mDisappear, (IMP)hooked_iconCtrlDisappear);
        }
        if (orig_iconCtrlLoad) NSLog(@"[LF2:Wall] hooked SBIconController");
        break;
    }

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
        NULL, LFWallDarwinCB, CFSTR("com.aldazdev.lf2/wall.changed"),
        NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

    NSLog(@"[LF2:Wall] init enabled=%d preset=%@", gWallEnabled, gWallPresetID);
}

// ─── UI del panel ────────────────────────────────────────────────────────────
@interface LFWallPresetCard : UIView
@property (strong) LFLiquidView *preview;
@property (strong) NSString     *presetID;
@property (copy)   void(^onTap)(LFWallPresetCard *);
@property (nonatomic) BOOL isActive;
@property (weak) UIView   *selBorder;
@property (weak) UILabel  *statusLabel;
@end
@implementation LFWallPresetCard
- (instancetype)initWithPreset:(const LFWallPreset *)preset isActive:(BOOL)active width:(CGFloat)w onTap:(void(^)(LFWallPresetCard *))onTap {
    self=[super initWithFrame:CGRectMake(0,0,w,88)]; if(!self) return nil;
    self.presetID=[NSString stringWithUTF8String:preset->id];
    self.isActive=active; self.onTap=onTap;
    self.backgroundColor=[UIColor colorWithWhite:1 alpha:active?.10f:.04f];
    self.layer.cornerRadius=16;
    if(@available(iOS 13,*)) self.layer.cornerCurve=kCACornerCurveContinuous;
    UIView *brd=[[UIView alloc]initWithFrame:self.bounds]; brd.layer.cornerRadius=16;
    if(@available(iOS 13,*)) brd.layer.cornerCurve=kCACornerCurveContinuous;
    brd.layer.borderWidth=active?2.f:0.f;
    brd.layer.borderColor=[UIColor colorWithRed:.22f green:.55f blue:1 alpha:1].CGColor;
    brd.userInteractionEnabled=NO; [self addSubview:brd]; self.selBorder=brd;
    LFLiquidView *prev=[[LFLiquidView alloc]initWithFrame:CGRectMake(12,12,64,64)];
    prev.layer.cornerRadius=12;
    if(@available(iOS 13,*)) prev.layer.cornerCurve=kCACornerCurveContinuous;
    prev.clipsToBounds=YES; prev.userInteractionEnabled=NO;
    [prev applyPreset:preset speed:1.5f]; [self addSubview:prev]; self.preview=prev;
    UILabel *nm=[[UILabel alloc]initWithFrame:CGRectMake(88,18,w-100,22)];
    nm.text=[NSString stringWithUTF8String:preset->title];
    nm.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    nm.textColor=[UIColor whiteColor]; nm.userInteractionEnabled=NO; [self addSubview:nm];
    UILabel *st=[[UILabel alloc]initWithFrame:CGRectMake(88,44,w-100,16)];
    st.text=active?@"● Active":@"";
    st.font=[UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    st.textColor=active?[UIColor colorWithRed:.2f green:.8f blue:.4f alpha:1]:[UIColor colorWithWhite:1 alpha:.25f];
    st.tag=9901; st.userInteractionEnabled=NO; [self addSubview:st]; self.statusLabel=st;
    [self addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(_tap)]];
    return self;
}
-(void)_tap{if(self.onTap)self.onTap(self);}
-(void)setIsActive:(BOOL)a{
    _isActive=a;
    self.backgroundColor=[UIColor colorWithWhite:1 alpha:a?.10f:.04f];
    self.selBorder.layer.borderWidth=a?2.f:0.f;
    self.statusLabel.text=a?@"● Active":@"";
    self.statusLabel.textColor=a?[UIColor colorWithRed:.2f green:.8f blue:.4f alpha:1]:[UIColor colorWithWhite:1 alpha:.25f];
}
-(void)dealloc{[self.preview stopAnimation];}
@end

UIScrollView *LFWallBuildPage(CGFloat pageWidth){
    LFWallLoadPrefs();
    UIScrollView *sc=[[UIScrollView alloc]initWithFrame:CGRectZero];
    sc.showsVerticalScrollIndicator=NO; sc.bounces=YES;
    CGFloat pad=12,gap=10,cw=pageWidth-pad*2,y=pad;
    NSMutableArray<LFWallPresetCard*> *cards=[NSMutableArray array];
    UIColor *ac=[UIColor colorWithRed:.22f green:.55f blue:1 alpha:1];

    UIView *tr=[[UIView alloc]initWithFrame:CGRectMake(pad,y,cw,44)];
    tr.backgroundColor=[UIColor colorWithWhite:1 alpha:.05f]; tr.layer.cornerRadius=12;
    UILabel *tl=[[UILabel alloc]initWithFrame:CGRectMake(14,12,cw-80,20)];
    tl.text=@"Animated Wallpaper"; tl.font=[UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    tl.textColor=[UIColor whiteColor]; [tr addSubview:tl];
    UISwitch *sw=[[UISwitch alloc]init]; sw.on=gWallEnabled; sw.onTintColor=ac;
    sw.center=CGPointMake(cw-30,22);
    [sw addAction:[UIAction actionWithHandler:^(UIAction *a){
        gWallEnabled=sw.on; LFWallSavePrefs();
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),CFSTR("com.aldazdev.lf2/wall.changed"),NULL,NULL,YES);
    }] forControlEvents:UIControlEventValueChanged];
    [tr addSubview:sw]; [sc addSubview:tr]; y+=54;

    UIView *atr=[[UIView alloc]initWithFrame:CGRectMake(pad,y,cw,50)];
    atr.backgroundColor=[UIColor colorWithWhite:1 alpha:.04f]; atr.layer.cornerRadius=12;
    UILabel *atl=[[UILabel alloc]initWithFrame:CGRectMake(14,6,cw-20,14)];
    atl.text=@"APPLY TO"; atl.font=[UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    atl.textColor=[UIColor colorWithWhite:1 alpha:.35f]; [atr addSubview:atl];
    UILabel *hl=[[UILabel alloc]initWithFrame:CGRectMake(14,26,90,16)];
    hl.text=@"Homescreen"; hl.font=[UIFont systemFontOfSize:11];
    hl.textColor=[UIColor colorWithWhite:1 alpha:.6f]; [atr addSubview:hl];
    UISwitch *hSw=[[UISwitch alloc]init]; hSw.transform=CGAffineTransformMakeScale(.75f,.75f);
    hSw.on=gWallHomescreen; hSw.onTintColor=ac; hSw.center=CGPointMake(120,34);
    [hSw addAction:[UIAction actionWithHandler:^(UIAction *a){
        gWallHomescreen=hSw.on; LFWallSavePrefs();
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),CFSTR("com.aldazdev.lf2/wall.changed"),NULL,NULL,YES);
    }] forControlEvents:UIControlEventValueChanged]; [atr addSubview:hSw];
    UILabel *ll=[[UILabel alloc]initWithFrame:CGRectMake(cw/2,26,90,16)];
    ll.text=@"Lockscreen"; ll.font=[UIFont systemFontOfSize:11];
    ll.textColor=[UIColor colorWithWhite:1 alpha:.6f]; [atr addSubview:ll];
    UISwitch *lSw=[[UISwitch alloc]init]; lSw.transform=CGAffineTransformMakeScale(.75f,.75f);
    lSw.on=gWallLockscreen; lSw.onTintColor=ac; lSw.center=CGPointMake(cw/2+106,34);
    [lSw addAction:[UIAction actionWithHandler:^(UIAction *a){
        gWallLockscreen=lSw.on; LFWallSavePrefs();
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),CFSTR("com.aldazdev.lf2/wall.changed"),NULL,NULL,YES);
    }] forControlEvents:UIControlEventValueChanged]; [atr addSubview:lSw];
    [sc addSubview:atr]; y+=60;

    UIView *sr=[[UIView alloc]initWithFrame:CGRectMake(pad,y,cw,50)];
    sr.backgroundColor=[UIColor colorWithWhite:1 alpha:.04f]; sr.layer.cornerRadius=12;
    UILabel *sl=[[UILabel alloc]initWithFrame:CGRectMake(14,6,cw-30,14)];
    sl.text=@"SPEED"; sl.font=[UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    sl.textColor=[UIColor colorWithWhite:1 alpha:.35f]; [sr addSubview:sl];
    UISlider *sld=[[UISlider alloc]initWithFrame:CGRectMake(14,26,cw-28,20)];
    sld.minimumValue=.2f; sld.maximumValue=3.0f; sld.value=(float)gWallSpeed; sld.tintColor=ac;
    [sld addAction:[UIAction actionWithHandler:^(UIAction *a){
        gWallSpeed=sld.value;
        for(LFWallPresetCard *c in cards){[c.preview stopAnimation];[c.preview applyPreset:LFWallFindPreset(c.presetID) speed:gWallSpeed];}
    }] forControlEvents:UIControlEventValueChanged];
    [sld addAction:[UIAction actionWithHandler:^(UIAction *a){
        LFWallSavePrefs();
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),CFSTR("com.aldazdev.lf2/wall.changed"),NULL,NULL,YES);
    }] forControlEvents:UIControlEventTouchUpInside];
    [sr addSubview:sld]; [sc addSubview:sr]; y+=60;

    UILabel *ph=[[UILabel alloc]initWithFrame:CGRectMake(pad+4,y,cw,16)];
    ph.text=@"PRESETS"; ph.font=[UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    ph.textColor=[UIColor colorWithWhite:1 alpha:.25f]; [sc addSubview:ph]; y+=22;

    for(int i=0;i<kLFPresetCount;i++){
        const LFWallPreset *preset=&kLFPresets[i];
        NSString *pid=[NSString stringWithUTF8String:preset->id];
        BOOL active=[pid isEqualToString:gWallPresetID]&&gWallEnabled;
        LFWallPresetCard *card=[[LFWallPresetCard alloc]
            initWithPreset:preset isActive:active width:cw
            onTap:^(LFWallPresetCard *tapped){
                gWallPresetID=tapped.presetID; gWallEnabled=YES; sw.on=YES;
                LFWallSavePrefs();
                for(LFWallPresetCard *c in cards) c.isActive=[c.presetID isEqualToString:tapped.presetID];
                CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),CFSTR("com.aldazdev.lf2/wall.changed"),NULL,NULL,YES);
            }];
        card.frame=CGRectMake(pad,y,cw,88);
        [sc addSubview:card]; [cards addObject:card]; y+=88+gap;
    }
    sc.contentSize=CGSizeMake(pageWidth,y+pad);
    return sc;
}
