#import "LFButton.h"

@interface LFButton ()
@property CGPoint dragOffset;
@property BOOL dragging;
@end

@implementation LFButton

- (instancetype)initWithFrame:(CGRect)f {
    self = [super initWithFrame:f];
    if (!self) return nil;

    self.layer.cornerRadius = 27;
    if (@available(iOS 13.0,*)) self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.shadowColor   = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.35f;
    self.layer.shadowRadius  = 12;
    self.layer.shadowOffset  = CGSizeMake(0,4);
    self.layer.borderWidth   = 0.5f;
    self.layer.borderColor   = [UIColor colorWithWhite:1 alpha:0.3f].CGColor;

    UIBlurEffect *fx;
    if (@available(iOS 13.0,*)) fx=[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    else fx=[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *bv = [[UIVisualEffectView alloc] initWithEffect:fx];
    bv.frame = self.bounds;
    bv.layer.cornerRadius = 27;
    if (@available(iOS 13.0,*)) bv.layer.cornerCurve = kCACornerCurveContinuous;
    bv.layer.masksToBounds = YES;
    bv.userInteractionEnabled = NO;
    [self addSubview:bv];

    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.frame  = self.bounds;
    grad.cornerRadius = 27;
    grad.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.18f].CGColor,
                    (id)[UIColor colorWithWhite:1 alpha:0.04f].CGColor];
    grad.startPoint = CGPointMake(0.5f,0);
    grad.endPoint   = CGPointMake(0.5f,1);
    [self.layer addSublayer:grad];

    if (@available(iOS 13.0,*)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration
            configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
        UIImage *img = [UIImage systemImageNamed:@"slider.horizontal.3" withConfiguration:cfg];
        UIImageView *iv = [[UIImageView alloc] initWithImage:img];
        iv.frame = CGRectMake(14,14,26,26);
        iv.tintColor = [UIColor colorWithRed:0.46f green:0.83f blue:1 alpha:1];
        iv.contentMode = UIViewContentModeScaleAspectFit;
        iv.userInteractionEnabled = NO;
        [self addSubview:iv];
    }

    self.alpha = 0.85f;
    self.userInteractionEnabled = YES;
    return self;
}

- (void)touchesBegan:(NSSet<UITouch*>*)t withEvent:(UIEvent*)e {
    UITouch *touch = t.anyObject;
    CGPoint loc = [touch locationInView:self.superview];
    self.dragOffset = CGPointMake(loc.x - self.center.x, loc.y - self.center.y);
    self.dragging = NO;
    [UIView animateWithDuration:0.12 animations:^{
        self.transform = CGAffineTransformMakeScale(1.1f,1.1f);
        self.alpha = 1;
    }];
}

- (void)touchesMoved:(NSSet<UITouch*>*)t withEvent:(UIEvent*)e {
    UITouch *touch = t.anyObject;
    CGPoint loc = [touch locationInView:self.superview];
    CGPoint nc = CGPointMake(loc.x - self.dragOffset.x, loc.y - self.dragOffset.y);
    if (!self.dragging && fabs(nc.x-self.center.x)+fabs(nc.y-self.center.y) < 8) return;
    self.dragging = YES;
    CGRect b = self.superview.bounds;
    nc.x = MAX(33, MIN(b.size.width-33,  nc.x));
    nc.y = MAX(33, MIN(b.size.height-33, nc.y));
    self.center = nc;
}

- (void)touchesEnded:(NSSet<UITouch*>*)t withEvent:(UIEvent*)e {
    BOOL was = self.dragging;
    self.dragging = NO;
    [UIView animateWithDuration:0.12 animations:^{
        self.transform = CGAffineTransformIdentity;
        self.alpha = 0.85f;
    }];
    if (was) [self snap];
    else     [self.delegate lockFlowButtonTapped];
}

- (void)touchesCancelled:(NSSet<UITouch*>*)t withEvent:(UIEvent*)e {
    self.dragging = NO;
    self.transform = CGAffineTransformIdentity;
    self.alpha = 0.85f;
}

- (void)snap {
    CGRect b = self.superview.bounds;
    CGFloat tx = (self.center.x < b.size.width/2) ? 39 : (b.size.width-39);
    CGFloat ty = MAX(80, MIN(b.size.height-60, self.center.y));
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.72f
             initialSpringVelocity:0.4f options:UIViewAnimationOptionAllowUserInteraction
                        animations:^{ self.center=CGPointMake(tx,ty); } completion:nil];
}

- (UIView*)hitTest:(CGPoint)p withEvent:(UIEvent*)e {
    return CGRectContainsPoint(CGRectInset(self.bounds,-10,-10),p) ? self : nil;
}

@end
