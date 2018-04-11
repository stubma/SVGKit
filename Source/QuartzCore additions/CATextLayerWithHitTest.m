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
		// create frame setter
		NSAttributedString* text = (NSAttributedString*)self.string;
		CTFramesetterRef fs = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)text);
		
		// create frame
		CGMutablePathRef path = CGPathCreateMutable();
		CGPathAddRect(path, NULL, self.bounds);
		CTFrameRef frame = CTFramesetterCreateFrame(fs,
													CFRangeMake(0, 0),
													path,
													NULL);
		CFRelease(path);
		
		// set current context
		UIGraphicsPushContext(context);
		
		// alow anti-aliasing
		CGContextSetAllowsAntialiasing(context, YES);
		
		// vertical alignment
		CGContextTranslateCTM(context, 0, self.bounds.size.height);
		CGContextScaleCTM(context, 1.0, -1.0);
		
		// draw
		CTFrameDraw(frame, context);
		
		// pop
		UIGraphicsPopContext();
		
		// release
		CFRelease(fs);
		CFRelease(frame);
	} else {
		[super drawInContext:context];
	}
}

@end
