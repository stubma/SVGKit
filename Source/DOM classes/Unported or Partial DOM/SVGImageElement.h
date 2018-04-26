#import <Foundation/Foundation.h>

#import "SVGElement.h"
#import "SVGTransformable.h"
#import "SVGFitToViewBox.h"

#import "SVGElement_ForParser.h" // to resolve Xcode circular dependencies; in long term, parsing SHOULD NOT HAPPEN inside any class whose name starts "SVG" (because those are reserved classes for the SVG Spec)

@interface SVGImageElement : SVGElement <SVGTransformable, SVGStylable, ConverterSVGToCALayer, SVGFitToViewBox>

@property (nonatomic, readonly) SVGLength* x;
@property (nonatomic, readonly) SVGLength* y;
@property (nonatomic, readonly) SVGLength* width;
@property (nonatomic, readonly) SVGLength* height;

@property (nonatomic, strong, readonly) NSString *href;

@end
