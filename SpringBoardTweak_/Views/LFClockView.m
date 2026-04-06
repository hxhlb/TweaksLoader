#import "LFClockView.h"
#import "../Model/LFPrefs.h"
#import <objc/runtime.h>

static const char kPatched  = 0;
static const char kHoursLbl = 0;
static const char kMinsLbl  = 0;
static const char kDateLbl  = 0;

static NSMutableArray *gPatched = nil;

// Helpers
static NSString *LFHours(void) {
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.dateFormat = LFPrefs.shared.use24h ? @"HH" : @"h";
    return [f stringFromDate:[NSDate date]];
}
static NSString *LFMins(void) {
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.dateFormat = @"mm";
    return [f stringFromDate:[NSDate date]];
}
static NSString *LFFullTime(void) {
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.dateFormat = LFPrefs.shared.use24h ? @"HH:mm" : @"h:mm";
    return [f stringFromDate:[NSDate date]];
}

static UILabel *makeLabel(UIView *parent, const char *key) {
    UILabel *l = [[UILabel alloc] init];
    l.textAlignment = NSTextAlignmentCenter;
    l.layer.shadowColor   = [UIColor blackColor].CGColor;
    l.layer.shadowOffset  = CGSizeZero;
    l.layer.shadowRadius  = 10;
    l.layer.shadowOpacity = 0.5f;
    l.adjustsFontSizeToFitWidth = NO;
    l.userInteractionEnabled = NO;
    [parent addSubview:l];
    objc_setAssociatedObject(parent, key, l, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return l;
}

// ─── Detectar notificaciones visibles en el lockscreen ────────────────────────
// Busca la primera NCNotificationListView o NCNotificationShortLookView en la
// jerarquía del LS VC para estimar cuánto espacio ocupan las notificaciones.
// Retorna el Y más alto al que llega la primera notificación (o b.height si no hay).
// Busca notificaciones visibles SOLO en la misma window del reloj (lockscreen).
// NO considera el Centro de Notificaciones (que vive en una window separada
// y cubre toda la pantalla — en ese estado el reloj no está visible de todas formas).
static CGFloat LFNotifTopY(UIView *dv) {
    // Solo escanear la jerarquía de la misma window donde vive el reloj
    UIWindow *dvWin = dv.window;
    if (!dvWin) return dv.bounds.size.height;

    CGFloat minY = CGFLOAT_MAX;
    NSMutableArray *stack = [NSMutableArray arrayWithObject:dvWin];
    while (stack.count) {
        UIView *v = stack.lastObject; [stack removeLastObject];
        if (v.hidden || v.alpha < 0.01f) continue;
        NSString *cls = NSStringFromClass(v.class);

        // Contenedores de notificaciones en el lockscreen propiamente dicho.
        // NCNotificationShortLookView = burbuja de notif individual en LS.
        // SBDashBoardNotificationAdjacencyController/View = stack de notifs en LS.
        // Excluimos NCNotificationList* porque eso es el Centro de Notificaciones completo.
        BOOL isLSNotif =
            [cls isEqualToString:@"NCNotificationShortLookView"]         ||
            [cls containsString:@"SBDashBoardNotification"]              ||
            [cls containsString:@"NCNotificationListSectionRevealHintView"] ||
            ([cls containsString:@"NCNotification"] &&
             ![cls containsString:@"NotificationList"] &&   // excluir NC completo
             ![cls containsString:@"NotificationCenter"]);  // excluir NC completo

        if (isLSNotif && v.bounds.size.height > 30) {
            CGPoint topInDv = [dv convertPoint:CGPointZero fromView:v];
            if (topInDv.y < minY) minY = topInDv.y;
            continue; // no profundizar dentro
        }
        for (UIView *sv in v.subviews) [stack addObject:sv];
    }
    return (minY == CGFLOAT_MAX) ? dv.bounds.size.height : minY;
}

static void updateView(UIView *dv) {
    LFPrefs *p = LFPrefs.shared;
    UILabel *hL = objc_getAssociatedObject(dv, &kHoursLbl);
    UILabel *mL = objc_getAssociatedObject(dv, &kMinsLbl);
    UILabel *dL = objc_getAssociatedObject(dv, &kDateLbl);
    if (!hL) return;

    hL.hidden = p.hideClock;
    mL.hidden = p.hideClock || !p.splitMode;
    dL.hidden = p.hideClock;
    if (p.hideClock) return;

    UIFont *clockFont = [p clockFont];
    UIFont *dateFont  = [p dateFont];

    hL.font      = clockFont;
    hL.textColor = p.clockColor;
    mL.font      = clockFont;
    mL.textColor = p.clockColor;
    dL.font      = dateFont;
    dL.textColor = p.dateColor;

    CGSize b = dv.bounds.size;
    if (b.width < 10) b = [UIScreen mainScreen].bounds.size;
    CGFloat cx = p.clockPX > 0 ? p.clockPX : b.width * 0.5f;

    // ── cy adaptativo: sube si hay notificaciones que lo taparían ────────────
    CGFloat defaultCY = p.clockPY > 0 ? p.clockPY : b.height * 0.30f;
    CGFloat cy = defaultCY;

    if (p.clockPY <= 0) {
        // Calcular altura total del bloque reloj+fecha
        CGFloat clockH = clockFont.lineHeight * (p.splitMode ? 2.1f : 1.0f);
        CGFloat dateH  = dateFont.lineHeight + 12;
        CGFloat blockH = clockH + dateH;

        // Top Y de las notificaciones
        CGFloat notifTop = LFNotifTopY(dv);

        // Si el bloque reloj en defaultCY solaparía con las notificaciones, subir
        CGFloat blockBottom = defaultCY + blockH / 2;
        if (blockBottom > notifTop - 16) {
            // Subir el reloj para que quede 24pt arriba de la primera notificación
            cy = notifTop - blockH / 2 - 24;
            // Mínimo: 18% de la pantalla (no subir demasiado)
            cy = MAX(cy, b.height * 0.18f);
        }
    }

    if (p.splitMode) {
        hL.text = LFHours();
        mL.text = LFMins();
        [hL sizeToFit]; [mL sizeToFit];
        CGFloat w = MAX(hL.bounds.size.width, mL.bounds.size.width) + 8;
        CGFloat hH = hL.bounds.size.height;
        CGFloat mH = mL.bounds.size.height;
        CGFloat gap = p.clockSize * 0.04f;
        CGFloat total = hH + mH + gap;
        CGFloat topY = cy - total/2;
        hL.frame = CGRectMake(cx - w/2, topY,         w, hH);
        mL.frame = CGRectMake(cx - w/2, topY+hH+gap,  w, mH);
        hL.textAlignment = NSTextAlignmentCenter;
        mL.textAlignment = NSTextAlignmentCenter;
    } else {
        hL.text = LFFullTime();
        [hL sizeToFit];
        hL.center = CGPointMake(cx, cy);
        mL.hidden = YES;
    }

    // Fecha
    CGFloat dateCX = p.datePX > 0 ? p.datePX : cx;
    CGFloat dateCY = p.datePY > 0 ? p.datePY : CGRectGetMaxY(p.splitMode ? mL.frame : hL.frame) + 12;
    dL.text = [p formattedDate];
    [dL sizeToFit];
    dL.center = CGPointMake(dateCX, dateCY);

    // ── Gradient ──────────────────────────────────────────────────────────
    if (p.clockGradient && p.clockGradColor1 && p.clockGradColor2) {
        void (^applyGrad)(UILabel*) = ^(UILabel *l) {
            if (!l || l.bounds.size.width < 2) return;
            // Presets
            NSArray *presets=@[
                @[[UIColor colorWithRed:1 green:.3f blue:.4f alpha:1],[UIColor colorWithRed:1 green:.1f blue:.6f alpha:1]],
                @[[UIColor colorWithRed:.1f green:.6f blue:1 alpha:1],[UIColor colorWithRed:.1f green:.9f blue:.8f alpha:1]],
                @[[UIColor colorWithRed:.6f green:.1f blue:1 alpha:1],[UIColor colorWithRed:0 green:1 blue:.7f alpha:1]],
                @[[UIColor colorWithRed:1 green:.2f blue:0 alpha:1],[UIColor colorWithRed:1 green:.8f blue:0 alpha:1]],
                @[[UIColor colorWithRed:.7f green:.9f blue:1 alpha:1],[UIColor colorWithRed:.3f green:.5f blue:1 alpha:1]],
                @[[UIColor colorWithRed:1 green:.78f blue:.2f alpha:1],[UIColor colorWithRed:1 green:.4f blue:.1f alpha:1]],
            ];
            UIColor *c1,*c2;
            NSInteger s=p.clockGradientStyle;
            if (s>=0 && s<(NSInteger)presets.count) { c1=presets[s][0]; c2=presets[s][1]; }
            else { c1=p.clockGradColor1; c2=p.clockGradColor2; }
            CGSize sz=l.bounds.size;
            UIGraphicsBeginImageContextWithOptions(sz,NO,[UIScreen mainScreen].scale);
            CGContextRef ctx=UIGraphicsGetCurrentContext();
            CGColorSpaceRef cs=CGColorSpaceCreateDeviceRGB();
            CGFloat locs[]={0,1};
            CGColorRef colors[]={c1.CGColor,c2.CGColor};
            CFArrayRef arr=CFArrayCreate(NULL,(const void**)colors,2,NULL);
            CGGradientRef gr=CGGradientCreateWithColors(cs,arr,locs);
            CFRelease(arr); CGColorSpaceRelease(cs);
            CGContextDrawLinearGradient(ctx,gr,CGPointZero,CGPointMake(sz.width,sz.height),0);
            CGGradientRelease(gr);
            UIImage *img=UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            if(img) l.textColor=[UIColor colorWithPatternImage:img];
        };
        applyGrad(hL);
        if (!mL.hidden) applyGrad(mL);
        applyGrad(dL);
    }
}

// ─── FIX: todos los métodos dentro del @implementation ────────────────────────
@implementation LFClockPatcher

+ (void)patchDateView:(UIView *)dv {
    if (!dv) return;
    if (objc_getAssociatedObject(dv, &kPatched)) {
        updateView(dv);
        return;
    }
    objc_setAssociatedObject(dv, &kPatched, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!gPatched) gPatched = [NSMutableArray array];
    [gPatched addObject:[NSValue valueWithNonretainedObject:dv]];

    // Ocultar subviews nativos
    for (UIView *sv in dv.subviews) sv.hidden = YES;

    makeLabel(dv, &kHoursLbl);
    makeLabel(dv, &kMinsLbl);
    makeLabel(dv, &kDateLbl);
    updateView(dv);
}

+ (void)refreshAll {
    if (!gPatched) return;
    NSMutableArray *stale = [NSMutableArray array];
    for (NSValue *v in gPatched) {
        UIView *dv = [v nonretainedObjectValue];
        if (!dv || !dv.superview) { [stale addObject:v]; continue; }
        updateView(dv);
    }
    [gPatched removeObjectsInArray:stale];
}

// ─── FIX #1: setEditMode estaba FUERA del @implementation → movido aquí ──────
+ (void)setEditMode:(BOOL)editing {
    if (!gPatched) return;
    for (NSValue *v in gPatched) {
        UIView *dv = [v nonretainedObjectValue];
        if (!dv) continue;
        dv.userInteractionEnabled = editing;
        UILabel *hL = objc_getAssociatedObject(dv, &kHoursLbl);
        UILabel *mL = objc_getAssociatedObject(dv, &kMinsLbl);
        UILabel *dL = objc_getAssociatedObject(dv, &kDateLbl);
        if (editing) {
            if (hL) {
                hL.layer.borderColor  = [UIColor colorWithRed:0 green:.6f blue:1 alpha:.8f].CGColor;
                hL.layer.borderWidth  = 1.5f;
                hL.layer.cornerRadius = 6;
            }
            if (dL) {
                dL.layer.borderColor  = [UIColor colorWithRed:.2f green:.9f blue:.4f alpha:.8f].CGColor;
                dL.layer.borderWidth  = 1.5f;
                dL.layer.cornerRadius = 4;
            }
        } else {
            if (hL) { hL.layer.borderWidth = 0; hL.userInteractionEnabled = NO; }
            if (mL) { mL.layer.borderWidth = 0; }
            if (dL) { dL.layer.borderWidth = 0; dL.userInteractionEnabled = NO; }
        }
    }
}

@end
