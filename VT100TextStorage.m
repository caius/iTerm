/*
 **  VT100TextStorage.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Ujwal S. Sathyam
 **
 **  Project: iTerm
 **
 **  Description: custom text storage object for vt100 terminal.
 **
 **  This program is free software; you can redistribute it and/or modify
 **  it under the terms of the GNU General Public License as published by
 **  the Free Software Foundation; either version 2 of the License, or
 **  (at your option) any later version.
 **
 **  This program is distributed in the hope that it will be useful,
 **  but WITHOUT ANY WARRANTY; without even the implied warranty of
 **  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 **  GNU General Public License for more details.
 **
 **  You should have received a copy of the GNU General Public License
 **  along with this program; if not, write to the Free Software
 **  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#import "iTerm.h"
#import "VT100TextStorage.h"

#define DEBUG_METHOD_TRACE    0


@implementation VT100TextStorage

- (id)initWithAttributedString:(NSAttributedString *)attrStr
{
    if (self = [super init])
    {
	contents = attrStr ? [attrStr mutableCopy] : [[NSMutableAttributedString alloc] init];
    }
    return self;
}

- init
{
    return [self initWithAttributedString:nil];
}

- (void)dealloc
{
    [contents release];
    [super dealloc];
}

- (NSString *)string
{
    return [contents string];
}

- (NSDictionary *)attributesAtIndex:(unsigned)location effectiveRange:(NSRange *)range
{
    return [contents attributesAtIndex:location effectiveRange:range];
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str
{
#if DEBUG_METHOD_TRACE
    NSLog(@"VT100TextStorage: replaceCharactersInRange: (%d,%d) withString: '%@'",
	  range.location, range.length, str);
#endif
    //if([str isEqualToString: [[contents attributedSubstringFromRange: range] string]] == NO)
    {
	int origLen = [self length];
	[contents replaceCharactersInRange:range withString:str];
	[self edited:NSTextStorageEditedCharacters range:range changeInLength:[self length] - origLen];
    }
}

- (void)setAttributes:(NSDictionary *)attrs range:(NSRange)range
{
    [contents setAttributes:attrs range:range];
    [self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
}

- (void) beginEditing
{
#if DEBUG_METHOD_TRACE
    NSLog(@"VT100TextStorage: beginEditing");
#endif
    [super beginEditing];
}

- (void) endEditing
{
#if DEBUG_METHOD_TRACE
    NSLog(@"VT100TextStorage: endEditing");
#endif
    [super endEditing];
}


@end 