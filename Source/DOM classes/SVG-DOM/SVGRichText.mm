#import "SVGRichText.h"
#include <string>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#include <math.h>
#include <vector>

using namespace std;

// tag char
#define TAG_START '['
#define TAG_END ']'

// span type
typedef enum {
	UNKNOWN,
	COLOR,
	FONT,
	SIZE,
	BOLD,
	ITALIC,
	UNDERLINE
} SpanType;

/// span
typedef struct Span {
	// span type
	SpanType type;
	
	// close tag?
	bool close;
	
	// pos in plain text
	// for close tag, it is exclusive, i.e., it is next char
	int pos;
	
	// only used for color
	int color;
	int toColor;
	float duration;
	bool transient;
	
	// only used for size
	int fontSize;
	
	// only used for font
	char* fontName;
} Span;
typedef vector<Span> SpanList;

///////////////////////////////////////

// alignment
#define ALIGN_TOP    1
#define ALIGN_CENTER 3
#define ALIGN_BOTTOM 2

// tag parsing state
typedef enum {
	READY,
	START_TAG,
	CLOSE_TAG,
	EQUAL,
	SUCCESS,
	FAIL
} TagParseState;

static int parseColor(NSString* s) {
	int color = 0;
	int len = (int)[s length];
	for(int i = 0; i < len; i++) {
		color <<= 4;
		unichar c = [s characterAtIndex:i];
		if(c >= '0' && c <= '9') {
			color |= c - '0';
		} else if(c >= 'a' && c <= 'f') {
			color |= c - 'a' + 10;
		} else if(c >= 'A' && c <= 'F') {
			color |= c - 'A' + 10;
		}
	}
	
	return color;
}

static SpanType checkTagName(unichar* p, NSUInteger start, NSUInteger end) {
	NSUInteger len = end - start;
	switch(len) {
		case 1:
			if(p[start] == 'b') {
				return BOLD;
			} else if(p[start] == 'i') {
				return ITALIC;
			} else if(p[start] == 'u') {
				return UNDERLINE;
			}
			break;
		case 4:
			if(p[start] == 'f' &&
			   p[start + 1] == 'o' &&
			   p[start + 2] == 'n' &&
			   p[start + 3] == 't') {
				return FONT;
			} else if(p[start] == 's' &&
					  p[start + 1] == 'i' &&
					  p[start + 2] == 'z' &&
					  p[start + 3] == 'e') {
				return SIZE;
			}
			break;
		case 5:
			if(p[start] == 'c' &&
			   p[start + 1] == 'o' &&
			   p[start + 2] == 'l' &&
			   p[start + 3] == 'o' &&
			   p[start + 4] == 'r') {
				return COLOR;
			}
			break;
	}
	
	return UNKNOWN;
}

// if parse failed, endTagPos will be len, otherwise it is end tag position
static SpanType checkTag(unichar* p, NSUInteger start, NSUInteger len, NSUInteger* endTagPos, NSUInteger* dataStart, NSUInteger* dataEnd, bool* close) {
	SpanType type = UNKNOWN;
	TagParseState state = READY;
	NSUInteger tagNameStart = 0, tagNameEnd = 0;
	*close = false;
	*endTagPos = len;
	*dataStart = -1;
	NSUInteger i = start;
	while(i < len) {
		switch (state) {
			case READY:
				if(p[i] == TAG_START) {
					state = START_TAG;
					tagNameStart = ++i;
				} else {
					state = FAIL;
				}
				break;
			case START_TAG:
				if((i == start + 1) && p[i] == '/') {
					state = CLOSE_TAG;
					*close = true;
					tagNameStart = ++i;
				} else if(p[i] == '=') {
					state = EQUAL;
					tagNameEnd = i++;
					type = checkTagName(p, tagNameStart, tagNameEnd);
					*dataStart = i;
				} else if(p[i] == TAG_END) {
					state = SUCCESS;
					*endTagPos = i;
					*dataEnd = i;
					tagNameEnd = i;
					if(type == UNKNOWN) {
						type = checkTagName(p, tagNameStart, tagNameEnd);
					}
				} else if(p[i] == ' ') {
					state = EQUAL;
					tagNameEnd = i++;
					type = checkTagName(p, tagNameStart, tagNameEnd);
					*dataStart = i;
				} else {
					i++;
				}
				break;
			case CLOSE_TAG:
				if(p[i] == TAG_END) {
					state = SUCCESS;
					*endTagPos = i;
					tagNameEnd = i;
					type = checkTagName(p, tagNameStart, tagNameEnd);
				} else {
					i++;
				}
				break;
			case EQUAL:
				if(p[i] == TAG_END) {
					state = SUCCESS;
					*endTagPos = i;
					*dataEnd = i;
				} else {
					i++;
				}
				break;
			default:
				break;
		}
		
		if(state == FAIL || state == SUCCESS)
			break;
	}
	
	if(state != SUCCESS)
		type = UNKNOWN;
	
	return type;
}

static unichar* buildSpan(const char* pText, SpanList& spans, int* outLen) {
	// get unichar of string
	NSString* ns = [NSString stringWithUTF8String:pText];
	NSUInteger uniLen = [ns length];
	unichar* uniText = (unichar*)malloc(uniLen * sizeof(unichar));
	[ns getCharacters:uniText range:NSMakeRange(0, uniLen)];
	
	int plainLen = 0;
	unichar* plain = (unichar*)malloc(sizeof(unichar) * uniLen);
	for(NSUInteger i = 0; i < uniLen; i++) {
		unichar c = uniText[i];
		switch(c) {
			case '\\':
				if(i < uniLen - 1) {
					unichar cc = uniText[i + 1];
					if(cc == TAG_START || cc == TAG_END) {
						plain[plainLen++] = cc;
						i++;
					}
				} else {
					plain[plainLen++] = c;
				}
				break;
			case TAG_START:
			{
				// parse the tag
				Span span;
				NSUInteger endTagPos, dataStart, dataEnd;
				SpanType type = checkTag(uniText, i, uniLen, &endTagPos, &dataStart, &dataEnd, &span.close);
				
				// fill span info
				do {
					// if type is unknown, discard
					if(type == UNKNOWN) break;
					
					// parse span data
					span.type = type;
					span.pos = plainLen;
					if(span.close) {
					} else {
						switch(span.type) {
							case COLOR:
							{
								NSString* content = [NSString stringWithCharacters:uniText + dataStart
																			length:dataEnd - dataStart];
								NSArray* parts = [content componentsSeparatedByString:@" "];
								
								// color
								span.color = parseColor([parts objectAtIndex:0]);
								
								break;
							}
							case FONT:
							{
								NSString* font = [NSString stringWithCharacters:uniText + dataStart
																		 length:dataEnd - dataStart];
								const char* cFont = [font cStringUsingEncoding:NSUTF8StringEncoding];
								size_t len = strlen(cFont);
								span.fontName = (char*)calloc(sizeof(char), len + 1);
								strcpy(span.fontName, cFont);
								break;
							}
							case SIZE:
							{
								NSString* size = [NSString stringWithCharacters:uniText + dataStart
																		 length:dataEnd - dataStart];
								span.fontSize = [size intValue];
								break;
							}
							default:
								break;
						}
					}
					
					// add span
					spans.push_back(span);
					
					// set i pos
					i = endTagPos;
				} while(0);
				
				break;
			}
			case TAG_END:
				// just discard it
				break;
			default:
				plain[plainLen++] = c;
				break;
		}
	}
	
	// return length
	if(outLen)
		*outLen = plainLen;
	
	// release
	free(uniText);
	
	// return plain str
	return plain;
}

static void setColorSpan(Span& top, CFMutableAttributedStringRef plainCFAStr, CGColorSpaceRef colorSpace, int start, int end) {
	CGFloat comp[] = {
		((top.color >> 16) & 0xff) / 255.0f,
		((top.color >> 8) & 0xff) / 255.0f,
		(top.color & 0xff) / 255.0f,
		((top.color >> 24) & 0xff) / 255.0f
	};
	
	// set color
	CGColorRef fc = CGColorCreate(colorSpace, comp);
	CFAttributedStringSetAttribute(plainCFAStr,
								   CFRangeMake(start, end - start),
								   kCTForegroundColorAttributeName,
								   fc);
	CGColorRelease(fc);
}

@interface SVGRichText ()

// attribute string in custom tag format
@property (copy, nonatomic) NSString* tagText;

// default property for text
@property (copy, nonatomic) NSString* fontName;
@property (assign, nonatomic) CGFloat fontSize;
@property (assign, nonatomic) NSTextAlignment alignment;

- (void)buildRichText;
- (void)measureRichText;

@end

@implementation SVGRichText

- (instancetype)initWithTagText:(NSString*)tagText {
	return [self initWithTagText:tagText fontName:@"Helvetica"];
}

- (instancetype)initWithTagText:(NSString*)tagText fontName:(NSString*)fontName {
	return [self initWithTagText:tagText fontName:fontName fontSize:20];
}

- (instancetype)initWithTagText:(NSString*)tagText fontName:(NSString*)fontName fontSize:(CGFloat)fontSize {
	return [self initWithTagText:tagText fontName:fontName fontSize:fontSize alignment:NSTextAlignmentLeft];
}

- (instancetype)initWithTagText:(NSString*)tagText fontName:(NSString*)fontName fontSize:(CGFloat)fontSize alignment:(NSTextAlignment)alignment {
	if(self = [super init]) {
		self.tagText = tagText;
		self.fontName = fontName;
		self.fontSize = fontSize;
		self.alignment = alignment;
		self.textColor = [UIColor blackColor];
		self.lineSpacing = 0;
		self.constraintSize = CGSizeZero;
		self.bounds = CGRectZero;
	}
	return self;
}

- (NSAttributedString*)richText {
	if(!_richText) {
		[self buildRichText];
		[self measureRichText];
	}
	return _richText;
}

- (CGRect)bounds {
	if(!_richText) {
		[self buildRichText];
		[self measureRichText];
	}
	return _bounds;
}

- (void)buildRichText {
	do {
		if(!self.tagText || _richText) break;
		
		// On iOS custom fonts must be listed beforehand in the App info.plist (in order to be usable) and referenced only the by the font family name itself when
		// calling [UIFont fontWithName]. Therefore even if the developer adds 'SomeFont.ttf' or 'fonts/SomeFont.ttf' to the App .plist, the font must
		// be referenced as 'SomeFont' when calling [UIFont fontWithName]. Hence we strip out the folder path components and the extension here in order to get just
		// the font family name itself. This stripping step is required especially for references to user fonts stored in CCB files; CCB files appear to store
		// the '.ttf' extensions when referring to custom fonts.
		NSString* fntName = [[self.fontName lastPathComponent] stringByDeletingPathExtension];
		
		// create the font
		CGFloat nSize = self.fontSize;
		if(nSize <= 0)
			nSize = (int)[UIFont systemFontSize];
		UIFont* uiDefaultFont = [UIFont fontWithName:fntName size:nSize];
		if(!uiDefaultFont) break;
		CTFontRef defaultFont = CTFontCreateWithName((CFStringRef)uiDefaultFont.fontName, nSize, NULL);
		
		// get plain text and extract span list
		SpanList spans;
		int uniLen;
		const char* pText = [self.tagText cStringUsingEncoding:NSUTF8StringEncoding];
		unichar* plain = buildSpan(pText, spans, &uniLen);
		
		// create attributed string
		CFStringRef plainCFStr = CFStringCreateWithCharacters(kCFAllocatorDefault,
															  (const UniChar*)plain,
															  uniLen);
		CFMutableAttributedStringRef plainCFAStr = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
		CFAttributedStringReplaceString(plainCFAStr, CFRangeMake(0, 0), plainCFStr);
		CFIndex plainLen = CFAttributedStringGetLength(plainCFAStr);
		
		// font and color stack
		CGFloat tintColorR, tintColorG, tintColorB, tintColorA;
		[self.textColor getRed:&tintColorR
						 green:&tintColorG
						  blue:&tintColorB
						 alpha:&tintColorA];
		Span defaultColor;
		defaultColor.type = COLOR;
		defaultColor.color = 0xff000000
			| ((int)(tintColorR * 255) << 16)
			| ((int)(tintColorG * 255) << 8)
			| (int)(tintColorB * 255);
		defaultColor.duration = 0;
		vector<CTFontRef> fontStack;
		vector<Span> colorStack;
		fontStack.push_back(defaultFont);
		colorStack.push_back(defaultColor);
		
		// iterate all spans, install attributes
		int colorStart = 0;
		int fontStart = 0;
		int underlineStart = -1;
		Span* openSpan = NULL;
		CGColorSpaceRef colorSpace  = CGColorSpaceCreateDeviceRGB();
		for(SpanList::iterator iter = spans.begin(); iter != spans.end(); iter++) {
			Span& span = *iter;
			if(span.close) {
				switch(span.type) {
					case COLOR:
					{
						if(span.pos > colorStart) {
							// set color span
							Span& top = *colorStack.rbegin();
							setColorSpan(top, plainCFAStr, colorSpace, colorStart, span.pos);
							
							// start need to be reset
							colorStart = span.pos;
						}
						
						// pop color
						colorStack.pop_back();
						
						break;
					}
					case FONT:
					case SIZE:
					case BOLD:
					case ITALIC:
					{
						// set previous span
						CTFontRef font = *fontStack.rbegin();
						if(span.pos > fontStart && font) {
							CFAttributedStringSetAttribute(plainCFAStr,
														   CFRangeMake(fontStart, plainLen - fontStart),
														   kCTFontAttributeName,
														   font);
							fontStart = span.pos;
						}
						
						// pop font
						fontStack.pop_back();
						if(font)
							CFRelease(font);
						
						break;
					}
					case UNDERLINE:
					{
						if(underlineStart > -1) {
							CFIndex style = kCTUnderlineStyleSingle;
							CFNumberRef styleNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberCFIndexType, &style);
							CFAttributedStringSetAttribute(plainCFAStr,
														   CFRangeMake(underlineStart, span.pos - underlineStart),
														   kCTUnderlineStyleAttributeName,
														   styleNum);
							CFRelease(styleNum);
							underlineStart = -1;
						}
						break;
					}
					default:
						break;
				}
			} else {
				// save open span pointer
				openSpan = &span;
				
				switch(span.type) {
					case COLOR:
					{
						// process previous run
						if(span.pos > colorStart) {
							// set color span
							Span& top = *colorStack.rbegin();
							setColorSpan(top, plainCFAStr, colorSpace, colorStart, span.pos);
							
							// start need to be reset
							colorStart = span.pos;
						}
						
						// push color
						colorStack.push_back(span);
						
						break;
					}
					case FONT:
					{
						// set previous span
						CTFontRef curFont = *fontStack.rbegin();
						if(span.pos > fontStart) {
							CFAttributedStringSetAttribute(plainCFAStr,
														   CFRangeMake(fontStart, plainLen - fontStart),
														   kCTFontAttributeName,
														   curFont);
							fontStart = span.pos;
						}
						
						// create the font
						NSString* fontName = [NSString stringWithCString:span.fontName
																encoding:NSUTF8StringEncoding];
						fontName = [[fontName lastPathComponent] stringByDeletingPathExtension];
						UIFont* uiFont = [UIFont fontWithName:fontName
														 size:CTFontGetSize(curFont)];
						if(!uiFont) break;
						CTFontRef font = CTFontCreateWithName((CFStringRef)uiFont.fontName,
															  CTFontGetSize(curFont),
															  NULL);
						fontStack.push_back(font);
						
						break;
					}
					case SIZE:
					{
						// set previous span
						CTFontRef curFont = *fontStack.rbegin();
						if(span.pos > fontStart) {
							CFAttributedStringSetAttribute(plainCFAStr,
														   CFRangeMake(fontStart, plainLen - fontStart),
														   kCTFontAttributeName,
														   curFont);
							fontStart = span.pos;
						}
						
						// push new font
						CTFontDescriptorRef fd = CTFontCopyFontDescriptor(curFont);
						CTFontRef font = CTFontCreateCopyWithAttributes(curFont,
																		span.fontSize,
																		NULL,
																		fd);
						fontStack.push_back(font);
						CFRelease(fd);
						
						break;
					}
					case BOLD:
					{
						// set previous span
						CTFontRef curFont = *fontStack.rbegin();
						if(span.pos > fontStart) {
							CFAttributedStringSetAttribute(plainCFAStr,
														   CFRangeMake(fontStart, plainLen - fontStart),
														   kCTFontAttributeName,
														   curFont);
							fontStart = span.pos;
						}
						
						// create new font
						CTFontRef font = CTFontCreateCopyWithSymbolicTraits(curFont,
																			CTFontGetSize(curFont),
																			NULL,
																			kCTFontBoldTrait,
																			kCTFontBoldTrait);
						fontStack.push_back(font);
						
						break;
					}
					case ITALIC:
					{
						// set previous span
						CTFontRef curFont = *fontStack.rbegin();
						if(span.pos > fontStart) {
							CFAttributedStringSetAttribute(plainCFAStr,
														   CFRangeMake(fontStart, plainLen - fontStart),
														   kCTFontAttributeName,
														   curFont);
							fontStart = span.pos;
						}
						
						// create new font
						CTFontRef font = CTFontCreateCopyWithSymbolicTraits(curFont,
																			CTFontGetSize(curFont),
																			NULL,
																			kCTFontItalicTrait,
																			kCTFontItalicTrait);
						fontStack.push_back(font);
						
						break;
					}
					case UNDERLINE:
					{
						underlineStart = span.pos;
						break;
					}
					default:
						break;
				}
			}
		}
		
		// last segment
		if(plainLen > colorStart) {
			Span& top = *colorStack.rbegin();
			setColorSpan(top, plainCFAStr, colorSpace, colorStart, (int)plainLen);
		}
		if(plainLen > fontStart) {
			CTFontRef font = *fontStack.rbegin();
			CFAttributedStringSetAttribute(plainCFAStr,
										   CFRangeMake(fontStart, plainLen - fontStart),
										   kCTFontAttributeName,
										   font);
		}
		
		// set paragraph style, including line spacing and alignment
		CTTextAlignment alignment = kCTLeftTextAlignment;
		switch(self.alignment) {
			case NSTextAlignmentRight:
				alignment = kCTRightTextAlignment;
				break;
			case NSTextAlignmentCenter:
				alignment = kCTCenterTextAlignment;
				break;
			default:
				break;
		}
		CGFloat asc = CTFontGetSize(defaultFont);
		CGFloat desc = CTFontGetDescent(defaultFont);
		CGFloat leading = CTFontGetLeading(defaultFont);
		CGFloat lineMultiple = 1 + self.lineSpacing / (asc + desc + leading);
		CTParagraphStyleSetting paraSettings[] = {
			{ kCTParagraphStyleSpecifierAlignment, sizeof(alignment), &alignment},
			{ kCTParagraphStyleSpecifierLineHeightMultiple, sizeof(CGFloat), &lineMultiple }
		};
		CTParagraphStyleRef paraStyle = CTParagraphStyleCreate(paraSettings,
															   sizeof(paraSettings) / sizeof(paraSettings[0]));
		CFAttributedStringSetAttribute(plainCFAStr,
									   CFRangeMake(0, CFAttributedStringGetLength(plainCFAStr)),
									   kCTParagraphStyleAttributeName,
									   paraStyle);
		
		// save rich text
		self.richText = [[NSAttributedString alloc] initWithAttributedString:(__bridge NSMutableAttributedString*)plainCFAStr];
		
		// release
		CGColorSpaceRelease(colorSpace);
		CFRelease(plainCFStr);
		CFRelease(plainCFAStr);
		CFRelease(defaultFont);
		CFRelease(paraStyle);
		free(plain);
		for(SpanList::iterator iter = spans.begin(); iter != spans.end(); iter++) {
			Span& span = *iter;
			if(span.type == FONT && !span.close && span.fontName) {
				free(span.fontName);
			}
		}
	} while(0);
}

- (void)measureRichText {
	// create frame setter
	CTFramesetterRef fs = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)self.richText);
	
	// constrain size
	CFRange range;
	CGSize ctConstrainSize = self.constraintSize;
	if(ctConstrainSize.width <= 0) {
		ctConstrainSize.width = CGFLOAT_MAX;
	}
	if(ctConstrainSize.height <= 0) {
		ctConstrainSize.height = CGFLOAT_MAX;
	}
	CGSize dim = CTFramesetterSuggestFrameSizeWithConstraints(fs,
															  CFRangeMake(0, 0),
															  NULL,
															  ctConstrainSize,
															  &range);
	dim.width = ceilf(dim.width);
	dim.height = ceilf(dim.height);
	
	// adjust text rect
	if (self.constraintSize.height > 0 && self.constraintSize.height < dim.height) {
		dim.height = self.constraintSize.height;
	}
	
	// release
	CFRelease(fs);
	
	// save bounds
	self.bounds = CGRectMake(0, 0, dim.width, dim.height);
}

@end
