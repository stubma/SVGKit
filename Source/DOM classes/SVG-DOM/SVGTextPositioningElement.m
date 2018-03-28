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
	
	self.x = [self getAttributeAsSVGLength:@"x"];
	[self.x convertToAbsolute:self.viewport.width];
	self.y = [self getAttributeAsSVGLength:@"y"];
	[self.y convertToAbsolute:self.viewport.height];
	self.dx = [self getAttributeAsSVGLength:@"dx"];
	[self.dx convertToAbsolute:self.viewport.width];
	self.dy = [self getAttributeAsSVGLength:@"dy"];
	[self.dy convertToAbsolute:self.viewport.height];
	self.rotate = [self getAttributeAsSVGLength:@"rotate"];
}

@end
