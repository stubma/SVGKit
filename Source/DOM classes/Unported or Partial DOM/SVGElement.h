/**
 SVGElement
 
 http://www.w3.org/TR/SVG/types.html#InterfaceSVGElement

 NB: "id" is illegal in Objective-C language, so we use "identifier" instead
 */
#import <QuartzCore/QuartzCore.h>

#import "Element.h"
#import "Node+Mutable.h"
#import "SVGStylable.h"
#import "SVGLength.h"

#define DEBUG_SVG_ELEMENT_PARSING 0

typedef enum {
	SVGGAlignItemStart = 0,
	SVGGAlignItemCenter,
	SVGGAlignItemEnd
} SVGGItemAlignment;

@class SVGSVGElement;
//obj-c's compiler sucks, and doesn't allow this line: #import "SVGSVGElement.h"

@interface SVGElement : Element <SVGStylable>

// client area size of parent element, client area includes padding but exclude margin
@property (assign, nonatomic, readonly) float parentClientWidth;
@property (assign, nonatomic, readonly) float parentClientHeight;

// alignment, only useful in <g> element
@property(nonatomic,assign) SVGGItemAlignment itemAlignment; // main axis
@property(nonatomic,assign) SVGGItemAlignment itemJustify; // cross axis

// touchable or not, if not touchable, hitTest returns nil
// by default it is true
@property (assign, nonatomic) BOOL touchable;

@property (assign, nonatomic) int z;

@property (nonatomic, readwrite, strong) NSString *identifier; // 'id' is reserved in Obj-C, so we have to break SVG Spec here, slightly
@property (nonatomic, strong) NSString* xmlbase;
/*!
 
 http://www.w3.org/TR/SVG/intro.html#TermSVGDocumentFragment
 
 SVG document fragment
 The XML document sub-tree which starts with an ‘svg’ element. An SVG document fragment can consist of a stand-alone SVG document, or a fragment of a parent XML document enclosed by an ‘svg’ element. When an ‘svg’ element is a descendant of another ‘svg’ element, there are two SVG document fragments, one for each ‘svg’ element. (One SVG document fragment is contained within another SVG document fragment.)
 */
@property (nonatomic, weak) SVGSVGElement* rootOfCurrentDocumentFragment;

/*! The viewport is set / re-set whenever an SVG node specifies a "width" (and optionally: a "height") attribute,
 assuming that SVG node is one of: svg, symbol, image, foreignobject
 
 The spec isn't clear what happens if this element redefines the viewport itself, but IMHO it implies that the
 viewportElement becomes a reference to "self" */
@property (nonatomic, weak) SVGElement* viewportElement;


#pragma mark - NON-STANDARD features of class (these are things that are NOT in the SVG spec, and should NOT be in SVGKit's implementation - they should be moved to a different class, although WE DO STILL NEED THESE in order to implement the spec, and to provide SVGKit features!)

/*! This is used when generating CALayer objects, to store the id of the SVGElement that created the CALayer */
#define kSVGElementIdentifier @"SVGElementIdentifier"
#define kSVGElementZ @"SVGElementZ"

/* this is used to associate layer and element so we can get element from layer */
#define kSVGElement "SVGElement"

#pragma mark - SVG-spec supporting methods that aren't in the Spec itself

- (id)initWithLocalName:(NSString*) n attributes:(NSMutableDictionary*) attributes;
- (id)initWithQualifiedName:(NSString*) n inNameSpaceURI:(NSString*) nsURI attributes:(NSMutableDictionary*) attributes;

-(void) reCalculateAndSetViewportElementReferenceUsingFirstSVGAncestor:(SVGElement*) firstAncestor;

/**
 Convenience method for reading an attribute (SVG defines all as strings), converting it into an SVGLength object
 */
-(SVGLength*) getAttributeAsSVGLength:(NSString*) attributeName;

#pragma mark - CSS cascading special attributes. c.f. full list here: http://www.w3.org/TR/SVG/propidx.html

-(NSString*) cascadedValueForStylableProperty:(NSString*) stylableProperty;
-(NSString*) cascadedValueForStylableProperty:(NSString*) stylableProperty inherit:(BOOL)inherit;

@end
