//
//  ImageAndVideoSupport.m
//  Camera Capture Sample
//
//  Created by numata on 2014/04/27.
//  Copyright (c) 2014 Sazameki and Satoshi Numata, Ph.D. All rights reserved.
//

#import "ImageAndVideoSupport.h"


/*!
    CGImageの画像サイズをCGSizeとして取得する。
 */
CGSize SZ_CGImageGetSize(CGImageRef cgImage)
{
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);

    return CGSizeMake(width, height);
}

/*!
    CGImageの画像の内容から、ARGB-32ビットの形式のビットマップデータを作成する。
 */
NSData *SZ_CGImageCreateBitmapDataFromCGImage(CGImageRef cgImage)
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (colorSpace == NULL) {
        NSLog(@"Failed to allocate color space.");
        return nil;
    }

    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);

    NSMutableData *bitmapData = [[NSMutableData alloc] initWithCapacity:width * height * 4];

    CGContextRef bitmapContext = CGBitmapContextCreate([bitmapData mutableBytes], width, height,
                                                       8, /* bits per component */
                                                       width * 4, /* bytes per row */
                                                       colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedFirst);

    CGContextDrawImage(bitmapContext, CGRectMake(0, 0, width, height), cgImage);

    CGColorSpaceRelease(colorSpace);
    CGContextRelease(bitmapContext);

    return bitmapData;
}

/*!
    ARGB-32ビットの形式のビットマップデータから、CGImageの画像を作成する。
 */
CGImageRef SZ_CGImageCreateFromBitmapData(NSData *bitmapData, CGSize size)
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (colorSpace == NULL) {
        NSLog(@"Failed to allocate color space.");
        return nil;
    }

    size_t width = (size_t)size.width;
    size_t height = (size_t)size.height;

    CGContextRef bitmapContext = CGBitmapContextCreate((void *)[bitmapData bytes], width, height,
                                                       8, /* bits per component */
                                                       width * 4, /* bytes per row */
                                                       colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedFirst);

    CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);

    CGContextRelease(bitmapContext);
    CGColorSpaceRelease(colorSpace);

    return cgImage;
}

/*!
    キャプチャ・セッションから取得したビデオの画像バッファからCGImage画像を作成する。
 */
CGImageRef SZ_CGImageCreateFromCMSampleBuffer(CMSampleBufferRef sampleBuffer)
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (colorSpace == NULL) {
        NSLog(@"Failed to allocate color space.");
        return nil;
    }

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);

    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);

    CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    CGContextRelease(newContext);

    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    /* CVBufferRelease(imageBuffer); */  // do not call this!

    return newImage;
}

