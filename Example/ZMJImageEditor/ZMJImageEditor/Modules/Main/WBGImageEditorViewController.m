//
//  WBGImageEditorViewController.m
//  CLImageEditorDemo
//
//  Created by Jason on 2017/2/27.
//  Copyright © 2017年 CALACULU. All rights reserved.
//

#import "WBGImageEditorViewController.h"
#import "WBGImageToolBase.h"
#import "WBGColorfullButton.h"
#import "WBGDrawTool.h"
#import "WBGTextTool.h"
#import "TOCropViewController.h"
#import "UIImage+CropRotate.h"
#import "WBGTextToolView.h"
#import "FrameAccessor.h"
#import "WBGImageEditor.h"
#import "WBGMoreKeyboard.h"
#import "WBGMosicaTool.h"
#import "Masonry.h"
#import "XRGBTool.h"
#import "WBGDrawView.h"


#pragma mark - WBGImageEditorViewController

@interface WBGImageEditorViewController ()
<UINavigationBarDelegate,
UIScrollViewDelegate,
TOCropViewControllerDelegate,
WBGMoreKeyboardDelegate,
WBGKeyboardDelegate,
WBGHitTestDelegate>

@property (weak, nonatomic) IBOutlet UIButton *backButton;
@property (weak, nonatomic) IBOutlet UIButton *finishButton;
@property (weak, nonatomic) IBOutlet UIView *bottomBar;
@property (weak, nonatomic) IBOutlet UIView *topBar;

@property (weak, nonatomic) IBOutlet TOCropScrollView *scrollView;
@property (weak, nonatomic) UIView *containerView;
@property (weak, nonatomic) UIImageView *imageView;
@property (strong, nonatomic) WBGDrawView *drawingView;
@property (strong, nonatomic) WBGScratchView *mosicaView;

@property (weak, nonatomic) IBOutlet UIButton *panButton;
@property (weak, nonatomic) IBOutlet UIButton *textButton;
@property (weak, nonatomic) IBOutlet UIButton *clipButton;
@property (weak, nonatomic) IBOutlet UIButton *paperButton;

@property (nonatomic, strong) WBGImageToolBase *currentTool;
@property (nonatomic, strong) WBGDrawTool *drawTool;
@property (nonatomic, strong) WBGTextTool *textTool;
@property (nonatomic, strong) WBGMosicaTool *mosicaTool;

@property (nonatomic, copy) UIImage *originImage;
@property (nonatomic, assign) CGSize originSize;
@property (nonatomic, assign) CGRect lastCropRect;
@property (nonatomic, assign) CGFloat lastAngle;
@property (nonatomic, assign) WBGEditorMode currentMode;

@property (nonatomic, assign) CGFloat clipInitScale;
@property (nonatomic, assign) BOOL barsHiddenStatus;
@property (nonatomic, strong) WBGMoreKeyboard *keyboard;

@end

@implementation WBGImageEditorViewController

- (id)init
{
    self = [self initWithNibName:NSStringFromClass([WBGImageEditorViewController class])
                          bundle:[NSBundle bundleForClass:self.class]];
    
    return self;
}

- (id)initWithImage:(UIImage *)image
{
    return [self initWithImage:image delegate:nil dataSource:nil];
}

- (id)initWithImage:(UIImage *)image
           delegate:(id<WBGImageEditorDelegate>)delegate
         dataSource:(id<WBGImageEditorDataSource>)dataSource;
{
    self = [self init];
    if (self)
    {
        _originImage = image;
        self.delegate = delegate;
        self.dataSource = dataSource;
    }
    
    return self;
}

- (id)initWithDelegate:(id<WBGImageEditorDelegate>)delegate
{
    self = [self init];
    if (self)
    {
        self.delegate = delegate;
    }
    return self;
}

#pragma mark - LifeCyle
- (void)viewDidLoad
{
    [super viewDidLoad];

    [self initViews];
    [self configCustomComponent];
    [self setupImageViewFrame];
    [self resetZoomScaleWithAnimated:NO];
    
    // 初始化
    self.imageView.frame = self.containerView.bounds;
    self.drawingView.frame = self.imageView.frame;
    self.mosicaView.frame = self.imageView.frame;
    self.drawingView.originSize = self.originSize;
}

- (void)configCustomComponent
{
     self.panButton.hidden = YES;
     self.textButton.hidden = YES;
     self.clipButton.hidden = YES;
     self.paperButton.hidden = YES;
    
    NSMutableArray *valibleCompoment = [NSMutableArray new];
    WBGImageEditorComponent curComponent = [self.dataSource respondsToSelector:@selector(imageEditorCompoment)] ? [self.dataSource imageEditorCompoment] : 0;
    
    if (curComponent == 0)
    {
        curComponent = WBGImageEditorALLComponent;
    }
    
    if (curComponent & WBGImageEditorDrawComponent)
    {
        self.panButton.hidden = NO;
        [valibleCompoment addObject:self.panButton];
    }
    
    if (curComponent & WBGImageEditorTextComponent)
    {
        self.textButton.hidden = NO;
        [valibleCompoment addObject:self.textButton];
    }
    
    if (curComponent & WBGImageEditorPaperComponent)
    {
        self.paperButton.hidden = NO;
        [valibleCompoment addObject:self.paperButton];
    }
    
    if (curComponent & WBGImageEditorClipComponent)
    {
        self.clipButton.hidden = NO;
        [valibleCompoment addObject:self.clipButton];
    }
    
    CGFloat padding = 45.0f;
    CGFloat width = WIDTH_SCREEN - 2 * padding;
    NSInteger count = valibleCompoment.count;
    CGFloat length = width / ((count - 1 > 0) ? (count - 1) : 1);
    
    [valibleCompoment enumerateObjectsUsingBlock:^(UIButton * _Nonnull button,
                                                   NSUInteger idx,
                                                   BOOL * _Nonnull stop)
     {
         button.centerX = length * idx + padding;
     }];
}

#pragma mark - Getter & Setter
- (WBGDrawTool *)drawTool
{
    if (_drawTool == nil)
    {
        _drawTool = [[WBGDrawTool alloc] initWithImageEditor:self];
        _drawTool.pathWidth = [self.dataSource respondsToSelector:@selector(imageEditorDrawPathWidth)] ? [self.dataSource imageEditorDrawPathWidth].floatValue : 5.0f;
    }
    
    return _drawTool;
}

- (WBGTextTool *)textTool
{
    if (_textTool == nil)
    {
        _textTool = [[WBGTextTool alloc] initWithImageEditor:self];
    }
    
    return _textTool;
}

- (WBGMosicaTool *)mosicaTool
{
    if (_mosicaTool == nil)
    {
        _mosicaTool = [[WBGMosicaTool alloc] initWithImageEditor:self];
    }
    
    return _mosicaTool;
}

- (void)setCurrentTool:(WBGImageToolBase *)currentTool
{
    [_currentTool cleanup];
    _currentTool = currentTool;
    [_currentTool setup];
    
    [self swapToolBarWithEditting];
}

- (void)initViews
{
    [self.finishButton setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
    
    self.scrollView.frame = [UIScreen mainScreen].bounds;
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.delegate = self;
    self.scrollView.hitTestDelegate = self;
    self.scrollView.clipsToBounds = NO;
    self.scrollView.backgroundColor = [UIColor blackColor];
    self.scrollView.contentInset = UIEdgeInsetsZero;
    self.scrollView.contentOffset = CGPointZero;
    if (@available(iOS 11.0, *)) {
        self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    
    UIView *containerView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.scrollView addSubview:containerView];
    self.containerView = containerView;
    self.containerView.clipsToBounds = YES;
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    imageView.image = self.originImage;
    [self.containerView addSubview:imageView];
    self.imageView = imageView;
    
    self.mosicaView = [[WBGScratchView alloc] initWithFrame:CGRectZero];
    self.mosicaView.surfaceImage = self.originImage;
    self.mosicaView.backgroundColor = [UIColor clearColor];
    [self.containerView addSubview:self.mosicaView];
    
    self.drawingView = [[WBGDrawView alloc] initWithFrame:CGRectZero];
    self.drawingView.clipsToBounds = YES;
    [self.containerView addSubview:self.drawingView];
    self.drawingView.userInteractionEnabled = YES;
    
    // 原始尺寸
    CGSize imageSize = self.imageView.image.size;
    CGSize scrollViewSize = self.scrollView.frame.size;
    CGSize originSize = CGSizeMake(scrollViewSize.width, imageSize.height*scrollViewSize.width/imageSize.width);
    self.originSize = originSize;
    self.lastCropRect = CGRectMake(0, 0, self.originSize.width, self.originSize.height);
}

- (void)setupImageViewFrame
{
    CGSize size = (_imageView.image) ? _imageView.image.size : _imageView.frame.size;
    if(size.width > 0 && size.height > 0 )
    {
        CGSize imageSize = self.imageView.image.size;
        CGSize scrollViewSize = self.scrollView.frame.size;
        
        self.containerView.frame = CGRectMake(0, 0, scrollViewSize.width, imageSize.height*scrollViewSize.width/imageSize.width);
        
        // 设置scrollView的缩小比例;
        CGSize newImageSize = self.containerView.viewSize;
        CGFloat widthRatio = 1.0f; // 宽已经缩放了
        CGFloat heightRatio = scrollViewSize.height/newImageSize.height;
        if (heightRatio >= 1.0f) heightRatio = 3.0f;
        
        self.scrollView.minimumZoomScale = MIN(widthRatio, heightRatio);
        self.scrollView.maximumZoomScale = MAX(widthRatio, heightRatio);
        self.scrollView.zoomScale = widthRatio;
    }
}

#pragma mark - Reset
- (void)resetImageViewFrameWithCropRect:(CGRect)cropRect
{
    CGSize imageSize = cropRect.size;
    CGSize scrollViewSize = self.scrollView.frame.size;
    
    self.containerView.frame = CGRectMake(0, 0, scrollViewSize.width, imageSize.height*scrollViewSize.width/imageSize.width);
    
    // 设置scrollView的缩小比例;
    CGSize newImageSize = self.containerView.viewSize;
    CGFloat widthRatio = 1.0f; // 宽已经缩放了
    CGFloat heightRatio = scrollViewSize.height/newImageSize.height;
    if (heightRatio >= 1.0f) heightRatio = MAX(3.0f, heightRatio);
    
    self.scrollView.minimumZoomScale = MIN(widthRatio, heightRatio);
    self.scrollView.maximumZoomScale = MAX(widthRatio, heightRatio);
    self.scrollView.zoomScale = widthRatio;
    
    [self resetZoomScaleWithAnimated:NO];
}

- (void)resetDrawViewUseAngle:(CGFloat)angle cropRect:(CGRect)cropRect
{
    CGFloat radius = (angle/180.0f)*M_PI;
    // 旋转
    CGAffineTransform rotation = CGAffineTransformMakeRotation(radius);
    self.drawingView.transform = rotation;
    self.imageView.transform = rotation;
    self.mosicaView.transform = rotation;
    
    if (angle == 0 || angle == -180)
    {
        CGFloat ratio = self.scrollView.width/cropRect.size.width;
        CGAffineTransform scale = CGAffineTransformMakeScale(ratio, ratio);
        self.imageView.transform = CGAffineTransformConcat(scale, self.imageView.transform);
        self.drawingView.transform = CGAffineTransformConcat(scale, self.drawingView.transform);
        self.mosicaView.transform = CGAffineTransformConcat(scale, self.mosicaView.transform);
        
        CGPoint viewOrigin = CGPointMake(-cropRect.origin.x * ratio, -cropRect.origin.y * ratio);
        self.drawingView.viewOrigin = viewOrigin;
        self.imageView.viewOrigin = viewOrigin;
        self.mosicaView.viewOrigin = viewOrigin;
    }
    else if (angle == -90 || angle == -270)
    {
        CGFloat ratio = self.scrollView.width/cropRect.size.width;
        CGAffineTransform scale = CGAffineTransformMakeScale(ratio, ratio);
        self.imageView.transform = CGAffineTransformConcat(scale, self.imageView.transform);
        self.drawingView.transform = CGAffineTransformConcat(scale, self.drawingView.transform);
        self.mosicaView.transform = CGAffineTransformConcat(scale, self.mosicaView.transform);
        
        CGPoint viewOrigin = CGPointMake(-cropRect.origin.x * ratio, -cropRect.origin.y * ratio);
        self.drawingView.viewOrigin = viewOrigin;
        self.imageView.viewOrigin = viewOrigin;
        self.mosicaView.viewOrigin = viewOrigin;
    }
}

- (void)updateTransform:(CGFloat)angle withCropRect:(CGRect)cropRect
{
    [self resetImageViewFrameWithCropRect:cropRect];
    [self resetDrawViewUseAngle:angle cropRect:cropRect];
}

- (void)resetZoomScaleWithAnimated:(BOOL)animated
{
    CGSize size = self.scrollView.bounds.size;
    CGSize contentSize = self.scrollView.contentSize;
    
    CGFloat offsetX = (size.width > contentSize.width) ?
    (size.width - contentSize.width) * 0.5 : 0.0;
    
    CGFloat offsetY = (size.height > contentSize.height) ?
    (size.height - contentSize.height) * 0.5 : 0.0;
    
    self.containerView.center = CGPointMake(contentSize.width * 0.5 + offsetX, contentSize.height * 0.5 + offsetY);
    
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

#pragma mark- ScrollView delegate
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.containerView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView
{
    CGSize size = scrollView.bounds.size;
    CGSize contentSize = scrollView.contentSize;
    
    CGFloat offsetX = (size.width > contentSize.width) ?
    (size.width - contentSize.width) * 0.5 : 0.0;
    
    CGFloat offsetY = (size.height > contentSize.height) ?
    (size.height - contentSize.height) * 0.5 : 0.0;
    
    self.containerView.center = CGPointMake(contentSize.width * 0.5 + offsetX, contentSize.height * 0.5 + offsetY);
}

#pragma mark - WBGHitTestDelegate
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [self.currentTool drawView];
    if (view)
    {
        return view;
    }
    else
    {
         return nil;
    }
}

#pragma mark - Actions
- (void)setDisSelect
{
    self.panButton.selected = NO;
    self.textButton.selected = NO;
    self.clipButton.selected = NO;
    self.paperButton.selected = NO;
    
    [self.textTool hideTextBorder];
}

///涂鸦模式
- (IBAction)panAction:(UIButton *)sender
{
    [self setDisSelect];
    self.panButton.selected = YES;
    
    if (_currentMode == WBGEditorModeDraw)
    {
        [self resetCurrentTool];
    }
    else
    {
        //先设置状态，然后在干别的
        self.currentMode = WBGEditorModeDraw;
        self.currentTool = self.drawTool;
    }
}

///裁剪模式
- (IBAction)clipAction:(UIButton *)sender
{
    [self setDisSelect];
    [self resetCurrentTool];
    
    [self buildClipImageWithBorder:NO complete:^(UIImage *clipedImage)
    {
        TOCropViewController *cropController = [[TOCropViewController alloc] initWithCroppingStyle:TOCropViewCroppingStyleDefault image:clipedImage];
        cropController.delegate = self;
         
        CGRect viewFrame = [self.view convertRect:self.containerView.frame
                                           toView:self.navigationController.view];
        
        [cropController
         presentAnimatedFromParentViewController:self
         fromImage:[self buildTransitionImage]
         fromView:self.containerView
         fromFrame:viewFrame
         angle:self.lastAngle
         toImageFrame:self.lastCropRect
         setup:nil
         completion:NULL];
    }];
    
}

//文字模式
- (IBAction)textAction:(UIButton *)sender
{
    [self setDisSelect];
    
    //先设置状态，然后在干别的
    self.currentMode = WBGEditorModeText;
    
    self.currentTool = self.textTool;
}

//马赛克模式
- (IBAction)paperAction:(UIButton *)sender
{
    [self setDisSelect];
    self.paperButton.selected = YES;
    
    if (_currentMode == WBGEditorModeMosica)
    {
        return;
    }
    
    self.currentMode = WBGEditorModeMosica;
    self.currentTool = self.mosicaTool;
}

- (void)editTextAgain
{
    //先设置状态，然后在干别的
    self.currentMode = WBGEditorModeText;
    [_currentTool cleanup];
    _currentTool = self.textTool;
    [_currentTool setup];
}

//贴图模块
- (IBAction)onPicButtonTapped:(UIButton *)sender
{
    NSArray<WBGMoreKeyboardItem *> *sources = nil;
    if (self.dataSource) {
        sources = [self.dataSource imageItemsEditor:self];
    }
    
    [self.keyboard setChatMoreKeyboardData:sources.mutableCopy];
    [self.keyboard showInView:self.view withAnimation:YES];
}

- (IBAction)backAction:(UIButton *)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)onFinishButtonTapped:(UIButton *)sender
{
    [self buildClipImageWithBorder:NO complete:^(UIImage *clipedImage)
    {
        UIImage *newImage = [clipedImage croppedImageWithFrame:self.lastCropRect angle:self.lastAngle circularClip:NO];
        
        if ([self.delegate respondsToSelector:@selector(imageEditor:didFinishEdittingWithImage:)])
        {
            [self.delegate imageEditor:self didFinishEdittingWithImage:newImage];
        }
    }];
}

- (void)resetCurrentTool
{
    self.currentMode = WBGEditorModeNone;
    self.currentTool = nil;
}

- (WBGMoreKeyboard *)keyboard
{
    if (!_keyboard)
    {
        WBGMoreKeyboard *keyboard = [WBGMoreKeyboard keyboard];
        [keyboard setKeyboardDelegate:self];
        [keyboard setDelegate:self];
        _keyboard = keyboard;
    }
    
    return _keyboard;
}

#pragma mark - WBGMoreKeyboardDelegate
- (void)moreKeyboard:(id)keyboard didSelectedFunctionItem:(WBGMoreKeyboardItem *)funcItem
{
    WBGMoreKeyboard *kb = (WBGMoreKeyboard *)keyboard;
    [kb dismissWithAnimation:YES];
    
    
    WBGTextToolView *view = [[WBGTextToolView alloc] initWithTool:self.textTool text:@"" font:nil orImage:funcItem.image];
    view.borderColor = [UIColor whiteColor];
    view.image = funcItem.image;
    view.center = [self.imageView.superview convertPoint:self.imageView.center toView:self.drawingView];
    view.userInteractionEnabled = YES;
    [self.drawingView addSubview:view];
    [WBGTextToolView setActiveTextView:view];
    
}

#pragma mark - Cropper Delegate
- (void)cropViewController:(TOCropViewController *)cropViewController
            didCropToImage:(UIImage *)image
                  withRect:(CGRect)cropRect
                     angle:(NSInteger)angle
{
    [self updateImageViewWithImage:image
                          withRect:cropRect
                             angle:angle
            fromCropViewController:cropViewController];
}

- (void)updateImageViewWithImage:(UIImage *)clipedImage
                        withRect:(CGRect)cropRect
                           angle:(NSInteger)angle
          fromCropViewController:(TOCropViewController *)cropViewController
{
    self.navigationItem.rightBarButtonItem.enabled = YES;
    
    [self updateTransform:angle withCropRect:cropRect];
    
    self.lastCropRect = cropRect;
    self.lastAngle = angle;
    
    if (cropViewController.croppingStyle != TOCropViewCroppingStyleCircular)
    {
        [cropViewController
         dismissAnimatedFromParentViewController:self
         withCroppedImage:clipedImage
         toView:self.containerView
         toFrame:self.containerView.frame
         setup:NULL
         completion:NULL];
    }
    else
    {
        [cropViewController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    }
    
}

- (void)cropViewController:(TOCropViewController *)cropViewController didFinishCancelled:(BOOL)cancelled
{
    __weak WBGImageEditorViewController *weakSelf = self;
    
    [cropViewController
     dismissAnimatedFromParentViewController:self
     withCroppedImage:[self buildTransitionImage]
     toView:self.containerView
     toFrame:self.containerView.frame
     setup:^{
         __weak WBGImageEditorViewController *strongSelf = weakSelf;
         strongSelf.imageView.hidden = YES;
     } completion:^{
         __weak WBGImageEditorViewController *strongSelf = weakSelf;
         strongSelf.imageView.hidden = NO;
     }];
}

#pragma mark -
- (void)swapToolBarWithEditting
{
    switch (_currentMode)
    {
        case WBGEditorModeDraw:
        {
            self.panButton.selected = YES;
        }
            break;
        case WBGEditorModeText:
        case WBGEditorModeClip:
        case WBGEditorModeNone:
        {
            self.panButton.selected = NO;
        }
            break;
        default:
            break;
    }
}

- (void)hiddenTopAndBottomBar:(BOOL)isHide
                    animation:(BOOL)animation
{
    if (self.keyboard.isShow)
    {
        [self.keyboard dismissWithAnimation:YES];
        return;
    }
    
    CGFloat time = animation ? .4f : 0.f;
    [UIView animateWithDuration:time animations:^{
        [self.currentTool hideTools:isHide];
        self.barsHiddenStatus = isHide;
        self.topBar.alpha = (isHide ? 0 : 1);
    }];
}

#pragma mark - Clipe
- (void)buildClipImageWithBorder:(BOOL)border
                        complete:(void(^)(UIImage *clipedImage))complete
{
    if (!border)
    {
        [self.textTool hideTextBorder];
    }
    
    [self.scrollView setZoomScale:1.0f];
    
    UIGraphicsBeginImageContextWithOptions(self.originSize,
                                           NO,
                                           [UIScreen mainScreen].scale);
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [self.originImage drawInRect:CGRectMake(0, 0, self.originSize.width, self.originSize.height)];
    [self.mosicaView.layer renderInContext:ctx];
    [self.drawingView.layer renderInContext:ctx];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    if (complete)
    {
        complete(image);
    }
}

- (UIImage *)buildTransitionImage
{
    [self.scrollView setZoomScale:1.0f];
    
    UIGraphicsBeginImageContextWithOptions(self.containerView.viewSize,
                                           NO,
                                           [UIScreen mainScreen].scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [self.originImage drawInRect:CGRectMake(0, 0, self.containerView.width, self.containerView.height)];
    [self.containerView.layer renderInContext:context];
    UIImage *transitionImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return transitionImage;
}

#pragma mark - Public
- (CGFloat)bottomBarHeight
{
    return self.bottomBar.height;
}

@end
