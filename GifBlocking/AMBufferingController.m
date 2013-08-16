
#import "AMBufferingController.h"

@interface AMBufferingController ()
@property (nonatomic) NSThread* bufferingThread;
@property (nonatomic) NSUInteger bufferedImageIndex;
@property (nonatomic) NSMutableDictionary *cache;
@property (nonatomic,weak) id<AMBufferingControllerDelegate> delegate;
@property (nonatomic) AMBufferingControllerAnimationState animationState;

@property NSMutableArray *rollingBufferTime;
@property NSTimeInterval averageTimeToBuffer;

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
        _currentImageIndex = 0;
    }
    return self;
}

- (void)dealloc
{
    [_bufferingThread cancel];
}

#pragma mark - General

-(BOOL) hasSufficientBufferToStartAnimating
{
    NSUInteger bufferedObjectCount = [self bufferedObjectCount];
    if (bufferedObjectCount == _maxBufferCount) {
        return YES;
    }

    NSUInteger minBufferFrames = MIN(kRollingBufferTimeSlice, [_delegate countOfObjectsToBuffer]);
    if (bufferedObjectCount<minBufferFrames) {
        return NO;
    }
    
    float percentComplete = [self percentComplete];
    DLog(@"projectedBufferTime: %.2f duration: %.2f percentComplete : %.2f",[self projectedBufferTime],[_delegate animationDuration],percentComplete);
    return percentComplete>=1.;
}

-(void) didReceiveMemoryWarning
{
    [self stopBuffering];
    [self purgeNonEssentialObjects];
    [self startBufferingFromIndex:_currentImageIndex];
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
        NSUInteger countOfObjectsToBuffer = [_delegate countOfObjectsToBuffer];
        if (bufferedObjectCount == countOfObjectsToBuffer) {
            [self shiftToAnimationState:AMBufferingControllerAnimationStateRunning];            
            DLog(@"objects all buffered %d == %d",bufferedObjectCount,countOfObjectsToBuffer);
            break;
        }
        if ([self isMaximumFrameBufferReached]) {
            usleep(1000);
            continue;
        }
        
        if ([[NSThread currentThread] isCancelled]) break;

        if (![self isObjectCachedAtIndex:_bufferedImageIndex]) {\
            [self withTimer:^{
                id obj = [_delegate loadObjectAtIndex:_bufferedImageIndex];
                [self cacheObjectAtIndex:_bufferedImageIndex withObject:obj];
            }];
        }
        
        [_delegate didBufferWithPercentComplete:[self percentComplete]];
        
        if(_animationState == AMBufferingControllerAnimationStateStopped && [self hasSufficientBufferToStartAnimating]) {
            [self shiftToAnimationState:AMBufferingControllerAnimationStateRunning];
        }
        _bufferedImageIndex = (_bufferedImageIndex + 1) % countOfObjectsToBuffer;
    }
    DLog(@"finished thread loadGifFrames");
}

#pragma mark - Helpers
         
-(float) percentComplete
{
    NSTimeInterval projectedBufferTime = [self projectedBufferTime];
    NSTimeInterval animationDuration = [_delegate animationDuration];
    float percent = animationDuration/projectedBufferTime;
    percent = fminf(1., percent);
    return percent;
}

static NSTimeInterval kProjectedBufferAdditionalTime = 1.0;
-(NSTimeInterval) projectedBufferTime
{
    NSUInteger bufferedObjectCount = [self bufferedObjectCount];
    NSUInteger countOfObjectsToBuffer = [_delegate countOfObjectsToBuffer];
    NSUInteger framesLeft = (countOfObjectsToBuffer - bufferedObjectCount);
    return (NSTimeInterval)(framesLeft * _averageTimeToBuffer + kProjectedBufferAdditionalTime);
}

-(void) withTimer:(void (^)(void))operation
{
    //Time the operation
    NSTimeInterval bufferTimerStart = [NSDate timeIntervalSinceReferenceDate];
    operation();
    NSTimeInterval bufferTimerFinish = [NSDate timeIntervalSinceReferenceDate];
    
    //Get rolling average
    [_rollingBufferTime addObject:@(bufferTimerFinish-bufferTimerStart)];
    if (_rollingBufferTime.count>10) {
        [_rollingBufferTime removeObjectAtIndex:0];
    }
    
    //Update average
    _averageTimeToBuffer = 0.;
    for (NSNumber *num in _rollingBufferTime) {
        _averageTimeToBuffer += [num doubleValue];
    }
    _averageTimeToBuffer /= ((NSTimeInterval)_rollingBufferTime.count);
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

-(id) popCachedObject
{
    @synchronized(_cache)
    {
        id key = @(_currentImageIndex);
        id obj = _cache[key];
        if (obj) {
            //purge buffered objects to make room
            if ([self isMaximumFrameBufferReached]) {
                [self purgeNonEssentialObjects];
            }
            
            _currentImageIndex = (_currentImageIndex + 1) % [_delegate countOfObjectsToBuffer];
        } else {
            //Failed to deliver buffered object, stop animation and start buffering
            [self shiftToAnimationState:AMBufferingControllerAnimationStateStopped];
            if (![_bufferingThread isExecuting]) {
                [self startBufferingFromIndex:_currentImageIndex];
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

-(void) purgeNonEssentialObjects
{
    NSUInteger index = _currentImageIndex-1;
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
