//
//  PTYTypesetter.h
//  iTerm
//
//  Created by sathyam1 on Mon Jun 02 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <AppKit/NSTypesetter.h>


@interface PTYTypesetter : NSSimpleHorizontalTypesetter {
#if 0
    NSLock *lock;

    NSLayoutManager *curLayoutManager;
    NSTextContainer *curTextContainer;
    NSTextStorage *curTextStorage;

    unsigned int curGlyph;
    NSPoint curPoint;


    NSParagraphStyle *curParagraphStyle;
    NSRange paragraphRange; /* characters */

    NSDictionary *curAttributes;
    NSRange attributeRange; /* characters */
    struct
    {
	BOOL explicit_kern;
	float kern;
	float baseline_offset;
	int superscript;
    } attributes;

    NSFont *curFont;
    NSRange fontRange; /* glyphs */

    struct GSHorizontalTypesetter_glyph_cache_s *cache;
    unsigned int cache_base, cache_size, cache_length;
    BOOL at_end;


    struct GSHorizontalTypesetter_line_frag_s *line_frags;
    int line_frags_num, line_frags_size;
#endif
}

- (float)baselineOffsetInLayoutManager:(NSLayoutManager *)layoutMgr glyphIndex:(unsigned)glyphIndex;
- (void)layoutGlyphsInLayoutManager:(NSLayoutManager *)layoutMgr startingAtGlyphIndex:(unsigned)startGlyphIndex maxNumberOfLineFragments:(unsigned)maxNumLines nextGlyphIndex:(unsigned *)nextGlyph;
- (NSLayoutStatus)layoutGlyphsInHorizontalLineFragment:(NSRect *)lineFragmentRect baseline:(float *)baseline;

@end

