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
    IBOutlet id transparency_control;
    IBOutlet id autoclose;
    IBOutlet id optionKey;
    IBOutlet id antiAlias;
    IBOutlet id copySelection;
    IBOutlet id hideTab;
    IBOutlet id silenceBell;
    IBOutlet id doubleWidth;
    IBOutlet id selectionColor;
    IBOutlet id tabViewType;
    
    NSUserDefaults *prefs;

    NSColor* defaultBackground;
    NSColor* defaultForeground;
    NSColor* defaultSelectionColor;

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
    BOOL defaultCopySelection;
    BOOL defaultHideTab;
    BOOL defaultSilenceBell;
    BOOL changingNA;
    BOOL defaultDoubleWidth;
    int defaultTabViewType;

}

+ (void)initialize;

- (id)init;
- (void)dealloc;

- (void) readPreferences;

- (IBAction)changeBackground:(id)sender;
- (IBAction)changeFontButton:(id)sender;
- (IBAction)changeNAFontButton:(id)sender;
- (IBAction)changeForeground:(id)sender;
- (IBAction)ok:(id)sender;
- (IBAction)cancel:(id)sender;
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
- (BOOL) copySelection;
- (BOOL) hideTab;
- (BOOL) silenceBell;
- (BOOL) doubleWidth;
- (NSColor *) selectionColor;
- (NSTabViewType) tabViewType;


@end
