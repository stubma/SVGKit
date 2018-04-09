#import "CATextLayerWithHitTest.h"

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

@end
