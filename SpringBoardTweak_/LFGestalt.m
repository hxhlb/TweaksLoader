// LFGestalt.m — MobileGestalt editor + Battery % icon
// Portado de ALGShowGestaltEditor en main.m de referencia

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <mach-o/loader.h>
#import "Controllers/LFPanelController.h"
#import "Model/LFPrefs.h"

// ─── Colores ──────────────────────────────────────────────────────────────────
#define LF_ACCENT  [UIColor colorWithRed:.22f green:.55f blue:1 alpha:1]
#define LF_WARN    [UIColor colorWithRed:1 green:.55f blue:.2f alpha:1]
#define LF_RED     [UIColor colorWithRed:.85f green:.22f blue:.22f alpha:1]
#define LF_GREEN   [UIColor colorWithRed:.2f green:.72f blue:.45f alpha:1]
#define PEIK       @"oPeik/9e8lQWMszEjbPzng"

// ─── Gestalt path ─────────────────────────────────────────────────────────────
static NSString *LFGestaltPath(void) {
    return @"/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist";
}
#define LF_GESTALT_PLIST  LFGestaltPath()
#define LF_GESTALT_BACKUP @"/var/mobile/Media/LockFlow2_MobileGestalt_backup.plist"

static void LFGestaltUnlockPath(NSString *p) {
    const char *cp=p.UTF8String; struct stat st;
    if(stat(cp,&st)==0&&(st.st_flags&(UF_IMMUTABLE|SF_IMMUTABLE)))
        chflags(cp,st.st_flags&~(UF_IMMUTABLE|SF_IMMUTABLE));
}
static void LFGestaltUnlock(void) {
    LFGestaltUnlockPath(LFGestaltPath());
    NSString *dir=[LFGestaltPath() stringByDeletingLastPathComponent];
    while(dir.length>1&&![dir isEqualToString:@"/"]){
        LFGestaltUnlockPath(dir); dir=[dir stringByDeletingLastPathComponent];
        if([dir hasSuffix:@"Shared"]){LFGestaltUnlockPath(dir);break;}
    }
}
static void LFGestaltLock(void) {
    const char *path=LFGestaltPath().UTF8String; struct stat st;
    if(stat(path,&st)==0) chflags(path,st.st_flags|UF_IMMUTABLE);
}

// ─── Load / Save / Backup / Restore ──────────────────────────────────────────
static NSDictionary *LFLoadGestaltPlist(void) {
    NSData *d=[NSData dataWithContentsOfFile:LF_GESTALT_PLIST];
    if(!d){
        FILE *f=fopen(LF_GESTALT_PLIST.UTF8String,"rb");
        if(f){NSMutableData *md=[NSMutableData data];char buf[4096];size_t n;
            while((n=fread(buf,1,sizeof(buf),f))>0)[md appendBytes:buf length:n];fclose(f);d=md;}
    }
    if(!d){NSLog(@"[LF2:Gestalt] cannot read plist");return nil;}
    NSError *e=nil;
    id obj=[NSPropertyListSerialization propertyListWithData:d options:NSPropertyListMutableContainersAndLeaves format:nil error:&e];
    return [obj isKindOfClass:[NSDictionary class]]?obj:nil;
}

static BOOL LFSaveGestaltPlist(NSDictionary *dict) {
    NSError *e=nil;
    NSData *data=[NSPropertyListSerialization dataWithPropertyList:dict format:NSPropertyListBinaryFormat_v1_0 options:0 error:&e];
    if(!data){NSLog(@"[LF2:Gestalt] serialize error: %@",e);return NO;}
    NSString *path=LFGestaltPath();
    LFGestaltUnlock();
    BOOL ok=[data writeToFile:path options:0 error:&e];
    if(!ok){int fd=open(path.UTF8String,O_WRONLY|O_CREAT|O_TRUNC,0644);
        if(fd>=0){ssize_t w=write(fd,data.bytes,data.length);close(fd);ok=(w==(ssize_t)data.length);}}
    if(!ok){NSString *tmp=@"/var/mobile/Media/LF2_gestalt_tmp.plist";
        if([data writeToFile:tmp options:0 error:nil]){
            ok=(rename(tmp.UTF8String,path.UTF8String)==0);
            if(!ok)[[NSFileManager defaultManager]removeItemAtPath:tmp error:nil];}}
    if(ok)LFGestaltLock();
    NSLog(@"[LF2:Gestalt] save result: %d",ok);
    return ok;
}

static void LFBackupGestalt(void) {
    if([[NSFileManager defaultManager]fileExistsAtPath:LF_GESTALT_BACKUP])return;
    NSData *d=[NSData dataWithContentsOfFile:LF_GESTALT_PLIST];
    if(d)[d writeToFile:LF_GESTALT_BACKUP options:0 error:nil];
}

static BOOL LFRestoreGestalt(void) {
    if(![[NSFileManager defaultManager]fileExistsAtPath:LF_GESTALT_BACKUP])return NO;
    NSData *d=[NSData dataWithContentsOfFile:LF_GESTALT_BACKUP]; if(!d)return NO;
    LFGestaltUnlock();
    [[NSFileManager defaultManager]removeItemAtPath:LFGestaltPath() error:nil];
    BOOL ok=[d writeToFile:LFGestaltPath() options:0 error:nil];
    if(!ok){NSString *tmp=@"/var/mobile/Media/LF2_restore_tmp.plist";
        if([d writeToFile:tmp options:0 error:nil]){
            ok=(rename(tmp.UTF8String,LFGestaltPath().UTF8String)==0);
            if(!ok)[[NSFileManager defaultManager]removeItemAtPath:tmp error:nil];}}
    if(ok)LFGestaltLock();
    return ok;
}

// ─── CacheData patch (SparseBox approach) ─────────────────────────────────────
static long LFFindCacheDataOffset(const char *mgKey) {
    const struct mach_header_64 *header=NULL;
    const char *mgName="/usr/lib/libMobileGestalt.dylib";
    dlopen(mgName,RTLD_GLOBAL);
    for(int i=0;i<_dyld_image_count();i++)
        if(!strncmp(mgName,_dyld_get_image_name(i),strlen(mgName)))
            {header=(const struct mach_header_64*)_dyld_get_image_header(i);break;}
    if(!header)return -1;
    size_t sz; const char *sec=(const char*)getsectiondata(header,"__TEXT","__cstring",&sz); if(!sec)return -1;
    const char *kp=NULL;
    for(size_t s=0;s<sz;s+=strlen(sec+s)+1)
        if(!strncmp(mgKey,sec+s,strlen(mgKey))){kp=sec+s;break;}
    if(!kp)return -1;
    size_t csz; const uintptr_t *cs=(const uintptr_t*)getsectiondata(header,"__AUTH_CONST","__const",&csz);
    if(!cs)cs=(const uintptr_t*)getsectiondata(header,"__DATA_CONST","__const",&csz);
    if(!cs)return -1;
    const uintptr_t *sp=NULL;
    for(int i=0;i<(int)(csz/8);i++)if(cs[i]==(uintptr_t)kp){sp=cs+i;break;}
    if(!sp)return -1;
    return (long)((uint16_t*)sp)[0x9a/2]<<3;
}

static BOOL LFPatchCacheDataDeviceClass(NSMutableDictionary *plist, BOOL toIPad) {
    NSMutableData *cd=plist[@"CacheData"];
    if(![cd isKindOfClass:[NSData class]])return NO;
    if(![cd isKindOfClass:[NSMutableData class]]){cd=[cd mutableCopy];plist[@"CacheData"]=cd;}
    long off=LFFindCacheDataOffset("mtrAoWJ3gsq+I90ZnQ0vQw");
    if(off<0||(NSUInteger)off>=cd.length-sizeof(int))return NO;
    int nv=toIPad?3:1;
    [cd replaceBytesInRange:NSMakeRange(off,sizeof(int)) withBytes:&nv];
    return YES;
}

// ─── Tweaks list ──────────────────────────────────────────────────────────────
static NSArray *LFGestaltTweaks(void) {
    return @[
        @{@"label":@"Dynamic Island (14 Pro)",     @"key":@"ArtworkDeviceSubType",@"value":@(2556),@"sub":PEIK,@"risky":@NO,@"section":@"Dynamic Island"},
        @{@"label":@"Dynamic Island (14 Pro Max)", @"key":@"ArtworkDeviceSubType",@"value":@(2796),@"sub":PEIK,@"risky":@NO,@"section":@"Dynamic Island"},
        @{@"label":@"Dynamic Island (15 Pro Max)", @"key":@"ArtworkDeviceSubType",@"value":@(2976),@"sub":PEIK,@"risky":@NO,@"section":@"Dynamic Island"},
        @{@"label":@"Dynamic Island (16 Pro)",     @"key":@"ArtworkDeviceSubType",@"value":@(2622),@"sub":PEIK,@"risky":@NO,@"section":@"Dynamic Island"},
        @{@"label":@"Dynamic Island (16 Pro Max)", @"key":@"ArtworkDeviceSubType",@"value":@(2868),@"sub":PEIK,@"risky":@NO,@"section":@"Dynamic Island"},
        @{@"label":@"Dynamic Island (iPhone 17)",  @"key":@"ArtworkDeviceSubType",@"value":@(2736),@"sub":PEIK,@"risky":@NO,@"section":@"Dynamic Island"},
        @{@"label":@"iPhone X Gestures",           @"key":@"ArtworkDeviceSubType",@"value":@(2436),@"sub":PEIK,@"risky":@NO,@"section":@"Dynamic Island"},
        @{@"label":@"Supports Dynamic Island",     @"key":@"YlEtTtHlNesRBMal1CqRaA",@"value":@YES,@"sub":@"",@"risky":@NO,@"section":@"Dynamic Island"},
        @{@"label":@"Boot Chime",                  @"key":@"QHxt+hGLaBPbQJbXiUJX3w",@"value":@YES,@"sub":@"",@"risky":@NO,@"section":@"Features"},
        @{@"label":@"80% Charge Limit",            @"key":@"37NVydb//GP/GrhuTN+exg",@"value":@YES,@"sub":@"",@"risky":@NO,@"section":@"Features"},
        @{@"label":@"Tap to Wake (SE)",            @"key":@"yZf3GTRMGTuwSV/lD7Cagw",@"value":@YES,@"sub":@"",@"risky":@NO,@"section":@"Features"},
        @{@"label":@"Action Button",               @"key":@"cT44WE1EohiwRzhsZ8xEsw",@"value":@YES,@"sub":@"",@"risky":@NO,@"section":@"Features"},
        @{@"label":@"Always On Display",           @"keys":@[@"2OOJf1VhaM7NxfRok3HbWQ",@"j8/Omm6s1lsmTDFsXjsBfA"],@"values":@[@YES,@YES],@"sub":@"",@"risky":@NO,@"section":@"Features"},
        @{@"label":@"AOD Vibrancy",                @"key":@"ykpu7qyhqFweVMKtxNylWA",@"value":@YES,@"sub":@"",@"risky":@NO,@"section":@"Features"},
        @{@"label":@"Apple Pencil Support",        @"key":@"yhHcB0iH0d1XzPO/CFd3ow",@"value":@YES,@"sub":@"",@"risky":@NO,@"section":@"Features"},
        @{@"label":@"Collision SOS",               @"key":@"HCzWusHQwZDea6nNhaKndw",@"value":@YES,@"sub":@"",@"risky":@NO,@"section":@"Features"},
        @{@"label":@"Camera Button (16)",          @"keys":@[@"CwvKxM2cEogD3p+HYgaW0Q",@"oOV1jhJbdV3AddkcCg0AEA"],@"values":@[@(1),@(1)],@"sub":@"",@"risky":@NO,@"section":@"Features"},
        @{@"label":@"Silent Shutter (US)",         @"keys":@[@"h63QSdBCiT/z0WU6rdQv6Q",@"zHeENZu+wbg7PUprwNwBWg"],@"values":@[@"US",@"LL/A"],@"sub":@"",@"risky":@NO,@"section":@"Features"},
        @{@"label":@"Apple Intelligence",          @"key":@"A62OafQ85EJAiiqKn4agtg",@"value":@YES,@"sub":@"",@"risky":@NO,@"section":@"Features"},
        @{@"label":@"iPadOS + Stage Manager",      @"keys":@[@"uKc7FPnEO++lVhHWHFlGbQ",@"mG0AnH/Vy1veoqoLRAIgTA",@"UCG5MkVahJxG1YULbbd5Bg",@"ZYqko/XM5zD3XBfN5RmaXA",@"nVh/gwNpy7Jv1NOk00CMrw",@"qeaj75wk3HF4DwQ8qbIi7g"],@"values":@[@(1),@(1),@(1),@(1),@(1),@(1)],@"sub":@"",@"risky":@YES,@"section":@"iPadOS",@"patchCacheData":@YES},
        @{@"label":@"Stage Manager only",          @"key":@"qeaj75wk3HF4DwQ8qbIi7g",@"value":@(1),@"sub":@"",@"risky":@YES,@"section":@"iPadOS"},
    ];
}

// ─── Glass panel helper (minimal) ─────────────────────────────────────────────
static UIView *LFMakeGlassPanel2(CGRect frame) {
    UIView *p=[[UIView alloc]initWithFrame:frame];
    p.backgroundColor=[UIColor clearColor]; p.layer.cornerRadius=28; p.clipsToBounds=YES;
    if(@available(iOS 13.0,*))p.layer.cornerCurve=kCACornerCurveContinuous;
    UIBlurEffect *bl;
    if(@available(iOS 13.0,*))bl=[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    else bl=[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *bv=[[UIVisualEffectView alloc]initWithEffect:bl];
    bv.frame=p.bounds;bv.userInteractionEnabled=NO;[p addSubview:bv];
    UIView *t=[[UIView alloc]initWithFrame:p.bounds];
    t.backgroundColor=[UIColor colorWithRed:.03f green:.03f blue:.11f alpha:.62f];
    t.userInteractionEnabled=NO;[p addSubview:t];
    CAGradientLayer *bd=[CAGradientLayer layer];bd.frame=p.bounds;
    bd.colors=@[(id)[UIColor colorWithWhite:1 alpha:.35f].CGColor,(id)[UIColor colorWithWhite:1 alpha:.05f].CGColor,(id)[UIColor colorWithWhite:1 alpha:.12f].CGColor];
    bd.locations=@[@0,@.5f,@1];
    CAShapeLayer *bm=[CAShapeLayer layer];
    UIBezierPath *bo=[UIBezierPath bezierPathWithRoundedRect:p.bounds cornerRadius:28];
    UIBezierPath *bi=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(p.bounds,.6f,.6f) cornerRadius:27.4f];
    [bo appendPath:bi];bo.usesEvenOddFillRule=YES;bm.path=bo.CGPath;bm.fillRule=kCAFillRuleEvenOdd;
    bd.mask=bm;[p.layer addSublayer:bd];
    return p;
}

// ─── Respring ─────────────────────────────────────────────────────────────────
static void LFDoRespring(void) {
    Class fbsCls=NSClassFromString(@"FBSSystemService");
    if(fbsCls){SEL ss=NSSelectorFromString(@"sharedService");SEL rs=NSSelectorFromString(@"exitAndRelaunch:");
        if([fbsCls respondsToSelector:ss]){id svc=((id(*)(id,SEL))objc_msgSend)(fbsCls,ss);
            if(svc&&[svc respondsToSelector:rs]){((void(*)(id,SEL,BOOL))objc_msgSend)(svc,rs,YES);return;}}}
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [[UIApplication sharedApplication] performSelector:NSSelectorFromString(@"terminateWithSuccess")];
    #pragma clang diagnostic pop
}

// ─── Main editor window ───────────────────────────────────────────────────────
static UIWindow *gLFGestaltWindow = nil;

void LFShowGestaltEditor(void) {
    if (!gLFGestaltWindow) {
        UIWindowScene *scene=nil;
        for(UIScene *s in UIApplication.sharedApplication.connectedScenes)
            if([s isKindOfClass:[UIWindowScene class]]){scene=(UIWindowScene*)s;break;}
        if(@available(iOS 13.0,*))
            gLFGestaltWindow=[[UIWindow alloc]initWithWindowScene:scene];
        else
            gLFGestaltWindow=[[UIWindow alloc]initWithFrame:[UIScreen mainScreen].bounds];
        gLFGestaltWindow.windowLevel=UIWindowLevelAlert+610;
        gLFGestaltWindow.backgroundColor=[UIColor clearColor];
        UIViewController *vc=[[UIViewController alloc]init];
        vc.view.backgroundColor=[UIColor clearColor];
        gLFGestaltWindow.rootViewController=vc;
    }
    gLFGestaltWindow.frame=[UIScreen mainScreen].bounds;
    gLFGestaltWindow.rootViewController.view.frame=[UIScreen mainScreen].bounds;
    [gLFGestaltWindow makeKeyAndVisible];
    gLFGestaltWindow.userInteractionEnabled=YES;

    UIView *root=gLFGestaltWindow.rootViewController.view;
    for(UIView *v in [root.subviews copy])[v removeFromSuperview];

    CGFloat sw=[UIScreen mainScreen].bounds.size.width;
    CGFloat sh=[UIScreen mainScreen].bounds.size.height;
    CGFloat mw=MIN(sw-20,380),mh=sh*.85f,mx=(sw-mw)/2,my=(sh-mh)/2;

    // Dim
    UIView *dim=[[UIView alloc]initWithFrame:[UIScreen mainScreen].bounds];
    dim.backgroundColor=[UIColor colorWithWhite:0 alpha:.45f];dim.alpha=0;
    __weak UIWindow *ww=gLFGestaltWindow;
    UIButton *dimBtn=[UIButton buttonWithType:UIButtonTypeCustom];dimBtn.frame=dim.bounds;
    [dimBtn addAction:[UIAction actionWithHandler:^(UIAction*a){
        [UIView animateWithDuration:.2f animations:^{dim.alpha=0;}
            completion:^(BOOL d){ww.hidden=YES;for(UIView*v in [root.subviews copy])[v removeFromSuperview];}];
    }] forControlEvents:UIControlEventTouchUpInside];
    [dim addSubview:dimBtn];[root addSubview:dim];

    // Shadow + panel
    UIView *shd=[[UIView alloc]initWithFrame:CGRectMake(mx,my,mw,mh)];
    shd.layer.cornerRadius=28;
    shd.layer.shadowColor=[UIColor colorWithRed:.1f green:.15f blue:.7f alpha:.5f].CGColor;
    shd.layer.shadowOpacity=.8f;shd.layer.shadowRadius=30;shd.layer.shadowOffset=CGSizeMake(0,10);
    shd.userInteractionEnabled=NO;[root addSubview:shd];

    UIView *panel=LFMakeGlassPanel2(CGRectMake(mx,my,mw,mh));

    // Pill
    UIView *pill=[[UIView alloc]initWithFrame:CGRectMake((mw-36)/2,8,36,4)];
    pill.backgroundColor=[UIColor colorWithWhite:1 alpha:.2f];pill.layer.cornerRadius=2;[panel addSubview:pill];

    // Title
    UILabel *ttl=[[UILabel alloc]initWithFrame:CGRectMake(0,18,mw,22)];
    ttl.text=@"MobileGestalt";ttl.font=[UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    ttl.textColor=[UIColor whiteColor];ttl.textAlignment=NSTextAlignmentCenter;
    ttl.userInteractionEnabled=NO;[panel addSubview:ttl];

    // Close X
    UIButton *xBtn=[UIButton buttonWithType:UIButtonTypeCustom];
    xBtn.frame=CGRectMake(mw-44,10,34,34);xBtn.layer.cornerRadius=17;
    xBtn.backgroundColor=[UIColor colorWithWhite:1 alpha:.08f];
    UILabel *xL=[[UILabel alloc]initWithFrame:CGRectMake(0,0,34,34)];
    xL.text=@"✕";xL.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    xL.textColor=[UIColor colorWithWhite:1 alpha:.45f];xL.textAlignment=NSTextAlignmentCenter;
    xL.userInteractionEnabled=NO;[xBtn addSubview:xL];
    [xBtn addAction:[UIAction actionWithHandler:^(UIAction*a){
        [UIView animateWithDuration:.2f animations:^{dim.alpha=0;panel.alpha=0;}
            completion:^(BOOL d){ww.hidden=YES;for(UIView*v in [root.subviews copy])[v removeFromSuperview];}];
    }] forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:xBtn];

    // Status
    BOOL hasBackup=[[NSFileManager defaultManager]fileExistsAtPath:LF_GESTALT_BACKUP];
    BOOL canWrite=[[NSFileManager defaultManager]isWritableFileAtPath:LF_GESTALT_PLIST];
    UILabel *statusLbl=[[UILabel alloc]initWithFrame:CGRectMake(16,42,mw-32,16)];
    statusLbl.font=[UIFont systemFontOfSize:10];statusLbl.textAlignment=NSTextAlignmentCenter;
    statusLbl.textColor=canWrite?LF_GREEN:[UIColor colorWithRed:1 green:.4f blue:.3f alpha:.8f];
    statusLbl.text=!canWrite?@"Read-only — needs TrollStore/jailbreak"
                 :hasBackup?@"Backup exists — safe to modify"
                 :@"No backup yet — will be created on first save";
    statusLbl.userInteractionEnabled=NO;[panel addSubview:statusLbl];

    UIView *sepH=[[UIView alloc]initWithFrame:CGRectMake(0,61,mw,.5f)];
    sepH.backgroundColor=[UIColor colorWithWhite:1 alpha:.12f];[panel addSubview:sepH];

    // Scroll list
    UIScrollView *sc=[[UIScrollView alloc]initWithFrame:CGRectMake(0,62,mw,mh-62-56)];
    sc.showsVerticalScrollIndicator=NO;sc.bounces=YES;
    NSDictionary *currentPlist=LFLoadGestaltPlist();
    NSDictionary *cacheExtra=currentPlist[@"CacheExtra"]?:@{};
    NSArray *tweaks=LFGestaltTweaks();
    CGFloat rowY=10;NSString *lastSection=@"";

    for(NSDictionary *tweak in tweaks){
        NSString *section=tweak[@"section"]?:@"";
        if(![section isEqualToString:lastSection]){
            if(rowY>10)rowY+=8;
            UILabel *secLbl=[[UILabel alloc]initWithFrame:CGRectMake(20,rowY,mw-40,16)];
            secLbl.text=[section uppercaseString];
            secLbl.font=[UIFont systemFontOfSize:10 weight:UIFontWeightBold];
            secLbl.textColor=[UIColor colorWithWhite:1 alpha:.30f];
            secLbl.userInteractionEnabled=NO;[sc addSubview:secLbl];rowY+=22;lastSection=section;
        }
        BOOL risky=[tweak[@"risky"] boolValue];
        NSString *key=tweak[@"key"];NSString *sub=tweak[@"sub"];NSArray *mKeys=tweak[@"keys"];
        BOOL isOn=NO;
        if(mKeys.count>0){BOOL all=YES;for(NSString*mk in mKeys)if(!cacheExtra[mk]){all=NO;break;}isOn=all;}
        else if(sub.length>0){NSDictionary*sd=cacheExtra[sub];id v=sd[key];isOn=(v&&![v isEqual:@(0)]&&![v isEqual:@NO]);}
        else{id v=cacheExtra[key];isOn=(v&&![v isEqual:@(0)]&&![v isEqual:@NO]);}

        UIView *row=[[UIView alloc]initWithFrame:CGRectMake(10,rowY,mw-20,50)];
        row.backgroundColor=[UIColor colorWithWhite:1 alpha:risky?.06f:.035f];
        row.layer.cornerRadius=13;
        if(@available(iOS 13.0,*))row.layer.cornerCurve=kCACornerCurveContinuous;
        [sc addSubview:row];

        UILabel *lbl=[[UILabel alloc]initWithFrame:CGRectMake(14,8,mw-20-90,20)];
        lbl.text=tweak[@"label"];
        lbl.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        lbl.textColor=risky?LF_WARN:[UIColor whiteColor];
        lbl.userInteractionEnabled=NO;[row addSubview:lbl];

        NSString *detail=key?:([NSString stringWithFormat:@"%lu keys",(unsigned long)mKeys.count]);
        if(detail.length>22)detail=[[detail substringToIndex:22]stringByAppendingString:@"…"];
        UILabel *klbl=[[UILabel alloc]initWithFrame:CGRectMake(14,28,mw-20-90,14)];
        klbl.text=detail;klbl.font=[UIFont systemFontOfSize:9];
        klbl.textColor=[UIColor colorWithWhite:1 alpha:.22f];klbl.userInteractionEnabled=NO;[row addSubview:klbl];

        UISwitch *gsw=[[UISwitch alloc]initWithFrame:CGRectMake(mw-20-64,10,51,31)];
        gsw.on=isOn;gsw.onTintColor=risky?LF_WARN:LF_ACCENT;

        NSDictionary *tref=tweak;
        // Retain gsw strongly via associated object on the switch itself
        [gsw addAction:[UIAction actionWithHandler:^(UIAction *a){
            LFBackupGestalt();
            NSData *td=[NSPropertyListSerialization dataWithPropertyList:[LFLoadGestaltPlist() mutableCopy] format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
            NSMutableDictionary *mpl=td?[[NSPropertyListSerialization propertyListWithData:td options:NSPropertyListMutableContainersAndLeaves format:nil error:nil] mutableCopy]:nil;
            if(!mpl){gsw.on=!gsw.on;return;}
            NSMutableDictionary *cache=mpl[@"CacheExtra"];
            if(![cache isKindOfClass:[NSMutableDictionary class]])cache=[cache mutableCopy]?:[NSMutableDictionary dictionary];
            NSString *subk=tref[@"sub"];NSArray *mk=tref[@"keys"];NSArray *mv=tref[@"values"];
            if(mk.count>0){for(NSInteger ki=0;ki<(NSInteger)mk.count;ki++){
                if(gsw.on)cache[mk[ki]]=ki<(NSInteger)mv.count?mv[ki]:@YES;
                else[cache removeObjectForKey:mk[ki]];
            }}else if(subk.length>0){
                NSMutableDictionary *sd=cache[subk];
                if(![sd isKindOfClass:[NSMutableDictionary class]])sd=[sd mutableCopy]?:[NSMutableDictionary dictionary];
                if(gsw.on)sd[tref[@"key"]]=tref[@"value"];else[sd removeObjectForKey:tref[@"key"]];
                cache[subk]=sd;
            }else{if(gsw.on)cache[tref[@"key"]]=tref[@"value"];else[cache removeObjectForKey:tref[@"key"]];}
            mpl[@"CacheExtra"]=cache;
            if([tref[@"patchCacheData"] boolValue])LFPatchCacheDataDeviceClass(mpl,gsw.on);
            BOOL saved=LFSaveGestaltPlist(mpl);
            gsw.on=saved?gsw.on:!gsw.on;
        }] forControlEvents:UIControlEventValueChanged];
        [row addSubview:gsw];rowY+=56;
    }
    sc.contentSize=CGSizeMake(mw,rowY+16);[panel addSubview:sc];

    // Bottom bar: Restore + Respring
    UIView *bot=[[UIView alloc]initWithFrame:CGRectMake(0,mh-56,mw,56)];
    UIView *bsep=[[UIView alloc]initWithFrame:CGRectMake(0,0,mw,.5f)];
    bsep.backgroundColor=[UIColor colorWithWhite:1 alpha:.1f];[bot addSubview:bsep];
    CGFloat bbw=(mw-36)/2;

    UIButton *restBtn=[UIButton buttonWithType:UIButtonTypeCustom];
    restBtn.frame=CGRectMake(12,8,bbw,40);restBtn.layer.cornerRadius=14;
    restBtn.backgroundColor=[UIColor colorWithRed:.85f green:.22f blue:.22f alpha:.65f];
    [restBtn setTitle:@"Restore" forState:UIControlStateNormal];
    restBtn.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [restBtn addAction:[UIAction actionWithHandler:^(UIAction*a){
        BOOL ok=LFRestoreGestalt();
        UILabel *toast=[[UILabel alloc]init];
        toast.text=ok?@"Restored! Respring to apply":@"No backup found";
        toast.font=[UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        toast.textColor=[UIColor whiteColor];toast.backgroundColor=ok?LF_GREEN:LF_RED;
        toast.textAlignment=NSTextAlignmentCenter;toast.layer.cornerRadius=14;toast.clipsToBounds=YES;
        [toast sizeToFit];CGFloat tw=toast.bounds.size.width+28;
        toast.frame=CGRectMake((mw-tw)/2,12,tw,30);toast.alpha=0;[panel addSubview:toast];
        [UIView animateWithDuration:.2f animations:^{toast.alpha=1;}completion:^(BOOL d){
            [UIView animateWithDuration:.3f delay:1.8f options:0 animations:^{toast.alpha=0;}completion:^(BOOL d2){[toast removeFromSuperview];}];}];
    }] forControlEvents:UIControlEventTouchUpInside];
    [bot addSubview:restBtn];

    UIButton *respBtn=[UIButton buttonWithType:UIButtonTypeCustom];
    respBtn.frame=CGRectMake(12+bbw+12,8,bbw,40);respBtn.layer.cornerRadius=14;
    respBtn.backgroundColor=[UIColor colorWithRed:.22f green:.55f blue:1 alpha:.75f];
    [respBtn setTitle:@"Apply (Respring)" forState:UIControlStateNormal];
    respBtn.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [respBtn addAction:[UIAction actionWithHandler:^(UIAction*a){LFDoRespring();}] forControlEvents:UIControlEventTouchUpInside];
    [bot addSubview:respBtn];
    [panel addSubview:bot];
    [root addSubview:panel];

    panel.alpha=0;dim.alpha=0;
    panel.transform=CGAffineTransformConcat(CGAffineTransformMakeScale(.92f,.92f),CGAffineTransformMakeTranslation(0,16));
    [UIView animateWithDuration:.35f delay:0 usingSpringWithDamping:.8f initialSpringVelocity:.4f
                        options:0 animations:^{panel.alpha=1;dim.alpha=1;panel.transform=CGAffineTransformIdentity;}completion:nil];
}

// ═══════════════════════════════════════════════════════════════════════════════
// BATTERY % ICON — portado exacto de ALGBatteryFillLogic case 5 de referencia
// Hook setFillLayer: + _updateFillLayer + layoutSubviews
// ═══════════════════════════════════════════════════════════════════════════════
#define LF_BATT_SUITE @"com.aldazdev.lf2"
static BOOL gBatteryPercentEnabled = NO;

static void LFLoadBatteryPrefs(void) {
    NSUserDefaults *ud=[[NSUserDefaults alloc]initWithSuiteName:LF_BATT_SUITE];
    gBatteryPercentEnabled=[ud objectForKey:@"batteryPercentIcon"]?[ud boolForKey:@"batteryPercentIcon"]:NO;
}

// Lógica principal — copiada del case 5 de referencia (ALGBatteryFillLogic)
static void LFBatteryFillLogic(UIView *batteryView) {
    if (!gBatteryPercentEnabled) return;
    CALayer *fl=((CALayer*(*)(id,SEL))objc_msgSend)(batteryView,sel_registerName("fillLayer"));
    if (!fl) return;
    CGFloat checkW=batteryView.bounds.size.width, checkH=batteryView.bounds.size.height;
    if (checkW<5||checkH<3) return;
    [[UIDevice currentDevice]setBatteryMonitoringEnabled:YES];
    float level=[UIDevice currentDevice].batteryLevel;
    if (level<0) level=0.5f;

    CGFloat vw=batteryView.bounds.size.width, vh=batteryView.bounds.size.height;
    if (vw<4) vw=25; if (vh<4) vh=13;
    CGFloat innerX=2,innerY=1.5f,innerW=vw-6,innerH=vh-3.f;

    // Quitar overlay anterior
    for (CALayer *l in [batteryView.layer.sublayers copy])
        if ([l.name isEqualToString:@"LFBattOverlay"]) [l removeFromSuperlayer];

    // Dimensiones reales via superlayer del fillLayer
    CALayer *battLayer=batteryView.layer;
    CGFloat trueX=innerX,trueY=innerY,trueW=innerW,trueH=innerH;
    if (fl.superlayer&&fl.superlayer!=battLayer){
        CALayer *clip=fl.superlayer;
        trueX=clip.frame.origin.x; trueY=clip.frame.origin.y;
        if(clip.bounds.size.width>2)  trueW=clip.bounds.size.width;
        if(clip.bounds.size.height>1) trueH=clip.bounds.size.height;
    } else {
        trueW=vw>8?vw-6.5f:vw-4.f; trueH=vh>5?vh-3.5f:vh-2.f;
        if(fl.frame.origin.x>0.5f) trueX=fl.frame.origin.x;
        if(fl.frame.origin.y>0.5f) trueY=fl.frame.origin.y;
    }
    CGFloat scaledX=trueX,scaledY=trueY,scaledW=trueW,scaledH=trueH;

    // Overlay case 5 — exacto de referencia
    CALayer *overlay=[CALayer layer];
    overlay.name=@"LFBattOverlay"; overlay.zPosition=100;
    overlay.masksToBounds=YES; overlay.cornerRadius=scaledH*0.28f;
    overlay.frame=CGRectMake(scaledX,scaledY,scaledW,scaledH);
    overlay.backgroundColor=[UIColor clearColor].CGColor;

    NSInteger pv=(NSInteger)(level*100);
    CATextLayer *pct=[CATextLayer layer];
    CGFloat fs=pv>=100?scaledH*0.50f:scaledH*0.62f;
    CGFloat textY=(scaledH-fs)*0.5f-(scaledH*0.08f);
    pct.frame=CGRectMake(0,textY,scaledW,fs);
    pct.string=[NSString stringWithFormat:@"%ld",(long)pv];
    pct.font=(__bridge CFTypeRef)[UIFont systemFontOfSize:fs weight:UIFontWeightBold];
    pct.fontSize=fs; pct.alignmentMode=kCAAlignmentCenter;
    pct.foregroundColor=[UIColor whiteColor].CGColor;
    pct.contentsScale=[UIScreen mainScreen].scale;
    [overlay addSublayer:pct];

    // Contorno de pila — cuerpo + terminal positivo (igual que referencia)
    CAShapeLayer *outline=[CAShapeLayer layer];
    outline.name=@"LFBattOutline"; outline.zPosition=200;
    CGFloat bW=scaledW+1,bH=scaledH+1,bX=-0.5f,bY=-0.5f,bR=bH*0.22f;
    CGFloat tipW=bH*0.18f,tipH=bH*0.42f,tipX=bW,tipY=(bH-tipH)/2;
    UIBezierPath *bp=[UIBezierPath bezierPath];
    [bp appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(bX,bY,bW,bH) cornerRadius:bR]];
    [bp appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(tipX,tipY,tipW,tipH) cornerRadius:tipH*0.3f]];
    outline.path=bp.CGPath; outline.fillColor=[UIColor clearColor].CGColor;
    outline.strokeColor=[UIColor colorWithWhite:1 alpha:0.7f].CGColor;
    outline.lineWidth=0.6f; outline.frame=overlay.frame;

    [batteryView.layer addSublayer:overlay];
    // Quitar outline anterior y agregar nuevo
    for (CALayer *l in [batteryView.layer.sublayers copy])
        if ([l.name isEqualToString:@"LFBattOutline"]) [l removeFromSuperlayer];
    [batteryView.layer addSublayer:outline];
}

static IMP orig_battSetFillLayer=NULL;
static void hooked_battSetFillLayer(UIView *self, SEL _cmd, CALayer *layer) {
    ((void(*)(id,SEL,id))orig_battSetFillLayer)(self,_cmd,layer);
    if (!gBatteryPercentEnabled) return;
    CALayer *fl=((CALayer*(*)(id,SEL))objc_msgSend)(self,sel_registerName("fillLayer"));
    if (fl) fl.hidden=YES;
    for (CALayer *sub in self.layer.sublayers)
        if (![sub.name isEqualToString:@"LFBattOverlay"]) sub.hidden=YES;
    LFBatteryFillLogic(self);
}

static IMP orig_battUpdateFill=NULL;
static void hooked_battUpdateFill(UIView *self, SEL _cmd) {
    ((void(*)(id,SEL))orig_battUpdateFill)(self,_cmd);
    if (!gBatteryPercentEnabled) return;
    CALayer *fl=((CALayer*(*)(id,SEL))objc_msgSend)(self,sel_registerName("fillLayer"));
    if (fl) fl.hidden=YES;
    for (CALayer *sub in self.layer.sublayers)
        if (![sub.name isEqualToString:@"LFBattOverlay"]) sub.hidden=YES;
    LFBatteryFillLogic(self);
}

static IMP orig_battLayout=NULL;
static void hooked_battLayout(UIView *self, SEL _cmd) {
    ((void(*)(id,SEL))orig_battLayout)(self,_cmd);
    if (!gBatteryPercentEnabled) return;
    // Ocultar subviews nativos (ícono bolt, etc)
    for (UIView *sub in self.subviews)
        if (![NSStringFromClass([sub class]) containsString:@"LF"]) sub.hidden=YES;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAGSAFE ANIMATION — anillo que pulsa desde el punto de contacto
// Animación real: anillo verde-blanco que se expande y desvanece,
// similar al MagSafe original de iOS/iPadOS
// ═══════════════════════════════════════════════════════════════════════════════
static UIWindow *gMagSafeWindow = nil;

// ═══════════════════════════════════════════════════════════════════════════════
// MAGSAFE — activa la animación nativa de iOS hookeando CSPowerChangeObserver
// Portado de MagSafe Enabler by Tomasz Poliszuk (GPL v3)
// ═══════════════════════════════════════════════════════════════════════════════

// Forward declarations
@interface CSPowerChangeObserver : NSObject
@property (nonatomic) bool isConnectedToWirelessInternalCharger;
- (bool)isConnectedToWirelessInternalChargingAccessory;
- (void)setIsConnectedToWirelessInternalChargingAccessory:(bool)arg1;
- (bool)isConnectedToWirelessInternalCharger;
- (void)setIsConnectedToWirelessInternalCharger:(bool)arg1;
- (void)update;
@end

@interface CSLockScreenChargingSettings : NSObject
- (long long)wirelessChargingAnimationType;
- (void)setWirelessChargingAnimationType:(long long)arg1;
@end

@interface CSAccessoryConfiguration : NSObject
- (CGSize)boltSize;
- (double)ringDiameter;
- (double)splashRingDiameter;
- (double)staticViewRingDiameter;
- (double)lineWidth;
@end

@interface CSMagSafeRingConfiguration : NSObject
- (double)ringDiameter;
- (double)splashRingDiameter;
- (double)staticViewRingDiameter;
- (double)lineWidth;
@end

@interface CSBatteryChargingRingView : UIView
- (CALayer *)chargingBoltGlyph;
- (void)_layoutChargePercentLabel;
@end

// ─── Helpers de tamaño (igual que referencia) ─────────────────────────────────
static CGFloat LFRingDiameter(void)       { return [UIScreen mainScreen].bounds.size.width < 321 ? 256 : 300; }
static CGFloat LFSplashDiameter(void)     { return [UIScreen mainScreen].bounds.size.width < 321 ? 598 : 700; }
static CGFloat LFLineWidth(void)          { return [UIScreen mainScreen].bounds.size.width < 321 ?  20 :  24; }
static CGSize  LFBoltSize(void)           { return [UIScreen mainScreen].bounds.size.width < 321 ? CGSizeMake(72,108) : CGSizeMake(84,124); }

// ─── IMPs originales ──────────────────────────────────────────────────────────
static IMP orig_isConnectedWireless       = NULL;
static IMP orig_setIsConnectedWireless    = NULL;
static IMP orig_isConnectedWirelessChgr   = NULL;
static IMP orig_setIsConnectedWirelessChgr= NULL;
static IMP orig_csUpdate                  = NULL;
static IMP orig_wirelessAnimType          = NULL;
static IMP orig_setWirelessAnimType       = NULL;
static IMP orig_boltSize                  = NULL;
static IMP orig_ringDiameter              = NULL;
static IMP orig_splashDiameter            = NULL;
static IMP orig_staticDiameter            = NULL;
static IMP orig_csLineWidth               = NULL;
static IMP orig_magRingDiameter           = NULL;
static IMP orig_magSplashDiameter         = NULL;
static IMP orig_magStaticDiameter         = NULL;
static IMP orig_magLineWidth              = NULL;
static IMP orig_chargingBolt              = NULL;
static IMP orig_layoutChargeLabel         = NULL;

// ─── iOS 14.1 – 14.5.1 hooks ─────────────────────────────────────────────────
static bool hooked_isConnectedWireless(id self, SEL _cmd) { return YES; }
static void hooked_setIsConnectedWireless(id self, SEL _cmd, bool v) {
    if (orig_setIsConnectedWireless) ((void(*)(id,SEL,bool))orig_setIsConnectedWireless)(self,_cmd,YES);
}
static bool hooked_isConnectedWirelessChgr(id self, SEL _cmd) { return YES; }
static void hooked_setIsConnectedWirelessChgr(id self, SEL _cmd, bool v) {
    if (orig_setIsConnectedWirelessChgr) ((void(*)(id,SEL,bool))orig_setIsConnectedWirelessChgr)(self,_cmd,YES);
}

// ─── iOS 14.6+ hook ───────────────────────────────────────────────────────────
static void hooked_csUpdate(id self, SEL _cmd) {
    if (orig_csUpdate) ((void(*)(id,SEL))orig_csUpdate)(self,_cmd);
    ((void(*)(id,SEL,bool))objc_msgSend)(self, sel_registerName("setIsConnectedToWirelessInternalCharger:"), YES);
}

// ─── CSLockScreenChargingSettings ────────────────────────────────────────────
static long long hooked_wirelessAnimType(id self, SEL _cmd) { return 1; }
static void hooked_setWirelessAnimType(id self, SEL _cmd, long long v) {
    if (orig_setWirelessAnimType) ((void(*)(id,SEL,long long))orig_setWirelessAnimType)(self,_cmd,1);
}

// ─── CSAccessoryConfiguration ─────────────────────────────────────────────────
static CGSize  hooked_boltSize(id self, SEL _cmd)         { return LFBoltSize(); }
static double  hooked_ringDiameter(id self, SEL _cmd)     { return LFRingDiameter(); }
static double  hooked_splashDiameter(id self, SEL _cmd)   { return LFSplashDiameter(); }
static double  hooked_staticDiameter(id self, SEL _cmd)   { return LFSplashDiameter(); }
static double  hooked_csLineWidth(id self, SEL _cmd)      { return LFLineWidth(); }

// ─── CSMagSafeRingConfiguration ──────────────────────────────────────────────
static double  hooked_magRingDiameter(id self, SEL _cmd)  { return LFRingDiameter(); }
static double  hooked_magSplashDiameter(id self, SEL _cmd){ return LFSplashDiameter(); }
static double  hooked_magStaticDiameter(id self, SEL _cmd){ return LFSplashDiameter(); }
static double  hooked_magLineWidth(id self, SEL _cmd)     { return LFLineWidth(); }

// ─── CSBatteryChargingRingView ────────────────────────────────────────────────
static CALayer* hooked_chargingBolt(id self, SEL _cmd) {
    CALayer *layer = orig_chargingBolt ? ((CALayer*(*)(id,SEL))orig_chargingBolt)(self,_cmd) : nil;
    if (layer) { CGRect f=layer.frame; CGSize s=LFBoltSize(); f.size=s; layer.frame=f; }
    return layer;
}
static void hooked_layoutChargeLabel(id self, SEL _cmd) {
    // Llamar primero chargingBoltGlyph para actualizar frame, luego orig
    ((CALayer*(*)(id,SEL))objc_msgSend)(self, sel_registerName("chargingBoltGlyph"));
    if (orig_layoutChargeLabel) ((void(*)(id,SEL))orig_layoutChargeLabel)(self,_cmd);
}

static void LFHookMethod(const char *cls, const char *selName, IMP imp, IMP *orig) {
    Class c=objc_getClass(cls); if(!c){NSLog(@"[LF2:MagSafe] miss class %s",cls);return;}
    SEL sel=sel_registerName(selName);
    Method m=class_getInstanceMethod(c,sel);
    if(!m){NSLog(@"[LF2:MagSafe] miss sel %s",selName);return;}
    if(orig)*orig=method_getImplementation(m);
    method_setImplementation(m,imp);
    NSLog(@"[LF2:MagSafe] hooked %s.%s",cls,selName);
}

static void LFInstallMagSafeHooks(void) {
    NSLog(@"[LF2:MagSafe] Installing hooks...");

    if (@available(iOS 14.6,*)) {
        // iOS 14.6+ — hook update
        LFHookMethod("CSPowerChangeObserver","update",(IMP)hooked_csUpdate,&orig_csUpdate);
    } else {
        // iOS 14.1 – 14.5.1
        LFHookMethod("CSPowerChangeObserver","isConnectedToWirelessInternalChargingAccessory",(IMP)hooked_isConnectedWireless,&orig_isConnectedWireless);
        LFHookMethod("CSPowerChangeObserver","setIsConnectedToWirelessInternalChargingAccessory:",(IMP)hooked_setIsConnectedWireless,&orig_setIsConnectedWireless);
        LFHookMethod("CSPowerChangeObserver","isConnectedToWirelessInternalCharger",(IMP)hooked_isConnectedWirelessChgr,&orig_isConnectedWirelessChgr);
        LFHookMethod("CSPowerChangeObserver","setIsConnectedToWirelessInternalCharger:",(IMP)hooked_setIsConnectedWirelessChgr,&orig_setIsConnectedWirelessChgr);
    }

    LFHookMethod("CSLockScreenChargingSettings","wirelessChargingAnimationType",(IMP)hooked_wirelessAnimType,&orig_wirelessAnimType);
    LFHookMethod("CSLockScreenChargingSettings","setWirelessChargingAnimationType:",(IMP)hooked_setWirelessAnimType,&orig_setWirelessAnimType);

    LFHookMethod("CSAccessoryConfiguration","boltSize",(IMP)hooked_boltSize,&orig_boltSize);
    LFHookMethod("CSAccessoryConfiguration","ringDiameter",(IMP)hooked_ringDiameter,&orig_ringDiameter);
    LFHookMethod("CSAccessoryConfiguration","splashRingDiameter",(IMP)hooked_splashDiameter,&orig_splashDiameter);
    LFHookMethod("CSAccessoryConfiguration","staticViewRingDiameter",(IMP)hooked_staticDiameter,&orig_staticDiameter);
    LFHookMethod("CSAccessoryConfiguration","lineWidth",(IMP)hooked_csLineWidth,&orig_csLineWidth);

    LFHookMethod("CSMagSafeRingConfiguration","ringDiameter",(IMP)hooked_magRingDiameter,&orig_magRingDiameter);
    LFHookMethod("CSMagSafeRingConfiguration","splashRingDiameter",(IMP)hooked_magSplashDiameter,&orig_magSplashDiameter);
    LFHookMethod("CSMagSafeRingConfiguration","staticViewRingDiameter",(IMP)hooked_magStaticDiameter,&orig_magStaticDiameter);
    LFHookMethod("CSMagSafeRingConfiguration","lineWidth",(IMP)hooked_magLineWidth,&orig_magLineWidth);

    LFHookMethod("CSBatteryChargingRingView","chargingBoltGlyph",(IMP)hooked_chargingBolt,&orig_chargingBolt);
    LFHookMethod("CSBatteryChargingRingView","_layoutChargePercentLabel",(IMP)hooked_layoutChargeLabel,&orig_layoutChargeLabel);

    NSLog(@"[LF2:MagSafe] Hooks installed");
}

void LFGestaltInit(void) {
    LFLoadBatteryPrefs();

    // Hooks batería — 3 hooks igual que referencia
    Class battCls=objc_getClass("_UIBatteryView");
    if (battCls) {
        Method ml=class_getInstanceMethod(battCls,@selector(layoutSubviews));
        if(ml){orig_battLayout=method_getImplementation(ml);method_setImplementation(ml,(IMP)hooked_battLayout);}
        Method mf=class_getInstanceMethod(battCls,sel_registerName("setFillLayer:"));
        if(mf){orig_battSetFillLayer=method_getImplementation(mf);method_setImplementation(mf,(IMP)hooked_battSetFillLayer);}
        Method mu=class_getInstanceMethod(battCls,sel_registerName("_updateFillLayer"));
        if(mu){orig_battUpdateFill=method_getImplementation(mu);method_setImplementation(mu,(IMP)hooked_battUpdateFill);}
        NSLog(@"[LF2] Battery %% hooks done");
    }

    // MagSafe — solo instalar si las clases CS* existen (iOS 14.1-16.x)
    // En iOS 17+ CoverSheet fue refactorizado, estas clases no existen → SIGSEGV
    if (@available(iOS 14.1,*)) {
        if (objc_getClass("CSPowerChangeObserver") ||
            objc_getClass("CSLockScreenChargingSettings")) {
            @try { LFInstallMagSafeHooks(); }
            @catch (NSException *e) { NSLog(@"[LF2:MagSafe] install failed: %@", e); }
        } else {
            NSLog(@"[LF2:MagSafe] CS classes absent, skipping");
        }
    }
}

// Llamado desde el panel cuando cambia la preferencia
void LFSetBatteryPercentEnabled(BOOL enabled) {
    gBatteryPercentEnabled=enabled;
    NSUserDefaults *ud=[[NSUserDefaults alloc]initWithSuiteName:LF_BATT_SUITE];
    [ud setBool:enabled forKey:@"batteryPercentIcon"];[ud synchronize];
}
