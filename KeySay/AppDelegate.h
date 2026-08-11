//
//  AppDelegate.h
//  KeySay
//

#import <Cocoa/Cocoa.h>
#include <Carbon/Carbon.h>
#include <Foundation/Foundation.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
    
@property (strong) IBOutlet NSWindow *settingsWindow;
@property (strong) IBOutlet NSTextField *currentLayout;
@property (strong) IBOutlet NSTextField *voiceName;
@property (strong) IBOutlet NSTextField *keyClick;
@property (strong) IBOutlet NSTextField *announceText;

@property (strong) IBOutlet NSButton *flashScreenOnChange;
@property (strong) IBOutlet NSButton *showSplashScreen;

@property (strong)  NSMenu *listOfLayouts;
@property (strong)  NSMenu *listOfVoices;
@property (strong)  NSMenu *listOfKeyClicks;

@property (strong)  NSMutableDictionary* settings;
@property (strong)  NSString* currentLayoutID;
@property (strong)  NSString* currentLayoutName;

@property (strong)  NSMutableDictionary* speechSynth;
@property (strong)  NSMutableDictionary* sounds;
@end

