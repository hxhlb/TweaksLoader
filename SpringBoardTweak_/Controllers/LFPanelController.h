#pragma once
#import <UIKit/UIKit.h>

@protocol LFPanelDelegate <NSObject>
- (void)panelDidApply;
- (void)panelDidDismiss;
@end

@interface LFPanelController : UIViewController
@property (weak) id<LFPanelDelegate> delegate;
+ (instancetype)panel;
- (void)dismiss:(id)sender;
@end
