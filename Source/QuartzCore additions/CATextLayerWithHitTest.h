#import <QuartzCore/QuartzCore.h>

@interface CATextLayerWithHitTest : CATextLayer

@property (assign, nonatomic) BOOL touchable;
@property (assign, nonatomic) BOOL drawParagraphStyle;
@property (assign, nonatomic) UIEdgeInsets insets;

@end
