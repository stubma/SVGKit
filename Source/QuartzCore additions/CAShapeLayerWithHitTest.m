#import "CAShapeLayerWithHitTest.h"
#import "SVGElement.h"

/*! Used by the main ShapeElement (and all subclasses) to do perfect "containsPoint" calculations via Apple's API calls
 
 This will only be called if it's the root of an SVG document and the hit was in the parent view on screen,
 OR if it's inside an SVGGElement that contained the hit
 */
@implementation CAShapeLayerWithHitTest

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
		BOOL pathContains = CGPathContainsPoint(self.path, NULL, p, false);
		
		if( pathContains )
		{
			for( CALayer* subLayer in self.sublayers )
			{
				SVGKitLogVerbose(@"...contains point, Apple will now check sublayer: %@", subLayer);
			}
			return TRUE;
		}
	}
	return FALSE;
}

- (CALayer *)hitTest:(CGPoint)p {
	// check sublayers, pick max z order hit
	int maxZ = INT_MIN;
	NSInteger size = self.sublayers.count;
	CALayer* topHit = nil;
	for(NSInteger i = 0; i < size; i++) {
		CGPoint ps = [self convertPoint:p toLayer:self.sublayers[i]];
		CALayer* hit = [self.sublayers[i] hitTest:ps];
		if(hit && !hit.hidden) {
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
