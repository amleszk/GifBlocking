
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
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFTypeRef)data, NULL);
    size_t count = CGImageSourceGetCount(source);
    NSMutableArray *images = [NSMutableArray arrayWithCapacity:count];
    CGFloat duration = 0.;
    for (size_t i = 0; i < count; ++i) {

        CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, i, NULL);
        UIImage *uiImage = [UIImage imageWithCGImage:cgImage];
        CGImageRelease(cgImage);
        
        //NB: If the gif contains compression force the decompress here, it blocks the main thread otherwise
        uiImage = [self decodedImageWithImage:uiImage];
        [images addObject:uiImage];
        
        CGFloat delayTime = [self frameDurationAtIndex:i source:source];
        duration += delayTime;
    }
    
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

#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>

@implementation UIImageView (NDVAnimatedGIFSupport)

- (id)ndv_initWithAnimatedGIFURL:(NSURL *)url {
    CGImageSourceRef sourceRef = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
    if (!sourceRef) return nil;
    
    UIImageView *imageView = [self _ndv_initWithCGImageSource:sourceRef];
    CFRelease(sourceRef);
    
    return imageView;
}

- (id)ndv_initWithAnimatedGIFData:(NSData *)data {
    CGImageSourceRef sourceRef = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!sourceRef) return nil;
    
    UIImageView *imageView = [self _ndv_initWithCGImageSource:sourceRef];
    CFRelease(sourceRef);
    
    return imageView;
}

- (id)_ndv_initWithCGImageSource:(CGImageSourceRef)sourceRef {
    size_t frameCount = CGImageSourceGetCount(sourceRef);
    
    NSMutableArray* frameImages = [NSMutableArray arrayWithCapacity:frameCount];
    NSMutableArray* frameDurations = [NSMutableArray arrayWithCapacity:frameCount];
    
    CFTimeInterval totalFrameDuration = 0.0;
    
    for (NSUInteger frameIndex = 0; frameIndex < frameCount; frameIndex++) {
        CGImageRef frameImageRef = CGImageSourceCreateImageAtIndex(sourceRef, frameIndex, NULL);
        [frameImages addObject:(__bridge id)frameImageRef];
        CGImageRelease(frameImageRef);
        
        CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(sourceRef, frameIndex, NULL);
        CFDictionaryRef GIFProperties = (CFDictionaryRef)CFDictionaryGetValue(properties, kCGImagePropertyGIFDictionary);
        
        NSNumber* duration = (NSNumber *)CFDictionaryGetValue(GIFProperties, kCGImagePropertyGIFDelayTime);
        [frameDurations addObject:duration];
        
        totalFrameDuration += [duration doubleValue];
        
        CFRelease(properties);
    }
    
    NSMutableArray* framePercentageDurations = [NSMutableArray arrayWithCapacity:frameCount];
    
    for (NSUInteger frameIndex = 0; frameIndex < frameCount; frameIndex++) {
        float currentDurationPercentage;
        
        if (frameIndex == 0) {
            currentDurationPercentage = 0.0;
            
        } else {
            NSNumber* previousDuration = [frameDurations objectAtIndex:frameIndex - 1];
            NSNumber* previousDurationPercentage = [framePercentageDurations objectAtIndex:frameIndex - 1];
            
            currentDurationPercentage = [previousDurationPercentage floatValue] + ([previousDuration floatValue] / totalFrameDuration);
        }
        
        [framePercentageDurations insertObject:[NSNumber numberWithFloat:currentDurationPercentage]
                                       atIndex:frameIndex];
    }
    
    CFDictionaryRef imageSourceProperties = CGImageSourceCopyProperties(sourceRef, NULL);
    CFDictionaryRef imageSourceGIFProperties = (CFDictionaryRef)CFDictionaryGetValue(imageSourceProperties, kCGImagePropertyGIFDictionary);
    NSNumber* imageSourceLoopCount = (NSNumber *)CFDictionaryGetValue(imageSourceGIFProperties, kCGImagePropertyGIFLoopCount);
    
    CFRelease(imageSourceProperties);
    
    CAKeyframeAnimation* frameAnimation = [CAKeyframeAnimation animationWithKeyPath:@"contents"];
    
    if ([imageSourceLoopCount floatValue] == 0.f) {
        frameAnimation.repeatCount = HUGE_VALF;
        
    } else {
        frameAnimation.repeatCount = [imageSourceLoopCount floatValue];
    }
    
    frameAnimation.calculationMode = kCAAnimationDiscrete;
    frameAnimation.values = frameImages;
    frameAnimation.duration = totalFrameDuration;
    frameAnimation.keyTimes = framePercentageDurations;
    frameAnimation.removedOnCompletion = NO;
    
    CGImageRef firstFrame = (__bridge CGImageRef)[frameImages objectAtIndex:0];
    UIImageView* imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0.f, 0.f, CGImageGetWidth(firstFrame), CGImageGetHeight(firstFrame))];
    [[imageView layer] addAnimation:frameAnimation forKey:@"contents"];
    
    return imageView;
}

@end

