//
//  CALayerWithChildHitTest.m
//  SVGKit
//
//

#import "CALayerWithChildHitTest.h"

@implementation CALayerWithChildHitTest

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

- (BOOL) containsPoint:(CGPoint)p
{
	BOOL boundsContains = CGRectContainsPoint(self.bounds, p); // must be BOUNDS because Apple pre-converts the point to local co-ords before running the test
	
	if( boundsContains )
	{
		BOOL atLeastOneChildContainsPoint = FALSE;
		
		for( CALayer* subLayer in self.sublayers )
		{
			// must pre-convert the point to local co-ords before running the test because Apple defines "containsPoint" in that fashion
			
			CGPoint pointInSubLayer = [self convertPoint:p toLayer:subLayer];
			
			if( [subLayer containsPoint:pointInSubLayer] )
			{
				atLeastOneChildContainsPoint = TRUE;
				break;
			}
		}
		
		return atLeastOneChildContainsPoint;
	}
	
	return NO;
}

- (CALayer *)hitTest:(CGPoint)p {
	return self.touchable ? [super hitTest:p] : nil;
}

@end

