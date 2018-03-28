#import "SVGTextPositioningElement.h"
#import "SVGTextPositioningElement_Mutable.h"

#import "SVGElement_ForParser.h" // because we do post-processing of the SVG x,y,dx,dy,rotate attributes

@interface SVGTextPositioningElement ()

@end

@implementation SVGTextPositioningElement

@synthesize x,y,dx,dy,rotate;


- (void)postProcessAttributesAddingErrorsTo:(SVGKParseResult *)parseResult
{
	[super postProcessAttributesAddingErrorsTo:parseResult];
	
	// save viewport size
	SVGRect r = parseResult.rootOfSVGTree.viewport;
	
	self.x = [self getAttributeAsSVGLength:@"x"];
	[self.x convertToAbsolute:r.width];
	self.y = [self getAttributeAsSVGLength:@"y"];
	[self.y convertToAbsolute:r.height];
	self.dx = [self getAttributeAsSVGLength:@"dx"];
	[self.dx convertToAbsolute:r.width];
	self.dy = [self getAttributeAsSVGLength:@"dy"];
	[self.dy convertToAbsolute:r.height];
	self.rotate = [self getAttributeAsSVGLength:@"rotate"];
}

@end
