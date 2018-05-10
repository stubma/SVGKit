#import "CATextLayerWithHitTest.h"
@import CoreText.CTFramesetter;

@implementation CATextLayerWithHitTest

- (instancetype)init {
	if(self = [super init]) {
		self.touchable = YES;
		self.insets = UIEdgeInsetsZero;
	}
	return self;
}

- (instancetype)initWithLayer:(id)layer {
	if(self = [super initWithLayer:layer]) {
		self.touchable = YES;
		self.insets = UIEdgeInsetsZero;
	}
	return self;
}

- (CALayer *)hitTest:(CGPoint)p {
	return self.touchable ? [super hitTest:p] : nil;
}

- (void)drawInContext:(CGContextRef)context {
	if(self.drawParagraphStyle) {
		UIGraphicsPushContext(context);

		// set drawing options
		CGContextSetShouldAntialias(context, YES);

		// set drawing options
		CGContextSetTextDrawingMode(context, kCGTextFill);

		// draw text
		CGRect rect = self.bounds;
		rect.origin.x += self.insets.left;
		rect.origin.y += self.insets.top;
		rect.size.width -= self.insets.left + self.insets.right;
		rect.size.height -= self.insets.top + self.insets.bottom;
		NSAttributedString* text = (NSAttributedString*)self.string;
		[text drawWithRect:rect
				   options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
				   context:nil];

		// set current context
		UIGraphicsPushContext(context);
	} else {
		[super drawInContext:context];
	}
}

@end
