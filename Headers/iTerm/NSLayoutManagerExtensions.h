//
//  NSLayoutManagerExtensions.h
//  iTerm
//
//  Created by Ujwal Sathyam on Tue Jun 03 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface NSLayoutManager (GNUstepExtensions)

- (NSFont *) effectiveFontForGlyphAtIndex: (unsigned int) glyphIndex range: (NSRange *) aRange;

@end
