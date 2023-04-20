//
//  AppDelegate.m
//  KeySay
//

#import "AppDelegate.h"

extern const CFStringRef kTISNotifySelectedKeyboardInputSourceChanged;

@interface AppDelegate ()

@property(strong) NSSpeechSynthesizer *speechSynth1;
@property(strong) NSSpeechSynthesizer *speechSynth2;
@property NSTimeInterval lastAnnounce;
@property(strong) NSSound *sound1;
@property(strong) NSSound *sound2;

@property (weak) IBOutlet NSWindow *window;

@end

@implementation AppDelegate

void theKeyboardChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    AppDelegate *slf = (__bridge AppDelegate*)observer;
    [slf announce];
    NSBeep();
}

- (void)announce {
    if( self.speechSynth1 != nil && self.speechSynth2 != nil ) {
        TISInputSourceRef inputSource = TISCopyCurrentKeyboardInputSource();
        NSString *inputSourceID = (__bridge NSString*)TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID);
        if( [inputSourceID isEqualToString:@"com.apple.keylayout.ABC"] )
            [self.speechSynth2 startSpeakingString:@"Lat"];
        if( [inputSourceID isEqualToString:@"com.apple.keylayout.Russian"] )
            [self.speechSynth1 startSpeakingString:@"Rus"];
        CFRelease(inputSource);
        self.lastAnnounce = CACurrentMediaTime();
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSURL *sound1 = [[NSBundle mainBundle] URLForResource:@"keyb_click" withExtension:@"riff"];
    NSURL *sound2 = [[NSBundle mainBundle] URLForResource:@"ios_click" withExtension:@"riff"];
    
    self.sound2 = [[NSSound alloc] initWithContentsOfURL:sound2 byReference:NO];
    self.sound1 = [[NSSound alloc] initWithContentsOfURL:sound1 byReference:NO];
    
    //NSArray *voices = [NSSpeechSynthesizer availableVoices];
    self.speechSynth1 = [[NSSpeechSynthesizer alloc] initWithVoice:@"com.apple.speech.synthesis.voice.milena.premium"];
    self.speechSynth1.volume = 0.1;
    self.speechSynth2 = [[NSSpeechSynthesizer alloc] initWithVoice:@"com.apple.speech.synthesis.voice.yuri.premium"];
    self.speechSynth2.volume = 0.2;

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
            [self.sound1 stop];
            [self.sound1 play];
        }
        if( [inputSourceID isEqualToString:@"com.apple.keylayout.Russian"] ) {
            [self.sound2 stop];
            [self.sound2 play];
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
    [self.window makeKeyAndOrderFront:self];

    [self.window performSelector:@selector(close) withObject:nil afterDelay:3];
    [self.speechSynth1 startSpeakingString:@"Key Say"];
    [self.speechSynth2 startSpeakingString:@"Key Say"];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
}


@end
