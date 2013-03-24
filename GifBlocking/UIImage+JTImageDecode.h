

@interface UIImage (JTImageDecode)
+ (UIImage *)decodedImageWithImage:(UIImage *)image;
+ (UIImage *)animatedGIFImageWithData:(NSData *)data;
@end
