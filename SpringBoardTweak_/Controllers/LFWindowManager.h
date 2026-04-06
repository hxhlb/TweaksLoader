#pragma once
#import <UIKit/UIKit.h>

@interface LFWindowManager : NSObject
+ (instancetype)shared;
- (void)setup;
- (void)patchLockscreenView:(UIView *)view;
- (void)lockscreenDidAppear;
- (void)lockscreenDidDisappear;
- (void)refreshClock;
- (void)togglePanel;
- (void)enterEditMode;
@end
