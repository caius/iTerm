/* PreferencePanel */

#import <Cocoa/Cocoa.h>

#define OPT_NORMAL 0
#define OPT_META   1
#define OPT_ESC    2

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
    IBOutlet id autoclose;
    IBOutlet id optionKey;
    IBOutlet id antiAlias;
    
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

    BOOL defaultAutoclose;
    int defaultOption;
    BOOL defaultAntiAlias;

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
- (BOOL) antiAlias;
- (BOOL) ai;
- (int) aiCode;
- (BOOL) autoclose;
- (int) option;	


@end
