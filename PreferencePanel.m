#import "PreferencePanel.h"
#import "NSStringITerm.h"

#define NIB_PATH  @"MainMenu"

static NSColor *BACKGROUND;
static NSColor *FOREGROUND;

static NSString *DEFAULT_FONTNAME = @"Osaka-Mono";
static float     DEFAULT_FONTSIZE = 14;
static NSFont* FONT;

static int   COL   = 80;
static int   ROW   = 25;

static NSString* ENCODING=@"Chinese (GB)";
static NSString* TERM    =@"vt100";
static NSString* SHELL   =@"/bin/bash --login";

static int TRANSPARENCY  =10;

@implementation PreferencePanel

+ (void)initialize
{
    BACKGROUND  = [[NSColor blackColor] retain];
    FOREGROUND  = [[NSColor whiteColor] retain];
    FONT = [[NSFont fontWithName:DEFAULT_FONTNAME
			    size:DEFAULT_FONTSIZE] retain];
}

- (id)init
{
#if DEBUG_OBJALLOC
    NSLog(@"%s(%d):-[PreferencePanel init]", __FILE__, __LINE__);
#endif
    if ((self = [super init]) == nil)
        return nil;

    prefs = [NSUserDefaults standardUserDefaults];

    defaultCol=([prefs integerForKey:@"Col"]?[prefs integerForKey:@"Col"]:COL);
    defaultRow=([prefs integerForKey:@"Row"]?[prefs integerForKey:@"Row"]:ROW);
    defaultTransparency=([prefs integerForKey:@"Transparency"]?[prefs integerForKey:@"Transparency"]:TRANSPARENCY);

    defaultTerminal=[[([prefs objectForKey:@"Terminal"]?[prefs objectForKey:@"Terminal"]:TERM)
                    copy] retain];
    defaultEncoding=[[([prefs objectForKey:@"Encoding"]?[prefs objectForKey:@"Encoding"]:ENCODING)
                    copy] retain];
    defaultShell=[[([prefs objectForKey:@"Shell"]?[prefs objectForKey:@"Shell"]:SHELL)
                 copy] retain];
                    
    defaultForeground=[[([prefs objectForKey:@"Foreground"]?
    [NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"Foreground"]]:FOREGROUND)
                      copy] retain];
    defaultBackground=[[([prefs objectForKey:@"Background"]?
    [NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"Background"]]:BACKGROUND)
                      copy] retain];
    defaultFont=[[([prefs objectForKey:@"Font"]?
    [NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"Font"]]:FONT)
                      copy] retain];
                 
    return self;
}

- (void)dealloc
{
}

- (void)run
{
    [prefPanel center];
    [shell setStringValue:defaultShell];
    [terminal setStringValue:defaultTerminal];
    [encoding setStringValue:defaultEncoding];
    
    [background setColor:defaultBackground];
    [foreground setColor:defaultForeground];
    
    [row setIntValue:defaultRow];
    [col setIntValue:defaultCol];
    [transparency setIntValue:defaultTransparency];
    
    [fontExample setTextColor:defaultForeground];
    [fontExample setBackgroundColor:defaultBackground];
    [fontExample setFont:defaultFont];
    [fontExample setStringValue:[NSString stringWithFormat:@"%@ %g", [defaultFont fontName], [defaultFont pointSize]]];
    
    [NSApp runModalForWindow:prefPanel];
    [prefPanel close];
}

- (IBAction)changeBackground:(id)sender
{
    [fontExample setBackgroundColor:[sender color]];
}

- (IBAction)changeFontButton:(id)sender
{
    [[fontExample window] makeFirstResponder:[fontExample window]];
    [[fontExample window] setDelegate:self];
    [[NSFontManager sharedFontManager] setSelectedFont:defaultFont isMultiple:NO];
    [[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}

- (IBAction)changeForeground:(id)sender
{
    [fontExample setTextColor:[sender color]];
}

- (void)changeFont:(id)fontManager
{
    [defaultFont autorelease];
    defaultFont=[fontManager convertFont:[fontExample font]];
    [fontExample setStringValue:[NSString stringWithFormat:@"%@ %g", [defaultFont fontName], [defaultFont pointSize]]];
    [fontExample setFont:defaultFont];
}

- (IBAction)ok:(id)sender
{
    if ([col intValue]>150||[col intValue]<10||[row intValue]>150||[row intValue]<3) {
        NSRunAlertPanel(NSLocalizedStringFromTable(@"Wrong Input",@"iTerm",@"wrong input"),
                        NSLocalizedStringFromTable(@"Please enter a valid window size",@"iTerm",@"wrong input"),
                        NSLocalizedStringFromTable(@"OK",@"iTerm",@"OK"),
                        nil,nil);
        return;
    }
    
    [defaultBackground autorelease];
    [defaultForeground autorelease];
    
    defaultBackground=[[[background color] copy] retain];
    defaultForeground=[[[foreground color] copy] retain];

    defaultCol=[col intValue];
    defaultRow=[row intValue];
    
    defaultEncoding=[encoding stringValue];
    defaultShell=[shell stringValue];
    defaultTerminal=[terminal stringValue];
    
    defaultTransparency=[transparency intValue];

    [prefs setInteger:defaultCol forKey:@"Col"];
    [prefs setInteger:defaultRow forKey:@"Row"];
    [prefs setObject:defaultTerminal forKey:@"Terminal"];
    [prefs setObject:defaultEncoding forKey:@"Encoding"];
    [prefs setObject:defaultShell forKey:@"Shell"];
    [prefs setInteger:defaultTransparency forKey:@"Transparency"];
               
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultForeground]
              forKey:@"Foreground"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultBackground]
              forKey:@"Background"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultFont]
              forKey:@"Font"];

    [NSApp stopModal];
    [[NSColorPanel sharedColorPanel] close];
    [[NSFontPanel sharedFontPanel] close];

}

- (IBAction)restore:(id)sender
{
    if (defaultBackground) [defaultBackground autorelease];
    if (defaultForeground) [defaultForeground autorelease];
    if (defaultFont) [defaultFont autorelease];
    
    defaultBackground=[[BACKGROUND copy] retain];
    defaultForeground=[[FOREGROUND copy] retain];
    defaultFont=[[FONT copy] retain];

    defaultCol=COL;
    defaultRow=ROW;
    
    defaultEncoding=[[ENCODING copy] retain];
    defaultShell=[[SHELL copy] retain];
    defaultTerminal=[[TERM copy] retain];
    
    defaultTransparency=TRANSPARENCY;

    [shell setStringValue:defaultShell];
    [terminal setStringValue:defaultTerminal];
    [encoding setStringValue:defaultEncoding];
    
    [background setColor:defaultBackground];
    [foreground setColor:defaultForeground];
    
    [row setIntValue:defaultRow];
    [col setIntValue:defaultCol];
    [transparency setIntValue:defaultTransparency];
    
    [fontExample setTextColor:defaultForeground];
    [fontExample setBackgroundColor:defaultBackground];
    [fontExample setFont:defaultFont];
    [fontExample setStringValue:[NSString stringWithFormat:@"%@ %g", [defaultFont fontName], [defaultFont pointSize]]];


}

- (NSColor*) background
{
    return defaultBackground;
}

- (NSColor*) foreground
{
    return defaultForeground;
}

- (int) col
{
    return defaultCol;
}

- (int) row
{
    return defaultRow;
}

- (NSStringEncoding) encoding
{
    NSStringEncoding enc;
if ([defaultEncoding compare:@"Chinese (GB)"]==NSOrderedSame)
        enc=NSStringEUCCNEncoding;
    else if ([defaultEncoding compare:@"Chinese (Big 5)"]==NSOrderedSame)
        enc=NSStringBig5Encoding;
    else //([defaultEncoding compare:@"Unicode"]==NSOrderedSame)
        enc=NSUTF8StringEncoding;
    
    return enc;
}

- (NSString*) shell
{
    return defaultShell;
}

- (NSString*) terminalType
{
    return defaultTerminal;
}

- (int) transparency
{
    return defaultTransparency;
}

- (NSFont*) font
{
    return defaultFont;
}

@end
