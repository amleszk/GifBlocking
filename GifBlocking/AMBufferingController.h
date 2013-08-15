
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
@end


@interface AMBufferingController : NSObject

-(id) initWithDelegate:(id<AMBufferingControllerDelegate>)delegate;
-(id) popCachedObjectAtIndex:(NSUInteger)index;
-(void) startBufferingFromIndex:(NSUInteger)index;
-(void) stopBuffering;
@property NSUInteger maxBufferCount;

@property (readonly) NSUInteger bufferedObjectCount;
@end
