//
//  CALayerWithChildHitTest.m
//  SVGKit
//
//

#import "CALayerWithChildHitTest.h"
#import "SVGElement.h"

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
	// check sublayers, pick max z order hit
	int maxZ = INT_MIN;
	NSInteger size = self.sublayers.count;
	CALayer* topHit = nil;
	for(NSInteger i = 0; i < size; i++) {
		CGPoint ps = [self convertPoint:p toLayer:self.sublayers[i]];
		CALayer* hit = [self.sublayers[i] hitTest:ps];
		if(hit) {
			int z = [[hit valueForKey:kSVGElementZ] intValue];
			if(z > maxZ) {
				topHit = hit;
				maxZ = z;
			}
		}
	}
	
	// if has hit, return, otherwise check self
	if(topHit) {
		return topHit;
	} else {
		return (self.touchable && [self containsPoint:p]) ? self : nil;
	}
}

@end

