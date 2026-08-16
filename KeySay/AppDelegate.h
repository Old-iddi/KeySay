//
//  AppDelegate.h
//  KeySay
//

#import <Cocoa/Cocoa.h>
#include <Carbon/Carbon.h>
#include <Foundation/Foundation.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate, NSTextFieldDelegate>
    
@property (strong) IBOutlet NSWindow *settingsWindow;
@property (strong) IBOutlet NSView *settingsView;
@property (strong) IBOutlet NSTextField *currentLayout;
@property (strong) IBOutlet NSTextField *voiceName;
@property (strong) IBOutlet NSTextField *keyClick;
@property (strong) IBOutlet NSTextField *announceText;
@property (strong) IBOutlet NSTextField *versionText;

@property (strong) IBOutlet NSButton *flashScreenOnChange;
@property (strong) IBOutlet NSButton *showSplashScreen;
@property (strong) IBOutlet NSButton *autostart;

@property (strong) IBOutlet NSSlider *speechVol;
@property (strong) IBOutlet NSSlider *soundVol;

@property (strong)  NSMenu *listOfLayouts;
@property (strong)  NSMenu *listOfVoices;
@property (strong)  NSMenu *listOfKeyClicks;

@property (strong)  NSMutableDictionary* settings;
@property (strong)  NSString* currentLayoutID;
@property (strong)  NSString* currentLayoutName;

@property (strong)  NSMutableDictionary* speechSynth;
@property (strong)  NSMutableDictionary* sounds;

@property NSTimeInterval lastAnnounce;
@property(strong) NSStatusItem *statusItem;
@property (weak) IBOutlet NSWindow *window;

@end
