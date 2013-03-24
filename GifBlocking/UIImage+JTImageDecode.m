
#import "UIImage+JTImageDecode.h"
#import <ImageIO/ImageIO.h>

@implementation UIImage (JTImageDecode)

+ (UIImage *)decodedImageWithImage:(UIImage *)image {
    CGImageRef imageRef = image.CGImage;
    // System only supports RGB, set explicitly and prevent context error
    // if the downloaded image is not the supported format
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef context = CGBitmapContextCreate(NULL,
                                                 CGImageGetWidth(imageRef),
                                                 CGImageGetHeight(imageRef),
                                                 8,
                                                 // width * 4 will be enough because are in ARGB format, don't read from the image
                                                 CGImageGetWidth(imageRef) * 4,
                                                 colorSpace,
                                                 // kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little
                                                 // makes system don't need to do extra conversion when displayed.
                                                 kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(colorSpace);
    
    if ( ! context) {
        return nil;
    }
    
    CGRect rect = (CGRect){CGPointZero, CGImageGetWidth(imageRef), CGImageGetHeight(imageRef)};
    CGContextDrawImage(context, rect, imageRef);
    CGImageRef decompressedImageRef = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    
    UIImage *decompressedImage = [[UIImage alloc] initWithCGImage:decompressedImageRef];
    CGImageRelease(decompressedImageRef);
    return decompressedImage;
}

+ (UIImage *)animatedGIFImageWithData:(NSData *)data
{
    NSString *frameKeyPath = [NSString stringWithFormat:@"%@.%@",(NSString*)kCGImagePropertyGIFDictionary,kCGImagePropertyGIFUnclampedDelayTime];
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFTypeRef)data, NULL);
    size_t count = CGImageSourceGetCount(source);
    NSMutableArray *images = [NSMutableArray arrayWithCapacity:count];
    CGFloat duration = 0.;
    for (size_t i = 0; i < count; ++i) {

        CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, i, NULL);
        UIImage *uiImage = [UIImage imageWithCGImage:cgImage];
        
        //NB: If the gif contains compression force the decompress here, it blocks the main thread otherwise
        uiImage = [self decodedImageWithImage:uiImage];

        [images addObject:uiImage];
        
        CGImageRelease(cgImage);
        
        CFDictionaryRef cfFrameProperties = CGImageSourceCopyPropertiesAtIndex(source,i,nil);
        NSDictionary *frameProperties = (__bridge NSDictionary*)cfFrameProperties;
        NSNumber *delayTimeProp = [frameProperties valueForKeyPath:frameKeyPath];
        CGFloat delayTime = 0.1f;
        if(delayTimeProp)
            delayTime = [delayTimeProp floatValue];
        
        duration += delayTime;
        CFRelease(cfFrameProperties);
    }
    CFRelease(source);
    UIImage * animatedImage = [UIImage animatedImageWithImages:images duration:duration];
    return animatedImage;
}


@end