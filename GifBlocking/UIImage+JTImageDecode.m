
#import "UIImage+JTImageDecode.h"
#import <ImageIO/ImageIO.h>

@implementation UIImage (JTImageDecode)

typedef struct {
    size_t bitsPerComponent;
    size_t bytesPerPixel;
    size_t bytesPerRow;
    size_t dataSize;
    CGFloat width;
    CGRect rect;
    CGFloat height;
    CGContextRef context;
    unsigned char *data;
} UIImageGIFDecodeProperties;

static UIImageGIFDecodeProperties UIImageGIFDecodePropertiesNone = {
    .data = NULL
};

+ (UIImageGIFDecodeProperties) createUIImageGIFDecodePropertiesWithRect:(CGRect)rect
{
    UIImageGIFDecodeProperties props;
    props.width = CGRectGetWidth(rect);
    props.height = CGRectGetHeight(rect);
    props.rect = rect;
    props.bitsPerComponent = 8;
    props.bytesPerPixel    = 4;
    props.bytesPerRow      = (props.width * props.bitsPerComponent * props.bytesPerPixel + 7) / 8;
    props.dataSize         = props.bytesPerRow * props.height;
    props.data = malloc(props.dataSize);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    props.context = CGBitmapContextCreate(props.data, props.width, props.height,
                                          props.bitsPerComponent, props.bytesPerRow, colorSpace,
                                          kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    return props;
}

+ (void) releaseIImageGIFDecodeProperties:(UIImageGIFDecodeProperties)props
{
    free(props.data);
}

+ (UIImage*) makeImageFromCGImageRef:(CGImageRef)cgImageRef
                          properties:(UIImageGIFDecodeProperties)properties
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    memset(properties.data, 0, properties.dataSize);
    CGColorSpaceRelease(colorSpace);
    CGContextDrawImage(properties.context, properties.rect, cgImageRef);
    CGImageRef imageRef = CGBitmapContextCreateImage(properties.context);
    UIImage *result = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    return result;
}

+ (UIImage *)decodedImageWithImage:(UIImage *)image
{
    UIImageGIFDecodeProperties decodeProperties = [self createUIImageGIFDecodePropertiesWithRect:(CGRect){.origin=CGPointZero,.size=image.size}];
    return [self makeImageFromCGImageRef:image.CGImage properties:decodeProperties];
    [self releaseIImageGIFDecodeProperties:decodeProperties];
}

+ (UIImage *)animatedGIFImageWithData:(NSData *)data
{    
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFTypeRef)data, NULL);
    size_t count = CGImageSourceGetCount(source);
    NSMutableArray *images = [NSMutableArray arrayWithCapacity:count];
    CGFloat duration = 0.;
    UIImageGIFDecodeProperties gifDecodeProperties = UIImageGIFDecodePropertiesNone;
    NSDictionary* cgImageProperties = @{(id)kCGImageSourceShouldCache : @(YES)};

    //Assumption every image is the same size, allocate re-usable data
    if (count>0) {
        CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, 0, NULL);
        CGRect imageDrawRect = (CGRect){CGPointZero, CGImageGetWidth(cgImage), CGImageGetHeight(cgImage)};
        gifDecodeProperties = [self createUIImageGIFDecodePropertiesWithRect:imageDrawRect];
    }
    
    for (size_t i = 0; i < count; ++i) {
        CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, i, (__bridge CFDictionaryRef)cgImageProperties);
        UIImage *uiImage = [self makeImageFromCGImageRef:cgImage properties:gifDecodeProperties];
        CGImageRelease(cgImage);
        
        if (uiImage) {
            [images addObject:uiImage];
        }
        
        CGFloat delayTime = [self frameDurationAtIndex:i source:source];
        duration += delayTime;
    }
    
    [self releaseIImageGIFDecodeProperties:gifDecodeProperties];
    CFRelease(source);
    UIImage * animatedImage = [UIImage animatedImageWithImages:images duration:duration];
    return animatedImage;
}

+ (float)frameDurationAtIndex:(NSUInteger)index source:(CGImageSourceRef)source
{
    float frameDuration = 0.1f;
    CFDictionaryRef cfFrameProperties = CGImageSourceCopyPropertiesAtIndex(source,index,nil);
    NSDictionary *frameProperties = (__bridge NSDictionary*)cfFrameProperties;
    NSDictionary *gifProperties = frameProperties[(NSString*)kCGImagePropertyGIFDictionary];

    NSNumber *delayTimeUnclampedProp = gifProperties[(NSString*)kCGImagePropertyGIFUnclampedDelayTime];
    if(delayTimeUnclampedProp) {
        frameDuration = [delayTimeUnclampedProp floatValue];
    } else {

        NSNumber *delayTimeProp = gifProperties[(NSString*)kCGImagePropertyGIFDelayTime];
        if(delayTimeProp) {
            frameDuration = [delayTimeProp floatValue];
        }
    }
    
    // Many annoying ads specify a 0 duration to make an image flash as quickly as possible.
    // We follow Firefox's behavior and use a duration of 100 ms for any frames that specify
    // a duration of <= 10 ms. See <rdar://problem/7689300> and <http://webkit.org/b/36082>
    // for more information.

    if (frameDuration < 0.011f)
        frameDuration = 0.100f;

    CFRelease(cfFrameProperties);
    return frameDuration;
}

@end


