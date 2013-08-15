
#import "AMBufferingController.h"

@interface AMBufferingController ()
@property (nonatomic) NSThread* bufferingThread;
@property (nonatomic) NSUInteger bufferedImageIndex;
@property (nonatomic) NSMutableDictionary *cache;
@property (nonatomic,weak) id<AMBufferingControllerDelegate> delegate;
@property (nonatomic) AMBufferingControllerAnimationState animationState;
@property NSMutableArray *rollingBufferTime;
@end

static NSUInteger kRollingBufferTimeSlice = 20;

@implementation AMBufferingController

-(id) initWithDelegate:(id<AMBufferingControllerDelegate>)delegate
{
    self = [super init];
    if (self) {
        _delegate = delegate;
        _rollingBufferTime = [NSMutableArray arrayWithCapacity:kRollingBufferTimeSlice];
        _maxBufferCount = 200;
        _cache = [NSMutableDictionary dictionaryWithCapacity:_maxBufferCount];
    }
    return self;
}

- (void)dealloc
{
    [_bufferingThread cancel];
}

-(BOOL) hasSufficientBufferToStartAnimating
{
    NSUInteger bufferedObjectCount = [self bufferedObjectCount];
    if (bufferedObjectCount == _maxBufferCount) {
        return YES;
    }

    NSUInteger minBufferFrames = MIN(kRollingBufferTimeSlice, [self.delegate countOfObjectsToBuffer]);
    if (bufferedObjectCount<minBufferFrames) {
        return NO;
    }
    
    NSTimeInterval projectedBufferTime = [self projectedBufferTime];
    DLog(@"projectedBufferTime: %.2f duration: %.2f",projectedBufferTime,[self.delegate animationDuration]);
    return projectedBufferTime<[self.delegate animationDuration];
}

#pragma mark Thread control

-(void) startBufferingFromIndex:(NSUInteger)index
{
    DLog(@"Cancelling buffer thread");
    [self stopBuffering];
    _bufferingThread = [[NSThread alloc] initWithTarget:self selector:@selector(loadGifFramesThread) object:nil];
    _bufferedImageIndex = index;
    DLog(@"Starting buffer thread");
    [_bufferingThread start];
}

-(void) stopBuffering
{
    [_bufferingThread cancel];
    _bufferingThread = nil;
}

-(void) loadGifFramesThread
{
    DLog(@"started thread loadGifFrames");
    while (YES)
    {
        NSUInteger bufferedObjectCount = [self bufferedObjectCount];
        NSUInteger countOfObjectsToBuffer = [self.delegate countOfObjectsToBuffer];
        if (bufferedObjectCount == countOfObjectsToBuffer) {
            [self shiftToAnimationState:AMBufferingControllerAnimationStateRunning];            
            DLog(@"objects all buffered %d == %d",bufferedObjectCount,countOfObjectsToBuffer);
            break;
        }
        if ([self isMaximumFrameBufferReached]) {
            DLog(@"loadGifFramesThread sleeping, maximum objects reached");
            sleep(1);
            continue;
        }
        
        if ([[NSThread currentThread] isCancelled]) break;

        if (![self isObjectCachedAtIndex:_bufferedImageIndex]) {\
            [self withTimer:^{
                id obj = [self.delegate loadObjectAtIndex:_bufferedImageIndex];
                [self cacheObjectAtIndex:_bufferedImageIndex withObject:obj];
            }];
        }
        if(_animationState == AMBufferingControllerAnimationStateStopped && [self hasSufficientBufferToStartAnimating]) {
            [self shiftToAnimationState:AMBufferingControllerAnimationStateRunning];
        }
        _bufferedImageIndex = (_bufferedImageIndex + 1) % countOfObjectsToBuffer;
    }
    DLog(@"finished thread loadGifFrames");
}

#pragma mark - 

static NSTimeInterval kProjectedBufferAdditionalTime = 1.0;
-(NSTimeInterval) projectedBufferTime
{
    NSUInteger bufferedObjectCount = [self bufferedObjectCount];
    NSUInteger countOfObjectsToBuffer = [self.delegate countOfObjectsToBuffer];
    NSUInteger framesLeft = (countOfObjectsToBuffer - bufferedObjectCount);
    
    NSTimeInterval averageTimeToBuffer = 0.;
    for (NSNumber *num in _rollingBufferTime) {
        averageTimeToBuffer += [num doubleValue];
    }
    averageTimeToBuffer /= ((NSTimeInterval)_rollingBufferTime.count);
    return (NSTimeInterval)(framesLeft * averageTimeToBuffer + kProjectedBufferAdditionalTime);
}

-(void) withTimer:(void (^)(void))operation
{
    NSTimeInterval bufferTimerStart = [NSDate timeIntervalSinceReferenceDate];
    operation();
    NSTimeInterval bufferTimerFinish = [NSDate timeIntervalSinceReferenceDate];
    [_rollingBufferTime addObject:@(bufferTimerFinish-bufferTimerStart)];
    if (_rollingBufferTime.count>10) {
        [_rollingBufferTime removeObjectAtIndex:0];
    }
}

-(void) shiftToAnimationState:(AMBufferingControllerAnimationState)newState
{
    if (_animationState == newState) return;
    
    _animationState = newState;
    [_delegate animationStateChange:_animationState];
}

#pragma mark - Thread safe image caching

-(BOOL) isMaximumFrameBufferReached
{
    return [self bufferedObjectCount] >= _maxBufferCount;
}

-(NSUInteger) bufferedObjectCount {
    @synchronized(_cache) {
        return [_cache count];
    }
}

-(BOOL) isObjectCachedAtIndex:(NSUInteger)index
{
    @synchronized(_cache)
    {
        return _cache[@(index)] != nil;
    }
}

-(id) popCachedObjectAtIndex:(NSUInteger)index
{
    @synchronized(_cache)
    {
        id key = @(index);
        id obj = _cache[key];
        if (obj) {
            if ([self isMaximumFrameBufferReached]) {
                [self removeAllKeysLessThanIndex:index];
            }
        } else {
            [self shiftToAnimationState:AMBufferingControllerAnimationStateStopped];
            if (![_bufferingThread isExecuting]) {
                [self startBufferingFromIndex:index];
            }
        }
        return obj;
    }
}

-(void) cacheObjectAtIndex:(NSUInteger)index withObject:(id)obj
{
    @synchronized(_cache)
    {
        _cache[@(index)] = obj;
    }
}

-(void) removeAllKeysLessThanIndex:(NSUInteger)index
{
    while (YES) {
        id key = @(index);
        if (!_cache[key]) {
            break;
        }
        [_cache removeObjectForKey:key];
        index--;
    }
}

@end
