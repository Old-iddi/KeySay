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
@property(strong) NSStatusItem *statusItem;
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

- (void)setupStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:16.0];
    
    // Create menu
    NSMenu *menu = [[NSMenu alloc] init];
    
    // Settings menu item
    NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:@"Settings..."
                                                          action:@selector(openSettings:)
                                                   keyEquivalent:@","];
    [settingsItem setTarget:self];
    [menu addItem:settingsItem];
    
    // Separator
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Quit menu item
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                      action:@selector(quitApp:)
                                               keyEquivalent:@"q"];
    [quitItem setTarget:self];
    [menu addItem:quitItem];
    
    // Set menu for status item
    [self.statusItem setMenu:menu];
    
    // Set icon (you can use system icon or custom image)
    // Set custom icon (add your icon file to the project)
    NSImage *icon = [NSImage imageNamed:@"16@2x.png"];
    //[icon setTemplate:YES]; // For proper dark/light mode support
    [self.statusItem setImage:icon];
    
    // Optional: tooltip
    [self.statusItem setToolTip:@"KeySay"];
}

- (void)openSettings:(id)sender {
    // Show the main window when settings is clicked
    [self.window makeKeyAndOrderFront:self];
    [self.window setLevel:kCGMaximumWindowLevel];
    
    // Auto-close after 3 seconds
    [self.window performSelector:@selector(close) withObject:nil afterDelay:3];
}

- (void)quitApp:(id)sender {
    // Give speech a moment to start before quitting
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[NSApplication sharedApplication] terminate:self];
    });
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
    
    // Set up status item
    [self setupStatusItem];

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
    // Clean up status item
    if (self.statusItem) {
        [[NSStatusBar systemStatusBar] removeStatusItem:self.statusItem];
    }
}

@end
