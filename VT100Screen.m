// -*- mode:objc -*-
// $Id: VT100Screen.m,v 1.7 2002-12-20 18:21:47 yfabian Exp $
//
//  VT100Screen.m
//  JTerminal
//
//  Created by kuma on Thu Jan 24 2002.
//  Copyright (c) 2001 Kiichi Kusama. All rights reserved.
//

// Debug option
#define DEBUG_ALLOC           0
#define DEBUG_METHOD_TRACE    0

#import "VT100Screen.h"
#import "NSStringITerm.h"
#import "PseudoTerminal.h"

@implementation VT100Screen

#define DEFAULT_WIDTH     80
#define DEFAULT_HEIGHT    25
#define DEFAULT_FONTNAME  @"Osaka-Mono"
#define DEFAULT_FONTSIZE  14
#define DEFAULT_LINELIMIT 1000000

#define MIN_WIDTH     10
#define MIN_HEIGHT    3

#define TABSIZE     8

#define WIDTH_REAL   (WIDTH + 1)

#define ISDOUBLEWIDTHCHARACTER(c) ((c)>=0x1000)

static NSString *NSReversedAttributeName=@"NSReversedAttributeName";
static NSString *NSBlinkAttributeName=@"NSBlinkAttributeName";
static NSString *NSBlinkColorAttributeName=@"NSBlinkColorAttributeName";

static BOOL PLAYBELL = YES;

+ (NSSize) fontSize:(NSFont *)font
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):+[VT100Screen fontSize:%@]",
          __FILE__, __LINE__, font);
#endif
    
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    NSSize sz;
    [dic setObject:font forKey:NSFontAttributeName];
    sz = [@"A" sizeWithAttributes:dic];

    return NSMakeSize(sz.width,[font defaultLineHeightForFont]);
}

+ (NSSize)requireSizeWithFont:(NSFont *)font
			width:(int)width
		       height:(int)height
{
    NSSize sz;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):+[VT100Screen requireSizeWithFont:%@ width:%d height:%d]",
	  __FILE__, __LINE__, font, width, height);
#endif    
    sz = [VT100Screen fontSize:font];
//    NSLog(@"--------fontsize:%f,%f",sz.width,sz.height);
    return NSMakeSize(sz.width * (width +2), sz.height * (height+1));
}

+ (NSSize)requireSizeWithFont:(NSFont *)font
{
    NSSize sz;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):+[VT100Screen requireSizeWithFont:%@]",
	  __FILE__, __LINE__, font);
#endif
    sz = [VT100Screen fontSize:font];

    return sz;
}

+ (NSSize)screenSizeInFrame:(NSRect)frame
		       font:(NSFont *)font
{
    NSSize sz;
    int w, h;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):+[VT100Screen screenSizeInFrame:(%f,%f,%f,%f) font:%@]",
	  __FILE__, __LINE__, 
	  frame.origin.x, frame.origin.y,
	  frame.size.width, frame.size.height,
	  font);
#endif
    sz = [VT100Screen fontSize:font];

    w = (int)(frame.size.width / sz.width + 0.5) - 2;
    h = (int)(frame.size.height / sz.height + 0.5)-1 ;

    return NSMakeSize(w, h);
}

+ (void)setPlayBellFlag:(BOOL)flag
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):+[VT100Screen setPlayBellFlag:%s]",
	  __FILE__, __LINE__, flag == YES ? "YES" : "NO");
#endif
    PLAYBELL = flag;
}

- (id)init
{
#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[VT100Screen init]", __FILE__, __LINE__);
#endif
    if ((self = [super init]) == nil)
	return nil;

    WIDTH = DEFAULT_WIDTH;
    HEIGHT = DEFAULT_HEIGHT;

    CURSOR_X = CURSOR_Y = 0;
    SAVE_CURSOR_X = SAVE_CURSOR_Y = 0;
    SCROLL_TOP = 0;
    SCROLL_BOTTOM = HEIGHT - 1;

    STORAGE = nil;
    FONT = [[NSFont fontWithName:DEFAULT_FONTNAME
			    size:DEFAULT_FONTSIZE]
	       retain];
    TERMINAL = nil;
    SHELL = nil;

    TOP_LINE  = 0;
    LINE_LIMIT = DEFAULT_LINELIMIT;
    OLD_CURSOR_INDEX=-1;
    [self clearTabStop];
    
    return self;
}

- (void)dealloc
{
#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[VT100Screen dealloc]", __FILE__, __LINE__);
#endif

    [FONT release];

    [super dealloc];
}

- (NSString *)description
{
    NSString *basestr;
    NSString *colstr;
    NSString *result;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen description]", __FILE__, __LINE__);
#endif
    basestr = [NSString stringWithFormat:@"WIDTH %d, HEIGHT %d, CURSOR (%d,%d)",
		   WIDTH, HEIGHT, CURSOR_X, CURSOR_Y];
    colstr = [STORAGE string];
    result = [NSString stringWithFormat:@"%@\n%@", basestr, colstr];

    return result;
}

- (void)setWidth:(int)width height:(int)height
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen resizeWidth:%d height:%d]",
          __FILE__, __LINE__, width, height);
#endif

    if (width >= MIN_WIDTH && height >= MIN_HEIGHT) {

        WIDTH = width;
        HEIGHT = height;


        CURSOR_X = CURSOR_Y = 0;
        SAVE_CURSOR_X = SAVE_CURSOR_Y = 0;
        SCROLL_TOP = 0;
        SCROLL_BOTTOM = HEIGHT - 1;

    }
}

- (void)resizeWidth:(int)width height:(int)height
{
    int i,j;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen resizeWidth:%d height:%d]",
	  __FILE__, __LINE__, width, height);
#endif

    if (width >= MIN_WIDTH && height >= MIN_HEIGHT) {
        int idx;

        if (width>=WIDTH) {
            if (height>=HEIGHT) {
                for(i=HEIGHT;i<height;i++)
                    [STORAGE appendAttributedString:[[NSAttributedString alloc] initWithAttributedString:[self attrString:[self fullLine]]]];
            }
            else {
                TOP_LINE+=HEIGHT-height;
                CURSOR_Y-=HEIGHT-height;
                if (CURSOR_Y<0) CURSOR_Y=0;
                SAVE_CURSOR_Y-=HEIGHT-height;
                if (SAVE_CURSOR_Y<0) SAVE_CURSOR_Y=0;

            }

            HEIGHT=height;
            idx=[self getIndex:0 y:0];
            for(i=0;i<height;i++) {
                idx=[self getIndex:WIDTH-1 y:i];
                for(j=0;j<width-WIDTH;j++)
                    [STORAGE insertAttributedString:[self attrStringFromChar:' '] atIndex:idx];
            }
            WIDTH=width;
            SCROLL_TOP = 0;
            SCROLL_BOTTOM = HEIGHT - 1;
        }
        else {
            TOP_LINE+=HEIGHT;
            WIDTH = width;
            HEIGHT = height;

            CURSOR_X = CURSOR_Y = 0;
            SAVE_CURSOR_X = SAVE_CURSOR_Y = 0;
            SCROLL_TOP = 0;
            SCROLL_BOTTOM = HEIGHT - 1;


            [self initScreen];
        }
    }
}

- (int)width
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen width]", __FILE__, __LINE__);
#endif
    return WIDTH;
}

- (int)height
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen height]", __FILE__, __LINE__);
#endif
    return HEIGHT;
}

- (NSWindow*) window
{
    return WINDOW;
}

- (void)setWindow:(NSWindow*)window
{
    WINDOW=window;
}

- (void)setSession:(PTYSession *)session
{
    SESSION=session;
}

- (void)setTerminal:(VT100Terminal *)terminal
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setTerminal:%@]",
	  __FILE__, __LINE__, terminal);
#endif
    TERMINAL = terminal;
    [TERMINAL setScreen: self];
}

- (VT100Terminal *)terminal
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen terminal]", __FILE__, __LINE__);
#endif
    return TERMINAL;
}

- (void)setShellTask:(PTYTask *)shell
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setShellTask:%@]",
	  __FILE__, __LINE__, shell);
#endif
    SHELL = shell;
}

- (PTYTask *)shellTask
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen shellTask]", __FILE__, __LINE__);
#endif
    return SHELL;
}

- (void)setTextStorage:(NSTextStorage *)storage
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setTextStorage:%@]",
	  __FILE__, __LINE__, storage);
#endif
    STORAGE = storage;
}

- (NSTextStorage *)textStorage
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen textStorage]", __FILE__, __LINE__ );
#endif
    return STORAGE;
}


-(void) initScreen
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen initScreen]", __FILE__, __LINE__ );
#endif

    int i;

    for(i=0;i<HEIGHT;i++) [STORAGE appendAttributedString:[[NSAttributedString alloc] initWithAttributedString:[self attrString:[self fullLine]]]];
}
    
- (void)beginEditing
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen beginEditing]", __FILE__, __LINE__ );
#endif
    [STORAGE beginEditing];
}

- (void)endEditing
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen endEditing]", __FILE__, __LINE__ );
#endif
    [STORAGE endEditing];
}

- (void)setFont:(NSFont *)font nafont:(NSFont *)nafont
{

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setFont:%@]", __FILE__, __LINE__, font );
#endif
    [FONT release];
    FONT = [font copy];
    [NAFONT release];
    NAFONT = [nafont copy];
    FONT_SIZE = [VT100Screen fontSize:FONT];

    [STORAGE addAttribute:NSFontAttributeName
                    value:FONT
                    range:NSMakeRange(0, [STORAGE length])];
}

- (NSFont *)font
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen font]",__FILE__, __LINE__);
#endif
    return FONT;
}

- (NSFont *)nafont
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen font]",__FILE__, __LINE__);
#endif
    return NAFONT;
}

-(NSString *)fullLine
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen fullLine]",__FILE__, __LINE__);
#endif
    char blank[300];
    int i;

    for(i=0;i<WIDTH;i++) blank[i]=' ';
    blank[i]='\n'; blank[i+1]=0;
    return [NSString stringWithCString:blank];
}

- (void)setLineLimit:(unsigned int)maxline
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setLineLimit:%d]",
	  __FILE__, __LINE__, maxline);
#endif
    LINE_LIMIT = maxline;
}

- (void)putToken:(VT100TCC)token
{
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen putToken:%d]",__FILE__, __LINE__, token);
#endif
    static unichar s[300];
    int i;
    NSString *str;
    
    switch (token.type) {
    // our special code
    case VT100_STRING:
	[self setString:token.u.string];
	break;
    case VT100_UNKNOWNCHAR: break;
    case VT100_NOTSUPPORT: break;

    //  VT100 CC
    case VT100CC_ENQ: break;
    case VT100CC_BEL: [self playBell]; break;
    case VT100CC_BS:  [self backSpace]; break;
    case VT100CC_HT:  [self setTab]; break;
    case VT100CC_LF:
    case VT100CC_VT:
    case VT100CC_FF:  [self setNewLine]; break;
    case VT100CC_CR:  CURSOR_X = 0; break;
    case VT100CC_SO:  break;
    case VT100CC_SI:  break;
    case VT100CC_DC1: break;
    case VT100CC_DC3: break;
    case VT100CC_CAN:
    case VT100CC_SUB: break;
    case VT100CC_DEL: [self deleteCharacters:1];break;

    // VT100 CSI
    case VT100CSI_CPR: break;
    case VT100CSI_CUB: [self cursorLeft:token.u.csi.p[0]]; break;
    case VT100CSI_CUD: [self cursorDown:token.u.csi.p[0]]; break;
    case VT100CSI_CUF: [self cursorRight:token.u.csi.p[0]]; break;
    case VT100CSI_CUP: [self cursorToX:token.u.csi.p[1]
                                     Y:token.u.csi.p[0]];
        break;
    case VT100CSI_CUU: [self cursorUp:token.u.csi.p[0]]; break;
    case VT100CSI_DA:   [self deviceAttribute:token]; break;
    case VT100CSI_DECALN:
        for (i=0;i<WIDTH;i++) s[i]='E';
        str=[NSString stringWithCharacters:s length:WIDTH];
        for(i=0;i<HEIGHT;i++)
            [self setStringToX:0 Y:i string:str];
        break;
    case VT100CSI_DECDHL: break;
    case VT100CSI_DECDWL: break;
    case VT100CSI_DECID: break;
    case VT100CSI_DECKPAM: break;
    case VT100CSI_DECKPNM: break;
    case VT100CSI_DECLL: break;
    case VT100CSI_DECRC: [self restoreCursorPosition]; break;
    case VT100CSI_DECREPTPARM: break;
    case VT100CSI_DECREQTPARM: break;
    case VT100CSI_DECSC: [self saveCursorPosition]; break;
    case VT100CSI_DECSTBM: [self setTopBottom:token]; break;
    case VT100CSI_DECSWL: break;
    case VT100CSI_DECTST: break;
    case VT100CSI_DSR:  [self deviceReport:token]; break;
    case VT100CSI_ED:   [self eraseInDisplay:token]; break;
    case VT100CSI_EL:   [self eraseInLine:token]; break;
    case VT100CSI_HTS: tabStop[CURSOR_X]=YES; break;
    case VT100CSI_HVP: [self cursorToX:token.u.csi.p[1]
                                     Y:token.u.csi.p[0]];
        break;
    case VT100CSI_NEL:
        CURSOR_X=0;
    case VT100CSI_IND:
        CURSOR_Y++;
        if (CURSOR_Y>=HEIGHT) {
            CURSOR_Y=HEIGHT-1;
            [self scrollUp];
        }
        break;
    case VT100CSI_RI:
        CURSOR_Y--;
        if (CURSOR_Y<0) {
            CURSOR_Y=0;
            [self scrollDown];
        }
            break;
    case VT100CSI_RIS: break;
    case VT100CSI_RM: break;
    case VT100CSI_SCS: break;
    case VT100CSI_SGR:  [self selectGraphicRendition:token]; break;
    case VT100CSI_SM: break;
    case VT100CSI_TBC:
        switch (token.u.csi.p[0]) {
            case 3: [self clearTabStop]; break;
            case 0: tabStop[CURSOR_X]=NO;
        }
        break;

    case VT100CSI_DECSET:
    case VT100CSI_DECRST:
        if (token.u.csi.p[0]==3) {	// set the column
            [STORAGE endEditing];
            [[SESSION parent] resizeWindow:([TERMINAL columnMode]?132:80)
                                    height:HEIGHT];
            [STORAGE beginEditing];
        }
        break;
        
    // XTERM extensions
    case XTERMCC_TITLE:
        //[SESSION setName:token.u.string];
        [WINDOW setTitle:token.u.string];
        break;
    case XTERMCC_INSBLNK: [self insertBlank:token.u.csi.p[0]]; break;
    case XTERMCC_INSLN: [self insertLines:token.u.csi.p[0]]; break;
    case XTERMCC_DELCH: [self deleteCharacters:token.u.csi.p[0]]; break;
    case XTERMCC_DELLN: [self deleteLines:token.u.csi.p[0]]; break;
        

    default:
	NSLog(@"%s(%d): bug?? token.type = %d", 
	      __FILE__, __LINE__, token.type);
	break;
    }
}

- (void)clearBuffer
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen clearBuffer]",  __FILE__, __LINE__ );
#endif
    [STORAGE deleteCharactersInRange:NSMakeRange(0, [STORAGE length])];
    [self clearScreen];
    [self initScreen];
    CURSOR_X = CURSOR_Y = 0;
}

- (int) getIndex:(int)x y:(int)y
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen getIndex]:(%d,%d)",  __FILE__, __LINE__ , x, y );
#endif

    NSString *s=[STORAGE string];
    int idx=[s length]-1;

    if (x>WIDTH||y>HEIGHT||x<0||y<0) {
        NSLog(@"getIndex: out of bound");
        return -1;
    }
    for(;y<HEIGHT&&idx>=0;idx--) {
        if ([s characterAtIndex:idx]=='\n') y++;
    }
    for(;x<WIDTH-1&&idx>=0;idx--) {
        if (ISDOUBLEWIDTHCHARACTER([s characterAtIndex:idx])) {
            //            NSLog(@"here!!!!");
            x+=2;
        }
        else x++;
    }

    if (x>=WIDTH) {
        idx++;
    }
    CURSOR_IN_MIDDLE=(x>WIDTH);
    if (index<0) {
        NSLog(@"getIndex Error! x:%d, y:%d",x,y);
    }
//    NSLog(@"index:%d[%d] (CURSOR_IN_MIDDLE:%d)",idx,[s length],CURSOR_IN_MIDDLE);
    
    return idx;
}

- (void)setString:(NSString *)s
{
    int i,j,idx,idx2,len,x,x2;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setString:%@]",
          __FILE__, __LINE__, s);
#endif
    
    if (s==nil) return;
    len = [s length];
    if (len<1) return;

    NSString *store=[STORAGE string];
    NSMutableString *string=[NSMutableString stringWithString:s];

    [self showCursor:NO];

    for(idx2=0;idx2<[string length];) {
        if (CURSOR_X>=WIDTH) {
            [self setNewLine];
            CURSOR_X=0;
        }
        if ([TERMINAL insertMode]) {
            for(j=0,x=CURSOR_X;x<WIDTH&&idx2+j<[string length];x++,j++)
                if (ISDOUBLEWIDTHCHARACTER([string characterAtIndex:idx2+j])) x++;
            if (x>WIDTH) {
                //            NSLog(@"setString: Hanzi cut at the end of line");
                [string replaceCharactersInRange:NSMakeRange(idx2+j-1,1) withString:@"? "];
                //            NSLog(@"           alter string to: %@",string);
                x--;
            }
            if (!j) {
                //            NSLog(@"setString: output length=0?");
                break;
            }
            [self insertBlank:x-CURSOR_X];
            idx=[self getIndex:CURSOR_X y:CURSOR_Y];
            [STORAGE replaceCharactersInRange:NSMakeRange(idx,x-CURSOR_X)
                         withAttributedString:[self attrString:[string substringWithRange:NSMakeRange(idx2,j)]]];
            CURSOR_X=x;
            idx2+=j;
        }
        else {
            idx=[self getIndex:CURSOR_X y:CURSOR_Y];
            //        NSLog(@"index {%d,%d]->%d",CURSOR_X,CURSOR_Y,idx);
            if (CURSOR_IN_MIDDLE) {
                //            NSLog(@"setString: Start from middle of a hanzi");
                [string insertString:@"?" atIndex:idx2];
                CURSOR_X--;
            }

            for(j=0,x=CURSOR_X;x<WIDTH&&idx2+j<[string length];x++,j++)
                if (ISDOUBLEWIDTHCHARACTER([string characterAtIndex:idx2+j])) x++;
            if (x>WIDTH) {
                //            NSLog(@"setString: Hanzi cut at the end of line");
                [string replaceCharactersInRange:NSMakeRange(idx2+j-1,1) withString:@"??"];
                //            NSLog(@"           alter string to: %@",string);
                x--;
            }
            if (!j) {
                //            NSLog(@"setString: output length=0?");
                break;
            }
            for(i=0,x2=CURSOR_X;x2<x;x2++,i++)
                if (ISDOUBLEWIDTHCHARACTER([store characterAtIndex:idx+i])) x2++;
            CURSOR_X=x;

            if (x2>x) {
                //            NSLog(@"setString: End in the middle of a hanzi");
                [string insertString:@"?" atIndex:idx2+j];
                j++;
                x++;
            }
            /*        NSLog(@"setString: About to change [%@](%d+%d) ==> [%@](%d+%d)  (%d)",
                [store substringWithRange:NSMakeRange(idx,i)],idx,i,
                [string substringWithRange:NSMakeRange(idx2,j)],idx2,j,[store length]); */
            [STORAGE replaceCharactersInRange:NSMakeRange(idx,i)
                         withAttributedString:[self attrString:[string substringWithRange:NSMakeRange(idx2,j)]]];
            idx2+=j;
        }
    }
//    NSLog(@"setString done");
}
        
            
- (void)setStringToX:(int)x
		   Y:(int)y
	      string:(NSString *)string 
{
    int sx, sy;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setStringToX:%d Y:%d string:%@]",
          __FILE__, __LINE__, x, y, string);
#endif

    sx = CURSOR_X;
    sy = CURSOR_Y;
    CURSOR_X = x;
    CURSOR_Y = y;
    [self setString:string];
    CURSOR_X = sx;
    CURSOR_Y = sy;
}

- (void)setStringSpaceToX:(int)x Y:(int)y length:(int)len
{
    NSMutableString *spc = [NSMutableString string];
    int i;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setStringSpaceToX:%d Y:%d length:%d]",
          __FILE__, __LINE__, x, y, len);
#endif

    for (i = 0; i < len; ++i)
        [spc appendString:@" "];
    [self setStringToX:x  Y:y  string:spc];
}


- (void)setNewLine
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setNewLine](%d,%d)", __FILE__, __LINE__, CURSOR_X, CURSOR_Y);
#endif

    if (CURSOR_Y  < SCROLL_BOTTOM) {
	CURSOR_Y++;
    }
    else if (SCROLL_TOP == 0 && SCROLL_BOTTOM == HEIGHT - 1) {
        [STORAGE appendAttributedString:[[NSAttributedString alloc] initWithAttributedString:[self attrString:[self fullLine]]]];
        TOP_LINE++;
        [self removeOverLine];
    }
    else {
        [self scrollUp];
    }
}


- (void)showCursor
{
    [self showCursor:YES];
}

- (void)showCursor:(BOOL)show
{
    NSColor *fg, *bg;
    NSDictionary *dic;

    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen showCursor]", __FILE__, __LINE__);
#endif
//    NSLog(@"----showCursor: (%d,%d):%d",CURSOR_X,CURSOR_Y,show);

    if (OLD_CURSOR_INDEX!=-1&&OLD_CURSOR_INDEX<[[STORAGE string] length]) {
        if ([STORAGE attribute:NSReversedAttributeName atIndex:OLD_CURSOR_INDEX effectiveRange:nil]==@"YES") {
            fg=[STORAGE attribute:NSForegroundColorAttributeName atIndex:OLD_CURSOR_INDEX effectiveRange:nil];
            bg=[STORAGE attribute:NSBackgroundColorAttributeName atIndex:OLD_CURSOR_INDEX effectiveRange:nil];
//            NSLog(@"fg=%@\nbg=%@",fg,bg);
            dic=[NSDictionary dictionaryWithObjectsAndKeys:fg,NSBackgroundColorAttributeName,bg,NSForegroundColorAttributeName,@"NO",NSReversedAttributeName,nil];
//            NSLog(@"----showCursor: (%d,%d):[%d|%c]",CURSOR_X,CURSOR_Y,[[STORAGE string] characterAtIndex:OLD_CURSOR_INDEX],[[STORAGE string] characterAtIndex:OLD_CURSOR_INDEX]);
            [STORAGE setAttributes:dic range:NSMakeRange(OLD_CURSOR_INDEX,1)];
            OLD_CURSOR_INDEX=-1;
        }
    }
    if (CURSOR_X >= 0 && CURSOR_X < WIDTH &&
        CURSOR_Y >= 0 && CURSOR_Y < HEIGHT)
    {
            int idx = [self getIndex:CURSOR_X y:CURSOR_Y];
            if (show) {
                fg=[STORAGE attribute:NSForegroundColorAttributeName atIndex:idx effectiveRange:nil];
                bg=[STORAGE attribute:NSBackgroundColorAttributeName atIndex:idx effectiveRange:nil];
                dic=[NSDictionary dictionaryWithObjectsAndKeys:fg,NSBackgroundColorAttributeName,bg,NSForegroundColorAttributeName,@"YES",NSReversedAttributeName,nil];
//                NSLog(@"----showCursor: (%d,%d):[%d|%c]",CURSOR_X,CURSOR_Y,[[STORAGE string] characterAtIndex:idx],[[STORAGE string] characterAtIndex:idx]);
                [STORAGE setAttributes:dic range:NSMakeRange(idx,1)];
                OLD_CURSOR_INDEX=idx;
            }
            else OLD_CURSOR_INDEX=-1;
        
    }
}

- (void)deleteCharacters:(int) n
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen deleteCharacter]", __FILE__, __LINE__);
#endif
    for(;n>0;n--)
        if (CURSOR_X >= 0 && CURSOR_X < WIDTH &&
            CURSOR_Y >= 0 && CURSOR_Y < HEIGHT)
        {
            NSString *s=[STORAGE string];
            int idx = [self getIndex:CURSOR_X y:CURSOR_Y];
            int width;

            width = (ISDOUBLEWIDTHCHARACTER([[STORAGE string] characterAtIndex:idx]))?2:1;
            [STORAGE deleteCharactersInRange:NSMakeRange(idx, 1)];
            if (width==2)  [STORAGE insertAttributedString:[self attrStringFromChar:' '] atIndex:idx];
            for(;[s characterAtIndex:idx]!='\n'&&idx<[s length];idx++);
            [STORAGE insertAttributedString:[self attrStringFromChar:' '] atIndex:idx];
        }
}

- (void)backSpace
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen backSpace]", __FILE__, __LINE__);
#endif
    if (CURSOR_X > 0) 
        --CURSOR_X;
}

- (void)setTab
{

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setTab]", __FILE__, __LINE__);
#endif

#if 0
    {
	int i;
        int dif = TABSIZE - CURSOR_X % TABSIZE;

	NSMutableString *str = [NSMutableString string];
	for (i = 0; i < dif; ++i)
	    [str appendString:@" "];
	[self setString:str width:1];
    }
#else
    for(;!tabStop[CURSOR_X]&&CURSOR_X<WIDTH; CURSOR_X++);
#endif
}

- (void)clearScreen
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen clearScreen]", __FILE__, __LINE__);
#endif
    [self resizeWidth:WIDTH height:HEIGHT];
}

- (void)eraseInDisplay:(VT100TCC)token
{
    int x1, y1, x2, y2;
    int y;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen eraseInDisplay:(param=%d)]",
          __FILE__, __LINE__, token.u.csi.p[0]);
#endif
    switch (token.u.csi.p[0]) {
    case 1:
        x1 = 0;
        y1 = 0;
        x2 = CURSOR_X;
        y2 = CURSOR_Y;
        break;

    case 2:
        x1 = 0;
        y1 = 0;
        x2 = WIDTH - 1;
        y2 = HEIGHT - 1;
        break;

    case 0:
    default:
        x1 = CURSOR_X;
        y1 = CURSOR_Y;
        x2 = WIDTH - 1;
        y2 = HEIGHT - 1;
        break;
    }

    for (y = y1; y <= y2; ++y ) {
        if (y == y1 && y == y2) {
            if (x2 - x1 > 0)
                [self setStringSpaceToX:x1 Y:y  length:x2 - x1+1];
        }
        else if (y == y1) {
            [self setStringSpaceToX:x1 Y:y  length:WIDTH - x1];
        }
        else if (y == y2) {
            [self setStringSpaceToX:0 Y:y  length:x2+1];
        }
        else {
            [self setStringSpaceToX:0 Y:y length:WIDTH];
        }
    }
}

- (void)eraseInLine:(VT100TCC)token
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen eraseInLine:(param=%d)]",
          __FILE__, __LINE__, token.u.csi.p[0]);
#endif
    switch (token.u.csi.p[0]) {
    case 1:
        [self setStringSpaceToX:0 Y:CURSOR_Y length:CURSOR_X+1];
        break;
    case 2:
	CURSOR_X = 0;
	// continue, next case....

    case 0:
        [self setStringSpaceToX:CURSOR_X Y:CURSOR_Y length:WIDTH-CURSOR_X];
        break;
    default:
        ;
    }
}

- (void)selectGraphicRendition:(VT100TCC)token
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen selectGraphicRendition:...]",
	  __FILE__, __LINE__);
#endif
}

- (void)cursorLeft:(int)n
{
    int x = CURSOR_X - (n>0?n:1);

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen cursorLeft:%d]", 
	  __FILE__, __LINE__, n);
#endif
    if (x < 0)
	x = 0;
    if (x >= 0 && x < WIDTH)
	CURSOR_X = x;
    [self getIndex:CURSOR_X y:CURSOR_Y];
//    if (CURSOR_IN_MIDDLE) CURSOR_X--;
}

- (void)cursorRight:(int)n
{
    int x = CURSOR_X + (n>0?n:1);

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen cursorRight:%d]", 
	  __FILE__, __LINE__, n);
#endif
    if (x >= WIDTH)
	x =  WIDTH - 1;
    if (x >= 0 && x < WIDTH)
	CURSOR_X = x;
    [self getIndex:CURSOR_X y:CURSOR_Y];
//   if (CURSOR_IN_MIDDLE) if (CURSOR_X<WIDTH-1) CURSOR_X++; else CURSOR_X--;
//    NSParameterAssert(CURSOR_X >= 0 && CURSOR_X < WIDTH);


}

- (void)cursorUp:(int)n
{
    int y = CURSOR_Y - (n>0?n:1);

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen cursorUp:%d]", 
	  __FILE__, __LINE__, n);
#endif
    CURSOR_Y=y<SCROLL_TOP?SCROLL_TOP:y;
    
/*
 NSParameterAssert(SCROLL_TOP >= 0 && SCROLL_TOP < HEIGHT);
 NSParameterAssert(SCROLL_BOTTOM >= 0 && SCROLL_BOTTOM < HEIGHT);
 NSParameterAssert(SCROLL_TOP <= SCROLL_BOTTOM);

 for (; y < SCROLL_TOP; ++y) {
	[self scrollDown];
    }
    CURSOR_Y = y;
    [self getIndex:CURSOR_X y:CURSOR_Y];
//    if (CURSOR_IN_MIDDLE) CURSOR_X--;
*/
}

- (void)cursorDown:(int)n
{
    int y = CURSOR_Y + (n>0?n:1);

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen cursorDown:%d]", 
	  __FILE__, __LINE__, n);
#endif
    CURSOR_Y=y>SCROLL_BOTTOM?SCROLL_BOTTOM:y;
/*
 NSParameterAssert(SCROLL_TOP >= 0 && SCROLL_TOP < HEIGHT);
    NSParameterAssert(SCROLL_BOTTOM >= 0 && SCROLL_BOTTOM < HEIGHT);
    NSParameterAssert(SCROLL_TOP <= SCROLL_BOTTOM);

    for (; y > SCROLL_BOTTOM; --y) {
	[self scrollUp];
    }
    CURSOR_Y = y;
    [self getIndex:CURSOR_X y:CURSOR_Y];
//    if (CURSOR_IN_MIDDLE) CURSOR_X--;
*/
}

- (void)cursorToX:(int)x Y:(int)y
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen cursorToX:%d Y:%d]", 
	  __FILE__, __LINE__, x, y);
#endif
    if ([TERMINAL originMode]) y+=SCROLL_TOP;
    
    x=(x-1)%WIDTH;
    y=(y-1)%HEIGHT;
    if (x >= 0 && x < WIDTH &&
	y >= 0 && y < HEIGHT) 
    {
	CURSOR_X = x ;
	CURSOR_Y = y ;
        [self getIndex:CURSOR_X y:CURSOR_Y];
//        if (CURSOR_IN_MIDDLE) CURSOR_X--;
    }
    else {
        NSLog(@"cursorToXY: out of bound:(%d,%d)",x,y);
    }
//    NSParameterAssert(CURSOR_X >= 0 && CURSOR_X < WIDTH);

}

- (void)saveCursorPosition
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen saveCursorPosition]", 
	  __FILE__, __LINE__);
#endif
    if (CURSOR_X >= 0 && CURSOR_X < WIDTH)

    NSParameterAssert(CURSOR_X >= 0 && CURSOR_X < WIDTH);
    NSParameterAssert(CURSOR_Y >= 0 && CURSOR_Y < HEIGHT);
    
    SAVE_CURSOR_X = CURSOR_X;
    SAVE_CURSOR_Y = CURSOR_Y;
}

- (void)restoreCursorPosition
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen restoreCursorPosition]", 
	  __FILE__, __LINE__);
#endif
    [self showCursor:NO];
    CURSOR_X = SAVE_CURSOR_X;
    CURSOR_Y = SAVE_CURSOR_Y;
    [self getIndex:CURSOR_X y:CURSOR_Y];
//    if (CURSOR_IN_MIDDLE) CURSOR_X--;
    
    if (CURSOR_X >= 0 && CURSOR_X < WIDTH)
    
    NSParameterAssert(CURSOR_X >= 0 && CURSOR_X < WIDTH);
    NSParameterAssert(CURSOR_Y >= 0 && CURSOR_Y < HEIGHT);
}

- (void)setTopBottom:(VT100TCC)token
{
    int top, bottom;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setTopBottom:(%d,%d)]", 
	  __FILE__, __LINE__, token.u.csi.p[0], token.u.csi.p[1]);
#endif

    top = token.u.csi.p[0] == 0 ? 0 : token.u.csi.p[0] - 1;
    bottom = token.u.csi.p[1] == 0 ? HEIGHT - 1 : token.u.csi.p[1] - 1;
    if (top >= 0 && top < HEIGHT &&
        bottom >= 0 && bottom < HEIGHT &&
        bottom >= top)
    {
        SCROLL_TOP = top;
        SCROLL_BOTTOM = bottom;

	if ([TERMINAL originMode]) {
	    CURSOR_X = 0;
	    CURSOR_Y = SCROLL_TOP;
	}
	else {
	    CURSOR_X = 0;
	    CURSOR_Y = 0;
	}
    }
}

- (void)scrollUp
{
    int idx, idx2;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen scrollUp]", __FILE__, __LINE__);
#endif

    NSParameterAssert(SCROLL_TOP >= 0 && SCROLL_TOP < HEIGHT);
    NSParameterAssert(SCROLL_BOTTOM >= 0 && SCROLL_BOTTOM < HEIGHT);
    NSParameterAssert(SCROLL_TOP <= SCROLL_BOTTOM );

//    NSLog(@"SCROLL-UP[%d-%d]",SCROLL_TOP,SCROLL_BOTTOM);
    [self showCursor:NO];
    idx=[self getIndex:0 y:SCROLL_TOP];
    idx2=[self getIndex:0 y:SCROLL_TOP+1];
    [STORAGE deleteCharactersInRange:NSMakeRange(idx,idx2-idx)];

    if (SCROLL_BOTTOM>=HEIGHT-1) {
        [STORAGE appendAttributedString:[self attrString:[self fullLine]]];
    }
    else {
        idx=[self getIndex:0 y:SCROLL_BOTTOM+1];
        [STORAGE insertAttributedString:[self attrString:[self fullLine]] atIndex:idx];
    }
}

- (void)scrollDown
{
    int idx, idx2;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen scrollDown]", __FILE__, __LINE__);
#endif
    NSParameterAssert(SCROLL_TOP >= 0 && SCROLL_TOP < HEIGHT);
    NSParameterAssert(SCROLL_BOTTOM >= 0 && SCROLL_BOTTOM < HEIGHT);
    NSParameterAssert(SCROLL_TOP <= SCROLL_BOTTOM );

//    NSLog(@"SCROLL-DOWN[%d-%d]",SCROLL_TOP,SCROLL_BOTTOM);
    [self showCursor:NO];
    idx=[self getIndex:0 y:SCROLL_TOP];
    [STORAGE insertAttributedString:[self attrString:[self fullLine]] atIndex:idx];
    if (SCROLL_BOTTOM>=HEIGHT-1) {
        [STORAGE deleteCharactersInRange:NSMakeRange([STORAGE length]-WIDTH_REAL,WIDTH_REAL)];
    }
    else {
        idx=[self getIndex:0 y:SCROLL_BOTTOM];
        idx2=[self getIndex:0 y:SCROLL_BOTTOM+1];
        [STORAGE deleteCharactersInRange:NSMakeRange(idx,idx2-idx)];
    }
    
}

- (void) insertBlank: (int)n
{
    int i, idx, idx2;
    
//    NSLog(@"insertBlank[%d@(%d,%d)]",n,CURSOR_X,CURSOR_Y);
    for(i=n;i>0;i--) {
        idx=[self getIndex:CURSOR_X y:CURSOR_Y];
        if (CURSOR_IN_MIDDLE) {
            [STORAGE deleteCharactersInRange:NSMakeRange(idx,1)];
            [STORAGE insertAttributedString:[self attrString:@"  "] atIndex:idx];
            idx++;
        }
        idx2=[self getIndex:WIDTH-1 y:CURSOR_Y];
        if (CURSOR_IN_MIDDLE) {
            [STORAGE deleteCharactersInRange:NSMakeRange(idx2,1)];
            [STORAGE insertAttributedString:[self attrString:@"  "] atIndex:idx];
            idx2++;
        }
        [STORAGE deleteCharactersInRange:NSMakeRange(idx2,1)];
        [STORAGE insertAttributedString:[self attrStringFromChar:' '] atIndex:idx];
    }
}

- (void) insertLines: (int)n
{
    int idx, idx2;
    
//    NSLog(@"insertLines %d[%d,%d]",n, CURSOR_X,CURSOR_Y);
    [self showCursor:NO];
    for(;n>0;n--) {
        idx=[self getIndex:0 y:CURSOR_Y];
        [STORAGE insertAttributedString:[self attrString:[self fullLine]] atIndex:idx];
        if (SCROLL_BOTTOM<CURSOR_Y||SCROLL_BOTTOM>=HEIGHT-1) {
            [STORAGE deleteCharactersInRange:NSMakeRange([STORAGE length]-WIDTH_REAL,WIDTH_REAL)];
        }
        else {
            idx=[self getIndex:0 y:SCROLL_BOTTOM];
            idx2=[self getIndex:0 y:SCROLL_BOTTOM+1];
            [STORAGE deleteCharactersInRange:NSMakeRange(idx,idx2-idx)];
        }
    }
//    [self showCursor];
}

- (void) deleteLines: (int)n
{
    int idx, idx2;

//    NSLog(@"deleteLines %d[%d,%d]",n, CURSOR_X,CURSOR_Y);
    [self showCursor:NO];
    for(;n>0;n--) {
        idx=[self getIndex:0 y:CURSOR_Y];
        idx2=[self getIndex:0 y:CURSOR_Y+1];
        [STORAGE deleteCharactersInRange:NSMakeRange(idx,idx2-idx)];
        if (SCROLL_BOTTOM<CURSOR_Y||SCROLL_BOTTOM>=HEIGHT-1) {
            [STORAGE appendAttributedString:[self attrString:[self fullLine]]];
        }
        else {
            idx=[self getIndex:0 y:SCROLL_BOTTOM+1];
            [STORAGE insertAttributedString:[self attrString:[self fullLine]] atIndex:idx];
        }
    }
}

- (void)playBell
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen playBell]",  __FILE__, __LINE__);
#endif
    if (PLAYBELL)
	NSBeep();
}

- (void)removeOverLine
{
  
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen removeOverLine]",  __FILE__, __LINE__);
#endif

    if (TOP_LINE + HEIGHT > LINE_LIMIT) {
	int over = TOP_LINE + HEIGHT - LINE_LIMIT;
        int i,idx;
        NSString *s=[STORAGE string];

        [self showCursor:NO];
        for(i=0,idx=0;i<over;idx++)
            if ([s characterAtIndex:idx]=='\n') i++;
        [STORAGE deleteCharactersInRange:NSMakeRange(0, idx+1)];
        TOP_LINE -= over;

        NSParameterAssert(TOP_LINE >= 0);
    }
}

- (void)deviceReport:(VT100TCC)token
{
    NSData *report = nil;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen deviceReport:%d]", 
	  __FILE__, __LINE__, token.u.csi.p[0]);
#endif
    if (SHELL == nil)
	return;

    switch (token.u.csi.p[0]) {
    case 3: // response from VT100 -- Malfunction -- retry
	break;

    case 5: // Command from host -- Please report status
	report = [TERMINAL reportStatus];
	break;

    case 6: // Command from host -- Please report active position
        {
	    int x, y;

	    if ([TERMINAL originMode]) {
		x = CURSOR_X + 1;
		y = CURSOR_Y - SCROLL_TOP + 1;
	    }
	    else {
		x = CURSOR_X + 1;
		y = CURSOR_Y + 1;
	    }
	    report = [TERMINAL reportActivePositionWithX:x Y:y];
	}
	break;

    case 0: // Response from VT100 -- Ready, No malfuctions detected
    default:
	break;
    }

    if (report != nil) {
	[SHELL writeTask:report];
    }
}

- (void)deviceAttribute:(VT100TCC)token
{
    NSData *report = nil;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen deviceAttribute:%d]", 
	  __FILE__, __LINE__, token.u.csi.p[0]);
#endif
    if (SHELL == nil)
	return;

    report = [TERMINAL reportDeviceAttribute];

    if (report != nil) {
	[SHELL writeTask:report];
    }
}


- (NSMutableDictionary *)characterAttributeDictionary{
    NSMutableDictionary *dic = [TERMINAL characterAttributeDictionary];
    //NSFont *f=FONT;
    //unsigned int attr = [TERMINAL characterAttribute];

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen characterAttributeDictionary]", 
	  __FILE__, __LINE__);
#endif
    
//    if ([TERMINAL characterAttribute]&VT100CHARATTR_BOLD)
//        f=[[NSFontManager  sharedFontManager] convertFont:FONT toHaveTrait:NSBoldFontMask];
    
    [dic setObject:FONT forKey:NSFontAttributeName];
//    NSLog(@"attribute:%@",dic);

    return dic;
}

- (NSAttributedString *)attrStringFromChar:(unichar) c
{
    NSAttributedString *attr;

    attr = [[NSAttributedString alloc]
               initWithString:[NSString stringWithCharacters:&c length:1]
                   attributes:[self characterAttributeDictionary]];
    [attr autorelease];

    return attr;
}


- (NSAttributedString *)attrString:(NSString *)str
{
    NSMutableAttributedString *attr;
    int i,j,len;
    BOOL ASCII;

    if (str==nil) {
        NSLog(@"attrString: nil received!");
        str=@"";
    }

    attr = [[NSMutableAttributedString alloc]
               initWithString:str
                   attributes:[self characterAttributeDictionary]];
    [attr autorelease];
    
    len=[str length];
    for (i=0;i<len;i++) {
        ASCII=([str characterAtIndex:i]<0x7f);
        for(j=i;j<len&&ASCII==([str characterAtIndex:j]<0x7f);j++);
        if (!ASCII) {
            [attr addAttribute:NSFontAttributeName
                         value:NAFONT
                         range:NSMakeRange(i,j-i+1)];
        }
        ASCII=!ASCII;
    }

    return attr;
}

- (BOOL) isDoubleWidthCharacter:(unichar)code
{
    BOOL result = NO;

    return (code>=0x1000)?YES:NO; //[NSString isDoubleWidthCharacter:code];

    return result;
}

- (void)blink
{

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen blink]", __FILE__, __LINE__);
#endif
    
    int idx=[self getIndex:0 y:0];
    int len=[[STORAGE string] length];
    NSColor *fg, *bg,*blink;
    NSDictionary *dic;
    NSRange range;

//    NSLog(@"blink!!");
    for(;idx<len;) {
        if ([[STORAGE attribute:NSBlinkAttributeName atIndex:idx effectiveRange:&range] intValue]) {
//            NSLog(@"true blink!!");
            for(;idx<range.length+range.location;idx++) {
                fg=[STORAGE attribute:NSForegroundColorAttributeName atIndex:idx effectiveRange:nil];
                bg=[STORAGE attribute:NSBackgroundColorAttributeName atIndex:idx effectiveRange:nil];
                blink=[STORAGE attribute:NSBlinkColorAttributeName atIndex:idx effectiveRange:nil];
                if (blink==nil) {
                    blink=bg;
                }
                dic=[NSDictionary dictionaryWithObjectsAndKeys:
                    bg,NSBackgroundColorAttributeName,
                    blink,NSForegroundColorAttributeName,
                    fg,NSBlinkColorAttributeName,
                    [NSNumber numberWithInt:1],NSBlinkAttributeName,
                    nil];
                [STORAGE setAttributes:dic range:NSMakeRange(idx,1)];
            }
//            NSLog(@"true blink end!!");
        }
        else idx+=range.length;
    }
    
}

- (int) cursorX
{
    return CURSOR_X+1;
}

- (int) cursorY
{
    return CURSOR_Y+1;
}

- (void) clearTabStop
{
    int i;
    for(i=0;i<300;i++) tabStop[i]=NO;
}

@end

