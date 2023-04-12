//
//  AppDelegate.m
//  KeySay
//

#import "AppDelegate.h"

extern const CFStringRef kTISNotifySelectedKeyboardInputSourceChanged;

@interface AppDelegate ()

@property(strong) NSSpeechSynthesizer *speechSynth;
@property NSTimeInterval lastAnnounce;
@property(strong) NSSound *rusSound;
@property(strong) NSSound *latSound;

@property (weak) IBOutlet NSWindow *window;

@end

@implementation AppDelegate

void theKeyboardChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    AppDelegate *slf = (__bridge AppDelegate*)observer;
    [slf announce];
    NSBeep();
}

- (void)announce {
    if( self.speechSynth != nil ) {
        TISInputSourceRef inputSource = TISCopyCurrentKeyboardInputSource();
        NSString *inputSourceID = (__bridge NSString*)TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID);
        if( [inputSourceID isEqualToString:@"com.apple.keylayout.ABC"] )
            [self.speechSynth startSpeakingString:@"Lat"];
        if( [inputSourceID isEqualToString:@"com.apple.keylayout.Russian"] )
            [self.speechSynth startSpeakingString:@"Rus"];
        CFRelease(inputSource);
        self.lastAnnounce = CACurrentMediaTime();
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSURL *latSoundURL = [[NSBundle mainBundle] URLForResource:@"keyb_click" withExtension:@"riff"];
    NSURL *rusSoundURL = [[NSBundle mainBundle] URLForResource:@"ios_click" withExtension:@"riff"];
    
    self.latSound = [[NSSound alloc] initWithContentsOfURL:latSoundURL byReference:NO];
    self.rusSound = [[NSSound alloc] initWithContentsOfURL:rusSoundURL byReference:NO];

    self.speechSynth = [[NSSpeechSynthesizer alloc] initWithVoice:@"com.apple.speech.synthesis.voice.milena.premium"];
    self.speechSynth.volume = 0.1;

    CFNotificationCenterAddObserver(CFNotificationCenterGetDistributedCenter(),
                                    (__bridge void*)self, theKeyboardChanged,
        kTISNotifySelectedKeyboardInputSourceChanged, NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately);
    
    [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                           handler:^(NSEvent *event){
        
        NSEventModifierFlags eventModifier = [event modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask;

        TISInputSourceRef inputSource = TISCopyCurrentKeyboardInputSource();
        NSString *inputSourceID = (__bridge NSString*)TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID);
        if( [inputSourceID isEqualToString:@"com.apple.keylayout.ABC"] ) {
            [self.latSound stop];
            [self.latSound play];
        }
        if( [inputSourceID isEqualToString:@"com.apple.keylayout.Russian"] ) {
            [self.rusSound stop];
            [self.rusSound play];
        }

        if( eventModifier==0 || eventModifier==NSEventModifierFlagShift ) {
            double currentTime = CACurrentMediaTime();
            if( fabs(self.lastAnnounce-currentTime) > 10.0 ) {
                [self announce];
            }
            self.lastAnnounce = currentTime;
        }
    }];
    
    [self.window setOpaque:NO];
    [self.window setBackgroundColor: [NSColor clearColor]];
    [self.window setLevel:kCGMaximumWindowLevel];

    [self.window performSelector:@selector(close) withObject:nil afterDelay:5];
    [self.speechSynth startSpeakingString:@"Key Say"];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
}


@end
