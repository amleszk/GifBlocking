
typedef enum {
    AMBufferingControllerAnimationStateStopped,
    AMBufferingControllerAnimationStateRunning,
}AMBufferingControllerAnimationState;

@protocol AMBufferingControllerDelegate <NSObject>

@required
-(id) loadObjectAtIndex:(NSUInteger)index;
-(void) animationStateChange:(AMBufferingControllerAnimationState)state;
-(NSUInteger) countOfObjectsToBuffer;
-(NSTimeInterval) animationDuration;
-(NSTimeInterval) didBufferWithPercentComplete:(float)percentComplete;
@end


@interface AMBufferingController : NSObject

-(id) initWithDelegate:(id<AMBufferingControllerDelegate>)delegate;
-(id) popCachedObject;
-(void) startBufferingFromIndex:(NSUInteger)index;
-(void) didReceiveMemoryWarning;
@property NSUInteger maxBufferCount;

@property (readonly) NSUInteger bufferedObjectCount;
@property (readonly) NSUInteger currentImageIndex;
@end
