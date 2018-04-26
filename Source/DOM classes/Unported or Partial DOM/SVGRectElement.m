#import "SVGRectElement.h"
#import "SVGGElement.h"
#import "SVGElement_ForParser.h" // to resolve Xcode circular dependencies; in long term, parsing SHOULD NOT HAPPEN inside any class whose name starts "SVG" (because those are reserved classes for the SVG Spec)

#import "SVGHelperUtilities.h"

@interface SVGRectElement ()

#if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_7_0 
void CGPathAddRoundedRect (CGMutablePathRef path, CGRect rect, CGFloat radiusX, CGFloat radiusY);
#endif

@end

@implementation SVGRectElement

@synthesize transform; // each SVGElement subclass that conforms to protocol "SVGTransformable" has to re-synthesize this to work around bugs in Apple's Objective-C 2.0 design that don't allow @properties to be extended by categories / protocols

@synthesize x = _x;
@synthesize y = _y;
@synthesize width = _width;
@synthesize height = _height;

@synthesize rx = _rx;
@synthesize ry = _ry;

#if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_7_0 
// adapted from http://www.cocoanetics.com/2010/02/drawing-rounded-rectangles/

void CGPathAddRoundedRect (CGMutablePathRef path, CGRect rect, CGFloat radiusX, CGFloat radiusY) {
	CGRect innerRect = CGRectInset(rect, radiusX, radiusY);
	
	CGFloat innerRight = innerRect.origin.x + innerRect.size.width;
	CGFloat right = rect.origin.x + rect.size.width;
	CGFloat innerBottom = innerRect.origin.y + innerRect.size.height;
	CGFloat bottom = rect.origin.y + rect.size.height;
	
	CGFloat innerTop = innerRect.origin.y;
	CGFloat top = rect.origin.y;
	CGFloat innerLeft = innerRect.origin.x;
	CGFloat left = rect.origin.x;
	
	CGPathMoveToPoint(path, NULL, innerLeft, top);
	
	CGPathAddLineToPoint(path, NULL, innerRight, top);
	/** c.f http://stackoverflow.com/a/12152442/153422 */
	CGAffineTransform t = CGAffineTransformConcat( CGAffineTransformMakeScale(1.0, radiusY/radiusX), CGAffineTransformMakeTranslation(innerRight, innerTop));
	CGPathAddArc(path, &t, 0, 0, radiusX, -M_PI_2, 0, false);
	
	CGPathAddLineToPoint(path, NULL, right, innerBottom);
	/** c.f http://stackoverflow.com/a/12152442/153422 */
	t = CGAffineTransformConcat( CGAffineTransformMakeScale(1.0, radiusY/radiusX), CGAffineTransformMakeTranslation(innerRight, innerBottom));
	CGPathAddArc(path, &t, 0, 0, radiusX, 0, M_PI_2, false);
	
	CGPathAddLineToPoint(path, NULL, innerLeft, bottom);
	/** c.f http://stackoverflow.com/a/12152442/153422 */
	t = CGAffineTransformConcat( CGAffineTransformMakeScale(1.0, radiusY/radiusX), CGAffineTransformMakeTranslation(innerLeft, innerBottom));
	CGPathAddArc(path, &t, 0, 0, radiusX, M_PI_2, M_PI, false);
	
	CGPathAddLineToPoint(path, NULL, left, innerTop);
	/** c.f http://stackoverflow.com/a/12152442/153422 */
	t = CGAffineTransformConcat( CGAffineTransformMakeScale(1.0, radiusY/radiusX), CGAffineTransformMakeTranslation(innerLeft, innerTop));
	CGPathAddArc(path, &t, 0, 0, radiusX, M_PI, 3*M_PI_2, false);
	
	CGPathCloseSubpath(path);
}
#endif

- (void)updatePathShape {
	float pcw = self.parentClientWidth;
	float pch = self.parentClientHeight;
	
	CGMutablePathRef path = CGPathCreateMutable();
	CGRect rect = CGRectMake([_x pixelsValueWithDimension:pcw], [_y pixelsValueWithDimension:pch],
							 [_width pixelsValueWithDimension:pcw], [_height pixelsValueWithDimension:pch]);
	
	// handle anchor
	switch(_x.anchor) {
		case CSS_ANCHOR_TR:
		case CSS_ANCHOR_BR:
			rect.origin.x = pcw - rect.size.width + rect.origin.x;
			break;
		case CSS_ANCHOR_CENTER:
			rect.origin.x = pcw / 2 - rect.size.width / 2 + rect.origin.x;
			break;
		default:
			break;
	}
	switch (_y.anchor) {
		case CSS_ANCHOR_BL:
		case CSS_ANCHOR_BR:
			rect.origin.y = pch - rect.size.height + rect.origin.y;
			break;
		case CSS_ANCHOR_CENTER:
			rect.origin.y = pch / 2 - rect.size.height / 2 + rect.origin.y;
			break;
		default:
			break;
	}
	
	CGFloat radiusXPixels = _rx != nil ? [_rx pixelsValueWithDimension:pcw] : 0;
	CGFloat radiusYPixels = _ry != nil ? [_ry pixelsValueWithDimension:pch] : 0;
	
	if( radiusXPixels == 0 && radiusYPixels == 0 )
	{
		CGPathAddRect(path, NULL, rect);
	}
	else
	{
		if( radiusXPixels > 0 && radiusYPixels == 0 ) // if RY unspecified, make it equal to RX
			radiusYPixels = radiusXPixels;
		else if( radiusXPixels == 0 && radiusYPixels > 0 ) // if RX unspecified, make it equal to RY
			radiusXPixels = radiusYPixels;
		
		if( radiusXPixels > CGRectGetWidth(rect) / 2 ) // give RX max value of half rect width
			radiusXPixels = CGRectGetWidth(rect) / 2;
		
		if( radiusYPixels > CGRectGetHeight(rect) / 2 ) // give RY max value of half rect height
			radiusYPixels = CGRectGetHeight(rect) / 2;
		
		CGPathAddRoundedRect(path,
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
							 nil,
#endif
							 rect, radiusXPixels, radiusYPixels);
	}
	self.pathForShapeInRelativeCoords = path;
	CGPathRelease(path);
}

- (void)postProcessAttributesAddingErrorsTo:(SVGKParseResult *)parseResult {
	[super postProcessAttributesAddingErrorsTo:parseResult];
	
	if( [[self getAttribute:@"x"] length] > 0 )
	_x = [SVGLength svgLengthFromNSString:[self getAttribute:@"x"]];
	
	if( [[self getAttribute:@"y"] length] > 0 )
	_y = [SVGLength svgLengthFromNSString:[self getAttribute:@"y"]];
	
	if( [[self getAttribute:@"width"] length] > 0 )
	_width = [SVGLength svgLengthFromNSString:[self getAttribute:@"width"]];
	
	if( [[self getAttribute:@"height"] length] > 0 )
	_height = [SVGLength svgLengthFromNSString:[self getAttribute:@"height"]];
	
	if( [[self getAttribute:@"rx"] length] > 0 )
	_rx = [SVGLength svgLengthFromNSString:[self getAttribute:@"rx"]];
	
	if( [[self getAttribute:@"ry"] length] > 0 )
	_ry = [SVGLength svgLengthFromNSString:[self getAttribute:@"ry"]];

	/**
	 Create a square OR rounded rectangle as a CGPath
	 
	 */
	[self updatePathShape];
}

- (CALayer *) newLayer {
	// if width/height not set, use g size if parent node is g element
	if(!self.width || !self.height) {
		if([self.parentNode isKindOfClass:[SVGGElement class]]) {
			SVGGElement* g = (SVGGElement*)self.parentNode;
			if(!self.width) {
				self.width = [SVGLength svgLengthFromFloat:g.clientWidth];
			}
			if(!self.height) {
				self.height = [SVGLength svgLengthFromFloat:g.clientHeight];
			}
			[self updatePathShape];
		}
	}
	
	return [super newLayer];
}

@end
