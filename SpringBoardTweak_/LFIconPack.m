// LFIconPack.m
// LockFlow2 — Sistema de temas de iconos
// Descarga PNG por PNG desde el server, grupos de complementos automáticos.
// ObjC puro, sin Logos.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <CoreFoundation/CoreFoundation.h>
#import "Model/LFPrefs.h"

#define LF_SUITE        @"com.aldazdev.lf2"
#define LF_THEMES_DIR   @"/var/mobile/Library/LockFlow2/Themes"
#define LF_THEMES_URL   @"https://ialdaz-activator.com/themes/themes.json"
#define LF_IP_ENABLED   @"iconPackEnabled"
#define LF_IP_ACTIVE    @"iconPackActive"
#define LF_ACCENT       [UIColor colorWithRed:.22f green:.55f blue:1   alpha:1]
#define LF_GREEN        [UIColor colorWithRed:.2f  green:.72f blue:.45f alpha:1]
#define LF_RED          [UIColor colorWithRed:.85f green:.22f blue:.22f alpha:1]
#define LF_WARN         [UIColor colorWithRed:1    green:.55f blue:.2f alpha:1]

// ─── Grupos de temas complementarios ─────────────────────────────────────────
// Al seleccionar el tema base, se descargan y aplican todos los del grupo.
// Orden importa: el primero tiene prioridad, los siguientes rellenan los huecos.
static NSArray<NSArray<NSString *> *> *LFIPThemeGroups(void) {
    static NSArray *groups = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        groups = @[
            // Felicity Pro — base + 4 complementos
            @[@"felicity-pro",
              @"felicity-pro-alt",
              @"felicity-pro-alt-2",
              @"felicity-pro-alt-3",
              @"felicity-pro-ipad-calendar"],
            // Vivacity
            @[@"vivacity", @"vivacity-alternates"],
            // Lollipop
            @[@"lollipop", @"lollipop-alt"],
            // Emotive
            @[@"emotive", @"emotive-alternatives"],
            // Solid Glass 2 — variantes de estilo (no se combinan entre sí)
            @[@"solid-glass-2-light"],
            @[@"solid-glass-2-dark"],
            @[@"solid-glass-2-clear-tinted"],
        ];
    });
    return groups;
}

// Dado un themeID, retorna todos los IDs del grupo (incluyendo el dado)
static NSArray<NSString *> *LFIPGroupForTheme(NSString *themeID) {
    for (NSArray *group in LFIPThemeGroups()) {
        if ([group containsObject:themeID]) return group;
    }
    return @[themeID];
}

// ─── Estado global ────────────────────────────────────────────────────────────
static BOOL     gIPEnabled    = NO;
static NSString *gIPActiveID  = nil;  // ID del tema base seleccionado
// Cache: bundleID → UIImage (NSNull = no hay icono para este bundle)
static NSMutableDictionary *gIconCache = nil;
// Catálogo descargado: array de NSDictionary
static NSArray *gCatalog = nil;

// ─── Prefs ────────────────────────────────────────────────────────────────────
static void LFIPLoadPrefs(void) {
    NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:LF_SUITE];
    gIPEnabled  = [ud objectForKey:LF_IP_ENABLED] ? [ud boolForKey:LF_IP_ENABLED] : NO;
    gIPActiveID = [ud stringForKey:LF_IP_ACTIVE];
}

static void LFIPSavePrefs(void) {
    NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:LF_SUITE];
    [ud setBool:gIPEnabled forKey:LF_IP_ENABLED];
    if (gIPActiveID) [ud setObject:gIPActiveID forKey:LF_IP_ACTIVE];
    else             [ud removeObjectForKey:LF_IP_ACTIVE];
    [ud synchronize];
}

// ─── Lookup catálogo ─────────────────────────────────────────────────────────
static NSDictionary *LFIPThemeByID(NSString *tid) {
    for (NSDictionary *t in gCatalog)
        if ([t[@"id"] isEqualToString:tid]) return t;
    return nil;
}

// ─── Ruta local de un tema ───────────────────────────────────────────────────
static NSString *LFIPThemeDir(NSString *tid) {
    return [LF_THEMES_DIR stringByAppendingPathComponent:tid];
}

static BOOL LFIPThemeInstalled(NSString *tid) {
    // Tiene al menos 1 PNG en su carpeta
    NSString *dir = LFIPThemeDir(tid);
    NSArray *files = [[NSFileManager defaultManager]
        contentsOfDirectoryAtPath:dir error:nil];
    for (NSString *f in files)
        if ([f.pathExtension.lowercaseString isEqualToString:@"png"])
            return YES;
    return NO;
}

// ─── Icono para bundle ID (busca en grupo de temas) ──────────────────────────
static UIImage *LFIPIconForBundle(NSString *bid) {
    if (!gIPEnabled || !gIPActiveID || !bid) return nil;

    // Cache hit
    id cached = gIconCache[bid];
    if (cached) return cached == (id)[NSNull null] ? nil : (UIImage *)cached;

    // Buscar en el grupo del tema activo (orden de prioridad)
    NSArray *group = LFIPGroupForTheme(gIPActiveID);
    NSFileManager *fm = [NSFileManager defaultManager];

    for (NSString *tid in group) {
        NSDictionary *theme = LFIPThemeByID(tid);
        if (!theme) continue;

        NSString *suffix   = theme[@"suffix"] ?: @"";
        NSString *themeDir = LFIPThemeDir(tid);
        NSString *fname    = [NSString stringWithFormat:@"%@%@.png", bid, suffix];
        NSString *path     = [themeDir stringByAppendingPathComponent:fname];

        if ([fm fileExistsAtPath:path]) {
            UIImage *img = [UIImage imageWithContentsOfFile:path];
            if (img) {
                gIconCache[bid] = img;
                return img;
            }
        } else {
            NSLog(@"[LF2:IP] not found: %@", path);
        }
    }

    gIconCache[bid] = (id)[NSNull null];
    return nil;
}

// ─── Refrescar iconos en pantalla ─────────────────────────────────────────────
// Implemented after hooked_SBIconView_updateIcon (forward declarations)
static void LFIPForceUpdateAllIconViews(void);
static void LFIPRefreshIcons(void);

// ─── Activar/desactivar ───────────────────────────────────────────────────────
static void LFIPActivate(NSString *themeID) {
    gIPActiveID = themeID;
    gIPEnabled  = (themeID != nil);
    LFIPSavePrefs();
    LFIPRefreshIcons();
    NSLog(@"[LF2:IP] activated: %@", themeID ?: @"(none)");
}

void LFIPDeactivate(void) { LFIPActivate(nil); }

// ═══════════════════════════════════════════════════════════════════════════════
// DESCARGA PNG POR PNG
// ═══════════════════════════════════════════════════════════════════════════════

// Descarga un solo PNG y lo guarda en disco
static void LFIPDownloadPNG(NSString *url, NSString *destPath,
                             dispatch_group_t group, dispatch_semaphore_t sem) {
    dispatch_group_enter(group);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithURL:[NSURL URLWithString:url]
        completionHandler:^(NSData *data, NSURLResponse *r, NSError *e) {
            if (data && data.length > 0)
                [data writeToFile:destPath options:NSDataWritingAtomic error:nil];
            dispatch_semaphore_signal(sem);
            dispatch_group_leave(group);
        }];
    // Limitar concurrencia: esperar slot disponible
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    [task resume];
}

// Descarga todos los PNGs de un tema dado su NSDictionary del catálogo
// progress: 0.0-1.0, completion: ok/err
static void LFIPDownloadThemeIcons(NSDictionary *theme,
                                    void(^progress)(CGFloat p, NSString *msg),
                                    void(^completion)(BOOL ok, NSString *err)) {
    NSString *tid    = theme[@"id"];
    NSDictionary *icons = theme[@"icons"]; // bundleID → URL
    if (!icons || icons.count == 0) {
        if (completion) completion(NO, @"No icons in catalog");
        return;
    }

    NSString *destDir = LFIPThemeDir(tid);
    [[NSFileManager defaultManager]
        createDirectoryAtPath:destDir
  withIntermediateDirectories:YES attributes:nil error:nil];

    NSArray *allKeys = [icons allKeys];
    NSUInteger total = allKeys.count;
    __block NSUInteger done = 0;

    // Semáforo para max 6 descargas simultáneas
    dispatch_semaphore_t sem = dispatch_semaphore_create(6);
    dispatch_group_t group   = dispatch_group_create();
    dispatch_queue_t queue   = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    if (progress) progress(0.02f, [NSString stringWithFormat:@"Downloading %lu icons...", (unsigned long)total]);

    dispatch_async(queue, ^{
        for (NSString *bundleID in allKeys) {
            NSString *url      = icons[bundleID];
            NSString *fname    = [NSString stringWithFormat:@"%@%@.png",
                                  bundleID, theme[@"suffix"] ?: @""];
            NSString *destPath = [destDir stringByAppendingPathComponent:fname];

            // Saltar si ya existe
            if ([[NSFileManager defaultManager] fileExistsAtPath:destPath]) {
                done++;
                if (progress) {
                    CGFloat p = (CGFloat)done / total;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        progress(0.02f + p * 0.93f,
                            [NSString stringWithFormat:@"%lu/%lu", (unsigned long)done, (unsigned long)total]);
                    });
                }
                continue;
            }

            LFIPDownloadPNG(url, destPath, group, sem);
            done++;
            if (progress) {
                CGFloat p = (CGFloat)done / total;
                dispatch_async(dispatch_get_main_queue(), ^{
                    progress(0.02f + p * 0.93f,
                        [NSString stringWithFormat:@"%lu/%lu", (unsigned long)done, (unsigned long)total]);
                });
            }
        }

        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            if (completion) completion(YES, nil);
        });
    });
}

// Descarga el tema base + todos sus complementos del grupo
void LFIPDownloadThemeGroup(NSString *baseThemeID,
                             void(^progress)(CGFloat p, NSString *msg),
                             void(^completion)(BOOL ok, NSString *err)) {
    NSArray *group = LFIPGroupForTheme(baseThemeID);

    // Filtrar solo los que están en el catálogo
    NSMutableArray *toDownload = [NSMutableArray array];
    for (NSString *tid in group) {
        NSDictionary *t = LFIPThemeByID(tid);
        if (t) [toDownload addObject:t];
    }

    if (toDownload.count == 0) {
        if (completion) completion(NO, @"Theme not in catalog");
        return;
    }

    // Calcular total de iconos entre todos los temas del grupo
    NSUInteger totalIcons = 0;
    for (NSDictionary *t in toDownload)
        totalIcons += [t[@"icons"] count];

    NSLog(@"[LF2:IP] Downloading group %@ (%lu themes, %lu total icons)",
          baseThemeID, (unsigned long)toDownload.count, (unsigned long)totalIcons);

    __block NSUInteger themeIdx = 0;

    // Descargar recursivamente tema por tema
    __block void (^downloadNext)(void);
    __block __weak void (^weakDownloadNext)(void);
    weakDownloadNext = downloadNext = ^{
        if (themeIdx >= toDownload.count) {
            // Todo descargado → activar
            LFIPActivate(baseThemeID);
            if (progress) progress(1.f, @"Done!");
            if (completion) completion(YES, nil);
            return;
        }
        NSDictionary *theme = toDownload[themeIdx++];
        NSString *tname = theme[@"name"] ?: theme[@"id"];
        NSUInteger tcount = [theme[@"icons"] count];

        // Progress offset por tema
        CGFloat baseP = (CGFloat)(themeIdx-1) / toDownload.count;
        CGFloat rangeP = 1.f / toDownload.count;

        if (progress) progress(baseP,
            [NSString stringWithFormat:@"%@ (%lu icons)", tname, (unsigned long)tcount]);

        LFIPDownloadThemeIcons(theme,
            ^(CGFloat p, NSString *msg) {
                if (progress) progress(baseP + p * rangeP, msg);
            },
            ^(BOOL ok, NSString *err) {
                if (weakDownloadNext) weakDownloadNext();
            });
    };

    downloadNext();
}

// ═══════════════════════════════════════════════════════════════════════════════
// CATÁLOGO — descarga desde el server
// ═══════════════════════════════════════════════════════════════════════════════
static void LFIPFetchCatalog(void(^completion)(BOOL ok)) {
    // Si ya tenemos el catálogo en memoria, usar ese
    if (gCatalog && gCatalog.count > 0) {
        if (completion) completion(YES);
        return;
    }

    // Intentar leer catálogo local cacheado
    NSString *cachePath = [LF_THEMES_DIR stringByAppendingPathComponent:@"themes.json"];
    NSData *cached = [NSData dataWithContentsOfFile:cachePath];
    if (cached) {
        id obj = [NSJSONSerialization JSONObjectWithData:cached options:0 error:nil];
        if ([obj isKindOfClass:[NSDictionary class]] && obj[@"themes"]) {
            gCatalog = obj[@"themes"];
            NSLog(@"[LF2:IP] catalog loaded from cache: %lu themes", (unsigned long)gCatalog.count);
            if (completion) completion(YES);
            // Actualizar en background
        }
    }

    // Descargar catálogo actualizado
    NSURLSessionDataTask *catalogTask = [[NSURLSession sharedSession]
        dataTaskWithURL:[NSURL URLWithString:LF_THEMES_URL]
        completionHandler:^(NSData *data, NSURLResponse *r, NSError *e) {
            if (!data) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!gCatalog && completion) completion(NO);
                });
                return;
            }
            id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([obj isKindOfClass:[NSDictionary class]] && obj[@"themes"]) {
                gCatalog = obj[@"themes"];
                // Cachear localmente
                [[NSFileManager defaultManager]
                    createDirectoryAtPath:LF_THEMES_DIR
                withIntermediateDirectories:YES attributes:nil error:nil];
                [data writeToFile:cachePath options:NSDataWritingAtomic error:nil];
                NSLog(@"[LF2:IP] catalog updated: %lu themes", (unsigned long)gCatalog.count);
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(gCatalog.count > 0);
            });
        }];
    [catalogTask resume];
}

// ═══════════════════════════════════════════════════════════════════════════════
// UI: Card de tema con previews y botón de descarga
// ═══════════════════════════════════════════════════════════════════════════════
static UIColor *LFIPColorFromHex(NSString *hex) {
    hex = [hex stringByReplacingOccurrencesOfString:@"#" withString:@""];
    unsigned int rgb = 0;
    [[NSScanner scannerWithString:hex] scanHexInt:&rgb];
    return [UIColor colorWithRed:((rgb>>16)&0xFF)/255.f
                           green:((rgb>>8)&0xFF)/255.f
                            blue:(rgb&0xFF)/255.f alpha:1];
}

@interface LFIPThemeCard : UIView
@property (strong) NSDictionary *theme;       // tema base
@property (strong) NSArray *groupThemes;      // todos los del grupo
@property (copy)   void(^onSelect)(LFIPThemeCard *card);
@property (weak)   UILabel  *statusLabel;
@property (weak)   UIButton *actionBtn;
@property (weak)   UIView   *selBorder;
@property (strong) NSMutableArray *imgTasks;
@property BOOL isActive;
@end

@implementation LFIPThemeCard

- (instancetype)initWithTheme:(NSDictionary *)theme
                  groupThemes:(NSArray *)groupThemes
                     isActive:(BOOL)active
                     onSelect:(void(^)(LFIPThemeCard *))onSelect
                        width:(CGFloat)w {
    self = [super initWithFrame:CGRectMake(0,0,w,140)];
    if (!self) return nil;
    self.theme       = theme;
    self.groupThemes = groupThemes;
    self.isActive    = active;
    self.onSelect    = onSelect;
    self.imgTasks    = [NSMutableArray array];

    UIColor *accent = theme[@"color"] ? LFIPColorFromHex(theme[@"color"]) : LF_ACCENT;

    self.backgroundColor = [UIColor colorWithWhite:1 alpha:active?.10f:.04f];
    self.layer.cornerRadius = 16;
    if (@available(iOS 13,*)) self.layer.cornerCurve = kCACornerCurveContinuous;

    // Borde selección
    UIView *border = [[UIView alloc] initWithFrame:self.bounds];
    border.layer.cornerRadius = 16;
    if (@available(iOS 13,*)) border.layer.cornerCurve = kCACornerCurveContinuous;
    border.layer.borderWidth  = active ? 2.f : 0.f;
    border.layer.borderColor  = accent.CGColor;
    border.userInteractionEnabled = NO;
    [self addSubview:border];
    self.selBorder = border;

    // Grid 2x2 previews
    CGFloat iconSz = 54, gap = 6, gridX = 12, gridY = 16;
    NSArray *previews = theme[@"previews"] ?: @[];
    for (NSInteger i = 0; i < 4; i++) {
        CGFloat ix = gridX + (i%2)*(iconSz+gap);
        CGFloat iy = gridY + (i/2)*(iconSz+gap);
        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(ix,iy,iconSz,iconSz)];
        iv.backgroundColor = [UIColor colorWithWhite:1 alpha:.06f];
        iv.layer.cornerRadius = 12;
        if (@available(iOS 13,*)) iv.layer.cornerCurve = kCACornerCurveContinuous;
        iv.clipsToBounds = YES;
        iv.contentMode  = UIViewContentModeScaleAspectFill;
        iv.tag = 100+i;
        [self addSubview:iv];

        if (i < (NSInteger)previews.count) {
            NSURLSessionDataTask *t = [[NSURLSession sharedSession]
                dataTaskWithURL:[NSURL URLWithString:previews[i]]
                completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
                    if (!d) return;
                    UIImage *img = [UIImage imageWithData:d];
                    if (!img) return;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        ((UIImageView *)[self viewWithTag:100+i]).image = img;
                    });
                }];
            [t resume];
            [self.imgTasks addObject:t];
        }
    }

    // Info a la derecha
    CGFloat tx = gridX + 2*(iconSz+gap) + 10;
    CGFloat tw = w - tx - 12;

    UILabel *nameLbl = [[UILabel alloc] initWithFrame:CGRectMake(tx,18,tw,20)];
    nameLbl.text = theme[@"name"];
    nameLbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    nameLbl.textColor = [UIColor whiteColor];
    [self addSubview:nameLbl];

    // Grupo info
    NSUInteger groupCount = groupThemes.count;
    NSUInteger groupIcons = 0;
    for (NSDictionary *gt in groupThemes) groupIcons += [gt[@"icons"] count];
    NSString *groupDesc = groupCount > 1
        ? [NSString stringWithFormat:@"%lu packs · %lu icons", (unsigned long)groupCount, (unsigned long)groupIcons]
        : theme[@"desc"] ?: @"";

    UILabel *descLbl = [[UILabel alloc] initWithFrame:CGRectMake(tx,40,tw,14)];
    descLbl.text = groupDesc;
    descLbl.font = [UIFont systemFontOfSize:10];
    descLbl.textColor = [UIColor colorWithWhite:1 alpha:.38f];
    [self addSubview:descLbl];

    // Complementos
    if (groupCount > 1) {
        NSMutableArray *names = [NSMutableArray array];
        for (NSDictionary *gt in groupThemes)
            if (![gt[@"id"] isEqualToString:theme[@"id"]])
                [names addObject:gt[@"name"]];
        UILabel *compLbl = [[UILabel alloc] initWithFrame:CGRectMake(tx,56,tw,28)];
        compLbl.text = [NSString stringWithFormat:@"+%@", [names componentsJoinedByString:@", "]];
        compLbl.font = [UIFont systemFontOfSize:9];
        compLbl.textColor = [UIColor colorWithWhite:1 alpha:.22f];
        compLbl.numberOfLines = 2;
        [self addSubview:compLbl];
    }

    // Status label
    UILabel *stLbl = [[UILabel alloc] initWithFrame:CGRectMake(tx,92,tw,14)];
    stLbl.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    stLbl.textColor = active ? LF_GREEN : [UIColor colorWithWhite:1 alpha:.25f];
    stLbl.text = active ? @"● Active" : @"";
    self.statusLabel = stLbl;
    [self addSubview:stLbl];

    // Botón
    BOOL installed = LFIPThemeInstalled(theme[@"id"]);
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(tx, 110, tw, 22);
    btn.layer.cornerRadius = 11;
    if (@available(iOS 13,*)) btn.layer.cornerCurve = kCACornerCurveContinuous;
    [self updateBtn:btn active:active installed:installed accent:accent];
    [btn addTarget:self action:@selector(btnTap:) forControlEvents:UIControlEventTouchUpInside];
    self.actionBtn = btn;
    [self addSubview:btn];

    return self;
}

- (void)updateBtn:(UIButton *)btn active:(BOOL)active installed:(BOOL)installed accent:(UIColor *)accent {
    if (active) {
        btn.backgroundColor = [UIColor colorWithWhite:1 alpha:.06f];
        [btn setTitle:@"Active ✓" forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor colorWithWhite:1 alpha:.3f] forState:UIControlStateNormal];
    } else if (installed) {
        btn.backgroundColor = [accent colorWithAlphaComponent:.22f];
        [btn setTitle:@"Apply" forState:UIControlStateNormal];
        [btn setTitleColor:accent forState:UIControlStateNormal];
    } else {
        btn.backgroundColor = [accent colorWithAlphaComponent:.18f];
        [btn setTitle:@"↓ Download" forState:UIControlStateNormal];
        [btn setTitleColor:accent forState:UIControlStateNormal];
    }
    btn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
}

- (void)btnTap:(id)sender {
    if (self.onSelect) self.onSelect(self);
}

- (void)setProgress:(CGFloat)p message:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (p < 1.f) {
            [self.actionBtn setTitle:[NSString stringWithFormat:@"%.0f%%", p*100]
                           forState:UIControlStateNormal];
            self.statusLabel.text = msg;
            self.statusLabel.textColor = LF_ACCENT;
        } else {
            self.statusLabel.text = @"● Active";
            self.statusLabel.textColor = LF_GREEN;
            self.isActive = YES;
            self.backgroundColor = [UIColor colorWithWhite:1 alpha:.10f];
            self.selBorder.layer.borderWidth = 2.f;
            UIColor *accent = self.theme[@"color"] ? LFIPColorFromHex(self.theme[@"color"]) : LF_ACCENT;
            [self updateBtn:self.actionBtn active:YES installed:YES accent:accent];
        }
    });
}

- (void)cancelTasks {
    for (NSURLSessionDataTask *t in self.imgTasks) [t cancel];
}

@end

// ─── Función pública: construir la página de temas ────────────────────────────
UIScrollView *LFIPBuildThemesPage(CGFloat pageWidth) {
    UIScrollView *sc = [[UIScrollView alloc] initWithFrame:CGRectZero];
    sc.showsVerticalScrollIndicator = NO;
    sc.bounces = YES;

    CGFloat pad = 12, gap = 10, cardW = pageWidth - pad*2;
    __block CGFloat y = pad;
    NSMutableArray<LFIPThemeCard *> *cards = [NSMutableArray array];

    // Toggle on/off
    UIView *togRow = [[UIView alloc] initWithFrame:CGRectMake(pad,y,cardW,44)];
    togRow.backgroundColor = [UIColor colorWithWhite:1 alpha:.04f];
    togRow.layer.cornerRadius = 12;
    UILabel *togLbl = [[UILabel alloc] initWithFrame:CGRectMake(14,12,cardW-80,20)];
    togLbl.text = @"Icon Themes";
    togLbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    togLbl.textColor = [UIColor whiteColor];
    [togRow addSubview:togLbl];
    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = gIPEnabled; sw.onTintColor = LF_ACCENT;
    sw.center = CGPointMake(cardW-30, 22);
    [sw addAction:[UIAction actionWithHandler:^(UIAction *a){
        gIPEnabled = sw.on;
        LFIPSavePrefs();
        LFIPRefreshIcons();
    }] forControlEvents:UIControlEventValueChanged];
    [togRow addSubview:sw];
    [sc addSubview:togRow];
    y += 54;

    // Deactivate
    if (gIPActiveID) {
        UIButton *deact = [UIButton buttonWithType:UIButtonTypeCustom];
        deact.frame = CGRectMake(pad,y,cardW,34);
        deact.backgroundColor = [UIColor colorWithRed:.85f green:.22f blue:.22f alpha:.15f];
        deact.layer.cornerRadius = 10;
        deact.layer.borderWidth = .5f;
        deact.layer.borderColor = [UIColor colorWithRed:.85f green:.22f blue:.22f alpha:.3f].CGColor;
        [deact setTitle:@"Deactivate theme" forState:UIControlStateNormal];
        deact.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        [deact setTitleColor:LF_RED forState:UIControlStateNormal];
        [deact addAction:[UIAction actionWithHandler:^(UIAction *a){
            LFIPDeactivate();
            for (LFIPThemeCard *c in cards) {
                c.isActive = NO;
                c.backgroundColor = [UIColor colorWithWhite:1 alpha:.04f];
                c.selBorder.layer.borderWidth = 0;
                c.statusLabel.text = @"";
            }
        }] forControlEvents:UIControlEventTouchUpInside];
        [sc addSubview:deact];
        y += 44;
    }

    // Loading label mientras descarga el catálogo
    UILabel *loadingLbl = [[UILabel alloc] initWithFrame:CGRectMake(pad,y,cardW,40)];
    loadingLbl.text = @"Loading catalog...";
    loadingLbl.font = [UIFont systemFontOfSize:13];
    loadingLbl.textColor = [UIColor colorWithWhite:1 alpha:.3f];
    loadingLbl.textAlignment = NSTextAlignmentCenter;
    [sc addSubview:loadingLbl];
    sc.contentSize = CGSizeMake(pageWidth, y+50);

    // Descargar catálogo y construir cards
    LFIPFetchCatalog(^(BOOL ok) {
        loadingLbl.hidden = YES;
        if (!ok || !gCatalog) {
            loadingLbl.text = @"Error loading catalog";
            loadingLbl.hidden = NO;
            return;
        }

        // Construir un card por tema BASE (primero del grupo)
        NSMutableSet *seen = [NSMutableSet set];
        NSMutableArray *baseThemes = [NSMutableArray array];

        for (NSDictionary *theme in gCatalog) {
            NSString *tid = theme[@"id"];
            // Saltar si ya fue procesado como parte de un grupo
            if ([seen containsObject:tid]) continue;

            NSArray *group = LFIPGroupForTheme(tid);
            // Solo agregar si es el primero del grupo
            if ([group.firstObject isEqualToString:tid]) {
                // Obtener NSDictionaries del grupo desde el catálogo
                NSMutableArray *groupThemes = [NSMutableArray array];
                for (NSString *gid in group) {
                    NSDictionary *gt = LFIPThemeByID(gid);
                    if (gt) [groupThemes addObject:gt];
                    [seen addObject:gid];
                }
                [baseThemes addObject:@{@"base": theme, @"group": groupThemes}];
            }
        }

        NSInteger colorIdx = 0;
        NSArray *colors = @[@"#4A90E2",@"#8B5CF6",@"#10B981",@"#EC4899",
                            @"#F59E0B",@"#EF4444",@"#06B6D4",@"#84CC16"];

        for (NSDictionary *entry in baseThemes) {
            NSDictionary *base   = entry[@"base"];
            NSArray *groupThemes = entry[@"group"];
            NSString *tid        = base[@"id"];
            BOOL isActive        = [tid isEqualToString:gIPActiveID] && gIPEnabled;

            // Usar color del catálogo o ciclar
            NSMutableDictionary *baseWithColor = [base mutableCopy];
            if (!baseWithColor[@"color"])
                baseWithColor[@"color"] = colors[colorIdx % colors.count];

            LFIPThemeCard *card = [[LFIPThemeCard alloc]
                initWithTheme:baseWithColor
                  groupThemes:groupThemes
                     isActive:isActive
                     onSelect:^(LFIPThemeCard *tappedCard) {
                        NSString *themeID = tappedCard.theme[@"id"];
                        BOOL alreadyInstalled = LFIPThemeInstalled(themeID);

                        if (alreadyInstalled) {
                            LFIPActivate(themeID);
                            for (LFIPThemeCard *c in cards) {
                                BOOL nowActive = [c.theme[@"id"] isEqualToString:themeID];
                                c.isActive = nowActive;
                                c.backgroundColor = [UIColor colorWithWhite:1 alpha:nowActive?.10f:.04f];
                                c.selBorder.layer.borderWidth = nowActive ? 2.f : 0.f;
                                c.statusLabel.text = nowActive ? @"● Active" : @"";
                                c.statusLabel.textColor = nowActive ? LF_GREEN : [UIColor colorWithWhite:1 alpha:.25f];
                            }
                        } else {
                            // Deshabilitar otros botones mientras descarga
                            for (LFIPThemeCard *c in cards) c.actionBtn.enabled = NO;

                            LFIPDownloadThemeGroup(themeID,
                                ^(CGFloat p, NSString *msg) {
                                    [tappedCard setProgress:p message:msg];
                                },
                                ^(BOOL ok, NSString *err) {
                                    for (LFIPThemeCard *c in cards) c.actionBtn.enabled = YES;
                                    if (ok) {
                                        for (LFIPThemeCard *c in cards) {
                                            BOOL nowActive = [c.theme[@"id"] isEqualToString:themeID];
                                            c.backgroundColor = [UIColor colorWithWhite:1 alpha:nowActive?.10f:.04f];
                                            c.selBorder.layer.borderWidth = nowActive ? 2.f : 0.f;
                                        }
                                    } else {
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            tappedCard.statusLabel.text = err ?: @"Error";
                                            tappedCard.statusLabel.textColor = LF_RED;
                                        });
                                    }
                                });
                        }
                     }
                        width:cardW];

            card.frame = CGRectMake(pad, y, cardW, 140);
            [sc addSubview:card];
            [cards addObject:card];
            y += 150;
            colorIdx++;
        }

        sc.contentSize = CGSizeMake(pageWidth, y + pad);
    });

    return sc;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HOOK: SBIconView
// ═══════════════════════════════════════════════════════════════════════════════
static IMP orig_SBIconView_updateIcon = NULL;
static IMP orig_SBIconView_iconImageDidUpdate = NULL;

// Forward declaration
static void LFIPApplyThemeToIconView(UIView *iconView, NSString *bid, UIImage *themed);

static NSString *LFIPBundleForIconView(UIView *iv) {
    @try {
        // Intentar obtener el icono por varias claves conocidas
        id icon = nil;
        for (NSString *k in @[@"icon", @"_icon", @"applicationIcon", @"sbIcon"]) {
            @try { icon = [iv valueForKey:k]; } @catch (...) {}
            if (icon) break;
        }
        if (!icon) {
            // Intentar via delegate
            @try {
                id delegate = [iv valueForKey:@"delegate"];
                if (delegate) icon = [delegate valueForKey:@"icon"];
            } @catch (...) {}
        }
        if (!icon) return nil;
        for (NSString *s in @[@"applicationBundleID", @"bundleIdentifier", @"applicationIdentifier", @"bundleID"]) {
            SEL sel = NSSelectorFromString(s);
            if ([icon respondsToSelector:sel]) {
                NSString *bid = ((NSString*(*)(id,SEL))objc_msgSend)(icon, sel);
                if (bid.length) return bid;
            }
        }
    } @catch (...) {}
    return nil;
}

static void hooked_SBIconView_updateIcon(UIView *self, SEL _cmd, BOOL animated) {
    if (orig_SBIconView_updateIcon)
        ((void(*)(id,SEL,BOOL))orig_SBIconView_updateIcon)(self, _cmd, animated);
    if (!gIPEnabled || !gIPActiveID) return;

    NSString *bid = LFIPBundleForIconView(self);
    if (!bid) { NSLog(@"[LF2:IP] hook: no bundleID for %@", [self class]); return; }
    UIImage *themed = LFIPIconForBundle(bid);
    if (!themed) { NSLog(@"[LF2:IP] hook: no image for %@", bid); return; }
    LFIPApplyThemeToIconView(self, bid, themed);
}

// iconImageDidUpdate: — se llama en cold-start
static void hooked_SBIconView_iconImageDidUpdate(UIView *self, SEL _cmd, id iconImage) {
    if (orig_SBIconView_iconImageDidUpdate)
        ((void(*)(id,SEL,id))orig_SBIconView_iconImageDidUpdate)(self, _cmd, iconImage);
    if (!gIPEnabled || !gIPActiveID) return;

    NSString *bid = LFIPBundleForIconView(self);
    if (!bid) return;
    UIImage *themed = LFIPIconForBundle(bid);
    if (!themed) return;

    __weak UIView *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            UIView *sv = weakSelf;
            if (!sv || !gIPEnabled || !gIPActiveID) return;
            LFIPApplyThemeToIconView(sv, bid, themed);
        });
}

// Aplica el ícono usando CALayer.contents en lugar de UIImageView.image
// para evitar romper el sistema interno de SBIconImageInfo de SpringBoard.
static void LFIPApplyThemeToIconView(UIView *iconView, NSString *bid, UIImage *themed) {
    if (!iconView) return;
    NSLog(@"[LF2:IP] applying to %@", bid);

    Class sbIconImageViewClass = objc_getClass("SBIconImageView");
    NSMutableArray *queue = [NSMutableArray arrayWithObject:iconView];
    UIView *imageView = nil;
    while (queue.count) {
        UIView *v = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if (v != iconView) {
            if ((sbIconImageViewClass && [v isKindOfClass:sbIconImageViewClass]) ||
                [NSStringFromClass([v class]) containsString:@"IconImageView"]) {
                imageView = v;
                break;
            }
        }
        [queue addObjectsFromArray:v.subviews];
    }
    if (!imageView) return;

    CGFloat size = imageView.bounds.size.width;
    // Radio de esquina estándar de iOS: ~22.5% del tamaño del ícono (superellipse)
    CGFloat radius = size * 0.2257f;

    // Usar CALayer.contents — no interfiere con el iconImageInfo interno de SpringBoard
    imageView.layer.contents = (__bridge id)themed.CGImage;
    imageView.layer.contentsScale = themed.scale;
    imageView.layer.contentsGravity = kCAGravityResizeAspect;
    imageView.layer.cornerRadius = radius;
    imageView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *))
        imageView.layer.cornerCurve = kCACornerCurveContinuous; // superellipse igual que iOS
}

// ═══════════════════════════════════════════════════════════════════════════════
// REFRESH — itera SBIconViews visibles y fuerza redibujado sin respring
// ═══════════════════════════════════════════════════════════════════════════════
static void LFIPForceUpdateAllIconViews(void) {
    Class iconViewClass = objc_getClass("SBIconView");
    if (!iconViewClass) return;

    NSMutableArray *queue = [NSMutableArray array];
    for (UIWindow *w in [UIApplication sharedApplication].windows)
        [queue addObject:w];

    while (queue.count) {
        UIView *v = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if ([v isKindOfClass:iconViewClass])
            hooked_SBIconView_updateIcon(v, NULL, NO);
        [queue addObjectsFromArray:v.subviews];
    }
}

static void LFIPRefreshIcons(void) {
    gIconCache = [NSMutableDictionary dictionary];
    dispatch_async(dispatch_get_main_queue(), ^{
        // Fuerza cada SBIconView visible a redibujar con el tema nuevo
        LFIPForceUpdateAllIconViews();

        // Además disparar _updateAfterManualIconImageInfoChangeInvalidatingLayout:YES
        // en cada SBIconView — este método sí existe y fuerza re-fetch del ícono
        Class iconViewClass = objc_getClass("SBIconView");
        if (iconViewClass) {
            SEL forceUpdate = sel_registerName("_updateAfterManualIconImageInfoChangeInvalidatingLayout:");
            NSMutableArray *queue = [NSMutableArray array];
            for (UIWindow *w in [UIApplication sharedApplication].windows)
                [queue addObject:w];
            while (queue.count) {
                UIView *v = queue.firstObject;
                [queue removeObjectAtIndex:0];
                if ([v isKindOfClass:iconViewClass] && [v respondsToSelector:forceUpdate])
                    ((void(*)(id,SEL,BOOL))objc_msgSend)(v, forceUpdate, YES);
                [queue addObjectsFromArray:v.subviews];
            }
        }

        // Pide a SpringBoard relayoutar por si hay iconos fuera de pantalla
        Class cls = NSClassFromString(@"SBIconController");
        if (!cls) return;
        SEL shared = NSSelectorFromString(@"sharedInstance");
        if (![cls respondsToSelector:shared]) return;
        id ic = ((id(*)(id,SEL))objc_msgSend)(cls, shared);
        if (!ic) return;
        SEL update = NSSelectorFromString(@"_updateVisibleIcons");
        if ([ic respondsToSelector:update])
            ((void(*)(id,SEL))objc_msgSend)(ic, update);
        SEL cv = NSSelectorFromString(@"contentView");
        if ([ic respondsToSelector:cv])
            [((UIView*(*)(id,SEL))objc_msgSend)(ic, cv) setNeedsLayout];
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// HOOK UIImage — intercepta antes de que el sistema renderice el icono
// ═══════════════════════════════════════════════════════════════════════════════
static IMP orig_UIImage_iconForBundleIdentifierFormatScale = NULL;
static IMP orig_UIImage_iconForBundleIdentifierRoleFormatScale = NULL;

static UIImage *hooked_UIImage_iconForBundleIdentifierFormatScale(id self, SEL _cmd, NSString *bid, int format, float scale) {
    UIImage *themed = LFIPIconForBundle(bid);
    if (themed) return themed;
    return ((UIImage*(*)(id,SEL,NSString*,int,float))orig_UIImage_iconForBundleIdentifierFormatScale)(self, _cmd, bid, format, scale);
}

static UIImage *hooked_UIImage_iconForBundleIdentifierRoleFormatScale(id self, SEL _cmd, NSString *bid, id role, int format, float scale) {
    UIImage *themed = LFIPIconForBundle(bid);
    if (themed) return themed;
    return ((UIImage*(*)(id,SEL,NSString*,id,int,float))orig_UIImage_iconForBundleIdentifierRoleFormatScale)(self, _cmd, bid, role, format, scale);
}


static void LFIPHomescreenShownCallback(CFNotificationCenterRef c, void *o,
    CFStringRef n, const void *obj, CFDictionaryRef u) {
    if (gIPEnabled && gIPActiveID)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{ LFIPForceUpdateAllIconViews(); });
}

static void LFIPDarwinCallback(CFNotificationCenterRef c, void *o,
    CFStringRef n, const void *obj, CFDictionaryRef u) {
    LFIPLoadPrefs();
    LFIPRefreshIcons();
}

void LFIPInit(void) {
    LFIPLoadPrefs();
    gIconCache = [NSMutableDictionary dictionary];

    [[NSFileManager defaultManager]
        createDirectoryAtPath:LF_THEMES_DIR
  withIntermediateDirectories:YES attributes:nil error:nil];

    // Hook UIImage para interceptar iconos antes de que el sistema los renderice
    Class uiImageClass = [UIImage class];
    struct { SEL sel; IMP imp; IMP *orig; } uiImageHooks[] = {
        {
            sel_registerName("_applicationIconImageForBundleIdentifier:format:scale:"),
            (IMP)hooked_UIImage_iconForBundleIdentifierFormatScale,
            &orig_UIImage_iconForBundleIdentifierFormatScale
        },
        {
            sel_registerName("_applicationIconImageForBundleIdentifier:roleIdentifier:format:scale:"),
            (IMP)hooked_UIImage_iconForBundleIdentifierRoleFormatScale,
            &orig_UIImage_iconForBundleIdentifierRoleFormatScale
        },
    };
    for (int i = 0; i < 2; i++) {
        Method m = class_getClassMethod(uiImageClass, uiImageHooks[i].sel);
        if (m) {
            *uiImageHooks[i].orig = method_getImplementation(m);
            method_setImplementation(m, uiImageHooks[i].imp);
            NSLog(@"[LF2:IP] hooked UIImage.%s", sel_getName(uiImageHooks[i].sel));
        }
    }

    // Hook SBIconView — dos selectores: uno para cold-start, otro para hot-reload
    NSArray *classNames = @[
        @"SBIconView",
        @"SBHIconView",
        @"_SBIconView",
    ];
    NSArray *selNames = @[
        @"_updateIconImageViewAnimated:",
        @"updateIconImageAnimated:",
        @"_updateIconImage:",
        @"updateIconImage",
        @"_updateIcon",
        @"updateIcon",
    ];
    BOOL hooked = NO;
    for (NSString *cn in classNames) {
        Class cls = objc_getClass(cn.UTF8String);
        if (!cls) { NSLog(@"[LF2:IP] class not found: %@", cn); continue; }
        NSLog(@"[LF2:IP] found class: %@", cn);

        for (NSString *sn in selNames) {
            SEL sel = sel_registerName(sn.UTF8String);
            Method m = class_getInstanceMethod(cls, sel);
            if (!m) continue;
            orig_SBIconView_updateIcon = method_getImplementation(m);
            method_setImplementation(m, (IMP)hooked_SBIconView_updateIcon);
            NSLog(@"[LF2:IP] hooked %@.%@", cn, sn);
            hooked = YES;
            break;
        }

        // Hook iconImageDidUpdate: — se llama en cold-start, crucial para ver el ícono al arrancar
        {
            SEL sel = sel_registerName("iconImageDidUpdate:");
            Method m = class_getInstanceMethod(cls, sel);
            if (m) {
                orig_SBIconView_iconImageDidUpdate = method_getImplementation(m);
                method_setImplementation(m, (IMP)hooked_SBIconView_iconImageDidUpdate);
                NSLog(@"[LF2:IP] hooked %@.iconImageDidUpdate:", cn);
            }
        }

        if (hooked) break;
    }
    if (!hooked) NSLog(@"[LF2:IP] WARNING: could not hook any SBIconView update method");

    // Escuchar cuando el homescreen se hace visible para refrescar iconos
    // (el activate puede ocurrir mientras el lockscreen esta activo)
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL, LFIPHomescreenShownCallback,
        CFSTR("SBHomeScreenShownNotification"),
        NULL, CFNotificationSuspensionBehaviorCoalesce);

    // Pre-fetch catálogo en background
    LFIPFetchCatalog(^(BOOL ok) {
        NSLog(@"[LF2:IP] catalog ready: %d (%lu themes)", ok, (unsigned long)gCatalog.count);
    });

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL, LFIPDarwinCallback,
        CFSTR("com.aldazdev.lf2/iconpack.changed"),
        NULL, CFNotificationSuspensionBehaviorCoalesce);

    NSLog(@"[LF2:IP] init complete, enabled=%d activeID=%@",
          gIPEnabled, gIPActiveID ?: @"(none)");
}

void LFIPDeactivatePublic(void) { LFIPDeactivate(); }
