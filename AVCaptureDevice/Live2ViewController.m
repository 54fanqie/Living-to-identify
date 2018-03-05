//
//  Live2ViewController.m
//  AVCaptureDevice
//
//  Created by 番茄 on 2018/1/10.
//  Copyright © 2018年 番茄. All rights reserved.
//

#import "Live2ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#import <CoreImage/CoreImage.h>
#import "UIImage+FixOrientation.h"
#import "iflyMSC/IFlyFaceSDK.h"
#import "IFlyFaceImage.h"

@interface Live2ViewController ()<AVCaptureMetadataOutputObjectsDelegate,AVCaptureVideoDataOutputSampleBufferDelegate>

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

@property (nonatomic, retain ) IFlyFaceDetector           *faceDetector;

//动画视图层
@property (nonatomic,strong) UIImageView * imageView;
//所有动作数组视图
@property (nonatomic,strong) NSMutableArray * allAnimationImages;
//捕获动作的视图
@property (nonatomic,strong) NSMutableArray * captureImages;
//捕获动作码数组
@property (nonatomic,strong) NSMutableArray * liveCodeList;

//随机动作码数组
@property (nonatomic,strong) NSMutableArray * randomCode;
//随机动画视图组
@property (nonatomic,strong) NSMutableArray * randImages;
//动画组数顺序码
@property (nonatomic,assign) int countNum;
//动作码
@property (nonatomic,assign) int changeCode;

//必须检测到人脸才能开始人脸识别流程
@property (nonatomic,assign) BOOL haveFace;
//开始获取到人脸图片
@property (nonatomic,assign)  BOOL starFaceing;
//已检测到人脸标识
@property (nonatomic,copy) UIImage * faceImage;

@property (nonatomic,strong) UIButton * button;
//请求识别结果次数
@property (nonatomic,assign) int requestTimeOut;

@property(nonatomic,strong) UILabel * textlabel;
//是否有相机权限
@property (nonatomic,assign) BOOL videoStatus;

@property(nonatomic,strong) NSMutableArray * images;

@property (nonatomic,assign) int gaga;
@end

#define randomNum  3  //随机取三组动画
#define ScreenHeight [UIScreen mainScreen].bounds.size.height
#define ScreenWidth [UIScreen mainScreen].bounds.size.width
@implementation Live2ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.starFaceing = NO;
    //主动获取相机、相册权限
    [self getPermissions];
    //初始化相机
    [self initAVCaptureDevice];
    [self cameraDistrict];
}


-(void)initAVCaptureDevice{
    //    AVCaptureDevicePositionBack  后置摄像头
    //    AVCaptureDevicePositionFront 前置摄像头
    self.device = [self cameraWithPosition:AVCaptureDevicePositionFront];
    self.input = [[AVCaptureDeviceInput alloc] initWithDevice:self.device error:nil];
    
    self.imageOutput = [[AVCaptureStillImageOutput alloc] init];
    self.session = [[AVCaptureSession alloc] init];
    //设定图像的大小
    if ([self.session canSetSessionPreset:AVCaptureSessionPresetMedium]) {
        NSLog(@"🍉AVCaptureSessionPresetMedium🍉");
        self.session.sessionPreset = AVCaptureSessionPresetMedium;
    }
    
    
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
        if ([_device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
            CGPoint exposurePoint = CGPointMake(0.5f, 0.5f); // 曝光点为中心
            [_device setExposurePointOfInterest:exposurePoint];
            [_device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        }
        [_device unlockForConfiguration];
    }
    
    AVCaptureConnection *conntion = [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    // 打开影院级光学防抖
    conntion.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeCinematic;
    [conntion setVideoOrientation:AVCaptureVideoOrientationPortrait];
    
    self.faceDetector=[IFlyFaceDetector sharedInstance];
    [self.faceDetector setParameter:@"1" forKey:@"detect"];
    [self.faceDetector setParameter:@"1" forKey:@"align"];
}

-(AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position{
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
        dispatch_queue_t queue = dispatch_queue_create("myQueue2", NULL);
        [_metadataOutput setMetadataObjectsDelegate:self queue:queue];
        //设置扫描区域
        _metadataOutput.rectOfInterest = self.view.bounds;
    }
    return _metadataOutput;
}
-(AVCaptureVideoDataOutput *)videoDataOutput{
    if (_videoDataOutput == nil) {
        _videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        [_videoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
        [_videoDataOutput setSampleBufferDelegate:self queue:queue];
    }
    return _videoDataOutput;
}

#pragma mark  自定义视图
- (void)cameraDistrict
{
    CGFloat  width = 90;
    UIView * buttonView = [[UIView alloc]initWithFrame:CGRectMake(ScreenWidth/2 - (width +10)/2, ScreenHeight - width - 10 - 15, width, width )];
    buttonView.backgroundColor = [UIColor whiteColor];
    buttonView.layer.cornerRadius = width/2;
    [buttonView.layer masksToBounds];
    [self.view addSubview:buttonView];
    //自己定义一个和原生的相机一样的按钮，开始检测按钮
    _button= [UIButton buttonWithType:UIButtonTypeRoundedRect];
    _button.frame = CGRectMake(15/2, 15/2, width -15, width -15);
    _button.backgroundColor = [UIColor whiteColor];
    _button.layer.cornerRadius = (width -15)/2;
    _button.layer.borderWidth = 2;
    _button.layer.borderColor = [UIColor blackColor].CGColor;
    [_button.layer masksToBounds];
    [_button setTitle:@"开始检测" forState:UIControlStateNormal];
    [_button addTarget:self action:@selector(strarDetection) forControlEvents:UIControlEventTouchUpInside];
    [buttonView addSubview:_button];
    
    self.textlabel = [[UILabel alloc]initWithFrame:CGRectMake((ScreenWidth-150)/2, ScreenHeight - width - 10 - 15 -30, 150, 30)];
    self.textlabel.textAlignment = NSTextAlignmentCenter;
    self.textlabel.layer.cornerRadius = 15;
    self.textlabel.text = @"请按提示做动作";
    self.textlabel.textColor = [UIColor whiteColor];
    [self.view addSubview:self.textlabel];
    
    
    UIImageView * faceBack = [[UIImageView alloc]initWithFrame:CGRectMake(0, 80, ScreenWidth, ScreenWidth * 1.135)];
    faceBack.image = [UIImage imageNamed:@"faceBounds.png"];
    [self.view addSubview:faceBack];
    
    self.imageView = [[UIImageView alloc]initWithFrame:CGRectMake(faceBack.center.x - 100, faceBack.center.y - 115 , 200, 230)];
    [self.view addSubview:self.imageView];
    
    //测试按钮
    UIButton *save = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    save.frame = CGRectMake(30, 30 , 60, 60);
    save.backgroundColor = [UIColor redColor];
    [save addTarget:self action:@selector(savePhoto) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:save];
    //初始化
    [self initImageViewAnimation];
    self.gaga = 0;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
//AVCaptureVideoDataOutput获取实时图像，这个代理方法的回调频率很快，几乎与手机屏幕的刷新频率一样快
-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    if(sampleBuffer == NULL){
        return ;
    }
    
    //    UIImage * largeImage = [self imageFromSampleBuffer:sampleBuffer];
    //
    //    NSDictionary *opts = [NSDictionary dictionaryWithObject:
    //                          CIDetectorAccuracyHigh forKey:CIDetectorAccuracy];
    //    // 将图像转换为CIImage
    //    CIImage *faceImage = [CIImage imageWithCGImage:largeImage.CGImage];
    //    CIDetector *faceDetector=[CIDetector detectorOfType:CIDetectorTypeFace context:nil options:opts];
    //    // 识别出人脸数组
    //    NSArray *features = [faceDetector featuresInImage:faceImage];
    //    CIFaceFeature *feature = nil;
    //
    //    CGRect rect;
    //
    //    for (CIFaceFeature *f in features)
    //
    //    {
    //
    //        CGRect aRect = f.bounds;
    //
    ////        NSLog(@"%f, %f, %f, %f", aRect.origin.x, aRect.origin.y, aRect.size.width, aRect.size.height);
    //        NSLog(@"脸长%f, 脸宽%f", aRect.size.width, aRect.size.height);
    //        //眼睛和嘴的位置
    //
    //        if(f.hasLeftEyePosition) NSLog(@"Left eye（左眼） %g %g\n", f.leftEyePosition.x, f.leftEyePosition.y);
    //
    //        if(f.hasRightEyePosition) NSLog(@"Right eye（右眼） %g %g\n", f.rightEyePosition.x, f.rightEyePosition.y);
    //
    //        if(f.hasMouthPosition)
    //
    //        {
    //
    ////            NSLog(@"Mouth %g %g %g %g\n", f.mouthPosition.x, f.mouthPosition.y,f.bounds.size.height,f.bounds.size.width);
    //
    //            feature = f;
    //
    //            rect = CGRectMake(f.mouthPosition.x - 100 , f.mouthPosition.y  - 60, 200, 250);
    //
    //        }
    //
    //    }
    //
    
    //    IFlyFaceImage* faceImage=[self faceImageFromSampleBuffer:sampleBuffer];
    //     NSString* strResult=[self.faceDetector trackFrame:faceImage.data withWidth:faceImage.width height:faceImage.height direction:(int)faceImage.direction];
    //    UIImage * image = [UIImage imageWithData:faceImage.data];
    //    NSLog(@"%@",strResult);
    //     faceImage.data=nil;
    //    if(self.starFaceing){
    //        [NSThread sleepForTimeInterval:.4];
    //        if (self.starFaceing) {
    //            UIImage * largeImage = [self imageFromSampleBuffer:sampleBuffer];
    //            self.gaga++;
    //        NSString * title = [NSString stringWithFormat:@"%d——%d",self.gaga,self.changeCode];
    //        CGPoint point = CGPointMake(50, 300);
    //        NSDictionary * attributed = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:50],NSForegroundColorAttributeName : [UIColor redColor]};
    //        largeImage = [UIImage jx_WaterStringWithImage:largeImage text:title textPoint:point attributedString:attributed];
    //        largeImage = [largeImage scaleToWidth:largeImage.size.width];
    //活体图片采集处理图片
    //            [_captureImages addObject:largeImage];
    
    //存储动作码
    //            [self.liveCodeList addObject:self.randomCode[self.countNum]];
    //            NSLog(@"🍉🍉🍉🍉🍉🍉🍉🍉%d------动作码%@",self.gaga,self.randomCode[self.countNum]);
    //        }
    //
    //    }else{
    //        NSLog(@"暂停  暂停");
    //    }
}
// Create a IFlyFaceImage from sample buffer data
- (IFlyFaceImage *) faceImageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    //获取灰度图像数据
    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    uint8_t *lumaBuffer  = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    
    size_t bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer,0);
    size_t width  = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    
    CGColorSpaceRef grayColorSpace = CGColorSpaceCreateDeviceGray();
    
    CGContextRef context=CGBitmapContextCreate(lumaBuffer, width, height, 8, bytesPerRow, grayColorSpace,0);
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    IFlyFaceDirectionType faceOrientation=[self faceImageOrientation];
    
    IFlyFaceImage* faceImage=[[IFlyFaceImage alloc] init];
    if(!faceImage){
        return nil;
    }
    
    CGDataProviderRef provider = CGImageGetDataProvider(cgImage);
    
    faceImage.data= (__bridge_transfer NSData*)CGDataProviderCopyData(provider);
    faceImage.width=width;
    faceImage.height=height;
    faceImage.direction=faceOrientation;
    
    CGImageRelease(cgImage);
    CGContextRelease(context);
    CGColorSpaceRelease(grayColorSpace);
    
    return faceImage;
    
}
-(IFlyFaceDirectionType)faceImageOrientation
{
    IFlyFaceDirectionType faceOrientation=IFlyFaceDirectionTypeLeft;
    BOOL isFrontCamera=self.input.device.position==AVCaptureDevicePositionFront;
    switch (self.interfaceOrientation) {
        case UIDeviceOrientationPortrait:{//
            faceOrientation=IFlyFaceDirectionTypeLeft;
        }
            break;
        case UIDeviceOrientationPortraitUpsideDown:{
            faceOrientation=IFlyFaceDirectionTypeRight;
        }
            break;
        case UIDeviceOrientationLandscapeRight:{
            faceOrientation=isFrontCamera?IFlyFaceDirectionTypeUp:IFlyFaceDirectionTypeDown;
        }
            break;
        default:{//
            faceOrientation=isFrontCamera?IFlyFaceDirectionTypeDown:IFlyFaceDirectionTypeUp;
        }
            break;
    }
    
    return faceOrientation;
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate
-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    //捕获人脸响应
    //    [NSThread sleepForTimeInterval:1];
    if (metadataObjects.count>0) {
        AVMetadataMachineReadableCodeObject *metadataObject = [metadataObjects objectAtIndex :0];
        if (metadataObject.type == AVMetadataObjectTypeFace) {
            self.haveFace = YES;
            AVMetadataFaceObject *face = (AVMetadataFaceObject *)metadataObject;
            
            CGRect faceRectangle = [face bounds];
            CGRect faceRect = [_previewLayer rectForMetadataOutputRectOfInterest:faceRectangle];
            
            int w = (int)faceRect.size.width;
            int h = (int)faceRect.size.height;
            int x = (int)faceRect.origin.x;
            int y = (int)faceRect.origin.y;
            NSString * string = nil;
            NSLog(@" 脸大不大 --%d----%d",w,h);
            //            NSLog(@"x偏移 %f", ScreenWidth/2 - (w/2 + x));
            //            NSLog(@"y偏移 %f", ScreenHeight/2 - (h/2 + y));
            //判断位置
            //            dispatch_async(dispatch_get_main_queue(), ^{
            //                if ( w < 200) {
            //                    NSLog(@"太远了...");
            //                    self.textlabel.text = @"太远了...";
            //                }else if (w > 300 ) {
            //                    NSLog(@"太近了...");
            //                    self.textlabel.text = @"太近了...";
            //                }else if((w/2 + x) + 30 < ScreenWidth/2 || (w/2 + x) - 30 > ScreenWidth/2){
            //                    NSLog(@"调整左右间距...");
            //                    self.textlabel.text = @"调整左右间距...";
            //                }else if( (h/2 + y) <  ScreenHeight - 20 || (h/2 + y) < ScreenHeight + 20){
            //                    NSLog(@"调整上下间距...");
            //                    self.textlabel.text = @"调整上下间距...";
            //                }else {
            //                    self.textlabel.text = @"";
            //                    NSLog(@"...");
            //                }
            //            });
            
            
            if ( w < 180) {
                NSLog(@"太远了...");
                string = @"太远了...";
            }else if (w > 250 ) {
                NSLog(@"太近了...");
                string = @"太近了...";
            }else if((w/2 + x) + 30 < ScreenWidth/2 || (w/2 + x) - 30 > ScreenWidth/2){
                NSLog(@"调整左右间距...");
                string= @"调整左右间距...";
            }else if( (h/2 + y) <  ScreenHeight/2 - 40 || (h/2 + y) > ScreenHeight/2 + 40){
                NSLog(@"调整上下间距...");
                string = @"调整上下间距...";
            }else{
                string = @"";
                NSLog(@"...");
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                self.textlabel.text = string;
            });

        }
    }
    if (self.haveFace) {
        return;
    }
    
}
#pragma mark animation group
-(void)initImageViewAnimation{
    self.allAnimationImages = [NSMutableArray arrayWithArray:[self imageDatas]];
    self.randomCode = [NSMutableArray array];
    self.randImages = [NSMutableArray array];
    
    self.starFaceing = NO;
    self.haveFace = NO;
    //活体检测图片组
    _captureImages = [NSMutableArray array];
    //活体检测动作码
    _liveCodeList = [NSMutableArray array];
    //设置播放周期时间
    self.imageView.animationDuration = 4;
    //设置播放次数
    self.imageView.animationRepeatCount = 1;
    //初始化随机动作数组
    [self randomAnimationImages];
    
}
//随机动作组
-(void)randomAnimationImages{
    self.countNum = 0;
    if (self.randImages.count > 0) {
        [self.randImages removeAllObjects];
    }
    if (self.randomCode.count > 0) {
        [self.randomCode removeAllObjects];
    }
    
    NSMutableSet * randomSet = [[NSMutableSet alloc] init];
    while ([randomSet count] < randomNum) {
        int r = arc4random() % [self.allAnimationImages count];
        [randomSet addObject:[self.allAnimationImages objectAtIndex:r]];
    }
    NSArray *randomArray = [randomSet allObjects];
    //随机动画组
    [self.randImages addObjectsFromArray:randomArray];
    //随机动作码
    for (int i=0;i<randomNum;i++) {
        NSInteger inde =[self.allAnimationImages indexOfObject:randomArray[i]];
        if (inde != NSNotFound) {
            [self.randomCode addObject:@(inde + 1)];
        }else{
            NSLog(@"不存在");
        }
    }
    
}

#pragma mark 开始动画->开始截图—>提交活体图片->提交人脸图片->进行签名->提交签名->返回
//获取人脸识别头像
-(void)strarDetection{
    if (!self.videoStatus) {
        NSLog(@"没有相机权限");
        return ;
    }
    if (!self.haveFace) {
        NSLog(@"没有识别到人脸");
        return;
    }
    _button.userInteractionEnabled = NO;
    self.faceImage = nil;
    //获取人脸识别图片
    //    [self takingPictures];
    //获取活体识别图片
    [self starLiveCollection];
}
//先判断是否有人脸，在开启动画，开启截图
-(void)starLiveCollection{
    //重置初始化值
    self.countNum = 0;
    self.gaga = 0;
    if (_captureImages.count > 0) {
        [_captureImages removeAllObjects];
    }
    if (_liveCodeList.count > 0) {
        [_liveCodeList removeAllObjects];
    }
    
    [self starImageAnimationGroup];
    //延迟1s开始截图
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.8 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        self.starFaceing = YES;
        NSLog(@"第1组动作");
    });
}
// 动画开始
-(void)starImageAnimationGroup{
    
    //设置imageView.animationImages动画组
    self.imageView.animationImages = self.randImages[self.countNum];
    // 播放动画
    [self.imageView startAnimating];
    NSLog(@"开始动画");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        //每组图片采集完成
        self.starFaceing = NO;
        NSLog(@"dispatch_after enter timer,thread = %@", [NSThread currentThread]);
        [self.imageView stopAnimating];
        if (self.countNum < randomNum -1) {
            self.countNum ++;
            NSLog(@"切换组动画");
            [self performSelector:@selector(changeImageGrounp) withObject:nil afterDelay:0.5];
        }else{
            [NSThread sleepForTimeInterval:1];
            //重置动作
            [self randomAnimationImages];
            [self uploadLiveImage];
        }
    });
    
}

-(void)changeImageGrounp{
    [self starImageAnimationGroup];
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.8 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        self.changeCode = self.countNum;
        self.starFaceing = YES;
        NSLog(@"第%d组动作",self.countNum + 1);
    });
    
}


//请求活体检测
-(void)uploadLiveImage{
    if(_captureImages.count==0){
        NSLog(@"未采集到图片信息");
        return;
    }
    //    UIImage * image = _captureImages[1];
    //    NSLog(@"活体检测图片尺寸 %.2f----%.2f",image.size.width * image.scale,image.size.height* image.scale);
    //    [self writeImages:_captureImages completion:^(id result) {
    //            NSLog(@"%@",result);
    //    }];
    //    largeImage = [UIImage imageWithCGImage:largeImage.CGImage scale:1 orientation:UIImageOrientationUp];
    int count = 0;
    NSMutableArray * images = [NSMutableArray array];
    for (UIImage * image in _captureImages) {
        count++;
        NSData * data = [image compressImageQuality:image toByte:10];
        UIImage * liveImg2  = [UIImage imageWithData:data];
        NSString * title = [NSString stringWithFormat:@"%d——%@",count,self.liveCodeList[count-1]];
        CGPoint point = CGPointMake(50, 300);
        NSDictionary * attributed = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:50],NSForegroundColorAttributeName : [UIColor redColor]};
        liveImg2 = [UIImage jx_WaterStringWithImage:liveImg2 text:title textPoint:point attributedString:attributed];
        [images addObject:liveImg2];
        
    }
    _button.userInteractionEnabled = YES;
    //    [self writeImages:images completion:^(id result) {
    //        NSLog(@"%@",result);
    //    }];
    
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
        
        
        if ([self faceDetectWithImage:image]) {
            self.faceImage = image;
            [self requestFaceDetector];
        }else{
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self takingPictures];
            });
        }
    }];
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
        return YES;
    }else{
        NSLog(@"检测中......");
        return NO;
    }
}




// 请求人脸识别
-(void)requestFaceDetector{
    
    UIImage * image = [UIImage imageWithCGImage:self.faceImage.CGImage scale:1 orientation:UIImageOrientationLeftMirrored];
    NSData * data  = [image compressImageQuality:image toByte:100];
    NSLog(@"大小KB %d",((int)data.length)/1024);
    
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
}


-(void)savePhoto{
    [self takingPictures];
}


/**
 *  批量存储图片到相册
 */
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



//主动获取相机、相册权限
-(void)getPermissions{
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        NSLog(@"%@",granted ? @"相机准许":@"相机不准许");
        self.videoStatus = granted;
    }];
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        
    }];
}
//初始化动画图片
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
