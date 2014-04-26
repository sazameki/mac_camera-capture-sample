//
//  ImageAndVideoSupport.h
//  Camera Capture Sample
//
//  Created by numata on 2014/04/27.
//  Copyright (c) 2014 Sazameki and Satoshi Numata, Ph.D. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>


CGSize SZ_CGImageGetSize(CGImageRef cgImage);
NSData *SZ_CGImageCreateBitmapDataFromCGImage(CGImageRef cgImage);
CGImageRef SZ_CGImageCreateFromBitmapData(NSData *bitmapData, CGSize size);
CGImageRef SZ_CGImageCreateFromCMSampleBuffer(CMSampleBufferRef sampleBuffer);

