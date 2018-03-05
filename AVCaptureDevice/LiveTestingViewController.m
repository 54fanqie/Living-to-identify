//
//  LiveTestingViewController.m
//  AVCaptureDevice
//
//  Created by 番茄 on 2017/12/25.
//  Copyright © 2017年 番茄. All rights reserved.
//

#import "LiveTestingViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "UIImage+FixOrientation.h"

#define ScreenHeight [UIScreen mainScreen].bounds.size.height
#define ScreenWidth [UIScreen mainScreen].bounds.size.width

@interface LiveTestingViewController ()<AVCaptureMetadataOutputObjectsDelegate,AVCaptureVideoDataOutputSampleBufferDelegate>
//捕获设备，通常是前置摄像头，后置摄像头，麦克风（音频输入）
@property (nonatomic,strong) AVCaptureDevice *device;
//AVCaptureDeviceInput 代表输入设备，他使用AVCaptureDevice 来初始化
@property (nonatomic,strong) AVCaptureDeviceInput *input;
//输出图片
@property (nonatomic,strong) AVCaptureStillImageOutput *imageOutput;
//session：由他把输入输出结合在一起，并开始启动捕获设备（摄像头）
@property (nonatomic,strong) AVCaptureSession *session;
//图像预览层，实时显示捕获的图像
@property (nonatomic,strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic,strong) AVCaptureVideoDataOutput * videoDataOutput;
@property (nonatomic,strong) AVCaptureMetadataOutput * metadataOutput;


//捕获的视图
@property (nonatomic,strong) NSMutableArray * captureImages;
//动画视图组
@property (nonatomic,strong) NSMutableArray * animationImages;
//随机动作码数组
@property (nonatomic,strong) NSMutableArray * randomCode;
//动作码数组
@property (nonatomic,strong) NSMutableArray * liveCodeList;
//动画组数顺序
@property (nonatomic,assign) int countNum;
//动画视图层
@property (nonatomic,strong) UIImageView * imageView;
//检测到人脸标识
@property (nonatomic,assign) BOOL haveFace;
//检测人脸中
@property (nonatomic,assign) BOOL faceing;
//获取到人脸识别图片
@property (nonatomic,assign) BOOL faceRecognition;

@property (nonatomic,strong) UIButton * button;


@property (nonatomic,strong) UIImage * faceImage;
@end

#define randomNum  2  //随机取三组动画

@implementation LiveTestingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    
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
    self.session.sessionPreset = AVCaptureSessionPresetHigh;
    //输入输出设备结合
    if ([self.session canAddInput:self.input]) {
        [self.session addInput:self.input];
    }
    if ([self.session canAddOutput:self.imageOutput]) {
        NSDictionary * outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil];
        [self.imageOutput setOutputSettings:outputSettings];
        [self.session addOutput:self.imageOutput];
    }
    if ([_session canAddOutput:self.metadataOutput]) {
        [_session addOutput:self.metadataOutput];
        //设置扫码格式
        self.metadataOutput.metadataObjectTypes = @[AVMetadataObjectTypeFace];
    }
    if ([_session canAddOutput:self.videoDataOutput]) {
        [_session addOutput:self.videoDataOutput];
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
        //自动对焦
        if ([_device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            [_device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
        }

        [_device unlockForConfiguration];
    }
    [self cameraDistrict];
}
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for ( AVCaptureDevice *device in devices )
        if ( device.position == position ){
            return device;
        }
    return nil;
}
-(AVCaptureMetadataOutput *)metadataOutput{
    if (_metadataOutput == nil) {
        _metadataOutput = [[AVCaptureMetadataOutput alloc]init];
        [_metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        //设置扫描区域
        _metadataOutput.rectOfInterest = self.view.bounds;
    }
    return _metadataOutput;
}
-(AVCaptureVideoDataOutput *)videoDataOutput{
    if (_videoDataOutput == nil) {
        _videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        [_videoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        [_videoDataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    }
    return _videoDataOutput;
}

#pragma mark  自定义视图
- (void)cameraDistrict
{
    UIView * buttonView = [[UIView alloc]initWithFrame:CGRectMake(ScreenWidth/2 - 35, ScreenHeight - 120 + 35, 70, 70)];
    buttonView.backgroundColor = [UIColor whiteColor];
    buttonView.layer.cornerRadius = 35;
    [buttonView.layer masksToBounds];
    [self.view addSubview:buttonView];
    //自己定义一个和原生的相机一样的按钮，开始检测按钮
    _button= [UIButton buttonWithType:UIButtonTypeRoundedRect];
    _button.frame = CGRectMake(5, 5, 60, 60);
    _button.backgroundColor = [UIColor whiteColor];
    _button.layer.cornerRadius = 30;
    _button.layer.borderWidth = 2;
    _button.layer.borderColor = [UIColor blackColor].CGColor;
    [_button.layer masksToBounds];
    [_button addTarget:self action:@selector(strarDetection) forControlEvents:UIControlEventTouchUpInside];
    [buttonView addSubview:_button];
    
    UIImageView * faceBack = [[UIImageView alloc]initWithFrame:CGRectMake(0, 80, ScreenWidth, ScreenWidth * 1.135)];
    faceBack.image = [UIImage imageNamed:@"faceBounds.png"];
    [self.view addSubview:faceBack];
    
    self.imageView = [[UIImageView alloc]initWithFrame:CGRectMake(faceBack.center.x - 100, faceBack.center.y - 115 , 200, 230)];
    [self.view addSubview:self.imageView];
    
    
    UIButton *save = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    save.frame = CGRectMake(30, 30 , 60, 60);
    save.backgroundColor = [UIColor redColor];
    [save addTarget:self action:@selector(savePhoto) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:save];
    //初始化
    [self initImageViewAnimation];
    self.faceing = NO;
    self.haveFace = YES;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
//AVCaptureVideoDataOutput获取实时图像，这个代理方法的回调频率很快，几乎与手机屏幕的刷新频率一样快
-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    
    
    
    
    
    if (self.haveFace) {
        return;
    }else{
        if (self.faceing) {
            return;
        }else{
            self.faceing = YES;
            [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
            UIImage * largeImage = [self imageFromSampleBuffer:sampleBuffer];
            if ([self faceDetectWithImage:largeImage]) {
                self.faceImage = largeImage;
                self.haveFace = YES;
                [self strarDetection];
            }else{
                self.faceing = NO;
            }
        }
    }
}
#pragma mark - 本地识别人脸
- (BOOL)faceDetectWithImage:(UIImage *)image {
    
    // 图像识别能力：可以在CIDetectorAccuracyHigh(较强的处理能力)与CIDetectorAccuracyLow(较弱的处理能力)中选择，因为想让准确度高一些在这里选择CIDetectorAccuracyHigh
    NSDictionary *opts = [NSDictionary dictionaryWithObject:
                          CIDetectorAccuracyHigh forKey:CIDetectorAccuracy];
    // 将图像转换为CIImage
    CIImage *faceImage = [CIImage imageWithCGImage:image.CGImage];
    CIDetector *faceDetector=[CIDetector detectorOfType:CIDetectorTypeFace context:nil options:opts];
    // 识别出人脸数组
    NSArray *features = [faceDetector featuresInImage:faceImage];
    
    if(features.count>0){
        NSLog(@"检测到人脸");
        UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
        return YES;
    }else{
        NSLog(@"检测中......");
        return NO;
    }
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate
-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    
    //    if (self.haveFace) {
    //        return;
    //    }
    //    if (metadataObjects.count>0) {
    //        AVMetadataMachineReadableCodeObject *metadataObject = [metadataObjects objectAtIndex :0];
    //        if (metadataObject.type == AVMetadataObjectTypeFace) {
    //            AVMetadataObject *objec = [self.previewLayer transformedMetadataObjectForMetadataObject:metadataObject];
    //            NSLog(@"%@",objec);
    //            [self takingPictures];
    //            self.haveFace = YES;
    //
    //        }
    //    }
}





#pragma mark animation group
-(void)initImageViewAnimation{
    
    self.randomCode = [NSMutableArray array];
    self.liveCodeList = [NSMutableArray array];
    
    NSMutableArray * initAnimationImages = [NSMutableArray arrayWithArray:[self imageDatas]];
    NSMutableSet * randomSet = [[NSMutableSet alloc] init];
    while ([randomSet count] < randomNum) {
        int r = arc4random() % [initAnimationImages count];
        NSLog(@"%d",r);
        [self.randomCode addObject:@(r)];
        [randomSet addObject:[initAnimationImages objectAtIndex:r]];
    }
    NSArray *randomArray = [randomSet allObjects];
    //随机动画组
    self.animationImages = [[NSMutableArray alloc]initWithArray:randomArray];
    
    self.haveFace = NO;
    self.faceRecognition = NO;
    _captureImages = [NSMutableArray array];
    
    self.countNum = 0;
    // 设置播放周期时间
    self.imageView.animationDuration = 4;
    // 设置播放次数
    self.imageView.animationRepeatCount = 0;
    
}
#pragma mark 开始检测
-(void)strarDetection{
    if(self.faceImage){
        self.haveFace = YES;
    }else{
        self.haveFace = NO;
        return;
    }
    
    
    if (_captureImages.count >0) {
        [_captureImages removeAllObjects];
        [_liveCodeList removeAllObjects];
    }
    if (self.haveFace) {
        //几组动画
        //总共动画时间
        int time = 4 * randomNum + 0.5*(randomNum- 1);
        //截图时间间隔，不能小于0.7否则会出在第二次点击活体采集时发出相机快门声音
        CGFloat  spaceTime = 0.7;
        
        __block int count = (int)ceilf(time / spaceTime);
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(0, 0));
        //通过start参数控制第一次执行的时间，DISPATCH_TIME_NOW表示立即执行
        dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, spaceTime * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(timer, ^{
            NSLog(@"dispatch_source_set_timer start %zd", count);
            if (count == 0) {
                //                self.haveFace = NO;
                //                self.faceRecognition = NO;
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.button.userInteractionEnabled = YES;
                });
                dispatch_source_cancel(timer);
            }else{
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.button.userInteractionEnabled = NO;
                });
                [self takingPictures];
            }
            count--;
        });
        dispatch_resume(timer);
        [self starImageAnimationGroup];
    }else{
        NSLog(@"未检测到人脸");
    }
}
#pragma mark 开始动画
-(void)starImageAnimationGroup{
    //设置imageView.animationImages动画组
    self.imageView.animationImages = self.animationImages[self.countNum];
    // 播放动画
    [self.imageView startAnimating];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"dispatch_after enter timer,thread = %@", [NSThread currentThread]);
        [self.imageView stopAnimating];
        if (self.countNum < randomNum -1) {
            self.countNum++;
            NSLog(@"切换组动画");
            [self performSelector:@selector(changeImageGrounp) withObject:nil afterDelay:0.5];
            // [self starImageAnimationGroup];
        }else{
            self.countNum = 0;
            NSLog(@"活体检测完成");
        }
        NSLog(@"%d",self.countNum);
        
    });
    
}

-(void)changeImageGrounp{
    [self starImageAnimationGroup];
}


//从AVCaptureDevice获取图片
- (void)takingPictures
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
        image = [image fixOrientation];
        
        if (!self.faceRecognition) {//面部识别
            self.faceRecognition  = YES;
            UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
            return;
        }
        
        //处理图片
//        UIImage * compressionImage = [compressionImage imageByScalingAndCroppingForSize:CGSizeMake(image.size.width/2, image.size.height/2) withSourceImage:image];
//        compressionImage = [compressionImage compressImageQuality:compressionImage toByte:10];
//        //存入数组
//        [_captureImages addObject:image];
        
        
    }];
}





-(UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    // 为媒体数据设置一个CMSampleBuffer的Core Video图像缓存对象
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // 锁定pixel buffer的基地址
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    // 得到pixel buffer的基地址
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    // 得到pixel buffer的行字节数
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // 得到pixel buffer的宽和高
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    // 创建一个依赖于设备的RGB颜色空间
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    // 用抽样缓存的数据创建一个位图格式的图形上下文（graphics context）对象
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // 根据这个位图context中的像素数据创建一个Quartz image对象
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // 解锁pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    // 释放context和颜色空间
    CGContextRelease(context); CGColorSpaceRelease(colorSpace);
    // 用Quartz image创建一个UIImage对象image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    // 释放Quartz image对象
    CGImageRelease(quartzImage);
    return (image);
}

-(void)savePhoto{
    
    [self takingPictures];
    
    //
    NSLog(@"_imagesMu : %lu",(unsigned long)_captureImages.count);
    
    [self writeImages:[_captureImages mutableCopy] completion:^(id result){
        // Caution: check the execution context - it may be any thread
        NSLog(@"Result: %@", result);
    }];
    
    
}

- (void) writeImages:(NSMutableArray*)images completion:(void (^)(id result))completionHandler{
    
    ALAssetsLibrary *assetsLibrary = [[ALAssetsLibrary alloc] init];
    if ([images count] == 0) {
        if (completionHandler) {
            // Signal completion to the call-site. Use an appropriate result,
            // instead of @"finished" possibly pass an array of URLs and NSErrors
            // generated below  in "handle URL or error".
            completionHandler(@"finished");
        }
        return;
    }
    
    UIImage* image = [images firstObject];
    [images removeObjectAtIndex:0];
    
    [assetsLibrary writeImageToSavedPhotosAlbum:image.CGImage
                                    orientation:ALAssetOrientationUp
                                completionBlock:^(NSURL *assetURL, NSError *error)
     {
         // Caution: check the execution context - it may be any thread,
         // possibly use dispatch_async to dispatch to the main thread or
         // any other queue.
         
         // handle URL or error
         
         // next image:
         [self writeImages:images completion:completionHandler];
     }];
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    
    NSLog(@"image = %@, error = %@, contextInfo = %@", image, error, contextInfo);
}


-(NSArray*)imageDatas{
    UIImage * mouth_00 = [UIImage imageNamed:@"mouth_00.png"];
    UIImage * mouth_01 = [UIImage imageNamed:@"mouth_01.png"];
    
    UIImage * eye_00 = [UIImage imageNamed:@"eye_00.png"];
    UIImage * eye_01 = [UIImage imageNamed:@"eye_01.png"];
    
    UIImage * down_00 = [UIImage imageNamed:@"down_00.png"];
    UIImage * down_01 = [UIImage imageNamed:@"down_01.png"];
    
    UIImage * up_00 = [UIImage imageNamed:@"up_00.png"];
    UIImage * up_01 = [UIImage imageNamed:@"up_01.png"];
    
    UIImage * right_00 = [UIImage imageNamed:@"right_00.png"];
    UIImage * right_01 = [UIImage imageNamed:@"right_01.png"];
    
    UIImage * left_00 = [UIImage imageNamed:@"left_00.png"];
    UIImage * left_01 = [UIImage imageNamed:@"left_01.png"];
    
    
    //张嘴1
    NSMutableArray * imagesArray1 = [NSMutableArray array];
    [imagesArray1 addObject:mouth_00];
    [imagesArray1 addObject:mouth_01];
    [imagesArray1 addObject:mouth_00];
    [imagesArray1 addObject:mouth_01];
    [imagesArray1 addObject:mouth_00];
    //眨眼2
    NSMutableArray * imagesArray2 = [NSMutableArray array];
    [imagesArray2 addObject:eye_00];
    [imagesArray2 addObject:eye_01];
    [imagesArray2 addObject:eye_00];
    [imagesArray2 addObject:eye_01];
    [imagesArray2 addObject:eye_00];
    //低头3
    NSMutableArray * imagesArray3 = [NSMutableArray array];
    [imagesArray3 addObject:down_00];
    [imagesArray3 addObject:down_01];
    [imagesArray3 addObject:down_00];
    [imagesArray3 addObject:down_01];
    [imagesArray3 addObject:down_00];
    //抬头4
    NSMutableArray * imagesArray4 = [NSMutableArray array];
    [imagesArray4 addObject:up_00];
    [imagesArray4 addObject:up_01];
    [imagesArray4 addObject:up_00];
    [imagesArray4 addObject:up_01];
    [imagesArray4 addObject:up_00];
    //右转头5
    NSMutableArray * imagesArray5 = [NSMutableArray array];
    [imagesArray5 addObject:right_00];
    [imagesArray5 addObject:right_01];
    [imagesArray5 addObject:right_00];
    [imagesArray5 addObject:right_01];
    [imagesArray5 addObject:right_00];
    //左转头6
    NSMutableArray * imagesArray6 = [NSMutableArray array];
    [imagesArray6 addObject:left_00];
    [imagesArray6 addObject:left_01];
    [imagesArray6 addObject:left_00];
    [imagesArray6 addObject:left_01];
    [imagesArray6 addObject:left_00];
    
    
    NSMutableArray * initAnimationImages = [NSMutableArray array];
    [initAnimationImages addObject:imagesArray1];
    [initAnimationImages addObject:imagesArray2];
    [initAnimationImages addObject:imagesArray3];
    [initAnimationImages addObject:imagesArray4];
    [initAnimationImages addObject:imagesArray5];
    [initAnimationImages addObject:imagesArray6];
    
    return (NSArray*)initAnimationImages;
}
-(void)dealloc{
    [self.session stopRunning];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end
