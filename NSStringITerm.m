// $Id: NSStringITerm.m,v 1.3 2002-12-10 18:26:28 yfabian Exp $
//
//  NSStringJTerminal.m
//
//  Additional fucntion to NSString Class by Category
//  2001.11.13 by Y.Hanahara
//  2002.05.18 by Kiichi Kusama
//

#define NSSTRINGJTERMINAL_CLASS_COMPILE
#import "NSStringITerm.h"


@implementation NSString (iTerm)


+ (NSString *)stringWithInt:(int)num
{
    return [NSString stringWithFormat:@"%d", num];
}

+ (BOOL)isDoubleWidthCharacter:(unichar)unicode
{
    BOOL result = NO;
    
    /*
      unicode character width check
       see. http://www.unicode.org
              EastAsianWidth-3.2.0.txt 
    */
    if ((unicode >= 0x1100 &&  unicode <= 0x115f) || // Hangule choseong
	unicode == 0x2329 ||	// left pointing angle bracket
	unicode == 0x232a ||	// right pointing angle bracket
        (unicode >= 0x2500 && unicode <= 0x267f) || // Box lines, Miscellaneous symbols, etc
	(unicode >= 0x2e80 && unicode <= 0x2fff) || // 
	(unicode >= 0x3001 && unicode <= 0x33ff) || // 
	(unicode >= 0x3400 && unicode <= 0x4db5) || // CJK ideograph extension A
	(unicode >= 0x4e00 && unicode <= 0x9fa5) || // CJK ideograph
	(unicode >= 0xa000 && unicode <= 0xa4c6) ||
	(unicode >= 0xac00 && unicode <= 0xd7a3) || // hangul syllable
	(unicode >= 0xf900 && unicode <= 0xfa6a) || // CJK compatibility
	(unicode >= 0xfe30 && unicode <= 0xfe6b) || 
	(unicode >= 0xff01 && unicode <= 0xff60) ||
	(unicode >= 0xffe0 && unicode <= 0xffe6))
    {
	result = YES;
    }
    return result;
}

//
// Replace Substring 
// 
- (NSMutableString *) stringReplaceSubstringFrom:(NSString *)oldSubstring to:(NSString *)newSubstring
{
	unsigned int     len;
	NSMutableString *mstr;
	NSRange          searchRange;
	NSRange          resultRange;
	
#define	ADDON_SPACE 10

	searchRange.location = 0;
	searchRange.length = len = [self length];
	mstr = [NSMutableString stringWithCapacity:(len + ADDON_SPACE)];
	NSParameterAssert(mstr != nil);
	
	for (;;) {
		resultRange = [self rangeOfString:oldSubstring options:NSLiteralSearch range:searchRange];
		if (resultRange.length == 0) {
			break;	// Not found!
		}
		
		// append and replace
		[mstr appendString:[self substringWithRange:
			NSMakeRange(searchRange.location, resultRange.location - searchRange.location)] ];
		[mstr appendString:newSubstring];
			
		// update search Range
		searchRange.location = resultRange.location + resultRange.length;
		searchRange.length   = len - searchRange.location;

		//	NSLog(@"resultRange.location=%d\n", resultRange.location);
		//	NSLog(@"resultRange.length=%d\n", resultRange.length);
	}

	[mstr appendString:[self substringWithRange:searchRange]];
	

	return mstr;
}

@end
