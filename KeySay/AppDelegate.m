//
//  AppDelegate.m
//  KeySay
//

#import "AppDelegate.h"

extern const CFStringRef kTISNotifySelectedKeyboardInputSourceChanged;

NSString* valueOrEmptyString(NSString *value) { return ((value)==0)?(@""):(value); }

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
}

- (void)announce {
    TISInputSourceRef inputSource = TISCopyCurrentKeyboardInputSource();
    NSString *inputSourceID = (__bridge NSString*)TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID);
    NSString *announce = self.settings[[NSString stringWithFormat:@"layouts.%@.announce", inputSourceID]];
    if( announce != nil ) {
        [self.speechSynth[inputSourceID] startSpeakingString:announce];
        self.lastAnnounce = CACurrentMediaTime();
    }
    if( self.settings[@"nsbeep"] != nil ) {
        NSBeep();
    }
}

- (void)setupStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:16.0];
    
    // Create menu
    NSMenu *menu = [[NSMenu alloc] init];
    
    // Settings menu item
    NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:@"Settings..."
                                                          action:@selector(openSettings:)
                                                   keyEquivalent:@""];
    [settingsItem setTarget:self];
    [menu addItem:settingsItem];
    
    // Separator
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Quit menu item
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                      action:@selector(quitApp:)
                                               keyEquivalent:@""];
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

- (void)saveDictionaryToPreferences {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.settings forKey:@"KeySay_0.1"];
}

// Retrieving dictionary from user defaults
- (void)loadDictionaryFromPreferences {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.settings = [[defaults dictionaryForKey:@"KeySay_0.1"] mutableCopy];
    if( self.settings == nil ) {
        self.settings = [NSMutableDictionary dictionaryWithCapacity:30];
    }
}


- (void)openSettings:(id)sender {
    // Show the main window when settings is clicked
    [self.settingsWindow makeKeyAndOrderFront:self];
    [self.settingsWindow setLevel:kCGMaximumWindowLevel];
    
    // Auto-close after 3 seconds
    //[self.window performSelector:@selector(close) withObject:nil afterDelay:3];
}

-(IBAction)flashScreenSet:(id)sender {
    if( self.flashScreenOnChange.state == NSOnState ) {
        self.settings[@"nsbeep"]=@"YES";
    }
    else {
        [self.settings removeObjectForKey:@"nsbeep"];
    }
    [self saveDictionaryToPreferences];
    [self setValues];
}

-(IBAction)showSplashScreenSet:(id)sender {
    if( self.showSplashScreen.state == NSOnState ) {
        self.settings[@"splash"]=@"YES";
    }
    else {
        [self.settings removeObjectForKey:@"splash"];
    }
    [self saveDictionaryToPreferences];
    [self setValues];
}

-(IBAction)announceChanged:(id)sender {
    self.settings[[NSString stringWithFormat:@"layouts.%@.announce", self.currentLayoutID]]=((NSTextField*)sender).stringValue;
    [self saveDictionaryToPreferences];
    [self setValues];
}

-(IBAction)chooseClickSound:(id)sender {
    self.listOfKeyClicks = [[NSMenu alloc] init];
    
    NSMenuItem *emptyItem = [[NSMenuItem alloc] initWithTitle:@"Quiet"
                                                          action:@selector(selectClickSound:)
                                                   keyEquivalent:@""];
    emptyItem.representedObject = nil;
    emptyItem.target = self;
    [self.listOfKeyClicks addItem:emptyItem];
    [self.listOfKeyClicks addItem:[NSMenuItem separatorItem]];

    NSArray *sounds = [[NSBundle mainBundle] pathsForResourcesOfType:@"riff" inDirectory:nil];
    
    for( NSString *sound in sounds ) {
        NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:[sound lastPathComponent]
                                                              action:@selector(selectClickSound:)
                                                       keyEquivalent:@""];
        settingsItem.representedObject = sound;
        settingsItem.target = self;
        [self.listOfKeyClicks addItem:settingsItem];
    }
    [self.listOfKeyClicks popUpMenuPositioningItem:[self.listOfKeyClicks itemAtIndex:1] atLocation:CGPointMake(4, 4) inView:sender];
}

-(IBAction)selectClickSound:(id)sender {
    NSMenuItem *sourceMenuItem = (NSMenuItem*)sender;
    if( sourceMenuItem.representedObject != nil ) {
        self.keyClick.stringValue = [(NSString*)sourceMenuItem.representedObject lastPathComponent];
        self.settings[[NSString stringWithFormat:@"layouts.%@.keyClickSound", self.currentLayoutID]]=(NSString*)sourceMenuItem.representedObject;
    }
    else {
        self.keyClick.stringValue = @"";
        [self.settings removeObjectForKey:[NSString stringWithFormat:@"layouts.%@.keyClickSound", self.currentLayoutID]];
    }
    [self saveDictionaryToPreferences];
    [self setValues];
}

-(IBAction)chooseVoice:(id)sender {
    self.listOfVoices = [[NSMenu alloc] init];
    
    NSMenuItem *emptyItem = [[NSMenuItem alloc] initWithTitle:@"Quiet"
                                                          action:@selector(selectVoice:)
                                                   keyEquivalent:@""];
    emptyItem.representedObject = nil;
    emptyItem.target = self;
    [self.listOfVoices addItem:emptyItem];
    [self.listOfVoices addItem:[NSMenuItem separatorItem]];
    
    NSArray *voices = [NSSpeechSynthesizer availableVoices];
    
    for( NSString *voiceID in voices ) {
        NSDictionary *voiceProperties = [NSSpeechSynthesizer attributesForVoice:voiceID];
        NSString *voiceName = voiceProperties[NSVoiceName];
        NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:voiceName
                                                              action:@selector(selectVoice:)
                                                       keyEquivalent:@""];
        settingsItem.representedObject = voiceID;
        settingsItem.target = self;
        [self.listOfVoices addItem:settingsItem];
    }
    [self.listOfVoices popUpMenuPositioningItem:[self.listOfVoices itemAtIndex:1] atLocation:CGPointMake(4, 4) inView:sender];
}

-(IBAction)selectVoice:(id)sender {
    NSMenuItem *sourceMenuItem = (NSMenuItem*)sender;
    if( sourceMenuItem.representedObject != nil ) {
        NSDictionary *voiceProperties = [NSSpeechSynthesizer attributesForVoice:(NSString*)sourceMenuItem.representedObject];
        NSString *voiceName = voiceProperties[NSVoiceName];
        self.voiceName.stringValue = voiceName;
        self.settings[[NSString stringWithFormat:@"layouts.%@.voiceID", self.currentLayoutID]]=(NSString*)sourceMenuItem.representedObject;
    }
    else {
        self.voiceName.stringValue = @"";
        [self.settings removeObjectForKey:[NSString stringWithFormat:@"layouts.%@.voiceID", self.currentLayoutID]];
    }
    [self saveDictionaryToPreferences];
    [self setValues];
}

-(IBAction)chooseLayout:(id)sender {
    CFArrayRef inputSourcesList = TISCreateInputSourceList(NULL, false);
    CFIndex inputSourcesCount = CFArrayGetCount(inputSourcesList);
    
    self.listOfLayouts = [[NSMenu alloc] init];
    for( int i=0; i < inputSourcesCount; i++ ) {
        //NSString *inputSourceID = (__bridge NSString*)TISGetInputSourceProperty(CFArrayGetValueAtIndex(inputSourcesList, i),kTISPropertyInputSourceID);
        NSString *inputSourceName = (__bridge NSString*)TISGetInputSourceProperty((TISInputSourceRef)CFArrayGetValueAtIndex(inputSourcesList, i), kTISPropertyLocalizedName);
        NSString *sourceType =(__bridge NSString*)TISGetInputSourceProperty((TISInputSourceRef)CFArrayGetValueAtIndex(inputSourcesList, i), kTISPropertyInputSourceType);
        if( [sourceType isEqualToString:(NSString*)kTISTypeKeyboardLayout] ) {
            NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:inputSourceName
                                                                  action:@selector(selectLayout:)
                                                           keyEquivalent:@""];
            settingsItem.representedObject = (__bridge id _Nullable)(CFArrayGetValueAtIndex(inputSourcesList, i));
            settingsItem.target = self;
            [self.listOfLayouts addItem:settingsItem];
        }
    }
    self.settings[[NSString stringWithFormat:@"layouts.%@.announce", self.currentLayoutID]]=self.announceText.stringValue;

    [self.listOfLayouts popUpMenuPositioningItem:[self.listOfLayouts itemAtIndex:1] atLocation:CGPointMake(4, 4) inView:sender];
}

-(IBAction)selectLayout:(id)sender {
    NSMenuItem *sourceMenuItem = (NSMenuItem*)sender;
    NSString *inputSourceName = (__bridge NSString*)TISGetInputSourceProperty((__bridge TISInputSourceRef)(sourceMenuItem.representedObject), kTISPropertyLocalizedName);
    self.currentLayout.stringValue = inputSourceName;
    NSString *inputSourceID = (__bridge NSString*)TISGetInputSourceProperty((__bridge TISInputSourceRef)(sourceMenuItem.representedObject),kTISPropertyInputSourceID);
    self.currentLayoutID = inputSourceID;
    self.currentLayoutName = inputSourceName;
    [self setValues];
    [self saveDictionaryToPreferences];
    [self setValues];
}

-(IBAction)playSound:(id)sender {
    NSSound *keyClick = self.sounds[self.currentLayoutID];

    [keyClick stop];
    [keyClick play];
}

-(IBAction)speak:(id)sender {
    [self.speechSynth[self.currentLayoutID] startSpeakingString:self.announceText.stringValue];
}

-(void)setValues {
    self.currentLayout.stringValue = self.currentLayoutName;

    NSString *voiceID = self.settings[[NSString stringWithFormat:@"layouts.%@.voiceID", self.currentLayoutID]];
    if( voiceID != nil ) {
        NSDictionary *voiceProperties = [NSSpeechSynthesizer attributesForVoice:voiceID];
        NSString *voiceName = voiceProperties[NSVoiceName];
        self.voiceName.stringValue = voiceName;
    }
    else {
        self.voiceName.stringValue = @"";
    }
    
    NSString *keyClickName = self.settings[[NSString stringWithFormat:@"layouts.%@.keyClickSound", self.currentLayoutID]];
    if( keyClickName != nil ) {
        self.keyClick.stringValue = [keyClickName lastPathComponent];
    }
    else {
        self.keyClick.stringValue = @"";
    }
    
    NSString* announce = valueOrEmptyString(self.settings[[NSString stringWithFormat:@"layouts.%@.announce", self.currentLayoutID]]);
    
    self.announceText.stringValue=announce;
    
    if( self.settings[@"nsbeep"] != nil ) {
        [self.flashScreenOnChange setState:NSOnState];
    }
    else {
        [self.flashScreenOnChange setState:NSOffState];
    }
    
    if( self.settings[@"splash"] != nil ) {
        [self.showSplashScreen setState:NSOnState];
    }
    else {
        [self.showSplashScreen setState:NSOffState];
    }
    
    [self updateEnvironment];
}

-(void)updateEnvironment {
    self.speechSynth = [NSMutableDictionary dictionaryWithCapacity:10];
    self.sounds = [NSMutableDictionary dictionaryWithCapacity:10];
    
    CFArrayRef inputSourcesList = TISCreateInputSourceList(NULL, false);
    CFIndex inputSourcesCount = CFArrayGetCount(inputSourcesList);
    
    self.listOfLayouts = [[NSMenu alloc] init];
    for( int i=0; i < inputSourcesCount; i++ ) {
        NSString *inputSourceID = (__bridge NSString*)TISGetInputSourceProperty((TISInputSourceRef)CFArrayGetValueAtIndex(inputSourcesList, i),kTISPropertyInputSourceID);
        NSString *voiceID = self.settings[[NSString stringWithFormat:@"layouts.%@.voiceID", inputSourceID]];
        if( voiceID != nil ) {
            NSSpeechSynthesizer *synth =[[NSSpeechSynthesizer alloc] initWithVoice:voiceID];
            [synth setVolume:0.4];
            self.speechSynth[inputSourceID]=synth;
        }
        NSString *keyClickName = self.settings[[NSString stringWithFormat:@"layouts.%@.keyClickSound", inputSourceID]];
        if( keyClickName != nil ) {
            self.sounds[inputSourceID]=[[NSSound alloc] initWithContentsOfFile:keyClickName byReference:NO];
        }
    }
}

- (void)quitApp:(id)sender {
    // Give speech a moment to start before quitting
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[NSApplication sharedApplication] terminate:self];
    });
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    TISInputSourceRef inputSource = TISCopyCurrentKeyboardInputSource();
    NSString *inputSourceID = (__bridge NSString*)TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID);
    self.currentLayoutID = inputSourceID;
    self.currentLayoutName = (__bridge NSString*)TISGetInputSourceProperty(inputSource, kTISPropertyLocalizedName);
    [self loadDictionaryFromPreferences];
    [self setValues];
    
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
        NSSound *keyClick = self.sounds[inputSourceID];
        if( keyClick != nil ) {
            [keyClick stop];
            [keyClick play];
        }

        if( eventModifier==0 || eventModifier==NSEventModifierFlagShift ) {
            double currentTime = CACurrentMediaTime();
            if( fabs(self.lastAnnounce-currentTime) > 10.0 ) {
                [self announce];
            }
            self.lastAnnounce = currentTime;
        }
    }];
    
    if( self.settings[@"splash"] != nil ) {
        [self.window setOpaque:NO];
        [self.window setBackgroundColor: [NSColor clearColor]];
        [self.window setLevel:kCGMaximumWindowLevel];
        [self.window makeKeyAndOrderFront:self];
        
        [self.window performSelector:@selector(close) withObject:nil afterDelay:3];
        
        for( NSSpeechSynthesizer *synth in self.speechSynth ) {
            [self.speechSynth[synth] startSpeakingString:@"Key Say"];
        }
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Clean up status item
    if (self.statusItem) {
        [[NSStatusBar systemStatusBar] removeStatusItem:self.statusItem];
    }
}

@end
