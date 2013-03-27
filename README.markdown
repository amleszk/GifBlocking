Demo project to illistrate how GIF images can block the main thread for up to 5 seconds.
To see the main thread get blocked, comment out this line:
`uiImage = [self decodedImageWithImage:uiImage];`

More info:
http://stackoverflow.com/questions/15598835/avoid-image-decompression-blocking-the-main-thread
