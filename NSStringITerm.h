// $Id: NSStringITerm.h,v 1.1.1.1 2002-11-26 04:56:47 ujwal Exp $
//
//  NSStringJTerminal.h
//
//  Additional fucntion to NSString Class by Category
//  2001.11.13 by Y.Hanahara
//  2002.05.18 by Kiichi Kusama
//

#import <Foundation/Foundation.h>

#ifdef NSSTRINGJTERMINAL_CLASS_COMPILE
# define EXTERN 
#else
# define EXTERN extern
#endif

EXTERN NSStringEncoding  NSStringEUCCNEncoding;
EXTERN NSStringEncoding  NSStringBig5Encoding;

@interface NSString (iTerm)

+ (void)initialize;
+ (NSString *)stringWithInt:(int)num;
+ (NSString *)shortEncodingName:(NSStringEncoding)encoding;
+ (BOOL)isDoubleWidthCharacter:(unichar)unicode;

- (NSMutableString *) stringReplaceSubstringFrom:(NSString *)oldSubstring to:(NSString *)newSubstring;

@end
