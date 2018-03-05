//
//  ViewController.m
//  AVCaptureDevice
//
//  Created by 番茄 on 2017/12/22.
//  Copyright © 2017年 番茄. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>


#define ScreenHeight [UIScreen mainScreen].bounds.size.height
#define ScreenWidth [UIScreen mainScreen].bounds.size.width
@interface ViewController ()
//捕获设备，通常是前置摄像头，后置摄像头，麦克风（音频输入）
@property (nonatomic, strong) AVCaptureDevice *device;

//AVCaptureDeviceInput 代表输入设备，他使用AVCaptureDevice 来初始化
@property (nonatomic, strong) AVCaptureDeviceInput *input;

//输出图片
@property (nonatomic ,strong) AVCaptureStillImageOutput *imageOutput;

//session：由他把输入输出结合在一起，并开始启动捕获设备（摄像头）
@property (nonatomic, strong) AVCaptureSession *session;

//图像预览层，实时显示捕获的图像
@property (nonatomic ,strong) AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic,strong) NSMutableArray * imagesMu;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self cameraDistrict];
    _imagesMu = [NSMutableArray array];

    __block int count = 4;
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(0, 0));
    //通过start参数控制第一次执行的时间，DISPATCH_TIME_NOW表示立即执行
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{
        NSLog(@"dispatch_source_set_timer start");
        NSLog(@"%zd", count);
        if (count == 0) {
            dispatch_source_cancel(timer);
        }else{
            [self photoBtnDidClick];
        }
        count--;
    });
    NSLog(@"main queue");
    dispatch_resume(timer);

}

- (void)cameraDistrict
{
    //    AVCaptureDevicePositionBack  后置摄像头
    //    AVCaptureDevicePositionFront 前置摄像头
    self.device = [self cameraWithPosition:AVCaptureDevicePositionFront];
    self.input = [[AVCaptureDeviceInput alloc] initWithDevice:self.device error:nil];
    
    self.imageOutput = [[AVCaptureStillImageOutput alloc] init];

    self.session = [[AVCaptureSession alloc] init];
    //     拿到的图像的大小可以自行设定
    //    AVCaptureSessionPreset320x240
    //    AVCaptureSessionPreset352x288
    //    AVCaptureSessionPreset640x480
    //    AVCaptureSessionPreset960x540
    //    AVCaptureSessionPreset1280x720
    //    AVCaptureSessionPreset1920x1080
    //    AVCaptureSessionPreset3840x2160
    self.session.sessionPreset = AVCaptureSessionPreset640x480;
    //输入输出设备结合
    if ([self.session canAddInput:self.input]) {
        [self.session addInput:self.input];
    }
    if ([self.session canAddOutput:self.imageOutput]) {
        NSDictionary * outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil];
        [self.imageOutput setOutputSettings:outputSettings];
        [self.session addOutput:self.imageOutput];
    }
    

    //预览层的生成
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    self.previewLayer.frame = CGRectMake(0,0, ScreenWidth, ScreenHeight);
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:self.previewLayer];
    //设备取景开始
    [self.session startRunning];
    if ([_device lockForConfiguration:nil]) {
        //自动闪光灯，
        if ([_device isFlashModeSupported:AVCaptureFlashModeAuto]) {
            [_device setFlashMode:AVCaptureFlashModeOff];
        }
        //自动白平衡,但是好像一直都进不去
        if ([_device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance]) {
            [_device setWhiteBalanceMode:AVCaptureWhiteBalanceModeLocked];
        }
        [_device unlockForConfiguration];
    }
    
    
    UIView *view = [[UIView alloc]initWithFrame:CGRectMake(ScreenWidth/2 - 30, ScreenHeight - 120 + 30, 60, 60)];
    view.backgroundColor = [UIColor whiteColor];
    view.layer.cornerRadius = 30;
    [view.layer masksToBounds];
    [self.view addSubview:view];
    //自己定义一个和原生的相机一样的按钮
    UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    button.frame = CGRectMake(ScreenWidth/2 - 25, ScreenHeight - 120 + 35, 50, 50);
    button.backgroundColor = [UIColor whiteColor];
    button.layer.cornerRadius = 25;
    button.layer.borderWidth = 2;
    button.layer.borderColor = [UIColor blackColor].CGColor;
    [button.layer masksToBounds];
    [button addTarget:self action:@selector(photoBtnDidClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
}
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for ( AVCaptureDevice *device in devices )
        if ( device.position == position ){
            return device;
        }
    return nil;
}
//获取图片
- (void)photoBtnDidClick
{
    static SystemSoundID soundID = 0;
    if (soundID == 0) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"photoShutter2" ofType:@"caf"];
        NSURL *filePath = [NSURL fileURLWithPath:path isDirectory:NO];
        AudioServicesCreateSystemSoundID((__bridge CFURLRef)filePath, &soundID);
    }
    AudioServicesPlaySystemSound(soundID);

    AVCaptureConnection *conntion = [self.imageOutput connectionWithMediaType:AVMediaTypeVideo];
    if (!conntion) {
        NSLog(@"拍照失败!");
        return;
    }
    [self.imageOutput captureStillImageAsynchronouslyFromConnection:conntion completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if (imageDataSampleBuffer == nil) {
            return ;
        }
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
     
       UIImage * image = [UIImage imageWithData:imageData];
       [_imagesMu addObject:image];
//       [self.session stopRunning];

    }];
}

//AVCaptureFlashMode  闪光灯
//AVCaptureFocusMode  对焦
//AVCaptureExposureMode  曝光
//AVCaptureWhiteBalanceMode  白平衡
//闪光灯和白平衡可以在生成相机时候设置
//曝光要根据对焦点的光线状况而决定,所以和对焦一块写
//point为点击的位置
- (void)focusAtPoint:(CGPoint)point{
    CGSize size = self.view.bounds.size;
    CGPoint focusPoint = CGPointMake( point.y /size.height ,1-point.x/size.width );
    NSError *error;
    if ([self.device lockForConfiguration:&error]) {
        //对焦模式和对焦点
        if ([self.device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            [self.device setFocusPointOfInterest:focusPoint];
            [self.device setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        //曝光模式和曝光点
        if ([self.device isExposureModeSupported:AVCaptureExposureModeAutoExpose ]) {
            [self.device setExposurePointOfInterest:focusPoint];
            [self.device setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        [self.device unlockForConfiguration];
        
        
        //设置对焦动画
//        _focusView.center = point;
//        _focusView.hidden = NO;
//        [UIView animateWithDuration:0.3 animations:^{
//            _focusView.transform = CGAffineTransformMakeScale(1.25, 1.25);
//        }completion:^(BOOL finished) {
//            [UIView animateWithDuration:0.5 animations:^{
//                _focusView.transform = CGAffineTransformIdentity;
//            } completion:^(BOOL finished) {
//                _focusView.hidden = YES;
//            }];
//        }];
    }
    
}


-(void)rightButton{
    UIImage * imageIm = nil;
    
    //截取照片，截取到自定义框内的照片
    imageIm = [self image:imageIm scaleToSize:CGSizeMake(ScreenWidth, ScreenHeight)];
    //应为在展开相片时放大的两倍，截取时也要放大两倍
//    imageIm = [self imageFromImage:imageIm inRect:CGRectMake(10*2, (ScreenHeight - (ScreenWidth - 20) /1.6)/2*2, (ScreenWidth - 20)*2 , (ScreenWidth - 20)/1.6*2)];
    
    //将图片存储到相册
//    UIImageWriteToSavedPhotosAlbum(imageIm, self, nil, nil);
//
//    //截取之后将图片显示在照相时页面，和拍摄时的照片进行像素对比
    UIImageView *imageView =[[UIImageView alloc] initWithFrame:CGRectMake(10, (ScreenHeight - (ScreenWidth - 20) /1.6)/2  + 170, ScreenWidth - 20 , (ScreenWidth - 20)/1.6)];
    imageView.image = imageIm;
    [self.view addSubview:imageView];
    
}

//截取图片
-(UIImage*)image:(UIImage *)imageI scaleToSize:(CGSize)size{
    /*
     UIGraphicsBeginImageContextWithOptions(CGSize size, BOOL opaque, CGFloat scale)
     CGSize size：指定将来创建出来的bitmap的大小
     BOOL opaque：设置透明YES代表透明，NO代表不透明
     CGFloat scale：代表缩放,0代表不缩放
     创建出来的bitmap就对应一个UIImage对象
     */
    UIGraphicsBeginImageContextWithOptions(size, NO, 1.0); //此处将画布放大两倍，这样在retina屏截取时不会影响像素
    
    [imageI drawInRect:CGRectMake(0, 0, size.width, size.height)];
    
    
    UIImage* scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return scaledImage;
}


-(UIImage *)imageFromImage:(UIImage *)imageI inRect:(CGRect)rect{
    
    CGImageRef sourceImageRef = [imageI CGImage];
    
    CGImageRef newImageRef = CGImageCreateWithImageInRect(sourceImageRef, rect);
    
    UIImage *newImage = [UIImage imageWithCGImage:newImageRef];
    
    return newImage;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
