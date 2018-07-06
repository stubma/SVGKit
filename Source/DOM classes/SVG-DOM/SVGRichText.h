#import <Foundation/Foundation.h>

@interface SVGRichText : NSObject

// rich text string built
@property (strong, nonatomic) NSAttributedString* richText;

// final rect of rich text bounding
@property (assign, nonatomic) CGRect bounds;

// default text color
@property (strong, nonatomic) UIColor* textColor;

// line spacing
@property (assign, nonatomic) CGFloat lineSpacing;

// constraint size, or zero if no constraint
@property (assign, nonatomic) CGSize constraintSize;

// property for text
@property (copy, nonatomic) NSString* fontName;
@property (assign, nonatomic) CGFloat fontSize;
@property (assign, nonatomic) NSTextAlignment alignment;

- (instancetype)initWithTagText:(NSString*)tagText;

@end
