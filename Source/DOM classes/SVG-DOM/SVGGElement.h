/**
 http://www.w3.org/TR/SVG/struct.html#InterfaceSVGGElement
 
 interface SVGGElement : SVGElement,
 SVGTests,
 SVGLangSpace,
 SVGExternalResourcesRequired,
 SVGStylable,
 SVGTransformable {
 */

#import <UIKit/UIKit.h>

#import "SVGElement.h"
#import "SVGElement_ForParser.h"

#import "ConverterSVGToCALayer.h"
#import "SVGTransformable.h"

typedef enum {
	SVGGAlignItemStart = 0,
	SVGGAlignItemCenter,
	SVGGAlignItemEnd
} SVGGItemAlignment;

@interface SVGGElement : SVGElement <SVGTransformable, SVGStylable, ConverterSVGToCALayer >

@property(nonatomic,strong) SVGLength* pt;
@property(nonatomic,strong) SVGLength* pb;
@property(nonatomic,strong) SVGLength* pr;
@property(nonatomic,strong) SVGLength* pl;
@property(nonatomic,strong) SVGLength* mt;
@property(nonatomic,strong) SVGLength* mb;
@property(nonatomic,strong) SVGLength* mr;
@property(nonatomic,strong) SVGLength* ml;
@property(nonatomic,strong) SVGLength* width;
@property(nonatomic,strong) SVGLength* height;
@property(nonatomic,assign) BOOL row;
@property(nonatomic,assign) SVGGItemAlignment itemAlignment;

@property (nonatomic, assign, readonly) float absoluteWidth;
@property (nonatomic, assign, readonly) float absoluteHeight;

// size of client area
@property (nonatomic, assign, readonly) float clientWidth;
@property (nonatomic, assign, readonly) float clientHeight;

- (CGPoint)originOfChild:(SVGElement*)child;

@end
