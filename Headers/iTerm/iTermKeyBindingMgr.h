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

// Key Definitions
#define KEY_CURSOR_DOWN					0
#define KEY_CURSOR_LEFT					1
#define KEY_CURSOR_RIGHT				2
#define KEY_CURSOR_UP					3
#define KEY_DEL							4
#define KEY_DELETE						5
#define KEY_END							6
#define KEY_F1							7
#define KEY_F2							8
#define KEY_F3							9
#define KEY_F4							10
#define KEY_F5							11
#define KEY_F6							12
#define KEY_F7							13
#define KEY_F8							14
#define KEY_F9							15
#define KEY_F10							16
#define KEY_F11							17
#define KEY_F12							18
#define KEY_F13							19
#define KEY_F14							20
#define KEY_F15							21
#define KEY_F16							22
#define KEY_F17							23
#define KEY_F18							24
#define KEY_F19							25
#define KEY_F20							26
#define KEY_HEX_CODE					27
#define KEY_HOME						28
#define KEY_NUMERIC_0					29
#define KEY_NUMERIC_1					30
#define KEY_NUMERIC_2					31
#define KEY_NUMERIC_3					32
#define KEY_NUMERIC_4					33
#define KEY_NUMERIC_5					34
#define KEY_NUMERIC_6					35
#define KEY_NUMERIC_7					36
#define KEY_NUMERIC_8					37
#define KEY_NUMERIC_9					38
#define KEY_NUMERIC_EQUAL				39
#define KEY_NUMERIC__DIVIDE				40
#define KEY_NUMERIC_MULTIPLY			41
#define KEY_NUMERIC_MINUS				42
#define KEY_NUMERIC_PLUS				43
#define KEY_NUMERIC_PERIOD				44
#define KEY_NUMLOCK						45
#define KEY_PAGE_DOWN					46
#define KEY_PAGE_UP						47


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

- (void) addProfileWithName: (NSString *) aString;
- (void) deleteProfileWithName: (NSString *) aString;
- (int) numberOfEntriesInProfile: (NSString *) profileName;

- (void) addEntryForKeyCode: (unsigned int) hexCode 
				  modifiers: (unsigned int) modifiers
					 action: (unsigned int) action
					   text: (NSString *) text
					profile: (NSString *) profile;
- (void) addEntryForKey: (unsigned int) key 
				  modifiers: (unsigned int) modifiers
					 action: (unsigned int) action
					   text: (NSString *) text
				profile: (NSString *) profile;
- (int) actionForKeyEvent: (NSEvent *) anEvent escapeSequence: (NSString **) escapeSequence hexCode: (int *) hexCode;
- (int) entryAtIndex: (int) index key: (NSString *) unmodkeystr modifiers: (int *) modifiers;

@end
