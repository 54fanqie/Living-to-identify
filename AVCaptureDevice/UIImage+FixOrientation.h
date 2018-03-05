//
//  UIImage+FixOrientation.h
//  BaoXinHuFu
//
//  Created by 番茄 on 2017/11/23.
//  Copyright © 2017年 番茄. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (FixOrientation)
- (UIImage *)fixOrientation;

//按照你想要的比例去缩放图片
- (UIImage *)scaleToWidth:(CGFloat)width;

- (NSData *)compressImageQuality:(UIImage *)image toByte:(NSInteger)maxLength;

+ (UIImage *)compressImage:(UIImage *)image toByte:(NSUInteger)maxLength ;

+ (UIImage *)jx_WaterImageWithImage:(UIImage *)image waterImage:(UIImage *)waterImage waterImageRect:(CGRect)rect;
+ (UIImage *)jx_WaterStringWithImage:(UIImage *)image text:(NSString *)text textPoint:(CGPoint)point attributedString:(NSDictionary * )attributed;
@end
