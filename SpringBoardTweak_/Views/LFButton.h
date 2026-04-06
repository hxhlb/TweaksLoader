#pragma once
#import <UIKit/UIKit.h>

@protocol LFButtonDelegate <NSObject>
- (void)lockFlowButtonTapped;
@end

@interface LFButton : UIView
@property (weak) id<LFButtonDelegate> delegate;
@end
