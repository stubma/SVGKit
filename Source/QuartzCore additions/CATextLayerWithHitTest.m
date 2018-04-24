#import "CATextLayerWithHitTest.h"
@import CoreText.CTFramesetter;

@implementation CATextLayerWithHitTest

- (instancetype)init {
	if(self = [super init]) {
		self.touchable = YES;
	}
	return self;
}

- (instancetype)initWithLayer:(id)layer {
	if(self = [super initWithLayer:layer]) {
		self.touchable = YES;
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

		// create frame setter
		NSAttributedString* text = (NSAttributedString*)self.string;
		[text drawInRect:self.bounds];

		// set current context
		UIGraphicsPushContext(context);
	} else {
		[super drawInContext:context];
	}
}

@end
