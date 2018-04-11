#import "SVGTextElement.h"

#import <CoreText/CoreText.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

#import "SVGElement_ForParser.h" // to resolve Xcode circular dependencies; in long term, parsing SHOULD NOT HAPPEN inside any class whose name starts "SVG" (because those are reserved classes for the SVG Spec)

#import "SVGHelperUtilities.h"
#import "SVGUtils.h"
#import "CSSPrimitiveValue.h"
#import "SVGRichText.h"
#import "CATextLayerWithHitTest.h"

@implementation SVGTextElement

@synthesize transform; // each SVGElement subclass that conforms to protocol "SVGTransformable" has to re-synthesize this to work around bugs in Apple's Objective-C 2.0 design that don't allow @properties to be extended by categories / protocols


- (CALayer *) newLayer
{
	/**
	 BY DESIGN: we work out the positions of all text in ABSOLUTE space, and then construct the Apple CALayers and CATextLayers around
	 them, as required.
	 
	 Because: Apple's classes REQUIRE us to provide a lot of this info up-front. Sigh
	 And: SVGKit works by pre-baking everything into position (its faster, and avoids Apple's broken CALayer.transform property)
	 */
	CGAffineTransform textTransformAbsolute = [SVGHelperUtilities transformAbsoluteIncludingViewportForTransformableOrViewportEstablishingElement:self];
	
	/**
	 Apple's CATextLayer is poor - one of those classes Apple hasn't finished writing?
	 
	 It's incompatible with UIFont (Apple states it is so), and it DOES NOT WORK by default:
	 
	 If you assign a font, and a font size, and text ... you get a blank empty layer of
	 size 0,0
	 
	 Because Apple requires you to ALSO do all the work of calculating the font size, shape,
	 position etc.
	 
	 But its the easiest way to get FULL control over size/position/rotation/etc in a CALayer
	 */
	NSString* actualSize = [self cascadedValueForStylableProperty:@"font-size"];
	NSString* actualFamily = [self cascadedValueForStylableProperty:@"font-family"];
	
	CGFloat effectiveFontSize = (actualSize.length > 0) ? [actualSize floatValue] : 12; // I chose 12. I couldn't find an official "default" value in the SVG spec.
	/** Convert the size down using the SVG transform at this point, before we calc the frame size etc */
//	effectiveFontSize = CGSizeApplyAffineTransform( CGSizeMake(0,effectiveFontSize), textTransformAbsolute ).height; // NB important that we apply a transform to a "CGSize" here, so that Apple's library handles worrying about whether to ignore skew transforms etc
	
	/** find a valid font reference, or Apple's APIs will break later */
	/** undocumented Apple bug: CTFontCreateWithName cannot accept nil input*/
	if(actualFamily == nil) {
		actualFamily = @"HelveticaNeue";
	}

	/** Convert all whitespace to spaces, and trim leading/trailing (SVG doesn't support leading/trailing whitespace, and doesnt support CR LF etc) */
	
	// parse rich text string
	// the rich string can be in following format:
	// 1. tag format, it is a custom format which use [] to present style info, it is human readable
	// but not very powerful
	// 2. base64 format, it is a encoded NSAttributedString
	NSString* encoding = [self cascadedValueForStylableProperty:@"encoding"];
	SVGRichText* rich = nil;
	NSAttributedString* richStr = nil;
	if([@"base64" isEqualToString:encoding]) {
		NSData* data = [[NSData alloc] initWithBase64EncodedString:self.textContent
														   options:NSDataBase64DecodingIgnoreUnknownCharacters];
		richStr = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	} else {
		rich = [[SVGRichText alloc] initWithTagText:[self.textContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
										   fontName:actualFamily
										   fontSize:effectiveFontSize];
	}
	
	// create text layer
    CATextLayerWithHitTest *label = [[CATextLayerWithHitTest alloc] init];
    [SVGHelperUtilities configureCALayer:label usingElement:self];
	
	// set default color
	label.foregroundColor = [SVGHelperUtilities parseFillForElement:self];
	if(rich) {
		rich.textColor = [UIColor colorWithCGColor:label.foregroundColor];
	}
	
	/** This is complicated for three reasons.
	 Partly: Apple and SVG use different defitions for the "origin" of a piece of text
	 Partly: Bugs in Apple's CoreText
	 Partly: flaws in Apple's CALayer's handling of frame,bounds,position,anchorPoint,affineTransform
	 
	 1. CALayer.frame DOES NOT EXIST AS A REAL PROPERTY - if you read Apple's docs you eventually realise it is fake. Apple explicitly says it is "not defined". They should DELETE IT from their API!
	 2. CALayer.bounds and .position ARE NOT AFFECTED BY .affineTransform - only the contents of the layer is affected
	 3. SVG defines two SEMI-INCOMPATIBLE ways of positioning TEXT objects, that we have to correctly combine here.
	 4. So ... to apply a transform to the layer text:
	     i. find the TRANSFORM
	     ii. merge it with the local offset (.x and .y from SVG) - which defaults to (0,0)
	     iii. apply that to the layer
	     iv. set the position to 0
	     v. BECAUSE SVG AND APPLE DEFINE ORIGIN DIFFERENTLY: subtract the "untransformed" height of the font ... BUT: pre-transformed ONLY BY the 'multiplying (non-translating)' part of the TRANSFORM.
	     vi. set the bounds to be (whatever Apple's CoreText says is necessary to render TEXT at FONT SIZE, with NO TRANSFORMS)
	 */
	if(rich) {
    	label.bounds = rich.bounds;
	} else {
		CGRect bounds = [richStr boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)
											 options:NSStringDrawingUsesLineFragmentOrigin
											 context:nil];
		bounds.size.width = self.viewport.width;
		bounds.size.height = self.viewport.height;
		label.bounds = bounds;
		label.drawParagraphStyle = YES;
	}
	
	/** add on the local x,y that will NOT BE iNCLUDED IN THE TRANSFORM
	 AUTOMATICALLY BECAUSE THEY ARE NOT TRANSFORM COMMANDS IN SVG SPEC!!
	 -- but they ARE part of the "implicit transform" of text elements!! (bad SVG Spec design :( )
	 
	 NB: the local bits (x/y offset) have to be pre-transformed by
	 
	 LUMA: to support relative position, I move it after final bounds is calculated
	 */
	float x = [self.x pixelsValue];
	float y = [self.y pixelsValue];
	switch(self.x.anchor) {
		case CSS_ANCHOR_RT:
		case CSS_ANCHOR_RB:
			x = self.viewport.width + x - label.bounds.size.width;
			break;
		case CSS_ANCHOR_CENTER:
			x = self.viewport.width / 2 + x - label.bounds.size.width / 2;
			break;
		default:
			break;
	}
	switch (self.y.anchor) {
		case CSS_ANCHOR_RB:
		case CSS_ANCHOR_LB:
			y = self.viewport.height + y - label.bounds.size.height;
			break;
		case CSS_ANCHOR_CENTER:
			y = self.viewport.height / 2 + y - label.bounds.size.height / 2;
			break;
		default:
			break;
	}
	CGAffineTransform textTransformAbsoluteWithLocalPositionOffset = CGAffineTransformConcat( CGAffineTransformMakeTranslation(x, y), textTransformAbsolute);
	
	/** NB: specific to Apple: the "origin" is the TOP LEFT corner of first line of text, whereas SVG uses the font's internal origin
	 (which is BOTTOM LEFT CORNER OF A LETTER SUCH AS 'a' OR 'x' THAT SITS ON THE BASELINE ... so we have to make the FRAME start "font leading" higher up
	 
	 WARNING: Apple's font-rendering system has some nasty bugs (c.f. StackOverflow)
	 
	 We TRIED to use the font's built-in numbers to correct the position, but Apple's own methods often report incorrect values,
	 and/or Apple has deprecated REQUIRED methods in their API (with no explanation - e.g. "font leading")
	 
	 If/when Apple fixes their bugs - or if you know enough about their API's to workaround the bugs, feel free to fix this code.
	 
	 LUMA: why? I think apple origin is good, let's take apple origin for svg text!
	 */
	label.position = CGPointZero;
    
    NSString *textAnchor = [self cascadedValueForStylableProperty:@"text-anchor"];
    if( [@"middle" isEqualToString:textAnchor] )
        label.anchorPoint = CGPointMake(0.5, 0.0);
    else if( [@"end" isEqualToString:textAnchor] )
        label.anchorPoint = CGPointMake(1.0, 0.0);
    else
        label.anchorPoint = CGPointZero; // WARNING: SVG applies transforms around the top-left as origin, whereas Apple defaults to center as origin, so we tell Apple to work "like SVG" here.
	
	// alignment, only valid for tag format
	NSString *textAlign = [self cascadedValueForStylableProperty:@"text-align"];
	if([@"right" isEqualToString:textAlign]) {
		label.alignmentMode = kCAAlignmentRight;
	} else if([@"center" isEqualToString:textAlign]) {
		label.alignmentMode = kCAAlignmentCenter;
	} else if([@"left" isEqualToString:textAlign]) {
		label.alignmentMode = kCAAlignmentLeft;
	} else if([@"justified" isEqualToString:textAlign]) {
		label.alignmentMode = kCAAlignmentJustified;
	} else {
    	label.alignmentMode = kCAAlignmentNatural;
	}
	
	// set transform, font size and final string
	label.affineTransform = textTransformAbsoluteWithLocalPositionOffset;
	label.fontSize = effectiveFontSize;
	label.string = rich ? rich.richText : richStr;
	
#if TARGET_OS_IPHONE
    label.contentsScale = [[UIScreen mainScreen] scale];
#endif

	/// VERY USEFUL when trying to debug text issues:
//	label.backgroundColor = [UIColor colorWithRed:0.5 green:0 blue:0 alpha:0.5].CGColor;
//	label.borderColor = [UIColor redColor].CGColor;
	//DEBUG: SVGKitLogVerbose(@"font size %2.1f at %@ ... final frame of layer = %@", effectiveFontSize, NSStringFromCGPoint(transformedOrigin), NSStringFromCGRect(label.frame));
	
    return label;
}

- (void)layoutLayer:(CALayer *)layer
{
	
}

@end
