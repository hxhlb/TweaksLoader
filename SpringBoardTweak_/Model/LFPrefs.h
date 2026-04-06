#pragma once
#import <UIKit/UIKit.h>

#define LF_SUITE    @"com.aldazdev.lf2"
#define LF_REFRESH   "com.aldazdev.lf2/refresh"

// Font families disponibles
typedef NS_ENUM(NSInteger, LFFontFamily) {
    LFFontSystem = 0,
    LFFontHelvetica,
    LFFontAvenir,
    LFFontFutura,
    LFFontMenlo,
    LFFontCourier,
    LFFontGeorgia,
    LFFontGillSans,
    LFFontCount
};

// Formatos de fecha
typedef NS_ENUM(NSInteger, LFDateFormat) {
    LFDateFull = 0,      // WEDNESDAY, MARCH 27
    LFDateShort,         // WED, MAR 27
    LFDateNumeric,       // 27 / 03 / 2026
    LFDateDayOnly,       // WEDNESDAY
    LFDateMonthDay,      // MARCH 27
    LFDateISO,           // 2026-03-27
    LFDateCount
};

@interface LFPrefs : NSObject
@property (class, readonly, strong) LFPrefs *shared;

// Tamaño único para ambos (horas y mins siempre igual)
@property CGFloat   clockSize;
@property BOOL      splitMode;
@property LFFontFamily fontFamily;
@property NSInteger    fontWeight;   // 0=Thin 1=Light 2=Regular 3=Medium 4=Bold

@property BOOL      use24h;
@property BOOL      hideClock;
@property LFDateFormat dateFormat;

// Colores
@property (strong) UIColor *clockColor;
@property (strong) UIColor *dateColor;

// Posiciones guardadas (centro, -1 = default)
@property CGFloat clockPX, clockPY;
@property CGFloat datePX,  datePY;

// Gradient
@property BOOL      clockGradient;
@property NSInteger clockGradientStyle;  // 0-5 preset, 6=custom
@property (strong) UIColor *clockGradColor1;
@property (strong) UIColor *clockGradColor2;

- (void)load;
- (void)save;

- (UIFont *)clockFont;
- (UIFont *)dateFont;
- (NSString *)formattedDate;
+ (NSArray<NSString*>*)fontFamilyNames;
+ (NSArray<NSString*>*)dateFormatPreviews;
@end
