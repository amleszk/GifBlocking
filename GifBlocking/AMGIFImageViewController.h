
@interface AMGIFImageView : UIImageView
-(id) initWithFrame:(CGRect)frame animating:(BOOL)animating;
-(void) setAnimating:(BOOL)animating;
-(void) setPercentBuffered:(float)percent;
@end

@interface AMGIFImageViewController : UIViewController

-(id) initWithData:(NSData*)data;

@property (nonatomic) AMGIFImageView* view;
@property NSUInteger totalImageCount;
@property CGFloat delayTime;
@property CGFloat duration;
@property CGRect imageFrame;
@property NSTimer* animationTimer;
@property NSTimer* animationBufferTimer;
@end
