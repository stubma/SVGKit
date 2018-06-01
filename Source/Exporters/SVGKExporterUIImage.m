#import "SVGKExporterUIImage.h"

#import "SVGKImage+CGContext.h" // needed for Context calls

@implementation SVGKExporterUIImage

+(UIImage*) exportAsUIImage:(SVGKImage *)image
{
	return [self exportAsUIImage:image antiAliased:TRUE curveFlatnessFactor:1.0 interpolationQuality:kCGInterpolationDefault];
}

+(UIImage*) exportAsUIImage:(SVGKImage*) image antiAliased:(BOOL) shouldAntialias curveFlatnessFactor:(CGFloat) multiplyFlatness interpolationQuality:(CGInterpolationQuality) interpolationQuality
{
	if( [image hasSize] )
	{
		SVGKitLogVerbose(@"[%@] DEBUG: Generating a UIImage using the current root-object's viewport (may have been overridden by user code): {0,0,%2.3f,%2.3f}", [self class], image.size.width, image.size.height);
		
		// create a cgcontext
		NSUInteger width = (NSUInteger)image.size.width;
		NSUInteger height = (NSUInteger)image.size.height;
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		NSUInteger bytesPerPixel = 4;
		NSUInteger bytesPerRow = bytesPerPixel * width;
		unsigned char *rawData = malloc(height * bytesPerRow);
		NSUInteger bitsPerComponent = 8;
		CGContextRef context = CGBitmapContextCreate(rawData,
													 width,
													 height,
													 bitsPerComponent,
													 bytesPerRow,
													 colorSpace,
													 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
		
		// setup context
		CGContextTranslateCTM(context, 0, image.size.height);
		CGContextScaleCTM(context, 1, -1);
		
		// render
		[image renderToContext:context
				   antiAliased:shouldAntialias
		   curveFlatnessFactor:multiplyFlatness
		  interpolationQuality:interpolationQuality
					 flipYaxis:FALSE];
		
		// get uiimage
		UIImage *result = [UIImage imageWithCGImage:CGBitmapContextCreateImage(context)];
		
		// release
		CGColorSpaceRelease(colorSpace);
		CGContextRelease(context);
		free(rawData);
		
		return result;
	}
	else
	{
		NSAssert(FALSE, @"You asked to export an SVG to bitmap, but the SVG file has infinite size. Either fix the SVG file, or set an explicit size you want it to be exported at (by calling .size = something on this SVGKImage instance");
		
		return nil;
	}
}

@end
