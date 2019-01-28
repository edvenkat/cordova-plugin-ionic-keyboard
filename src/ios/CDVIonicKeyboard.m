/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at
 http://www.apache.org/licenses/LICENSE-2.0
 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "CDVIonicKeyboard.h"
#import <Cordova/CDVAvailability.h>
#import <Cordova/NSDictionary+CordovaPreferences.h>
#import <objc/runtime.h>

typedef enum : NSUInteger {
    ResizeNone,
    ResizeNative,
    ResizeBody,
    ResizeIonic,
} ResizePolicy;

#ifndef __CORDOVA_3_2_0
#warning "The keyboard plugin is only supported in Cordova 3.2 or greater, it may not work properly in an older version. If you do use this plugin in an older version, make sure the HideKeyboardFormAccessoryBar and KeyboardShrinksView preference values are false."
#endif

@interface CDVIonicKeyboard () <UIScrollViewDelegate>

@property (nonatomic, readwrite, assign) BOOL keyboardIsVisible;
@property (nonatomic, readwrite) ResizePolicy keyboardResizes;
@property (nonatomic, readwrite) BOOL isWK;
@property (nonatomic, readwrite) int paddingBottom;

@end

@implementation CDVIonicKeyboard

- (id)settingForKey:(NSString *)key
{
    return [self.commandDelegate.settings objectForKey:[key lowercaseString]];
}
#pragma mark Initialize
- (void)returnKeyType:(CDVInvokedUrlCommand *)command {
    NSString* echo = [command.arguments objectAtIndex:0];
    NSString* returnKeyType = [command.arguments objectAtIndex:1];
  if([echo isEqualToString:@"returnKeyType"]) {
        IMP darkImp = imp_implementationWithBlock(^(id _s) {
           //return UIKeyboardAppearanceDark;
           //return UIReturnKeyDone;
           //return UIReturnKeyTypeSend;
         //if([returnKeyType isEqualToString:@"send"])
          //  return UIReturnKeySend;
         if([returnKeyType isEqualToString:@"go"]) {
            return UIReturnKeyGo;
         } else if([returnKeyType isEqualToString:@"google"]) {
            return UIReturnKeyGoogle;
         } else if([returnKeyType isEqualToString:@"join"]) {
            return UIReturnKeyJoin;
         } else if([returnKeyType isEqualToString:@"next"]) {
            return UIReturnKeyNext;
         } else if([returnKeyType isEqualToString:@"route"]) {
            return UIReturnKeyRoute;
         } else if([returnKeyType isEqualToString:@"search"]) {
            return UIReturnKeySearch;
         } else if([returnKeyType isEqualToString:@"send"]) {
            return UIReturnKeySend;
         } else if([returnKeyType isEqualToString:@"yahoo"]) {
            return UIReturnKeyYahoo;
         } else if([returnKeyType isEqualToString:@"done"]) {
            return UIReturnKeyDone;
         } else if([returnKeyType isEqualToString:@"emergencycall"]) {
            return UIReturnKeyEmergencyCall;
         }
         return UIReturnKeyDefault;
       });

    for (NSString* classString in @[@"UIWebBrowserView", @"UITextInputTraits"]) {
        Class c = NSClassFromString(classString);
       // Method m = class_getInstanceMethod(c, @selector(keyboardAppearance));
      Method m = class_getInstanceMethod(c, @selector(returnKeyType));

        if (m != NULL) {
            method_setImplementation(m, darkImp);
        } else {
          //  class_addMethod(c, @selector(keyboardAppearance), darkImp, "l@:");
           class_addMethod(c, @selector(returnKeyType), darkImp, "l@:");
        }
    }
    }
}
#pragma mark Initialize

- (void)pluginInitialize
{
    NSDictionary *settings = self.commandDelegate.settings;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarDidChangeFrame:) name: UIApplicationDidChangeStatusBarFrameNotification object:nil];

    self.keyboardResizes = ResizeNative;
    BOOL doesResize = [settings cordovaBoolSettingForKey:@"KeyboardResize" defaultValue:YES];
    if (!doesResize) {
        self.keyboardResizes = ResizeNone;
        NSLog(@"CDVIonicKeyboard: no resize");

    } else {
        NSString *resizeMode = [settings cordovaSettingForKey:@"KeyboardResizeMode"];
        if (resizeMode) {
            if ([resizeMode isEqualToString:@"ionic"]) {
                self.keyboardResizes = ResizeIonic;
            } else if ([resizeMode isEqualToString:@"body"]) {
                self.keyboardResizes = ResizeBody;
            }
        }
        NSLog(@"CDVIonicKeyboard: resize mode %d", self.keyboardResizes);
    }
    self.hideFormAccessoryBar = [settings cordovaBoolSettingForKey:@"HideKeyboardFormAccessoryBar" defaultValue:YES];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    [nc addObserver:self selector:@selector(onKeyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [nc addObserver:self selector:@selector(onKeyboardDidHide:) name:UIKeyboardDidHideNotification object:nil];
    [nc addObserver:self selector:@selector(onKeyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [nc addObserver:self selector:@selector(onKeyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_pickerViewWillBeShown:) name: UIKeyboardWillShowNotification object:nil];

    // Prevent WKWebView to resize window
    BOOL isWK = self.isWK = [self.webView isKindOfClass:NSClassFromString(@"WKWebView")];
    if (!isWK) {
        NSLog(@"CDVIonicKeyboard: WARNING!!: Keyboard plugin works better with WK");
    }

    if (isWK) {
        [nc removeObserver:self.webView name:UIKeyboardWillHideNotification object:nil];
        [nc removeObserver:self.webView name:UIKeyboardWillShowNotification object:nil];
        [nc removeObserver:self.webView name:UIKeyboardWillChangeFrameNotification object:nil];
        [nc removeObserver:self.webView name:UIKeyboardDidChangeFrameNotification object:nil];
    }
}


- (void)_pickerViewWillBeShown:(NSNotification*)aNotification {
    [self performSelector:@selector(_resetPickerViewBackgroundAfterDelay) withObject:nil afterDelay:0];
}

-(void)_resetPickerViewBackgroundAfterDelay
{
    //UIPickerView *pickerView = nil;
    UIDatePicker *pickerView = nil;
    for (UIWindow *uiWindow in [[UIApplication sharedApplication] windows]) {
        for (UIView *uiView in [uiWindow subviews]) {
          NSLog(@"%@", uiView);
        //   if ([uiView isKindOfClass:NSClassFromString(@"UIDatePicker")] ){
        // if ([uiView isKindOfClass:[UIDatePicker class]] ){
              pickerView = [self _findPickerView:uiView];
          // }
        }
    }

    if (pickerView){
        NSDate *now = [NSDate date];
        NSCalendar *calendar = [[NSCalendar alloc]    initWithCalendarIdentifier:NSGregorianCalendar];
        NSDateComponents *components = [calendar components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:now];
        //set for today at 8 am
        [components setHour:8];
        NSDate *todayAtTime = [calendar dateFromComponents:components];
     
       [components setYear:[components year] - 100];
        NSDate *prevYears = [calendar dateFromComponents:components];
        //set max at now + 60 days
      //  NSDate *futureDate = [NSDate dateWithTimeIntervalSinceNow:60 * 60 * 24 * 60];
        //  NSDate *futureDate = [NSDate dateWithTimeIntervalSinceNow:60 * 60 * 24 * 36500];
         NSDate *futureDate = [now dateByAddingTimeInterval:60 * 60 * 24 * 100 * 365];
       // NSDate *prevDate = [now dateByAddingTimeInterval:60 * 60 * 24 * -13 * 365];
        
        [components setYear:[components year] + 86];
        NSDate *hundredYearsAgo = [calendar dateFromComponents:components];
     
        //[self.downArrow setHidden:true];
        //[pickerView.superview setClearButtonMode:@true];
//        [pickerView setBackgroundColor:[UIColor greenColor]];
        [pickerView.superview setValue:@"15" forKey:@"minuteInterval"];
        [pickerView.superview setValue:hundredYearsAgo forKey:@"maximumDate"];
        [pickerView.superview setValue:prevYears forKey:@"minimumDate"];
     
    
     
       /* UIToolbar *toolBar= [[UIToolbar alloc] initWithFrame:CGRectMake(0,0,320,44)];
        [toolBar setBarStyle:UIBarStyleBlackOpaque];
        UIBarButtonItem *barButtonDone = [[UIBarButtonItem alloc] initWithTitle:@"Done" 
        style:UIBarButtonItemStyleBordered target:self action:@selector(changeDateFromLabel:)];
        toolBar.items = @[barButtonDone];
       barButtonDone.tintColor=[UIColor blackColor];
       [pickerView addSubview:toolBar];*/
   /*  
     UIToolbar* keyboardToolbar = [[UIToolbar alloc] init];
[keyboardToolbar sizeToFit];
UIBarButtonItem *flexBarButton = [[UIBarButtonItem alloc]
                                  initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                  target:nil action:nil];
UIBarButtonItem *doneBarButton = [[UIBarButtonItem alloc]
                                  initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                  target:self action:@selector(yourTextViewDoneButtonPressed)];
keyboardToolbar.items = @[flexBarButton, doneBarButton];
      [pickerView addSubview:keyboardToolbar];
     */
     
    }
}

-(UIPickerView *) _findPickerView:(UIView *)uiView
{
       //if ([uiView isKindOfClass:[UIPickerView class]] ){
        if ([uiView isKindOfClass:objc_getClass("_UIDatePickerView")] || [uiView isKindOfClass:objc_getClass("UIDatePickerView")]) {
           // return (UIDatePicker*) uiView;
           // [(UITextField *)uiView setClearButtonMode:UITextFieldViewModeNever];
           // [(UIPickerView *)uiView setClearButtonMode:UITextFieldViewModeNever];
         
        // for (UIView *sub in uiView) {
              //[self hideKeyboardShortcutBar:sub];
         /*     if ([NSStringFromClass([uiView class]) isEqualToString:@"UIWebBrowserView"]) {
                  Method method = class_getInstanceMethod(uiView.class, @selector(inputAccessoryView));
                  IMP newImp = imp_implementationWithBlock(^(id _s) {
                      if ([uiView respondsToSelector:@selector(inputAssistantItem)]) {
                          UITextInputAssistantItem *inputAssistantItem = [uiView inputAssistantItem];
                          inputAssistantItem.leadingBarButtonGroups = @[];
                          inputAssistantItem.trailingBarButtonGroups = @[];
                      }
                      return nil;
                  });
                  method_setImplementation(method, newImp);
              }*/
        //  }
         
         
            return (UIPickerView*) uiView;
        }
 
      // if ([uiView isKindOfClass:NSClassFromString(@"UIDatePicker")] ){
      /* if ([uiView isKindOfClass:[UIDatePicker class]] ){
            return (UIDatePicker*) uiView;
       }*/

        if ([uiView subviews].count > 0) {
            for (UIView *subview in [uiView subviews]){
                UIPickerView* view = [self _findPickerView:subview];
                if (view)
                    return view;
            }
        }
        return nil;
}
-(void)statusBarDidChangeFrame:(NSNotification*)notification
{
    [self _updateFrame];
}


#pragma mark Keyboard events

- (void)resetScrollView
{
    UIScrollView *scrollView = [self.webView scrollView];
    [scrollView setContentInset:UIEdgeInsetsZero];
}

- (void)onKeyboardWillHide:(NSNotification *)sender
{
    if (self.isWK) {
        [self setKeyboardHeight:0 delay:0.01];
        [self resetScrollView];
    }
    [self.commandDelegate evalJs:@"Keyboard.fireOnHiding();"];
}

- (void)onKeyboardWillShow:(NSNotification *)note
{
    CGRect rect = [[note.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    double height = rect.size.height;

    if (self.isWK) {
        double duration = [[note.userInfo valueForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
        [self setKeyboardHeight:height delay:duration/2.0];
        [self resetScrollView];
    }

    NSString *js = [NSString stringWithFormat:@"Keyboard.fireOnShowing(%d);", (int)height];
    [self.commandDelegate evalJs:js];
}

- (void)onKeyboardDidShow:(NSNotification *)note
{
    CGRect rect = [[note.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    double height = rect.size.height;

    if (self.isWK) {
        [self resetScrollView];
    }

    NSString *js = [NSString stringWithFormat:@"Keyboard.fireOnShow(%d);", (int)height];
    [self.commandDelegate evalJs:js];
}

- (void)onKeyboardDidHide:(NSNotification *)sender
{
    [self.commandDelegate evalJs:@"Keyboard.fireOnHide();"];
    [self resetScrollView];
}

- (void)setKeyboardHeight:(int)height delay:(NSTimeInterval)delay
{
    if (self.keyboardResizes != ResizeNone) {
        [self setPaddingBottom: height delay:delay];
    }
}

- (void)setPaddingBottom:(int)paddingBottom delay:(NSTimeInterval)delay
{
    if (self.paddingBottom == paddingBottom) {
        return;
    }

    self.paddingBottom = paddingBottom;

    __weak CDVIonicKeyboard* weakSelf = self;
    SEL action = @selector(_updateFrame);
    [NSObject cancelPreviousPerformRequestsWithTarget:weakSelf selector:action object:nil];
    if (delay == 0) {
        [self _updateFrame];
    } else {
        [weakSelf performSelector:action withObject:nil afterDelay:delay];
    }
}

- (void)_updateFrame
{
    CGSize statusBarSize = [[UIApplication sharedApplication] statusBarFrame].size;
    int statusBarHeight = MIN(statusBarSize.width, statusBarSize.height);
    
    int _paddingBottom = (int)self.paddingBottom;
        
    if (statusBarHeight == 40) {
        _paddingBottom = _paddingBottom + 20;
    }
    NSLog(@"CDVIonicKeyboard: updating frame");
    // NOTE: to handle split screen correctly, the application's window bounds must be used as opposed to the screen's bounds.
    CGRect f = [[[[UIApplication sharedApplication] delegate] window] bounds];
    CGRect wf = self.webView.frame;
    switch (self.keyboardResizes) {
        case ResizeBody:
        {
            NSString *js = [NSString stringWithFormat:@"Keyboard.fireOnResize(%d, %d, document.body);",
                            _paddingBottom, (int)f.size.height];
            [self.commandDelegate evalJs:js];
            break;
        }
        case ResizeIonic:
        {
            NSString *js = [NSString stringWithFormat:@"Keyboard.fireOnResize(%d, %d, document.querySelector('ion-app'));",
                            _paddingBottom, (int)f.size.height];
            [self.commandDelegate evalJs:js];
            break;
        }
        case ResizeNative:
        {
            [self.webView setFrame:CGRectMake(wf.origin.x, wf.origin.y, f.size.width - wf.origin.x, f.size.height - wf.origin.y - self.paddingBottom)];
            break;
        }
        default:
            break;
    }
    [self resetScrollView];
}


#pragma mark HideFormAccessoryBar

static IMP UIOriginalImp;
static IMP WKOriginalImp;

- (void)setHideFormAccessoryBar:(BOOL)hideFormAccessoryBar
{
    if (hideFormAccessoryBar == _hideFormAccessoryBar) {
        return;
    }

    NSString* UIClassString = [@[@"UI", @"Web", @"Browser", @"View"] componentsJoinedByString:@""];
    NSString* WKClassString = [@[@"WK", @"Content", @"View"] componentsJoinedByString:@""];

    Method UIMethod = class_getInstanceMethod(NSClassFromString(UIClassString), @selector(inputAccessoryView));
    Method WKMethod = class_getInstanceMethod(NSClassFromString(WKClassString), @selector(inputAccessoryView));

    if (hideFormAccessoryBar) {
        UIOriginalImp = method_getImplementation(UIMethod);
        WKOriginalImp = method_getImplementation(WKMethod);

        IMP newImp = imp_implementationWithBlock(^(id _s) {
            return nil;
        });

        method_setImplementation(UIMethod, newImp);
        method_setImplementation(WKMethod, newImp);
    } else {
        method_setImplementation(UIMethod, UIOriginalImp);
        method_setImplementation(WKMethod, WKOriginalImp);
    }

    _hideFormAccessoryBar = hideFormAccessoryBar;
}


#pragma mark Plugin interface

- (void)hideFormAccessoryBar:(CDVInvokedUrlCommand *)command
{
    if (command.arguments.count > 0) {
        id value = [command.arguments objectAtIndex:0];
        if (!([value isKindOfClass:[NSNumber class]])) {
            value = [NSNumber numberWithBool:NO];
        }

        self.hideFormAccessoryBar = [value boolValue];
    }

    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:self.hideFormAccessoryBar]
                                callbackId:command.callbackId];
}

- (void)hide:(CDVInvokedUrlCommand *)command
{
    [self.webView endEditing:YES];
}

-(void)setResizeMode:(CDVInvokedUrlCommand *)command
{
    NSString * mode = [command.arguments objectAtIndex:0];
    if ([mode isEqualToString:@"ionic"]) {
        self.keyboardResizes = ResizeIonic;
    } else if ([mode isEqualToString:@"body"]) {
        self.keyboardResizes = ResizeBody;
    } else if ([mode isEqualToString:@"native"]) {
        self.keyboardResizes = ResizeNative;
    } else {
        self.keyboardResizes = ResizeNone;
    }
}


#pragma mark dealloc

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
