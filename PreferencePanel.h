/* PreferencePanel */

#import <Cocoa/Cocoa.h>

@interface PreferencePanel : NSResponder
{
    IBOutlet id background;
    IBOutlet id col;
    IBOutlet id encoding;
    IBOutlet id fontExample;
    IBOutlet id nafontExample;
    IBOutlet id foreground;
    IBOutlet id prefPanel;
    IBOutlet id row;
    IBOutlet id shell;
    IBOutlet id terminal;
    IBOutlet id transparency;
    
    NSUserDefaults *prefs;

    NSColor* defaultBackground;
    NSColor* defaultForeground;

    int defaultCol;
    int defaultRow;
    
    NSStringEncoding defaultEncoding;
    NSString* defaultShell;
    NSString* defaultTerminal;
    
    NSFont* defaultFont;
    NSFont* defaultNAFont;
    float defaultTransparency;

    BOOL changingNA;

}

+ (void)initialize;

- (id)init;
- (void)dealloc;

- (IBAction)changeBackground:(id)sender;
- (IBAction)changeFontButton:(id)sender;
- (IBAction)changeNAFontButton:(id)sender;
- (IBAction)changeForeground:(id)sender;
- (IBAction)ok:(id)sender;
- (IBAction)restore:(id)sender;
- (void)changeFont:(id)fontManager;

- (void)run;

- (NSColor*) background;
- (NSColor*) foreground;
- (int) col;
- (int) row;
- (NSStringEncoding) encoding;
- (NSString*) shell;
- (NSString*) terminalType;
- (int) transparency;
- (NSFont*) font;
- (NSFont*) nafont;
- (BOOL) ai;
- (int) aiCode;


@end
