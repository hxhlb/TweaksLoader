#import "LFPrefs.h"

// Forward declaration — LFGoogleFonts.m
extern UIFont *LFGFFont(CGFloat size);
extern BOOL    LFGFIsActive(void);

@implementation LFPrefs

+ (instancetype)shared {
    static LFPrefs *s; static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [[LFPrefs alloc] init]; [s load]; });
    return s;
}

+ (NSArray<NSString*>*)fontFamilyNames {
    return @[@"System",@"Helvetica",@"Avenir",@"Futura",
             @"Menlo",@"Courier",@"Georgia",@"Gill Sans"];
}
+ (NSArray<NSString*>*)dateFormatPreviews {
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    NSDate *now = [NSDate date];
    NSMutableArray *out = [NSMutableArray array];
    NSArray *fmts = @[@"EEEE, MMMM d", @"EEE, MMM d",
                      @"d / MM / yyyy", @"EEEE", @"MMMM d", @"yyyy-MM-dd"];
    for (NSString *fmt in fmts) {
        f.dateFormat = fmt;
        [out addObject:[[f stringFromDate:now] uppercaseString]];
    }
    return out;
}

- (void)load {
    NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:LF_SUITE];
    [ud synchronize];
    self.clockSize   = [ud floatForKey:@"clockSize"]   ?: 80.f;
    self.splitMode   = [ud objectForKey:@"splitMode"]  ? [ud boolForKey:@"splitMode"] : NO;
    self.fontFamily  = [ud objectForKey:@"fontFamily"] ? (LFFontFamily)[ud integerForKey:@"fontFamily"] : LFFontSystem;
    self.fontWeight  = [ud objectForKey:@"fontWeight"] ? [ud integerForKey:@"fontWeight"] : 0;
    self.use24h      = [ud boolForKey:@"use24h"];
    self.hideClock   = [ud boolForKey:@"hideClock"];
    self.dateFormat  = [ud objectForKey:@"dateFormat"] ? (LFDateFormat)[ud integerForKey:@"dateFormat"] : LFDateFull;

    CGFloat cr = [ud objectForKey:@"clockR"] ? [ud floatForKey:@"clockR"] : 1;
    CGFloat cg = [ud objectForKey:@"clockG"] ? [ud floatForKey:@"clockG"] : 1;
    CGFloat cb = [ud objectForKey:@"clockB"] ? [ud floatForKey:@"clockB"] : 1;
    self.clockColor = [UIColor colorWithRed:cr green:cg blue:cb alpha:1];

    CGFloat dr = [ud objectForKey:@"dateR"] ? [ud floatForKey:@"dateR"] : 1;
    CGFloat dg = [ud objectForKey:@"dateG"] ? [ud floatForKey:@"dateG"] : 1;
    CGFloat db = [ud objectForKey:@"dateB"] ? [ud floatForKey:@"dateB"] : 1;
    self.dateColor = [UIColor colorWithRed:dr green:dg blue:db alpha:.85f];

    self.clockPX = [ud objectForKey:@"clockPX"] ? [ud floatForKey:@"clockPX"] : -1;
    self.clockPY = [ud objectForKey:@"clockPY"] ? [ud floatForKey:@"clockPY"] : -1;
    self.datePX  = [ud objectForKey:@"datePX"]  ? [ud floatForKey:@"datePX"]  : -1;
    self.datePY  = [ud objectForKey:@"datePY"]  ? [ud floatForKey:@"datePY"]  : -1;

    self.clockGradient      = [ud boolForKey:@"clockGradient"];
    self.clockGradientStyle = [ud objectForKey:@"clockGradientStyle"] ? [ud integerForKey:@"clockGradientStyle"] : 0;
    CGFloat g1r=[ud objectForKey:@"grad1R"]?[ud floatForKey:@"grad1R"]:1;
    CGFloat g1g=[ud objectForKey:@"grad1G"]?[ud floatForKey:@"grad1G"]:.3f;
    CGFloat g1b=[ud objectForKey:@"grad1B"]?[ud floatForKey:@"grad1B"]:.4f;
    self.clockGradColor1=[UIColor colorWithRed:g1r green:g1g blue:g1b alpha:1];
    CGFloat g2r=[ud objectForKey:@"grad2R"]?[ud floatForKey:@"grad2R"]:.1f;
    CGFloat g2g=[ud objectForKey:@"grad2G"]?[ud floatForKey:@"grad2G"]:.6f;
    CGFloat g2b=[ud objectForKey:@"grad2B"]?[ud floatForKey:@"grad2B"]:1;
    self.clockGradColor2=[UIColor colorWithRed:g2r green:g2g blue:g2b alpha:1];
}

- (void)save {
    NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:LF_SUITE];
    [ud setFloat:self.clockSize    forKey:@"clockSize"];
    [ud setBool:self.splitMode     forKey:@"splitMode"];
    [ud setInteger:self.fontFamily forKey:@"fontFamily"];
    [ud setInteger:self.fontWeight forKey:@"fontWeight"];
    [ud setBool:self.use24h        forKey:@"use24h"];
    [ud setBool:self.hideClock     forKey:@"hideClock"];
    [ud setInteger:self.dateFormat forKey:@"dateFormat"];
    CGFloat r,g,b,a;
    [self.clockColor getRed:&r green:&g blue:&b alpha:&a];
    [ud setFloat:r forKey:@"clockR"]; [ud setFloat:g forKey:@"clockG"]; [ud setFloat:b forKey:@"clockB"];
    [self.dateColor getRed:&r green:&g blue:&b alpha:&a];
    [ud setFloat:r forKey:@"dateR"]; [ud setFloat:g forKey:@"dateG"]; [ud setFloat:b forKey:@"dateB"];
    [ud setFloat:self.clockPX forKey:@"clockPX"]; [ud setFloat:self.clockPY forKey:@"clockPY"];
    [ud setFloat:self.datePX  forKey:@"datePX"];  [ud setFloat:self.datePY  forKey:@"datePY"];
    [ud setBool:self.clockGradient forKey:@"clockGradient"];
    [ud setInteger:self.clockGradientStyle forKey:@"clockGradientStyle"];
    if (self.clockGradColor1) {
        CGFloat r,g,b,a; [self.clockGradColor1 getRed:&r green:&g blue:&b alpha:&a];
        [ud setFloat:r forKey:@"grad1R"]; [ud setFloat:g forKey:@"grad1G"]; [ud setFloat:b forKey:@"grad1B"];
    }
    if (self.clockGradColor2) {
        CGFloat r,g,b,a; [self.clockGradColor2 getRed:&r green:&g blue:&b alpha:&a];
        [ud setFloat:r forKey:@"grad2R"]; [ud setFloat:g forKey:@"grad2G"]; [ud setFloat:b forKey:@"grad2B"];
    }
    [ud synchronize];
}

- (UIFontWeight)_weight {
    UIFontWeight w[] = {UIFontWeightThin,UIFontWeightLight,UIFontWeightRegular,
                        UIFontWeightMedium,UIFontWeightBold};
    NSInteger i = MAX(0, MIN(self.fontWeight, 4));
    return w[i];
}
- (UIFont *)_fontNamed:(NSString*)name size:(CGFloat)sz {
    if (!name) return [UIFont systemFontOfSize:sz weight:[self _weight]];
    UIFont *f = [UIFont fontWithName:name size:sz];
    return f ?: [UIFont systemFontOfSize:sz weight:[self _weight]];
}
- (UIFont *)clockFont {
    if (LFGFIsActive()) {
        UIFont *gf = LFGFFont(self.clockSize);
        if (gf) return gf;
    }
    NSArray *names = @[[NSNull null],@"HelveticaNeue-Thin",@"AvenirNext-UltraLight",
                       @"Futura-Medium",@"Menlo-Regular",@"CourierNewPSMT",
                       @"Georgia",@"GillSans-Light"];
    NSInteger i = MAX(0,MIN(self.fontFamily,(NSInteger)names.count-1));
    id n = names[i]; NSString *nm = [n isKindOfClass:[NSString class]] ? n : nil;
    return [self _fontNamed:nm size:self.clockSize];
}
- (UIFont *)dateFont {
    if (LFGFIsActive()) {
        UIFont *gf = LFGFFont(14);
        if (gf) return gf;
    }
    NSArray *names = @[[NSNull null],@"HelveticaNeue-Light",@"AvenirNext-UltraLight",
                       @"Futura-CondensedMedium",@"Menlo-Regular",@"CourierNewPSMT",
                       @"Georgia",@"GillSans-Light"];
    NSInteger i = MAX(0,MIN(self.fontFamily,(NSInteger)names.count-1));
    id n = names[i]; NSString *nm = [n isKindOfClass:[NSString class]] ? n : nil;
    return [self _fontNamed:nm size:14];
}
- (NSString *)formattedDate {
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    NSArray *fmts = @[@"EEEE, MMMM d",@"EEE, MMM d",
                      @"d / MM / yyyy",@"EEEE",@"MMMM d",@"yyyy-MM-dd"];
    NSInteger i = MAX(0,MIN(self.dateFormat,(NSInteger)fmts.count-1));
    f.dateFormat = fmts[i];
    return [[f stringFromDate:[NSDate date]] uppercaseString];
}
@end
