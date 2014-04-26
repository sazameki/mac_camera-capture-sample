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

/*!
    アプリケーション起動直後、最初に呼び出されるメソッド。
    ここでカメラ利用の初期化処理を行う。
 */
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // ウィンドウサイズの設定（GUIエディタで変更しても良いが、手動でやる方が簡単。）
    [self setupWindowForWidth:720];

    // カメラ利用のためのキャプチャ・セッション作成
    captureSession = [self setupAVCaptureSession];
    [self setupPreviewLayerForSession:captureSession];
    [self setupVideoOutputForSession:captureSession];

    // 画像処理後のデータの表示用レイヤ作成
    [self setupTestLayer];

    // カメラ撮影の開始
	[captureSession startRunning];
}

/*!
    ビデオデータが更新された時点で呼び出されるコールバック・メソッド。
 */
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    dispatch_sync(dispatch_get_main_queue(), ^(void) {
        // サンプルバッファから画像を取り出して表示
        CGImageRef cgImage = SZ_CGImageCreateFromCMSampleBuffer(sampleBuffer);
        testLayer.contents = (__bridge id)(cgImage);

        // クリーンアップ
        CGImageRelease(cgImage);

        // 画像取得のインターバルを設定
        [NSThread sleepForTimeInterval:0.5];
    });
}

@end

