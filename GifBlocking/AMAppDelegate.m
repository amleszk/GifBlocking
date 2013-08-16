
#import "AMAppDelegate.h"
//#import "UIImage+JTImageDecode.h"
#import "AMGIFImageViewController.h"

@interface AMAppDelegate ()
@property (strong, nonatomic) UIImageView *imageView;
@property (strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) UIActivityIndicatorView *activity;
@property AMGIFImageViewController *gifImageViewController;
@end


@interface AMDemoVC : UIViewController
@end

@implementation AMAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[AMDemoVC alloc] initWithNibName:nil bundle:nil];
    [self.window makeKeyAndVisible];
    return YES;
}


@end


@implementation AMDemoVC
{
    NSMutableArray *_gifViewControllers;
}
-(void) viewDidLoad
{
    _gifViewControllers = [NSMutableArray arrayWithCapacity:10];
    //NSArray *gifs = @[@"rXYyQTo",@"514c09947cfe5",@"16-cell",@"GeraniumFlowerUnfurl2",@"mbImw",@"tX9cjUO"];
    NSArray *gifs = @[@"mbImw"];
    
    for (NSString *gif in gifs) {
        NSData *gifData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:gif ofType:@"gif"]];
        AMGIFImageViewController *vc = [[AMGIFImageViewController alloc] initWithData:gifData];
        [self.view addSubview:vc.view];
        [_gifViewControllers addObject:vc];
    }
}


-(void) viewDidLayoutSubviews
{
    CGRect bounds = self.view.bounds;
    CGSize boundsEachSize = bounds.size;
    boundsEachSize.width/=3;
    boundsEachSize.height/=3;
    
    CGFloat originX=0,originY=0;
    for (UIViewController *vc in _gifViewControllers){
        vc.view.frame = (CGRect){.origin={originX, originY},.size=boundsEachSize};
        originX += boundsEachSize.width;
        if (originX==bounds.size.width) {
            originX = 0, originY += boundsEachSize.height;
        }
    }
}

@end

