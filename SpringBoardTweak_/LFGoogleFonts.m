// LFGoogleFonts.m
// LockFlow2 — Google Fonts browser, downloader y registrador CoreText.
// Descarga el catálogo via API, muestra preview con el texto "14:36",
// descarga el TTF al seleccionar, lo registra con CTFontManagerRegisterFontsForURL,
// y persiste el nombre PostScript en LFPrefs para que clockFont/dateFont lo usen.

#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#import <objc/runtime.h>
#import "Model/LFPrefs.h"

#define GF_API_KEY   @"AIzaSyD0dP9ly2cTMNOvdGlPZUs4BpVNJ93FGrM"
#define GF_FONARTO_URL @"https://st.1001fonts.net/download/font/fonarto.regular.ttf"
#define GF_FONARTO_FAMILY @"Fonarto"
#define GF_LIST_URL  @"https://www.googleapis.com/webfonts/v1/webfonts?key=" GF_API_KEY @"&sort=popularity&fields=items(family,files)"
#define GF_FONTS_DIR @"/var/mobile/Library/LockFlow2/GoogleFonts"
#define GF_SUITE     @"com.aldazdev.lf2"
#define GF_PREFS_KEY @"gfSelectedFamily"     // NSString: familia elegida, nil = built-in

// ─── Helpers de disco ────────────────────────────────────────────────────────
static void LFGFEnsureDir(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:GF_FONTS_DIR])
        [fm createDirectoryAtPath:GF_FONTS_DIR
      withIntermediateDirectories:YES attributes:nil error:nil];
}

static NSString *LFGFPathForFamily(NSString *family) {
    NSString *safe = [family stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    return [GF_FONTS_DIR stringByAppendingPathComponent:[safe stringByAppendingPathExtension:@"ttf"]];
}

// ─── Registro CoreText ────────────────────────────────────────────────────────
// Registra el TTF en el proceso actual si no está ya registrado.
// Retorna el PostScript name del primer font del archivo.
static NSString *LFGFRegisterFont(NSString *path) {
    NSURL *url = [NSURL fileURLWithPath:path];
    CFErrorRef err = NULL;
    // kCTFontManagerScopeProcess: sólo este proceso, no requiere permisos especiales
    CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url,
                                     kCTFontManagerScopeProcess, &err);
    if (err) { CFRelease(err); }

    // Extraer el PostScript name del primer descriptor del archivo
    CFArrayRef descs = CTFontManagerCreateFontDescriptorsFromURL((__bridge CFURLRef)url);
    NSString *psName = nil;
    if (descs && CFArrayGetCount(descs) > 0) {
        CTFontDescriptorRef d = (CTFontDescriptorRef)CFArrayGetValueAtIndex(descs, 0);
        psName = (__bridge_transfer NSString *)CTFontDescriptorCopyAttribute(d, kCTFontNameAttribute);
    }
    if (descs) CFRelease(descs);
    return psName;
}

// ─── Estado global de fuentes Google ─────────────────────────────────────────
static NSString *gGFSelectedFamily = nil; // familia Google Fonts activa (nil = built-in)
static NSString *gGFPostScriptName = nil; // PS name registrado en CoreText

static void LFGFLoadPrefs(void) {
    NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:GF_SUITE];
    gGFSelectedFamily = [ud stringForKey:GF_PREFS_KEY];
    if (gGFSelectedFamily) {
        // Re-registrar la fuente en cada arranque (scope Process no persiste)
        NSString *path = LFGFPathForFamily(gGFSelectedFamily);
        if ([[NSFileManager defaultManager] fileExistsAtPath:path])
            gGFPostScriptName = LFGFRegisterFont(path);
    }
}

// Descarga Fonarto en background si no existe todavía
static void LFGFDownloadFonarto(void) {
    NSString *path = LFGFPathForFamily(GF_FONARTO_FAMILY);
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        // Ya descargado — solo registrar
        NSString *ps = LFGFRegisterFont(path);
        NSLog(@"[LF2:GF] Fonarto already cached, ps=%@", ps ?: @"nil");
        return;
    }
    NSLog(@"[LF2:GF] Downloading Fonarto...");
    NSURL *url = [NSURL URLWithString:GF_FONARTO_URL];
    NSURLSessionDownloadTask *task = [[NSURLSession sharedSession]
        downloadTaskWithURL:url
          completionHandler:^(NSURL *loc, NSURLResponse *resp, NSError *err) {
        if (err || !loc) { NSLog(@"[LF2:GF] Fonarto download error: %@", err); return; }
        LFGFEnsureDir();
        NSString *dest = LFGFPathForFamily(GF_FONARTO_FAMILY);
        [[NSFileManager defaultManager] moveItemAtURL:loc
                                                toURL:[NSURL fileURLWithPath:dest]
                                                error:nil];
        NSLog(@"[LF2:GF] Fonarto saved to %@", dest);
        // Si no hay ninguna fuente seleccionada, aplicar Fonarto automáticamente
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!gGFSelectedFamily) {
                NSString *ps = LFGFRegisterFont(dest);
                if (ps) {
                    gGFSelectedFamily = GF_FONARTO_FAMILY;
                    gGFPostScriptName = ps;
                    NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:GF_SUITE];
                    [ud setObject:GF_FONARTO_FAMILY forKey:GF_PREFS_KEY];
                    [ud synchronize];
                    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                        CFSTR("com.aldazdev.lf2/refresh"), NULL, NULL, YES);
                    NSLog(@"[LF2:GF] Fonarto auto-applied, ps=%@", ps);
                }
            }
        });
    }];
    [task resume];
}

void LFGFInit(void) {
    LFGFEnsureDir();
    LFGFLoadPrefs();
    // Fonarto: precargar siempre, aplicar si no hay otra fuente elegida
    LFGFDownloadFonarto();
    NSLog(@"[LF2:GF] init — family=%@ ps=%@", gGFSelectedFamily ?: @"(built-in)", gGFPostScriptName ?: @"nil");
}

// ─── API pública para LFPrefs ────────────────────────────────────────────────
// Llama a esto desde clockFont/dateFont en LFPrefs.m cuando haya una GF activa.
UIFont *LFGFFont(CGFloat size) {
    if (!gGFPostScriptName) return nil;
    return [UIFont fontWithName:gGFPostScriptName size:size];
}

BOOL LFGFIsActive(void) { return gGFSelectedFamily != nil; }

// ─── Modelo de fuente del catálogo ───────────────────────────────────────────
@interface LFGFItem : NSObject
@property (strong) NSString *family;
@property (strong) NSDictionary *files; // variant → url
@property BOOL downloaded;
@property (strong) UIFont *previewFont; // nil si no descargada
@end
@implementation LFGFItem
@end

// ═══════════════════════════════════════════════════════════════════════════════
// LFGFCell — celda de la lista de fuentes
// ═══════════════════════════════════════════════════════════════════════════════
@interface LFGFCell : UITableViewCell
@property (strong) UILabel *previewLabel;  // "14:36" en la fuente
@property (strong) UILabel *familyLabel;   // nombre de familia
@property (strong) UILabel *statusLabel;   // "Downloaded" / "Tap to download"
@property (strong) UIActivityIndicatorView *spinner;
@property (strong) UIImageView *checkmark;
@end

@implementation LFGFCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)ri {
    self = [super initWithStyle:style reuseIdentifier:ri];
    if (!self) return nil;
    self.backgroundColor    = [UIColor colorWithWhite:1 alpha:0.05f];
    self.selectionStyle     = UITableViewCellSelectionStyleNone;

    // Preview "14:36"
    _previewLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 10, 90, 40)];
    _previewLabel.text      = @"14:36";
    _previewLabel.textColor = [UIColor whiteColor];
    _previewLabel.font      = [UIFont systemFontOfSize:26 weight:UIFontWeightLight];
    _previewLabel.adjustsFontSizeToFitWidth = YES;
    [self.contentView addSubview:_previewLabel];

    // Nombre familia
    _familyLabel = [[UILabel alloc] initWithFrame:CGRectMake(118, 10, 180, 22)];
    _familyLabel.textColor = [UIColor whiteColor];
    _familyLabel.font      = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [self.contentView addSubview:_familyLabel];

    // Estado
    _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(118, 34, 180, 16)];
    _statusLabel.textColor = [UIColor colorWithWhite:1 alpha:0.4f];
    _statusLabel.font      = [UIFont systemFontOfSize:11];
    [self.contentView addSubview:_statusLabel];

    // Spinner (descargando)
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.color  = [UIColor colorWithWhite:1 alpha:0.6f];
    _spinner.center = CGPointMake(self.contentView.bounds.size.width - 28, 30);
    _spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    _spinner.hidesWhenStopped = YES;
    [self.contentView addSubview:_spinner];

    // Checkmark (seleccionada)
    if (@available(iOS 13,*)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
        _checkmark = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle.fill" withConfiguration:cfg]];
    } else {
        _checkmark = [[UIImageView alloc] init];
    }
    _checkmark.tintColor = [UIColor colorWithRed:0.2f green:0.8f blue:0.4f alpha:1];
    _checkmark.frame     = CGRectMake(0, 0, 20, 20);
    _checkmark.center    = CGPointMake(self.contentView.bounds.size.width - 28, 30);
    _checkmark.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    _checkmark.hidden = YES;
    [self.contentView addSubview:_checkmark];

    return self;
}

- (void)configureWithItem:(LFGFItem *)item isSelected:(BOOL)selected downloading:(BOOL)dl {
    _familyLabel.text   = item.family;
    _previewLabel.font  = item.previewFont ?: [UIFont systemFontOfSize:26 weight:UIFontWeightLight];
    _statusLabel.text   = dl ? @"Downloading…" : (item.downloaded ? @"Downloaded — tap to apply" : @"Tap to download");
    _statusLabel.textColor = selected
        ? [UIColor colorWithRed:0.2f green:0.8f blue:0.4f alpha:1]
        : [UIColor colorWithWhite:1 alpha:0.4f];
    _checkmark.hidden = !selected;
    if (dl) [_spinner startAnimating]; else [_spinner stopAnimating];
    self.backgroundColor = [UIColor colorWithWhite:1 alpha:selected ? 0.10f : 0.04f];
}

@end

// ═══════════════════════════════════════════════════════════════════════════════
// LFGFViewController — tabla de Google Fonts con buscador
// ═══════════════════════════════════════════════════════════════════════════════
@interface LFGFViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating>
@property (copy) void(^onApply)(NSString *family, NSString *psName);
@end

@implementation LFGFViewController {
    UITableView            *_table;
    UISearchController     *_search;
    NSMutableArray<LFGFItem*> *_allItems;
    NSMutableArray<LFGFItem*> *_filtered;
    NSMutableSet<NSString*>   *_downloading;
    UILabel                *_statusLbl;
    UIActivityIndicatorView *_loadSpinner;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.05f green:0.05f blue:0.12f alpha:0.97f];

    // Header
    UILabel *hdr = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 48)];
    hdr.text = @"Google Fonts";
    hdr.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    hdr.textColor = [UIColor whiteColor];
    hdr.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:hdr];

    // Botón "Built-in" (resetear a fuente del sistema)
    UIButton *reset = [UIButton buttonWithType:UIButtonTypeSystem];
    reset.frame = CGRectMake(16, 8, 80, 32);
    [reset setTitle:@"Built-in" forState:UIControlStateNormal];
    reset.titleLabel.font = [UIFont systemFontOfSize:13];
    [reset setTitleColor:[UIColor colorWithWhite:1 alpha:0.6f] forState:UIControlStateNormal];
    [reset addTarget:self action:@selector(_resetToBuiltin) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:reset];

    // SearchBar
    _search = [[UISearchController alloc] initWithSearchResultsController:nil];
    _search.searchResultsUpdater = self;
    _search.obscuresBackgroundDuringPresentation = NO;
    _search.searchBar.tintColor = [UIColor colorWithRed:0.22f green:0.55f blue:1 alpha:1];
    _search.searchBar.barStyle  = UIBarStyleBlack;
    [_search.searchBar sizeToFit];
    CGRect sbf = _search.searchBar.frame;
    sbf.origin.y = 48; sbf.size.width = self.view.bounds.size.width;
    _search.searchBar.frame = sbf;
    [self.view addSubview:_search.searchBar];

    // Tabla
    CGFloat tableTop = sbf.origin.y + sbf.size.height;
    _table = [[UITableView alloc] initWithFrame:CGRectMake(0, tableTop, self.view.bounds.size.width, self.view.bounds.size.height - tableTop) style:UITableViewStylePlain];
    _table.dataSource         = self;
    _table.delegate           = self;
    _table.backgroundColor    = [UIColor clearColor];
    _table.separatorColor     = [UIColor colorWithWhite:1 alpha:0.08f];
    _table.rowHeight          = 62;
    _table.autoresizingMask   = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [_table registerClass:[LFGFCell class] forCellReuseIdentifier:@"gfc"];
    [self.view addSubview:_table];

    // Loading overlay
    _loadSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    _loadSpinner.color  = [UIColor whiteColor];
    _loadSpinner.center = CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2);
    _loadSpinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:_loadSpinner];

    _statusLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, CGRectGetMaxY(_loadSpinner.frame)+12, self.view.bounds.size.width-40, 24)];
    _statusLbl.textColor     = [UIColor colorWithWhite:1 alpha:0.5f];
    _statusLbl.textAlignment = NSTextAlignmentCenter;
    _statusLbl.font          = [UIFont systemFontOfSize:13];
    _statusLbl.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:_statusLbl];

    _allItems   = [NSMutableArray array];
    _filtered   = [NSMutableArray array];
    _downloading = [NSMutableSet set];

    [self _fetchCatalog];
}

- (void)_fetchCatalog {
    [_loadSpinner startAnimating];
    _statusLbl.text = @"Loading catalog…";

    NSURL *url = [NSURL URLWithString:GF_LIST_URL];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithURL:url
      completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_loadSpinner stopAnimating];
            if (err || !data) {
                self->_statusLbl.text = [NSString stringWithFormat:@"Error: %@", err.localizedDescription ?: @"no data"];
                return;
            }
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSArray *items = json[@"items"];
            if (!items.count) { self->_statusLbl.text = @"No fonts returned"; return; }

            NSFileManager *fm = [NSFileManager defaultManager];
            for (NSDictionary *d in items) {
                LFGFItem *it = [[LFGFItem alloc] init];
                it.family = d[@"family"];
                it.files  = d[@"files"];
                NSString *path = LFGFPathForFamily(it.family);
                it.downloaded = [fm fileExistsAtPath:path];
                if (it.downloaded) {
                    // Registrar y cargar preview font
                    NSString *ps = LFGFRegisterFont(path);
                    if (ps) it.previewFont = [UIFont fontWithName:ps size:26];
                }
                [self->_allItems addObject:it];
            }
            // Fonarto siempre primero — fuente recomendada
            NSString *fonartoPath = LFGFPathForFamily(GF_FONARTO_FAMILY);
            LFGFItem *fonartoItem = [[LFGFItem alloc] init];
            fonartoItem.family = GF_FONARTO_FAMILY;
            fonartoItem.files  = @{@"regular": GF_FONARTO_URL};
            fonartoItem.downloaded = [[NSFileManager defaultManager] fileExistsAtPath:fonartoPath];
            if (fonartoItem.downloaded) {
                NSString *ps = LFGFRegisterFont(fonartoPath);
                if (ps) fonartoItem.previewFont = [UIFont fontWithName:ps size:26];
            }
            [self->_allItems insertObject:fonartoItem atIndex:0];

            self->_filtered = [self->_allItems mutableCopy];
            self->_statusLbl.text = [NSString stringWithFormat:@"%d fonts", (int)self->_allItems.count];
            [self->_table reloadData];
        });
    }];
    [task resume];
}

// ─── SearchBar ───────────────────────────────────────────────────────────────
- (void)updateSearchResultsForSearchController:(UISearchController *)sc {
    NSString *q = sc.searchBar.text;
    if (!q.length) { _filtered = [_allItems mutableCopy]; }
    else {
        NSPredicate *p = [NSPredicate predicateWithFormat:@"family CONTAINS[cd] %@", q];
        _filtered = [[_allItems filteredArrayUsingPredicate:p] mutableCopy];
    }
    [_table reloadData];
}

// ─── TableView ───────────────────────────────────────────────────────────────
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return (NSInteger)_filtered.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    LFGFCell *cell = [tv dequeueReusableCellWithIdentifier:@"gfc" forIndexPath:ip];
    LFGFItem *it   = _filtered[(NSUInteger)ip.row];
    BOOL selected  = [it.family isEqualToString:gGFSelectedFamily];
    BOOL dl        = [_downloading containsObject:it.family];
    [cell configureWithItem:it isSelected:selected downloading:dl];
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    LFGFItem *it = _filtered[(NSUInteger)ip.row];
    if ([_downloading containsObject:it.family]) return;

    if (it.downloaded && it.previewFont) {
        // Ya descargada → aplicar directamente
        [self _applyItem:it];
        return;
    }
    // Descargar
    NSString *urlStr = it.files[@"regular"] ?: it.files.allValues.firstObject;
    if (!urlStr) return;

    [_downloading addObject:it.family];
    [tv reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];

    NSURL *url = [NSURL URLWithString:urlStr];
    NSURLSessionDownloadTask *dl = [[NSURLSession sharedSession]
        downloadTaskWithURL:url
          completionHandler:^(NSURL *loc, NSURLResponse *resp, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_downloading removeObject:it.family];
            if (err || !loc) {
                NSLog(@"[LF2:GF] Download error %@", err);
                [tv reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
                return;
            }
            LFGFEnsureDir();
            NSString *dest = LFGFPathForFamily(it.family);
            NSError *mvErr = nil;
            [[NSFileManager defaultManager] moveItemAtURL:loc
                                                    toURL:[NSURL fileURLWithPath:dest]
                                                    error:&mvErr];
            if (mvErr) { NSLog(@"[LF2:GF] Move error %@", mvErr); }
            NSString *ps = LFGFRegisterFont(dest);
            it.downloaded  = YES;
            it.previewFont = ps ? [UIFont fontWithName:ps size:26] : nil;
            [tv reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
            if (ps) [self _applyItem:it];
        });
    }];
    [dl resume];
}

- (void)_applyItem:(LFGFItem *)it {
    NSString *path = LFGFPathForFamily(it.family);
    NSString *ps   = LFGFRegisterFont(path);
    gGFSelectedFamily = it.family;
    gGFPostScriptName = ps;

    NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:GF_SUITE];
    [ud setObject:it.family forKey:GF_PREFS_KEY];
    [ud synchronize];

    [_table reloadData];

    if (self.onApply) self.onApply(it.family, ps);

    // Notificar refresh al tweak
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.aldazdev.lf2/refresh"), NULL, NULL, YES);

    // Toast visual
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(0,0,220,40)];
    toast.text = [NSString stringWithFormat:@"Applied: %@", it.family];
    toast.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    toast.textColor = [UIColor whiteColor];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.backgroundColor = [UIColor colorWithRed:0.1f green:0.6f blue:0.3f alpha:0.92f];
    toast.layer.cornerRadius = 12;
    toast.clipsToBounds = YES;
    toast.center = CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height - 80);
    toast.alpha = 0;
    [self.view addSubview:toast];
    [UIView animateWithDuration:0.3 animations:^{ toast.alpha=1; } completion:^(BOOL d){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.8*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.3 animations:^{ toast.alpha=0; } completion:^(BOOL d2){ [toast removeFromSuperview]; }];
        });
    }];
}

- (void)_resetToBuiltin {
    gGFSelectedFamily = nil;
    gGFPostScriptName = nil;
    NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:GF_SUITE];
    [ud removeObjectForKey:GF_PREFS_KEY];
    [ud synchronize];
    [_table reloadData];
    if (self.onApply) self.onApply(nil, nil);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.aldazdev.lf2/refresh"), NULL, NULL, YES);
}

@end

// ═══════════════════════════════════════════════════════════════════════════════
// Función pública: abre el VC de Google Fonts presentado desde parentVC
// ═══════════════════════════════════════════════════════════════════════════════
void LFGFPresent(UIViewController *parentVC, void(^onApply)(NSString *family, NSString *psName)) {
    LFGFViewController *vc = [[LFGFViewController alloc] init];
    vc.onApply = onApply;
    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    [parentVC presentViewController:vc animated:YES completion:nil];
}
