/*
 **  iTermKeyBindingMgr.h
 **
 **  Copyright (c) 2002, 2003, 2004
 **
 **  Author: Ujwal S. Sathyam
 **
 **  Project: iTerm
 **
 **  Description: Header file for key binding manager.
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

#import <Cocoa/Cocoa.h>

// Actions for key bindings
#define KEY_ACTION_NEXT_SESSION			0
#define KEY_ACTION_NEXT_WINDOW			1
#define KEY_ACTION_PREVIOUS_SESSION		2
#define KEY_ACTION_PREVIOUS_WINDOW		3
#define KEY_ACTION_SCROLL_LINE_DOWN		4
#define KEY_ACTION_SCROLL_LINE_UP		5
#define KEY_ACTION_SCROLL_PAGE_DOWN		6
#define KEY_ACTION_SCROLL_PAGE_UP		7
#define KEY_ACTION_ESCAPE_SEQUENCE		8
#define KEY_ACTION_HEX_CODE				9


@interface iTermKeyBindingMgr : NSObject {
	NSMutableDictionary *profiles;
	NSMutableDictionary *currentProfile;
}

// Class methods
+ (id) singleInstance;

// Instance methods
- (id) init;
- (void) dealloc;

- (NSMutableDictionary *) profiles;
- (void) setProfiles: (NSMutableDictionary *) aDict;
- (NSDictionary *) currentProfile;
- (void) setCurrentProfile: (NSMutableDictionary *) aDict;

- (int) actionForKeyEvent: (NSEvent *) anEvent escapeSequence: (NSString **) escapeSequence hexCode: (int *) hexCode;
- (int) entryAtIndex: (int) index key: (NSString *) unmodkeystr modifiers: (int *) modifiers;

@end
