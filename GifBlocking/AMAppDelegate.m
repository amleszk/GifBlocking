
#import "AMAppDelegate.h"
#import "UIImageView+NDVAnimatedGIFSupport.h"

@interface AMAppDelegate ()
@property (strong, nonatomic) UIImageView *imageView;
@end

@implementation AMAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    NSTimer *timer =
    [NSTimer timerWithTimeInterval:0.2
                            target:self
                          selector:@selector(updateTimerFireMethod:)
                          userInfo:nil
                           repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    

    //[NSThread detachNewThreadSelector:@selector(decodeGif) toTarget:self withObject:nil];
    [self performSelector:@selector(decodeGif) withObject:nil afterDelay:1.];
    return YES;
}

-(void) updateTimerFireMethod:(NSTimer*)timer
{
    NSLog(@"Timer fired");
}

-(void) decodeGif
{
    NSData *gifData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"mbImw" ofType:@"gif"]];
    _imageView = [[UIImageView alloc] ndv_initWithAnimatedGIFData:gifData];
    [self.window addSubview:_imageView];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
