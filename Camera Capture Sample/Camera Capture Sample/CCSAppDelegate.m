//
//  CCSAppDelegate.m
//  Camera Capture Sample
//
//  Created by numata on 2014/04/27.
//  Copyright (c) 2014 Sazameki and Satoshi Numata, Ph.D. All rights reserved.
//

#import "CCSAppDelegate.h"
#import <AVFoundation/AVFoundation.h>


@interface CCSAppDelegate ()
@property (unsafe_unretained) IBOutlet NSWindow *mainWindow;
@property (weak) IBOutlet NSView *view;
@end


@implementation CCSAppDelegate {
    AVCaptureSession            *captureSession;
    AVCaptureVideoPreviewLayer  *previewLayer;
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

    // カメラ撮影の開始
	[captureSession startRunning];
}

@end

