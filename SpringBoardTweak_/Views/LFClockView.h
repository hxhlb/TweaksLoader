#pragma once
#import <UIKit/UIKit.h>

// Ya no es una UIView standalone — es un helper que modifica
// directamente los subviews de SBFLockScreenDateView
@interface LFClockPatcher : NSObject

// Llamado desde hooked_lsClockLayout — parchea la view del lockscreen nativo
+ (void)patchDateView:(UIView *)dateView;

// Activa/desactiva modo drag en todos los patched views
+ (void)setEditMode:(BOOL)editing;

// Actualiza texto en todas las views parcheadas (timer)
+ (void)refreshAll;

@end
