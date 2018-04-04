#import "SVGGElement.h"

#import "CALayerWithChildHitTest.h"

#import "SVGHelperUtilities.h"
#import <objc/runtime.h>

@interface SVGGElement ()

@property (assign, nonatomic, readonly) float parentWidth;
@property (assign, nonatomic, readonly) float parentHeight;

@end

@implementation SVGGElement

@synthesize transform; // each SVGElement subclass that conforms to protocol "SVGTransformable" has to re-synthesize this to work around bugs in Apple's Objective-C 2.0 design that don't allow @properties to be extended by categories / protocols

- (void)postProcessAttributesAddingErrorsTo:(SVGKParseResult *)parseResult {
	[super postProcessAttributesAddingErrorsTo:parseResult];
	
	// padding
	if( [[self getAttribute:@"padding"] length] > 0 ) {
		NSArray* paddingElements = [[self getAttribute:@"padding"] componentsSeparatedByString:@" "];
		if(paddingElements.count == 4) {
			self.pl = [SVGLength svgLengthFromNSString:paddingElements[0]];
			self.pt = [SVGLength svgLengthFromNSString:paddingElements[1]];
			self.pr = [SVGLength svgLengthFromNSString:paddingElements[2]];
			self.pb = [SVGLength svgLengthFromNSString:paddingElements[3]];
		}
	}
	if(!self.pl) {
		self.pl = [SVGLength svgLengthZero];
		self.pr = [SVGLength svgLengthZero];
		self.pt = [SVGLength svgLengthZero];
		self.pb = [SVGLength svgLengthZero];
	}
	
	// margin
	if( [[self getAttribute:@"margin"] length] > 0 ) {
		NSArray* marginElements = [[self getAttribute:@"margin"] componentsSeparatedByString:@" "];
		if(marginElements.count == 4) {
			self.ml = [SVGLength svgLengthFromNSString:marginElements[0]];
			self.mt = [SVGLength svgLengthFromNSString:marginElements[1]];
			self.mr = [SVGLength svgLengthFromNSString:marginElements[2]];
			self.mb = [SVGLength svgLengthFromNSString:marginElements[3]];
		}
	}
	if(!self.ml) {
		self.ml = [SVGLength svgLengthZero];
		self.mr = [SVGLength svgLengthZero];
		self.mt = [SVGLength svgLengthZero];
		self.mb = [SVGLength svgLengthZero];
	}
	
	// other
	self.width = [self getAttributeAsSVGLength:@"width"];
	self.height = [self getAttributeAsSVGLength:@"height"];
	self.row = [@"true" isEqualToString:[self getAttribute:@"row"]];
	
	// item alignment
	self.itemAlignment = SVGGAlignItemStart;
	NSString* align = [self getAttribute:@"align-item"];
	if([@"center" isEqualToString:align]) {
		self.itemAlignment = SVGGAlignItemCenter;
	} else if([@"end" isEqualToString:align]) {
		self.itemAlignment = SVGGAlignItemEnd;
	}
}

- (float)parentWidth {
	// if parent is g, use g width, otherwise use viewport width
	float dim = self.viewport.width;
	if([self.parentNode isKindOfClass:[SVGGElement class]]) {
		SVGGElement* g = (SVGGElement*)self.parentNode;
		dim = g.absoluteWidth;
	}
	return dim;
}

- (float)parentHeight {
	// if parent is g, use g height, otherwise use viewport height
	float dim = self.viewport.height;
	if([self.parentNode isKindOfClass:[SVGGElement class]]) {
		SVGGElement* g = (SVGGElement*)self.parentNode;
		dim = g.absoluteHeight;
	}
	return dim;
}

- (float)absoluteWidth {
	// calculate
	float dim = self.parentClientWidth;
	float width = [self.width pixelsValueWithDimension:dim];
	if(width <= 0) {
		float ml = [self.ml pixelsValueWithDimension:dim];
		float mr = [self.mr pixelsValueWithDimension:dim];
		width = dim - ml - mr;
	}
	return width;
}

- (float)absoluteHeight {
	// calculate
	float dim = self.parentClientHeight;
	float height = [self.height pixelsValueWithDimension:dim];
	if(height <= 0) {
		float mt = [self.mt pixelsValueWithDimension:dim];
		float mb = [self.mb pixelsValueWithDimension:dim];
		height = dim - mt - mb;
	}
	return height;
}

- (float)clientWidth {
	float dim = self.absoluteWidth;
	float pl = [self.pl pixelsValueWithDimension:dim];
	float pr = [self.pr pixelsValueWithDimension:dim];
	return dim - pl - pr;
}

- (float)clientHeight {
	float dim = self.absoluteHeight;
	float pt = [self.pt pixelsValueWithDimension:dim];
	float pb = [self.pb pixelsValueWithDimension:dim];
	return dim - pt - pb;
}

- (CGPoint)originOfChild:(SVGElement*)child {
	float pw = self.parentClientWidth;
	float ph = self.parentClientHeight;
	float x = [self.pl pixelsValueWithDimension:pw];
	float y = [self.pt pixelsValueWithDimension:ph];
	NSArray<Node*>* gList = [self.childNodes subarrayOfClass:[SVGGElement class]];
	NSInteger idx = [gList indexOfObject:child];
	for(NSInteger i = 0; i < idx; i++) {
		SVGGElement* sibling = (SVGGElement*)gList[i];
		if(self.row) {
			x += sibling.absoluteWidth;
		} else {
			y += sibling.absoluteHeight;
		}
	}
	return CGPointMake(x, y);
}

- (CALayer *) newLayer
{
	
	CALayer* _layer = [CALayerWithChildHitTest layer];
	
	// set frame
	// for easy handler, we define g can only contain g or one other element
	if([self.parentNode isKindOfClass:[SVGGElement class]]) {
		CGPoint pos = [(SVGGElement*)self.parentNode originOfChild:self];
		_layer.frame = CGRectMake(pos.x, pos.y, self.absoluteWidth, self.absoluteHeight);
	} else {
		float ml = [self.ml pixelsValueWithDimension:self.viewport.width];
		float mt = [self.mt pixelsValueWithDimension:self.viewport.width];
		_layer.frame = CGRectMake(ml, mt, self.absoluteWidth, self.absoluteHeight);
	}
	
	[SVGHelperUtilities configureCALayer:_layer usingElement:self];
	
	return _layer;
}

- (void)layoutLayer:(CALayer *)layer {
	float pcw = self.parentClientWidth;
	float pch = self.parentClientHeight;
	float pl = [self.pl pixelsValueWithDimension:pcw];
	float pt = [self.pt pixelsValueWithDimension:pch];
	float cw = self.clientWidth;
	float ch = self.clientHeight;
	
	/** make mainrect the UNION of all sublayer's frames (i.e. their individual "bounds" inside THIS layer's space) */
	for ( CALayer *currentLayer in [layer sublayers] ) {
		SVGElement* e = (SVGElement*)objc_getAssociatedObject(currentLayer, kSVGElement);
		if(e && ![e isKindOfClass:[SVGGElement class]]) {
			CGRect frame = currentLayer.frame;
			frame.origin = CGPointMake(pl, pt);
			switch(self.itemAlignment) {
				case SVGGAlignItemCenter:
					if(self.row) {
						frame.origin.x = pl + (cw - frame.size.width) / 2;
					} else {
						frame.origin.y = pt + (ch - frame.size.height) / 2;
					}
					break;
				case SVGGAlignItemEnd:
					if(self.row) {
						frame.origin.x = pl + cw - frame.size.width;
					} else {
						frame.origin.y = pt + ch - frame.size.height;
					}
					break;
				default:
					break;
			}
			currentLayer.frame = frame;
		}
	}
}

@end
