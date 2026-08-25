//
//  AppDelegate.m
//  KeySay
//

#import "AppDelegate.h"
#import <ApplicationServices/ApplicationServices.h>
#import <ServiceManagement/ServiceManagement.h>

#import <AVFoundation/AVFoundation.h>
#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>

@interface KeyLoggerManager : NSObject
- (void)startMonitoring;
@property AppDelegate *delegate;
@end

@implementation KeyLoggerManager {
    CFMachPortRef _eventTap;
    CFRunLoopSourceRef _runLoopSource;
}

CGEventRef KeyboardEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    if (type == kCGEventKeyDown) {
 //       CGKeyCode keyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        NSEvent *nsEvent = [NSEvent eventWithCGEvent:event];
        [(__bridge KeyLoggerManager *)refcon eventOccured:nsEvent];
        
    }
    return event;
}

- (void)openInputMonitoringSettings {
    NSString *urlString;

    if (@available(macOS 13.0, *)) {
        // macOS Ventura and later: System Settings
        urlString = @"x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent";
    } else {
        // macOS 10.15–12: System Preferences
        urlString = @"x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent";
    }

    NSURL *url = [NSURL URLWithString:urlString];
    if (url != nil) {
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
    
    [self openFolderContainingApplication];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleInformational;
    alert.messageText = NSLocalizedString(@"Drag app to Input Monitoring", @"");
    alert.informativeText = NSLocalizedString(@"To play sounds when keys are pressed we need permission for Input Monitoring. There is no automatic way to do it. You need to drag and drop KeySay application to opened preference pane and then enable it with switch on the right.", @"");
    [alert addButtonWithTitle:NSLocalizedString(@"Ok", @"")];
    [alert runModal];
}

- (void)openFolderContainingApplication {
    NSURL *appURL = [[NSBundle mainBundle] bundleURL];
    NSURL *containingFolderURL = [appURL URLByDeletingLastPathComponent];

    if (appURL == nil || containingFolderURL == nil) {
        return;
    }
    [[NSWorkspace sharedWorkspace] selectFile:appURL.path
                     inFileViewerRootedAtPath:containingFolderURL.path];
}

- (void)startMonitoring {
    if (@available(macOS 10.15, *)) {
        BOOL hasAccess = CGPreflightListenEventAccess();
        if (!hasAccess) {
            [self openInputMonitoringSettings];
            return;
        }
    }

    CGEventMask eventMask = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp);
    _eventTap = CGEventTapCreate(
        kCGSessionEventTap,
        kCGHeadInsertEventTap,
        kCGEventTapOptionListenOnly,
        eventMask,
        KeyboardEventCallback,
        (__bridge void *)self
    );

    _runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), _runLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(_eventTap, true);
}

-(void)eventOccured:(NSEvent*)event {
    [self.delegate eventOccured:event];
}

- (void)dealloc {
    if (_runLoopSource) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), _runLoopSource, kCFRunLoopCommonModes);
        CFRelease(_runLoopSource);
    }
    if (_eventTap) {
        CFMachPortInvalidate(_eventTap);
        CFRelease(_eventTap);
    }
}

@end


extern const CFStringRef kTISNotifySelectedKeyboardInputSourceChanged;

NSString* valueOrEmptyString(NSString *value) { return ((value)==0)?(@""):(value); }
int valueOr( NSString *value, int defaultValue ) { return ((value)==0)?(defaultValue):(value.intValue); }

@interface AppDelegate ()
@property (nonatomic, strong) NSTimer *accessibilityTimer;
@property (strong) KeyLoggerManager *klmanager;
@property (nonatomic) BOOL didShowInitialSettingsWindow;
- (AVSpeechSynthesisVoice *)voiceForIdentifier:(NSString *)identifier;
- (void)speakText:(NSString *)text forLayoutID:(NSString *)layoutID;
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
        [self speakText:announce forLayoutID:inputSourceID];
        self.lastAnnounce = CACurrentMediaTime();
    }
    if( self.settings[@"nsbeep"] != nil ) {
        NSBeep();
    }
}

- (void)restartApplication:(id)sender {
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *command = [NSString stringWithFormat:@"sleep 1; open \"%@\"", bundlePath];
    [NSTask launchedTaskWithLaunchPath:@"/bin/sh" arguments:@[@"-c", command]];
    [NSApp terminate:nil];
}

- (void)setupStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:24.0];

    NSMenu *menu = [[NSMenu alloc] init];

    NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Settings...", @"")
                                                          action:@selector(openSettings:)
                                                   keyEquivalent:@""];
    [settingsItem setTarget:self];
    [menu addItem:settingsItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Quit", @"")
                                                      action:@selector(quitApp:)
                                               keyEquivalent:@""];
    [quitItem setTarget:self];
    [menu addItem:quitItem];
    
    [self.statusItem setMenu:menu];
    
    NSImage *icon = [NSImage imageNamed:@"24@2x.png"];
    [self.statusItem.button setImage:icon];
    
    [self.statusItem.button setToolTip:NSLocalizedString(@"KeySay", @"")];
}

- (void)saveDictionaryToPreferences {
    [self announceSave];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.settings forKey:@"KeySay_0.1"];
}

- (void)loadDictionaryFromPreferences {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.settings = [[defaults dictionaryForKey:@"KeySay_0.1"] mutableCopy];
    if( self.settings == nil ) {
        self.settings = [NSMutableDictionary dictionaryWithCapacity:30];
        self.settings[@"splash"]=@"YES";
        self.settings[@"nsbeep"]=@"YES";
    }
}

- (void)openSettings:(id)sender {
    [self.settingsWindow makeKeyAndOrderFront:self];
    [self.settingsWindow setLevel:kCGMaximumWindowLevel];
    [self updateAutostartState];
    // Do not give the text field/editor first responder status when opening.
    [self.settingsWindow makeFirstResponder:nil];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (control == self.announceText && commandSelector == @selector(insertNewline:)) {
        [self.settingsWindow makeFirstResponder:nil];
        [self announceChanged:nil];
        return YES;
    }
    return NO;
}

-(IBAction)flashScreenSet:(id)sender {
    if( self.flashScreenOnChange.state == NSControlStateValueOn ) {
        self.settings[@"nsbeep"]=@"YES";
    }
    else {
        [self.settings removeObjectForKey:@"nsbeep"];
    }
    [self saveDictionaryToPreferences];
    [self setValues];
}

-(IBAction)showSplashScreenSet:(id)sender {
    if( self.showSplashScreen.state == NSControlStateValueOn ) {
        self.settings[@"splash"]=@"YES";
    }
    else {
        [self.settings removeObjectForKey:@"splash"];
    }
    [self saveDictionaryToPreferences];
    [self setValues];
}

-(IBAction)autostartSet:(id)sender {
    if( self.autostart.state == NSControlStateValueOn ) {
        [self addToLoginItems];
    }
    else {
        [self removeFromLoginItems];
    }
}

-(IBAction)speechVolChanged:(id)sender {
    self.settings[[NSString stringWithFormat:@"layouts.%@.announceVol", self.currentLayoutID]]=self.speechVol.stringValue;
    [self saveDictionaryToPreferences];
    [self setValues];
    
    NSString *announce = self.settings[[NSString stringWithFormat:@"layouts.%@.announce", self.currentLayoutID]];
    if( announce != nil ) {
        [self speakText:announce forLayoutID:self.currentLayoutID];
    }
}

-(IBAction)soundVolChanged:(id)sender {
    self.settings[[NSString stringWithFormat:@"layouts.%@.keyclickVol", self.currentLayoutID]]=self.soundVol.stringValue;
    [self saveDictionaryToPreferences];
    [self setValues];
    
    [self playSound:nil];
}

-(IBAction)announceChanged:(id)sender {
    [self.settingsWindow makeFirstResponder:nil];
    [self saveDictionaryToPreferences];
    [self setValues];
}

-(void)announceSave {
    self.settings[[NSString stringWithFormat:@"layouts.%@.announce", self.currentLayoutID]]=self.announceText.stringValue;
}

-(IBAction)chooseClickSound:(id)sender {
    self.listOfKeyClicks = [[NSMenu alloc] init];
    
    NSString *currentSound = self.settings[[NSString stringWithFormat:@"layouts.%@.keyClickSound", self.currentLayoutID]];
    
    NSMenuItem *emptyItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Quiet", @"")
                                                          action:@selector(selectClickSound:)
                                                   keyEquivalent:@""];
    emptyItem.representedObject = nil;
    emptyItem.target = self;
    emptyItem.state = (currentSound == nil) ? NSControlStateValueOn : NSControlStateValueOff;
    [self.listOfKeyClicks addItem:emptyItem];
    [self.listOfKeyClicks addItem:[NSMenuItem separatorItem]];

    NSArray *sounds = [[NSBundle mainBundle] pathsForResourcesOfType:@"riff" inDirectory:nil];
    NSArray *sortedSounds = [sounds sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSString *one = obj1;
        NSString *two = obj2;
        return [one compare:two options:NSNumericSearch];
    }];
    
    int item = 0;
    
    for( NSString *sound in sortedSounds ) {
        NSString *soundName = [[sound lastPathComponent] stringByDeletingPathExtension];
        NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:soundName
                                                              action:@selector(selectClickSound:)
                                                       keyEquivalent:@""];
        settingsItem.representedObject = [[sound lastPathComponent] stringByDeletingPathExtension];
        settingsItem.target = self;
        
        if( [soundName isEqualToString:currentSound] ) {
            settingsItem.state = NSControlStateValueOn;
            item = (int)[sortedSounds indexOfObject:sound]+2;
        }
        else {
            settingsItem.state = NSControlStateValueOff;
        }
        
        [self.listOfKeyClicks addItem:settingsItem];
    }
    [self.listOfKeyClicks popUpMenuPositioningItem:[self.listOfKeyClicks itemAtIndex:item] atLocation:CGPointMake(0, 0) inView:sender];
}

-(IBAction)selectClickSound:(id)sender {
    NSMenuItem *sourceMenuItem = (NSMenuItem*)sender;
    if( sourceMenuItem.representedObject != nil ) {
        self.keyClick.stringValue = (NSString*)sourceMenuItem.representedObject;
        self.settings[[NSString stringWithFormat:@"layouts.%@.keyClickSound", self.currentLayoutID]]=(NSString*)sourceMenuItem.representedObject;
    }
    else {
        self.keyClick.stringValue = @"";
        [self.settings removeObjectForKey:[NSString stringWithFormat:@"layouts.%@.keyClickSound", self.currentLayoutID]];
    }
    [self saveDictionaryToPreferences];
    [self setValues];
    [self playSound:nil];
}

-(IBAction)chooseVoice:(id)sender {
    
    [(AVSpeechSynthesizer *)self.speechSynth[self.currentLayoutID] stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];

    self.listOfVoices = [[NSMenu alloc] init];
    
    NSString *currentVoiceID = self.settings[[NSString stringWithFormat:@"layouts.%@.voiceID", self.currentLayoutID]];
    
    NSMenuItem *emptyItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"No Voice", @"")
                                                          action:@selector(selectVoice:)
                                                   keyEquivalent:@""];
    emptyItem.representedObject = nil;
    emptyItem.target = self;
    emptyItem.state = (currentVoiceID == nil) ? NSControlStateValueOn : NSControlStateValueOff;
    [self.listOfVoices addItem:emptyItem];
    [self.listOfVoices addItem:[NSMenuItem separatorItem]];
    
    NSArray *voices = [AVSpeechSynthesisVoice speechVoices];

    int item = 0;

    for( AVSpeechSynthesisVoice *voice in voices ) {
        NSString *voiceID = voice.identifier;
        NSString *voiceName = voice.name;
        
        NSString *language = voice.language;
        NSLocale *currentLocale = [NSLocale currentLocale];
        NSString *langName = [currentLocale localizedStringForLanguageCode:language];
     
        voiceName = [[voiceName stringByAppendingString:@" - "] stringByAppendingString:langName];
        
        NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:voiceName
                                                              action:@selector(selectVoice:)
                                                       keyEquivalent:@""];
        settingsItem.representedObject = voiceID;
        settingsItem.target = self;
 
        if( [voiceID isEqualToString:currentVoiceID] ) {
            settingsItem.state = NSControlStateValueOn;
            item = (int)[voices indexOfObject:voice]+2;
        }
        else {
            settingsItem.state = NSControlStateValueOff;
        }
        
        [self.listOfVoices addItem:settingsItem];
    }
    [self.listOfVoices popUpMenuPositioningItem:[self.listOfVoices itemAtIndex:item] atLocation:CGPointMake(0, 0) inView:sender];
}

-(IBAction)selectVoice:(id)sender {

    NSMenuItem *sourceMenuItem = (NSMenuItem*)sender;
    if( sourceMenuItem.representedObject != nil ) {
        AVSpeechSynthesisVoice *voice = [self voiceForIdentifier:(NSString*)sourceMenuItem.representedObject];
        NSString *voiceName = voice.name;
        self.voiceName.stringValue = voiceName;
        self.settings[[NSString stringWithFormat:@"layouts.%@.voiceID", self.currentLayoutID]]=(NSString*)sourceMenuItem.representedObject;
    }
    else {
        self.voiceName.stringValue = @"";
        [self.settings removeObjectForKey:[NSString stringWithFormat:@"layouts.%@.voiceID", self.currentLayoutID]];
    }
    [self saveDictionaryToPreferences];
    [self setValues];
    
    NSString *announce = self.settings[[NSString stringWithFormat:@"layouts.%@.announce", self.currentLayoutID]];
    if( announce != nil ) {
        [self speakText:announce forLayoutID:self.currentLayoutID];
        self.lastAnnounce = CACurrentMediaTime();
    }
}

-(IBAction)chooseLayout:(id)sender {
    CFArrayRef inputSourcesList = TISCreateInputSourceList(NULL, false);
    CFIndex inputSourcesCount = CFArrayGetCount(inputSourcesList);
    
    int item = 0;
    
    self.listOfLayouts = [[NSMenu alloc] init];
    for( int i=0, j=0; i < inputSourcesCount; i++ ) {
        TISInputSourceRef inputSource = (TISInputSourceRef)CFArrayGetValueAtIndex(inputSourcesList, i);
        NSString *inputSourceName = (__bridge NSString*)TISGetInputSourceProperty(inputSource, kTISPropertyLocalizedName);
        NSString *sourceType =(__bridge NSString*)TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceType);
        NSString *inputSourceID = (__bridge NSString*)TISGetInputSourceProperty(inputSource,kTISPropertyInputSourceID);
        if( [sourceType isEqualToString:(NSString*)kTISTypeKeyboardLayout] ) {
            NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:inputSourceName
                                                                  action:@selector(selectLayout:)
                                                           keyEquivalent:@""];
            settingsItem.representedObject = (__bridge id _Nullable)inputSource;
            settingsItem.target = self;
            [self.listOfLayouts addItem:settingsItem];
            
            if( [inputSourceID isEqualToString:self.currentLayoutID] ) {
                item = j;
            }
            j++;
        }
    }
    [self announceSave];

    [self.listOfLayouts popUpMenuPositioningItem:[self.listOfLayouts itemAtIndex:item] atLocation:CGPointMake(0, 0) inView:sender];
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
}

-(IBAction)playSound:(id)sender {
    NSSound *keyClick = self.sounds[self.currentLayoutID];

    [keyClick stop];
    [keyClick play];
}

-(IBAction)speak:(id)sender {
    [self speakText:self.announceText.stringValue forLayoutID:self.currentLayoutID];
}

-(void)setValues {
    self.currentLayout.stringValue = self.currentLayoutName;

    NSString *voiceID = self.settings[[NSString stringWithFormat:@"layouts.%@.voiceID", self.currentLayoutID]];
    if( voiceID != nil ) {
        AVSpeechSynthesisVoice *voice = [self voiceForIdentifier:voiceID];
        if( voice != nil ) {
            self.voiceName.stringValue = voice.name;
        }
        else {
            self.voiceName.stringValue = @"";
        }
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
        [self.flashScreenOnChange setState:NSControlStateValueOn];
    }
    else {
        [self.flashScreenOnChange setState:NSControlStateValueOff];
    }
    
    if( self.settings[@"splash"] != nil ) {
        [self.showSplashScreen setState:NSControlStateValueOn];
    }
    else {
        [self.showSplashScreen setState:NSControlStateValueOff];
    }
    
    NSString *speechVolString = self.settings[[NSString stringWithFormat:@"layouts.%@.announceVol", self.currentLayoutID]];
    self.speechVol.intValue = valueOr(speechVolString,50);
    
    NSString *soundVolString = self.settings[[NSString stringWithFormat:@"layouts.%@.keyclickVol", self.currentLayoutID]];
    self.soundVol.intValue = valueOr(soundVolString,50);
    
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
            self.speechSynth[inputSourceID] = [[AVSpeechSynthesizer alloc] init];
        }
        NSString *keyClickName = self.settings[[NSString stringWithFormat:@"layouts.%@.keyClickSound", inputSourceID]];
        if( keyClickName != nil ) {
            NSString *soundPath = [[NSBundle mainBundle] pathForResource:keyClickName ofType:@"riff"];
            if( soundPath == nil ) {
                soundPath = [[NSBundle mainBundle] pathForResource:[[keyClickName lastPathComponent] stringByDeletingPathExtension] ofType:@"riff"];
            }
            if( soundPath != nil ) self.sounds[inputSourceID]=[[NSSound alloc] initWithContentsOfFile:soundPath byReference:NO];
            NSString *soundVolString = self.settings[[NSString stringWithFormat:@"layouts.%@.keyclickVol", inputSourceID]];
            double vol = valueOr(soundVolString,50)/100.0;
            [self.sounds[inputSourceID] setVolume:vol];
        }
    }
}

- (AVSpeechSynthesisVoice *)voiceForIdentifier:(NSString *)identifier {
    if( identifier == nil ) {
        return nil;
    }
    return [AVSpeechSynthesisVoice voiceWithIdentifier:identifier];
}

- (void)speakText:(NSString *)text forLayoutID:(NSString *)layoutID {
    AVSpeechSynthesizer *synth = self.speechSynth[layoutID];
    if( synth == nil ) {
        return;
    }

    NSString *voiceID = self.settings[[NSString stringWithFormat:@"layouts.%@.voiceID", layoutID]];
    NSString *speechVolString = self.settings[[NSString stringWithFormat:@"layouts.%@.announceVol", layoutID]];

    AVSpeechUtterance *utterance = [[AVSpeechUtterance alloc] initWithString:text];
    utterance.voice = [self voiceForIdentifier:voiceID];
    utterance.volume = valueOr(speechVolString,50)/100.0;

    [synth stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    [synth speakUtterance:utterance];
}

- (void)quitApp:(id)sender {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[NSApplication sharedApplication] terminate:self];
    });
}

- (void)addToLoginItems {
    if (@available(macOS 13.0, *)) {
        SMAppService *service = [SMAppService mainAppService];
        NSError *error = nil;
        if (![service registerAndReturnError:&error]) {
            NSLog(@"Failed to add login item: %@", error.localizedDescription);
        }
    } else {
        // Fallback for older macOS
        LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
        if (!loginItems) return;

        NSURL *appURL = [NSBundle mainBundle].bundleURL;
        LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemLast, NULL, NULL, (__bridge CFURLRef)appURL, NULL, NULL);
        if (item) CFRelease(item);
        CFRelease(loginItems);
    }
}

- (void)removeFromLoginItems {
    if (@available(macOS 13.0, *)) {
        SMAppService *service = [SMAppService mainAppService];
        NSError *error = nil;
        if (![service unregisterAndReturnError:&error]) {
            NSLog(@"Failed to remove login item: %@", error.localizedDescription);
        }
    } else {
        // Fallback for older macOS
        LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
        if (!loginItems) return;

        NSURL *appURL = [NSBundle mainBundle].bundleURL;
        UInt32 seedValue;
        NSArray *list = (__bridge_transfer NSArray *)LSSharedFileListCopySnapshot(loginItems, &seedValue);
        for (id itemRef in list) {
            LSSharedFileListItemRef item = (__bridge LSSharedFileListItemRef)itemRef;
            CFURLRef itemURL = NULL;
            if (LSSharedFileListItemResolve(item, 0, &itemURL, NULL) == noErr && itemURL) {
                if ([(__bridge NSURL *)itemURL isEqual:appURL]) {
                    LSSharedFileListItemRemove(loginItems, item);
                    CFRelease(itemURL);
                    break;
                }
                CFRelease(itemURL);
            }
        }
        CFRelease(loginItems);
    }
}

- (BOOL)isInLoginItems {
    if (@available(macOS 13.0, *)) {
        return [SMAppService mainAppService].status == SMAppServiceStatusEnabled;
    }

    // Fallback for older macOS
    LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (!loginItems) return NO;

    NSURL *appURL = [NSBundle mainBundle].bundleURL;
    UInt32 seedValue;
    NSArray *list = (__bridge_transfer NSArray *)LSSharedFileListCopySnapshot(loginItems, &seedValue);
    BOOL found = NO;

    for (id itemRef in list) {
        LSSharedFileListItemRef item = (__bridge LSSharedFileListItemRef)itemRef;
        CFURLRef itemURL = NULL;

        if (LSSharedFileListItemResolve(item, 0, &itemURL, NULL) == noErr && itemURL) {
            if ([(__bridge NSURL *)itemURL isEqual:appURL]) {
                found = YES;
                CFRelease(itemURL);
                break;
            }
            CFRelease(itemURL);
        }
    }
    CFRelease(loginItems);
    return found;
}

- (void)updateAutostartState {
    BOOL inLoginItems = [self isInLoginItems];
    [self.autostart setState:(inLoginItems ? NSControlStateValueOn : NSControlStateValueOff)];
}

-(void)eventOccured:(NSEvent*)event {
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
}

-(void)startKeylogger {
    self.klmanager = [[KeyLoggerManager alloc] init];
    self.klmanager.delegate = self;
    [self.klmanager startMonitoring];
}

- (void)showInitialSettingsWindowIfNeeded {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (self.didShowInitialSettingsWindow) {
        return;
    }

    if ([defaults boolForKey:@"KeySay_0.1_InitialSettingsShown"]) {
        self.didShowInitialSettingsWindow = YES;
        return;
    }

    if ([defaults dictionaryForKey:@"KeySay_0.1"] != nil) {
        return;
    }

    // If Input Monitoring permission still needs user action, let that flow
    // present its own system settings/alert instead of also showing this window.
    if (@available(macOS 10.15, *)) {
        if (!CGPreflightListenEventAccess()) {
            return;
        }
    }

    self.didShowInitialSettingsWindow = YES;
    [defaults setBool:YES forKey:@"KeySay_0.1_InitialSettingsShown"];
    [self openSettings:self];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    TISInputSourceRef inputSource = TISCopyCurrentKeyboardInputSource();
    NSString *inputSourceID = (__bridge NSString*)TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID);
    self.currentLayoutID = inputSourceID;
    self.currentLayoutName = (__bridge NSString*)TISGetInputSourceProperty(inputSource, kTISPropertyLocalizedName);
    [self loadDictionaryFromPreferences];
    [self setValues];

    self.announceText.delegate = self;
    self.announceText.target = self;
    self.announceText.action = @selector(announceChanged:);
    
    [self setupStatusItem];
    
    NSString *shortVersionString = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if( shortVersionString == nil ) {
        shortVersionString = NSLocalizedString(@"n/a", @"");
    }
    NSString *longVersionString = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
    if( longVersionString == nil ) {
        longVersionString = NSLocalizedString(@"n/a", @"");
    }
    NSString *copyright =[NSBundle.mainBundle objectForInfoDictionaryKey:@"NSHumanReadableCopyright"];
    if( copyright == nil ) {
        copyright = NSLocalizedString(@"n/a", @"");
    }
    self.versionText.stringValue = [NSString stringWithFormat:NSLocalizedString(@"v%@ (%@)\n%@", @""), shortVersionString, longVersionString, copyright];

    CFNotificationCenterAddObserver(CFNotificationCenterGetDistributedCenter(),
                                    (__bridge void*)self, theKeyboardChanged,
        kTISNotifySelectedKeyboardInputSourceChanged, NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately);
        
    if( self.settings[@"splash"] != nil ) {
        [self.window setOpaque:NO];
        [self.window setBackgroundColor: [NSColor clearColor]];
        [self.window setLevel:kCGMaximumWindowLevel];
        [self.window makeKeyAndOrderFront:self];
        
        [self.window performSelector:@selector(close) withObject:nil afterDelay:3];
        
        [self performSelector:@selector(startKeylogger) withObject:nil afterDelay:3.5];
        
        for( NSString *layoutID in self.speechSynth ) {
            [self speakText:NSLocalizedString(@"Key Say", @"") forLayoutID:layoutID];
        }
    } else {
        [self performSelector:@selector(startKeylogger) withObject:nil afterDelay:3.5];
    }

    [self showInitialSettingsWindowIfNeeded];

    if( @available( macOS 26, *) ) {
        [self.settingsWindow setOpaque:NO];
        NSRect frame = self.settingsWindow.frame;
        frame.origin.x = 0;
        frame.origin.y = 0;
        NSGlassEffectView *gev = [[NSGlassEffectView alloc] initWithFrame:frame];
        [self.settingsView addSubview:gev positioned:NSWindowBelow relativeTo:nil];
        [self.settingsWindow setBackgroundColor:[NSColor clearColor]];
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self.accessibilityTimer invalidate];
    self.accessibilityTimer = nil;
    if (self.statusItem) {
        [[NSStatusBar systemStatusBar] removeStatusItem:self.statusItem];
    }
}

@end
