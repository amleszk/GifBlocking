
#import <ImageIO/ImageIO.h>
#import "AMGIFImageViewController.h"
#import "AMBufferingController.h"

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

@interface AMGIFImageViewController () <AMBufferingControllerDelegate>

@property CGImageSourceRef gifImageSource;
@property UIImageGIFDecodeProperties gifDecodeProperties;
@property NSDictionary* cgImageProperties;
@property AMBufferingController *bufferingController;

@end

@implementation AMGIFImageViewController

-(id) initWithData:(NSData*)data
{
    if (self = [super initWithNibName:nil bundle:nil]) {
        _gifImageSource = CGImageSourceCreateWithData((__bridge CFTypeRef)data, NULL);
        _totalImageCount = CGImageSourceGetCount(_gifImageSource);
        _cgImageProperties = @{(id)kCGImageSourceShouldCache : @(YES)};
        
        //Assumption every image is the same size, allocate re-usable data
        if (_totalImageCount>0) {
            {
                CGImageRef cgImage = CGImageSourceCreateImageAtIndex(_gifImageSource, 0, (__bridge CFDictionaryRef)_cgImageProperties);
                _imageFrame = (CGRect){CGPointZero, CGImageGetWidth(cgImage), CGImageGetHeight(cgImage)};
                CGImageRelease(cgImage);
            }
            
            _gifDecodeProperties = [self createUIImageGIFDecodePropertiesWithRect:_imageFrame];
            _delayTime = [self frameDurationAtIndex:0 source:_gifImageSource];
            _duration = _delayTime*_totalImageCount;
            _bufferingController = [[AMBufferingController alloc] initWithDelegate:self];
            [_bufferingController startBufferingFromIndex:0];
        }

    }
    return self;
}

-(void) dealloc
{
    [self releaseIImageGIFDecodeProperties:_gifDecodeProperties];
}


#pragma mark - UIViewController overrides

-(void) loadView
{
    self.view = [[AMGIFImageView alloc] initWithFrame:_imageFrame animating:[self isAnimating]];
}

-(void) didReceiveMemoryWarning
{
    [_bufferingController didReceiveMemoryWarning];
}

#pragma mark Animation

-(void) startAnimation
{
    NSLog(@"startAnimation");
    [self.view setAnimating:YES];

    [_animationTimer invalidate];
    _animationTimer = [NSTimer timerWithTimeInterval:_delayTime
                                              target:self
                                            selector:@selector(nextGifImageFireMethod:)
                                            userInfo:nil
                                             repeats:YES];
    [self nextGifImageFireMethod:_animationTimer];
    if (_animationTimer) {
        [[NSRunLoop mainRunLoop] addTimer:_animationTimer forMode:NSRunLoopCommonModes];
    }
}

-(void) stopAnimation
{
    NSLog(@"stopAnimation");
    [_animationTimer invalidate];
    _animationTimer = nil;
    [self.view setAnimating:NO];
}

-(void) nextGifImageFireMethod:(NSTimer*)timer
{
    if (![self isViewLoaded]) return;
    
    UIImage *imageFrame = [_bufferingController popCachedObject];
    if (imageFrame) {
        self.view.image = imageFrame;
    }
}

-(BOOL) isAnimating
{
    return [_animationTimer isValid];
}

#pragma mark - <AMBufferingControllerDelegate>

-(id) loadObjectAtIndex:(NSUInteger)index
{
    CGImageRef cgImage = CGImageSourceCreateImageAtIndex(_gifImageSource, index, (__bridge CFDictionaryRef)_cgImageProperties);
    UIImage *uiImage = [self makeImageFromCGImageRef:cgImage properties:_gifDecodeProperties];
    //[self cacheFrameAtIndex:_bufferedImageIndex withImage:uiImage];
    CGImageRelease(cgImage);
    return uiImage;
}

-(NSUInteger) countOfObjectsToBuffer
{
    return _totalImageCount;
}

-(void) animationStateChange:(AMBufferingControllerAnimationState)state
{
    switch (state) {
        case AMBufferingControllerAnimationStateStopped:{
            [self stopAnimation];
            break;
        }
        case AMBufferingControllerAnimationStateRunning:{
            [self startAnimation];
            break;
        }
    }
}

-(NSTimeInterval) animationDuration
{
    return _duration;
}

-(NSTimeInterval) didBufferWithPercentComplete:(float)percentComplete
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.view setPercentBuffered:percentComplete];
    });
}

#pragma mark - Helpers

- (UIImageGIFDecodeProperties) createUIImageGIFDecodePropertiesWithRect:(CGRect)rect
{
    UIImageGIFDecodeProperties props;
    props.width = CGRectGetWidth(rect);
    props.height = CGRectGetHeight(rect);
    props.rect = rect;
    props.bitsPerComponent = 8;
    props.bytesPerPixel    = (props.bitsPerComponent * 4 + 7)/8;
    props.bytesPerRow      = props.width * props.bytesPerPixel;
    props.dataSize         = props.bytesPerRow * props.height;
    props.data = malloc(props.dataSize);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    props.context = CGBitmapContextCreate(props.data, props.width, props.height,
                                          props.bitsPerComponent, props.bytesPerRow, colorSpace,
                                          kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
    CGColorSpaceRelease(colorSpace);
    return props;
}

- (void) releaseIImageGIFDecodeProperties:(UIImageGIFDecodeProperties)props
{
    free(props.data);
    props = UIImageGIFDecodePropertiesNone;
}

- (UIImage*) makeImageFromCGImageRef:(CGImageRef)cgImageRef properties:(UIImageGIFDecodeProperties)properties
{
    memset(properties.data, 0, properties.dataSize);
    CGContextDrawImage(properties.context, properties.rect, cgImageRef);
    CGImageRef imageRef = CGBitmapContextCreateImage(properties.context);
    UIImage *resultImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    return resultImage;
}

- (float)frameDurationAtIndex:(NSUInteger)index source:(CGImageSourceRef)source
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

@interface AMGIFImageView ()
@property UIImageView *imageView;
@property UILabel *loadingLabel;
@end

@implementation AMGIFImageView

-(id) initWithFrame:(CGRect)frame animating:(BOOL)animating
{
    if (self = [super initWithFrame:frame]) {
        _loadingLabel = [[UILabel alloc] initWithFrame:frame];
        _loadingLabel.text = @"Buffering...";
        _loadingLabel.font = [UIFont boldSystemFontOfSize:20];
        _loadingLabel.backgroundColor = [UIColor colorWithWhite:0. alpha:0.5];
        _loadingLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.];
        _loadingLabel.textAlignment = NSTextAlignmentCenter;
        [_loadingLabel sizeToFit];
        [self setAnimating:animating];
    }
    return self;
}

-(void) layoutSubviews
{
    [super layoutSubviews];
    CGRect fr = _loadingLabel.frame;
    fr.origin.y = self.bounds.size.height-fr.size.height;
    _loadingLabel.frame = fr;
}

-(void) setPercentBuffered:(float)percent
{
    self.loadingLabel.text = [NSString stringWithFormat:@"Buffering: %.1f%%",percent*100];
    [_loadingLabel sizeToFit];
    [self layoutSubviews];
}

-(void) setAnimating:(BOOL)animating
{
    if (!animating) {
        [self addSubview:_loadingLabel];
    } else {
        [_loadingLabel removeFromSuperview];
    }
}

@end
