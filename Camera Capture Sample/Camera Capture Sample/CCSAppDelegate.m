//
//  CCSAppDelegate.m
//  Camera Capture Sample
//
//  Created by numata on 2014/04/27.
//  Copyright (c) 2014 Sazameki and Satoshi Numata, Ph.D. All rights reserved.
//

#import "CCSAppDelegate.h"
#import <AVFoundation/AVFoundation.h>
#import "ImageAndVideoSupport.h"


#define kEyeHistoryCount    10


@interface CCSAppDelegate ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property (unsafe_unretained) IBOutlet NSWindow *mainWindow;
@property (weak) IBOutlet NSView *view;

@end


@implementation CCSAppDelegate {
    AVCaptureSession            *captureSession;
    AVCaptureVideoPreviewLayer  *previewLayer;

    AVCaptureVideoDataOutput    *videoDataOutput;
    dispatch_queue_t            videoDataOutputQueue;

    CALayer                     *testLayer;

    CIDetector                  *faceDetector;

    int     leftEyeHistory[kEyeHistoryCount];
    int     leftEyeHistoryPos;
    BOOL    isLeftEyeClosed;

    int     rightEyeHistory[kEyeHistoryCount];
    int     rightEyeHistoryPos;
    BOOL    isRightEyeClosed;
}

/*!
    16:9のアスペクト比でウィンドウのコンテンツ・サイズを設定する。
 */
- (void)setupWindowForWidth:(CGFloat)width
{
    NSSize size = NSMakeSize(width, width / (16.0/9.0));
    [self.mainWindow setContentSize:size];

    self.view.wantsLayer = YES;
}

/*!
    カメラを利用するためのキャプチャ・セッションを作成する。
    Macは基本的に1つしかカメラがないので、デフォルトのキャプチャ・デバイスを取得してそれを使う。
 */
- (AVCaptureSession *)setupAVCaptureSession
{
    AVCaptureSession *session = [AVCaptureSession new];
	//session.sessionPreset = AVCaptureSessionPresetHigh;
	session.sessionPreset = AVCaptureSessionPresetMedium;
    //session.sessionPreset = AVCaptureSessionPresetLow;

    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                                              error:&error];
    if (error) {
        NSLog(@"Failed to make a device input: %@", error.localizedDescription);
        return nil;
    }
    if ([session canAddInput:deviceInput]) {
        [session addInput:deviceInput];
    } else {
        NSLog(@"Failed to setup video input.");
        return nil;
    }
    return session;
}

/*!
    ビデオデータをプレビューするためのCore Animationレイヤをキャプチャ・セッションから作成する。
 */
- (void)setupPreviewLayerForSession:(AVCaptureSession *)session
{
    previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
	previewLayer.backgroundColor = [NSColor colorWithCalibratedWhite:0.2 alpha:1.0].CGColor;
	previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
	previewLayer.frame = self.view.layer.bounds;
	[self.view.layer addSublayer:previewLayer];
}

/*!
    ビデオデータをバッファに格納するための出力をキャプチャ・セッションに追加する。
 */
- (void)setupVideoOutputForSession:(AVCaptureSession *)session
{
    videoDataOutput = [AVCaptureVideoDataOutput new];
	videoDataOutput.videoSettings = @{ (__bridge NSString*)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
    if ([session canAddOutput:videoDataOutput]) {
        videoDataOutput.alwaysDiscardsLateVideoFrames = YES;    // ←画像取得と画像処理に時間がかかった場合、その間の新規のビデオデータを破棄する。
        videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
        [videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
        [session addOutput:videoDataOutput];
    } else {
        NSLog(@"Cannot add video output.");
    }
}

/*!
    画像処理後のデータを表示するためのレイヤを作成する。
 */
- (void)setupTestLayer
{
    testLayer = [CALayer layer];
    testLayer.bounds = CGRectMake(0, 0, 320, 180);
    testLayer.position = CGPointMake(0, 0);
    testLayer.anchorPoint = CGPointMake(0, 0);
    testLayer.borderWidth = 1.0;
    testLayer.borderColor = [NSColor whiteColor].CGColor;
    testLayer.backgroundColor = [NSColor blackColor].CGColor;

    [self.view.layer addSublayer:testLayer];
}

- (void)setupFaceDetector
{
    faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace
                                      context:nil
                                      options:@{ CIDetectorAccuracy : CIDetectorAccuracyHigh }];
}

/*!
    アプリケーション起動直後、最初に呼び出されるメソッド。
    ここでカメラ利用の初期化処理を行う。
 */
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    for (int i = 0; i < kEyeHistoryCount; i++) {
        leftEyeHistory[i] = 0;
        rightEyeHistory[i] = 0;
    }
    leftEyeHistoryPos = 0;
    isLeftEyeClosed = NO;
    rightEyeHistoryPos = 0;
    isRightEyeClosed = NO;

    // ウィンドウサイズの設定（GUIエディタで変更しても良いが、手動でやる方が簡単。）
    [self setupWindowForWidth:720];

    // カメラ利用のためのキャプチャ・セッション作成
    captureSession = [self setupAVCaptureSession];
    [self setupPreviewLayerForSession:captureSession];
    [self setupVideoOutputForSession:captureSession];

    // 顔検出用のフィルタ作成
    [self setupFaceDetector];

    // 画像処理後のデータの表示用レイヤ作成
    [self setupTestLayer];

    // カメラ撮影の開始
	[captureSession startRunning];
}

- (void)drawFaceFeatures:(NSArray *)features inBitmapContext:(CGContextRef)bitmapContext
{
    for (CIFaceFeature *faceFeature in features) {
        CGContextSetLineWidth(bitmapContext, 10.0);

        // 顔全体の領域の描画
        CGContextSetRGBStrokeColor(bitmapContext, 1.0, 0.0, 0.0, 1.0);
        CGContextStrokeRect(bitmapContext, faceFeature.bounds);

        // 口の位置の描画
        if (faceFeature.hasMouthPosition) {
            CGPoint mouthPos = faceFeature.mouthPosition;
            CGRect mouthRect = CGRectMake(mouthPos.x-20, mouthPos.y-20, 40, 40);
            CGContextSetRGBFillColor(bitmapContext, 1.0, 0.0, 0.0, 0.5);
            CGContextFillEllipseInRect(bitmapContext, mouthRect);
        }

        // 左目
        if (faceFeature.hasLeftEyePosition) {
            CGPoint leftEyePos = faceFeature.leftEyePosition;
            CGRect leftEyeRect = CGRectMake(leftEyePos.x-20, leftEyePos.y-20, 40, 40);
            if (isLeftEyeClosed) {
                CGContextSetRGBFillColor(bitmapContext, 0.0, 0.0, 1.0, 0.5);
            } else {
                CGContextSetRGBFillColor(bitmapContext, 1.0, 0.0, 0.0, 0.5);
            }
            CGContextFillEllipseInRect(bitmapContext, leftEyeRect);
        }

        // 右目
        if (faceFeature.hasRightEyePosition) {
            CGPoint rightEyePos = faceFeature.rightEyePosition;
            CGRect rightEyeRect = CGRectMake(rightEyePos.x-20, rightEyePos.y-20, 40, 40);
            if (isRightEyeClosed) {
                CGContextSetRGBFillColor(bitmapContext, 0.0, 0.0, 1.0, 0.5);
            } else {
                CGContextSetRGBFillColor(bitmapContext, 1.0, 0.0, 0.0, 0.5);
            }
            CGContextFillEllipseInRect(bitmapContext, rightEyeRect);
        }
    }
}

- (BOOL)checkEyeClosedInRect:(CGRect)rect ciImage:(CIImage *)ciImage history:(int[])history historyPos:(int *)historyPos
{
    {
        CIFilter *filter = [CIFilter filterWithName:@"CICrop"];
        [filter setValue:[CIVector vectorWithX:rect.origin.x Y:rect.origin.y
                                             Z:rect.size.width W:rect.size.height] forKey:@"inputRectangle"];
        [filter setValue:ciImage forKey:@"inputImage"];
        ciImage = [filter valueForKey:@"outputImage"];
    }
    {
        CIFilter *filter = [CIFilter filterWithName:@"CIRowAverage"];
        [filter setDefaults];
        [filter setValue:ciImage forKey:@"inputImage"];
        [filter setValue:[CIVector vectorWithCGRect:ciImage.extent] forKey:@"inputExtent"];
        ciImage = [filter valueForKey:@"outputImage"];
    }
    {
        CIFilter *filter = [CIFilter filterWithName:@"CIAreaAverage"];
        [filter setDefaults];
        [filter setValue:ciImage forKey:@"inputImage"];
        [filter setValue:[CIVector vectorWithCGRect:ciImage.extent] forKey:@"inputExtent"];
        ciImage = [filter valueForKey:@"outputImage"];
    }

    CGImageRef cgImage = SZ_CGImageCreateFromCIImage(ciImage);
    NSData *averageData = SZ_CGImageCreateBitmapDataFromCGImage(cgImage);
    uint8_t *buffer = (uint8_t *)averageData.bytes;
    int r = (int)buffer[1];
    int g = (int)buffer[2];
    int b = (int)buffer[3];

    int v = (int)(0.29891 * r + 0.58661 * g + 0.11448 * b);
    history[(*historyPos)++] = v;
    if (*historyPos >= kEyeHistoryCount) {
        *historyPos = 0;
    }

    float average = 0.0f;
    for (int i = 0; i < kEyeHistoryCount; i++) {
        average += history[i];
    }
    average /= kEyeHistoryCount;
    BOOL isEyeClosed = YES;
    if (average < 120) {
        isEyeClosed = NO;
    }
    NSLog(@"average=%.2f", average);
    CGImageRelease(cgImage);

    return isEyeClosed;
}

- (void)checkEyesClosedWithFeatures:(NSArray *)features ciImage:(CIImage *)ciImage
{
    if (features.count == 0) {
        return;
    }

    CIFaceFeature *feature = features[0];
    if (!feature.hasLeftEyePosition) {
        return;
    }

    CGRect faceBounds = feature.bounds;
    CGFloat eyeWidth = CGRectGetWidth(faceBounds) * 0.04;
    CGFloat eyeHeight = CGRectGetWidth(faceBounds) * 0.1;
    CGPoint leftEyePos = feature.leftEyePosition;
    CGRect leftEyeRect = CGRectMake(leftEyePos.x-eyeWidth/2, leftEyePos.y-eyeHeight/2, eyeWidth, eyeHeight);
    isLeftEyeClosed = [self checkEyeClosedInRect:leftEyeRect ciImage:ciImage history:leftEyeHistory historyPos:&leftEyeHistoryPos];

    CGPoint rightEyePos = feature.rightEyePosition;
    CGRect rightEyeRect = CGRectMake(rightEyePos.x-eyeWidth/2, rightEyePos.y-eyeHeight/2, eyeWidth, eyeHeight);
    isRightEyeClosed = [self checkEyeClosedInRect:rightEyeRect ciImage:ciImage history:rightEyeHistory historyPos:&rightEyeHistoryPos];
}

/*!
    ビデオデータが更新された時点で呼び出されるコールバック・メソッド。
 */
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    dispatch_sync(dispatch_get_main_queue(), ^(void) {
        // サンプルバッファから画像を取得
        CIImage *ciImage = SZ_CIImageCreateFromCMSampleBuffer(sampleBuffer);

        CIFilter *toneFilter = [CIFilter filterWithName:@"CIFaceBalance"];
        [toneFilter setDefaults];
        [toneFilter setValue:ciImage forKey:@"inputImage"];
        ciImage = [toneFilter valueForKey:@"outputImage"];

        // サンプルバッファから画像を取得
        CGImageRef cgImage = SZ_CGImageCreateFromCIImage(ciImage);
        CGSize imageSize = SZ_CGImageGetSize(cgImage);
        NSData *bitmapData = SZ_CGImageCreateBitmapDataFromCGImage(cgImage);
        CGContextRef bitmapContext = SZ_CGImageCreateBitmapContextFromBitmapData(bitmapData, imageSize);

        // Core Imageフィルタで画像処理
        NSArray *features = [faceDetector featuresInImage:ciImage options:nil];
        [self checkEyesClosedWithFeatures:features ciImage:ciImage];
        [self drawFaceFeatures:features inBitmapContext:bitmapContext];

        // 画像処理結果を表示
        CGImageRef resultImage = SZ_CGImageCreateFromBitmapContext(bitmapContext);
        testLayer.contents = (__bridge id)(resultImage);

        // クリーンアップ
        CGImageRelease(resultImage);
        CGContextRelease(bitmapContext);
        CGImageRelease(cgImage);

        // 画像取得のインターバルを設定
        //[NSThread sleepForTimeInterval:0.5];
    });
}

@end

