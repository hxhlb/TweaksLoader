#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <CoreFoundation/CoreFoundation.h>
#import "Controllers/LFWindowManager.h"
#import "Views/LFClockView.h"
#import "Model/LFPrefs.h"

// ─── Forward declarations ──────────────────────────────────────────────────────
@interface NCNotificationSeamlessContentView : UIView
@property (nonatomic,copy) UIImage *prominentIcon;
@property (nonatomic,copy) UIImage *subordinateIcon;
@end
@interface NCNotificationShortLookView : UIView
@property (nonatomic,readonly) UIView *backgroundMaterialView;
@end
@interface NCNotificationShortLookViewController : UIViewController
@property (nonatomic,readonly) UIView *viewForPreview;
@end
@interface NCNotificationSummaryPlatterView : UIView @end
@interface NCBadgedIconView : UIView
@property (nonatomic,retain) UIView *iconView;
@end

static void hookMethod(const char *cls, SEL sel, IMP imp, IMP *orig) {
    Class c = objc_getClass(cls);
    if (!c) { NSLog(@"[LF2] MISS class %s", cls); return; }
    Method m = class_getInstanceMethod(c, sel);
    if (!m) { NSLog(@"[LF2] MISS sel %s", sel_getName(sel)); return; }
    if (orig) *orig = method_getImplementation(m);
    method_setImplementation(m, imp);
    NSLog(@"[LF2] Hooked %s", sel_getName(sel));
}

// ═══════════════════════════════════════════════════════════════════════════════
// VELVET2 — Prefs globales de notificaciones
// ═══════════════════════════════════════════════════════════════════════════════
#define LF_SUITE @"com.aldazdev.lf2"

static BOOL      gNotifEnabled    = YES;
static CGFloat   gNotifRadius     = 16.0f;
static BOOL      gNotifTitleBold  = YES;
static BOOL      gNotifShowIcon   = YES;
static CGFloat   gNotifAlpha      = 0.95f;
static BOOL      gBorderEnabled   = YES;
static CGFloat   gBorderWidth     = 2.0f;
static CGFloat   gBorderIconAlpha = 0.85f;
static UIColor  *gBorderColor     = nil;
static BOOL      gBgEnabled       = YES;
static CGFloat   gBgIconAlpha     = 0.22f;
static UIColor  *gBgColor         = nil;
static BOOL      gShadowEnabled   = YES;
static CGFloat   gShadowWidth     = 10.0f;
static UIColor  *gShadowColor     = nil;
static BOOL      gLineEnabled     = YES;
static NSInteger gLinePosition    = 0;
static CGFloat   gLineWidth       = 3.0f;
static UIColor  *gLineColor       = nil;

static UIColor *LFColorFromUD(NSUserDefaults *ud, NSString *key) {
    NSNumber *r=[ud objectForKey:[key stringByAppendingString:@"R"]];
    NSNumber *g=[ud objectForKey:[key stringByAppendingString:@"G"]];
    NSNumber *b=[ud objectForKey:[key stringByAppendingString:@"B"]];
    if (r&&g&&b) return [UIColor colorWithRed:[r floatValue] green:[g floatValue] blue:[b floatValue] alpha:1];
    return nil;
}

static void LFLoadNotifPrefs(void) {
    NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:LF_SUITE];
    [ud synchronize];
    gNotifEnabled   = [ud objectForKey:@"notifEnabled"]   ? [ud boolForKey:@"notifEnabled"]   : YES;
    gNotifRadius    = [ud objectForKey:@"notifRadius"]    ? [ud floatForKey:@"notifRadius"]   : 16.0f;
    gNotifTitleBold = [ud objectForKey:@"notifTitleBold"] ? [ud boolForKey:@"notifTitleBold"] : YES;
    gNotifShowIcon  = [ud objectForKey:@"notifShowIcon"]  ? [ud boolForKey:@"notifShowIcon"]  : YES;
    gNotifAlpha     = [ud objectForKey:@"notifAlpha"]     ? [ud floatForKey:@"notifAlpha"]    : 0.95f;
    gBorderEnabled   = [ud objectForKey:@"borderEnabled"]  ? [ud boolForKey:@"borderEnabled"]  : YES;
    gBorderWidth     = [ud objectForKey:@"borderWidth"]    ? [ud floatForKey:@"borderWidth"]   : 2.0f;
    gBorderIconAlpha = [ud objectForKey:@"borderAlpha"]    ? [ud floatForKey:@"borderAlpha"]   : 0.85f;
    gBorderColor     = LFColorFromUD(ud, @"borderColor");
    gBgEnabled    = [ud objectForKey:@"bgEnabled"]  ? [ud boolForKey:@"bgEnabled"]  : YES;
    gBgIconAlpha  = [ud objectForKey:@"bgAlpha"]    ? [ud floatForKey:@"bgAlpha"]   : 0.22f;
    gBgColor      = LFColorFromUD(ud, @"bgColor");
    gShadowEnabled = [ud objectForKey:@"shadowEnabled"] ? [ud boolForKey:@"shadowEnabled"] : YES;
    gShadowWidth   = [ud objectForKey:@"shadowWidth"]   ? [ud floatForKey:@"shadowWidth"]  : 10.0f;
    gShadowColor   = LFColorFromUD(ud, @"shadowColor");
    gLineEnabled   = [ud objectForKey:@"lineEnabled"]  ? [ud boolForKey:@"lineEnabled"]  : YES;
    gLineWidth     = [ud objectForKey:@"lineWidth"]    ? [ud floatForKey:@"lineWidth"]   : 3.0f;
    gLineColor     = LFColorFromUD(ud, @"lineColor");
    NSString *lpos = [ud stringForKey:@"linePosition"] ?: @"left";
    gLinePosition  = [@[@"left",@"right",@"top",@"bottom"] indexOfObject:lpos];
    if (gLinePosition == NSNotFound) gLinePosition = 0;
}

// ─── Color dominante del ícono ─────────────────────────────────────────────────
static UIColor *LFExtractIconColor(UIImage *img) {
    if (!img) return nil;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(16,16),NO,1);
    [img drawInRect:CGRectMake(0,0,16,16)];
    UIImage *small=UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (!small) return nil;
    CGImageRef cg=small.CGImage; if(!cg) return nil;
    unsigned char *data=(unsigned char*)calloc(16*16*4,1); if(!data) return nil;
    CGColorSpaceRef cs=CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx=CGBitmapContextCreate(data,16,16,8,64,cs,kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);
    if(!ctx){free(data);return nil;}
    CGContextDrawImage(ctx,CGRectMake(0,0,16,16),cg); CGContextRelease(ctx);
    long rA=0,gA=0,bA=0,cnt=0;
    for(int i=0;i<16*16*4;i+=4){
        unsigned char cr=data[i],cg2=data[i+1],cb=data[i+2];
        float bright=(cr+cg2+cb)/(3.f*255.f);
        float sat=(MAX(cr,MAX(cg2,cb))-MIN(cr,MIN(cg2,cb)))/255.f;
        if(bright>0.35f&&bright<0.92f&&sat>0.15f){rA+=cr;gA+=cg2;bA+=cb;cnt++;}
    }
    free(data);
    if(cnt==0) return [UIColor colorWithWhite:0.85f alpha:1];
    return [UIColor colorWithRed:rA/(CGFloat)(cnt*255) green:gA/(CGFloat)(cnt*255) blue:bA/(CGFloat)(cnt*255) alpha:1];
}

// ─── Aplicar efectos Velvet2 ────────────────────────────────────────────────────
static const char kVelvetKey = 0;

static void LFApplyVelvetEffects(UIView *vv, UIView *matV, UIImage *icon, CGFloat cornerRadius) {
    if (!vv||!gNotifEnabled) return;
    CGFloat r=MIN(cornerRadius,matV.frame.size.height/2);
    matV.layer.cornerRadius=r; vv.layer.cornerRadius=r;
    if (@available(iOS 13.0,*)){matV.layer.cornerCurve=kCACornerCurveContinuous;vv.layer.cornerCurve=kCACornerCurveContinuous;}
    UIColor *ic=LFExtractIconColor(icon)?:[UIColor colorWithWhite:0.7f alpha:1];
    // Background
    if (gBgEnabled){
        vv.backgroundColor=gBgColor?[gBgColor colorWithAlphaComponent:gBgIconAlpha]:[ic colorWithAlphaComponent:gBgIconAlpha];
        matV.alpha=0;
    } else { vv.backgroundColor=[UIColor clearColor]; matV.alpha=1; }
    // Border
    if (gBorderEnabled){
        UIColor *bc=gBorderColor?[gBorderColor colorWithAlphaComponent:0.9f]:[ic colorWithAlphaComponent:gBorderIconAlpha];
        vv.layer.borderWidth=gBorderWidth; vv.layer.borderColor=bc.CGColor;
    } else { vv.layer.borderWidth=0; vv.layer.borderColor=nil; }
    // Shadow/glow
    if (gShadowEnabled){
        UIColor *sc=gShadowColor?:ic;
        matV.layer.shadowRadius=gShadowWidth; matV.layer.shadowOffset=CGSizeZero;
        matV.layer.shadowColor=sc.CGColor; matV.layer.shadowOpacity=1.f; matV.layer.masksToBounds=NO;
    } else { matV.layer.shadowOpacity=0; }
    // Line
    for (CALayer *l in [vv.layer.sublayers copy]) if ([l.name isEqualToString:@"LFVelvetLine"]) [l removeFromSuperlayer];
    if (gLineEnabled){
        UIColor *lc=gLineColor?:ic;
        CGFloat fw=vv.bounds.size.width,fh=vv.bounds.size.height; CGRect lf;
        switch(gLinePosition){
            case 0:lf=CGRectMake(0,0,gLineWidth,fh);break;
            case 1:lf=CGRectMake(fw-gLineWidth,0,gLineWidth,fh);break;
            case 2:lf=CGRectMake(0,0,fw,gLineWidth);break;
            case 3:lf=CGRectMake(0,fh-gLineWidth,fw,gLineWidth);break;
            default:lf=CGRectMake(0,0,gLineWidth,fh);
        }
        CALayer *ll=[CALayer layer]; ll.name=@"LFVelvetLine";
        ll.frame=lf; ll.backgroundColor=lc.CGColor; [vv.layer addSublayer:ll];
    }
}

static UIView *LFGetOrCreateVelvetView(UIViewController *vc) {
    UIView *vv=objc_getAssociatedObject(vc,&kVelvetKey); if(vv) return vv;
    NCNotificationShortLookView *slv=(NCNotificationShortLookView*)[vc valueForKey:@"viewForPreview"]; if(!slv) return nil;
    UIView *matV=slv.backgroundMaterialView; if(!matV) return nil;
    vv=[[UIView alloc]init]; [matV.superview insertSubview:vv atIndex:1]; vv.clipsToBounds=YES;
    objc_setAssociatedObject(vc,&kVelvetKey,vv,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return vv;
}

// ─── Hook: NCNotificationShortLookViewController.viewDidLayoutSubviews ─────────
static IMP orig_ncLayout=NULL;
static void hooked_ncLayout(UIViewController *self, SEL _cmd) {
    if (orig_ncLayout) ((void(*)(id,SEL))orig_ncLayout)(self,_cmd);
    @try {
        // Observer tiempo real — exacto de referencia, usa "ALGVelvetUpdateStyle"
        if (!objc_getAssociatedObject(self,"ncVelvetObs")) {
            [[NSNotificationCenter defaultCenter]
                addObserverForName:@"ALGVelvetUpdateStyle" object:nil
                queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n){
                    LFLoadNotifPrefs();
                    [self.view setNeedsLayout]; [self.view layoutIfNeeded];
                }];
            objc_setAssociatedObject(self,"ncVelvetObs",@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        NCNotificationShortLookView *slv=(NCNotificationShortLookView*)[self valueForKey:@"viewForPreview"];
        if (!slv||slv.frame.size.width==0) return;
        UIView *vv=LFGetOrCreateVelvetView(self);
        UIView *matV=slv.backgroundMaterialView; if(!vv||!matV) return;
        vv.frame=matV.frame;
        NCNotificationSeamlessContentView *cv=(NCNotificationSeamlessContentView*)[slv valueForKey:@"notificationContentView"];
        UIImage *icon=cv.prominentIcon?:cv.subordinateIcon;
        CGFloat defR=19.f; if(@available(iOS 16.0,*)) defR=23.5f;
        LFApplyVelvetEffects(vv,matV,icon,gNotifRadius?:defR);
        self.view.alpha=gNotifAlpha;
    } @catch(NSException *e){}
}

// ─── Hook: viewDidAppear — bold title + icon ────────────────────────────────
static IMP orig_ncAppear=NULL;
static void hooked_ncAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_ncAppear) ((void(*)(id,SEL,BOOL))orig_ncAppear)(self,_cmd,animated);
    @try {
        if (!gNotifEnabled) return;
        NCNotificationShortLookView *slv=(NCNotificationShortLookView*)[self valueForKey:@"viewForPreview"];
        NCNotificationSeamlessContentView *cv=(NCNotificationSeamlessContentView*)[slv valueForKey:@"notificationContentView"];
        UILabel *title=(UILabel*)[cv valueForKey:@"primaryTextLabel"];
        UILabel *msg=(UILabel*)[cv valueForKey:@"secondaryTextElement"];
        UILabel *date=(UILabel*)[cv valueForKey:@"dateLabel"];
        if (gNotifTitleBold&&title)
            title.font=[UIFont systemFontOfSize:title.font.pointSize weight:UIFontWeightSemibold];
        NCBadgedIconView *bv=(NCBadgedIconView*)[cv valueForKey:@"badgedIconView"];
        UIView *iv=bv.iconView;
        if (iv) {
            if (!gNotifShowIcon){
                iv.alpha=0; iv.hidden=YES;
                CGFloat shift=iv.frame.size.width+8;
                if(title) title.frame=CGRectMake(title.frame.origin.x-shift,title.frame.origin.y,title.frame.size.width+shift,title.frame.size.height);
                if(msg)   msg.frame  =CGRectMake(msg.frame.origin.x-shift,  msg.frame.origin.y,  msg.frame.size.width+shift,  msg.frame.size.height);
            } else if (iv.hidden) { iv.alpha=1; iv.hidden=NO; }
        }
        if (date) date.layer.filters=nil;
    } @catch(NSException *e){}
}

// ─── Hook: NCNotificationSummaryPlatterView ────────────────────────────────────
static IMP orig_summaryLayout=NULL;
static void hooked_summaryLayout(UIView *self, SEL _cmd) {
    if (orig_summaryLayout) ((void(*)(id,SEL))orig_summaryLayout)(self,_cmd);
    @try {
        if (!gNotifEnabled) return;
        UIView *matV=self.subviews.count>0?self.subviews[0]:nil;
        if (!matV||self.frame.size.width==0) return;
        UIView *vv=objc_getAssociatedObject(self,&kVelvetKey);
        if (!vv){
            vv=[[UIView alloc]init]; [self insertSubview:vv atIndex:1]; vv.clipsToBounds=YES;
            objc_setAssociatedObject(self,&kVelvetKey,vv,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        vv.frame=matV.frame;
        CGFloat defR=19.f; if(@available(iOS 16.0,*)) defR=23.5f;
        LFApplyVelvetEffects(vv,matV,nil,gNotifRadius?:defR);
    } @catch(NSException *e){}
}

// ═══════════════════════════════════════════════════════════════════════════════
// DRAG — los labels viven dentro de SBFLockScreenDateView (view nativa).
// Solo necesitamos mover los labels dentro de su superview y guardar la posición.
// NO hacemos clock window separada — el reloj queda en el lockscreen donde pertenece.
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Hook: SBFLockScreenDateView.layoutSubviews ────────────────────────────────
static IMP orig_lsClockLayout=NULL;
static void hooked_lsClockLayout(UIView *self, SEL _cmd) {
    @try { ((void(*)(id,SEL))orig_lsClockLayout)(self,_cmd); } @catch(...) {}
    dispatch_async(dispatch_get_main_queue(),^{
        [[LFWindowManager shared] patchLockscreenView:self];
    });
}

static IMP orig_lsDateLayout=NULL;
static void hooked_lsDateLayout(UIView *self, SEL _cmd) {
    @try { ((void(*)(id,SEL))orig_lsDateLayout)(self,_cmd); } @catch(...) {}
    dispatch_async(dispatch_get_main_queue(),^{
        self.hidden=YES; self.alpha=0;
    });
}

// ─── Lockscreen appear/disappear ──────────────────────────────────────────────
static IMP orig_lsAppear=NULL;
static void hooked_lsAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_lsAppear) ((void(*)(id,SEL,BOOL))orig_lsAppear)(self,_cmd,animated);
    dispatch_async(dispatch_get_main_queue(),^{
        [[LFWindowManager shared] lockscreenDidAppear];
        // Dispara el wallpaper animado en LockScreen (sin re-hookear el mismo selector)
        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"LFWallApplyLS"
            object:self.view];
    });
}

static IMP orig_lsDisappear=NULL;
static void hooked_lsDisappear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_lsDisappear) ((void(*)(id,SEL,BOOL))orig_lsDisappear)(self,_cmd,animated);
    dispatch_async(dispatch_get_main_queue(),^{
        [[LFWindowManager shared] lockscreenDidDisappear];
    });
}

// ─── Edit mode — activa/desactiva drag en los labels del patcher ───────────────
void LFTweakSetEditMode(BOOL editing) {
    [LFClockPatcher setEditMode:editing];
    // Si estamos activando, también instalar el drag en la view nativa
    if (editing) {
        // LFClockPatcher guarda las views parchadas — accedemos via refreshAll trick:
        // Disparamos un layout en todas las views parchadas para que instalen el drag
        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"LFInstallDrag" object:nil];
    }
    NSLog(@"[LF2] Edit mode: %@", editing?@"ON":@"OFF");
}

// ─── Darwin notification ───────────────────────────────────────────────────────
static void onRefresh(CFNotificationCenterRef c,void*o,CFStringRef n,const void*ob,CFDictionaryRef i){
    dispatch_async(dispatch_get_main_queue(),^{
        [LFPrefs.shared load];
        LFLoadNotifPrefs();
        [LFClockPatcher refreshAll];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ALGVelvetUpdateStyle" object:nil];
    });
}

__attribute__((constructor))
static void LF2Init(void) {
    @autoreleasepool {
        NSLog(@"[LF2] ── Init ──");
        LFLoadNotifPrefs();

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),NULL,onRefresh,
            CFSTR(LF_REFRESH),NULL,CFNotificationSuspensionBehaviorDeliverImmediately);

        // Clock
        const char *clocks[]={"SBFLockScreenDateView","_UIDateLabelView",NULL};
        for(int i=0;clocks[i]&&!orig_lsClockLayout;i++)
            hookMethod(clocks[i],@selector(layoutSubviews),(IMP)hooked_lsClockLayout,&orig_lsClockLayout);

        // Date subtitle
        const char *dates[]={"SBFLockScreenDateSubtitleDateView","SBFLockScreenDateSubtitleView",NULL};
        for(int i=0;dates[i]&&!orig_lsDateLayout;i++)
            hookMethod(dates[i],@selector(layoutSubviews),(IMP)hooked_lsDateLayout,&orig_lsDateLayout);

        // Lockscreen appear/disappear
        const char *lsVCs[]={"SBDashBoardViewController","CSCoverSheetViewController",NULL};
        for(int i=0;lsVCs[i];i++){
            Class cls=objc_getClass(lsVCs[i]); if(!cls) continue;
            Method ma=class_getInstanceMethod(cls,@selector(viewDidAppear:));
            Method md=class_getInstanceMethod(cls,@selector(viewDidDisappear:));
            if(ma&&!orig_lsAppear){orig_lsAppear=method_getImplementation(ma);method_setImplementation(ma,(IMP)hooked_lsAppear);}
            if(md&&!orig_lsDisappear){orig_lsDisappear=method_getImplementation(md);method_setImplementation(md,(IMP)hooked_lsDisappear);}
            if(orig_lsAppear&&orig_lsDisappear){NSLog(@"[LF2] LS hooks via %s",lsVCs[i]);break;}
        }

        // Velvet2 notification hooks
        hookMethod("NCNotificationShortLookViewController",@selector(viewDidLayoutSubviews),(IMP)hooked_ncLayout,&orig_ncLayout);
        hookMethod("NCNotificationShortLookViewController",sel_registerName("viewDidAppear:"),(IMP)hooked_ncAppear,&orig_ncAppear);
        hookMethod("NCNotificationSummaryPlatterView",@selector(layoutSubviews),(IMP)hooked_summaryLayout,&orig_summaryLayout);
        NSLog(@"[LF2] Velvet hooks done");

        // Hook NCNotificationListView.layoutSubviews para re-posicionar el reloj
        // cuando la lista de notificaciones cambia de tamaño (más o menos notifs)
        const char *notifListClasses[]={"NCNotificationListView","NCNotificationListCollectionView","SBDashBoardNotificationListView",NULL};
        for(int i=0;notifListClasses[i];i++){
            Class nlc=objc_getClass(notifListClasses[i]); if(!nlc) continue;
            Method nlm=class_getInstanceMethod(nlc,@selector(layoutSubviews)); if(!nlm) continue;
            IMP origNL=method_getImplementation(nlm);
            method_setImplementation(nlm, imp_implementationWithBlock(^(UIView *slf){
                ((void(*)(id,SEL))origNL)(slf,@selector(layoutSubviews));
                // Tras re-layout de notificaciones, actualizar posición del reloj
                dispatch_async(dispatch_get_main_queue(),^{
                    [LFClockPatcher refreshAll];
                });
            }));
            NSLog(@"[LF2] Hooked notif list layout: %s", notifListClasses[i]);
            break; // solo hookear el primero que exista
        }

        // Init gestalt + battery hooks
        extern void LFGestaltInit(void);
        LFGestaltInit();
        extern void LFIPInit(void);
        LFIPInit();
        extern void LFWallInit(void);
        LFWallInit();
        extern void LFGFInit(void);
        LFGFInit();

        // Setup botón flotante — dispatch_after directo
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(2.5*NSEC_PER_SEC)),
                       dispatch_get_main_queue(),^{
            NSLog(@"[LF2] Calling setup...");
            [[LFWindowManager shared] setup];
            NSLog(@"[LF2] Setup done");
        });

        NSLog(@"[LF2] ── Listo ──");
    }
}
