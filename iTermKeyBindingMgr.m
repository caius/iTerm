/*
 **  iTermKeyBindingMgr.m
 **
 **  Copyright (c) 2002, 2003, 2004
 **
 **  Author: Ujwal S. Sathyam
 **
 **  Project: iTerm
 **
 **  Description: implements the key binding manager.
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

#import <iTerm/iTermKeyBindingMgr.h>

static iTermKeyBindingMgr *singleInstance = nil;

@implementation iTermKeyBindingMgr

+ (id) singleInstance;
{
	if(singleInstance == nil)
	{
		singleInstance = [[iTermKeyBindingMgr alloc] init];
	}
	
	return (singleInstance);
}

- (id) init
{
	self = [super init];
	
	if(!self)
		return (nil);
	
	profiles = [[NSMutableDictionary alloc] init];

	return (self);
}

- (void) dealloc
{
	[profiles release];
	[super dealloc];
}

- (NSDictionary *) profiles
{
	return (profiles);
}

- (void) setProfiles: (NSMutableDictionary *) aDict
{
	NSEnumerator *keyEnumerator;
	
	if(aDict != nil)
		[profiles setDictionary: aDict];
	keyEnumerator = [profiles keyEnumerator];
	currentProfile = [profiles objectForKey: [keyEnumerator nextObject]];
	if(currentProfile == nil)
	{
		currentProfile = [[NSMutableDictionary alloc] init];
		[profiles setObject: currentProfile forKey: [NSString stringWithFormat: @"Profile %d", [profiles count]]];
		[currentProfile release];
	}
}

- (NSDictionary *) currentProfile
{
	return (currentProfile);
}

- (void) setCurrentProfile: (NSMutableDictionary *) aDict
{
	currentProfile = aDict;
}

- (void) addProfileWithName: (NSString *) aString
{
	//NSLog(@"%s: %@", __PRETTY_FUNCTION__, aString);
	if([aString length] > 0)
	{
		NSEnumerator *keyEnumerator;
		NSDictionary *firstProfile, *newProfile;
		
		keyEnumerator = [profiles keyEnumerator];
		firstProfile = [profiles objectForKey: [keyEnumerator nextObject]];
		newProfile = [[NSMutableDictionary alloc] initWithDictionary: firstProfile];
		[profiles setObject: newProfile forKey: aString];
		[newProfile release];		
	}
}

- (void) deleteProfileWithName: (NSString *) aString
{
	if([aString length] > 0)
	{
		[profiles removeObjectForKey: aString];
	}
}

- (int) numberOfEntriesInProfile: (NSString *) profileName
{
	NSDictionary *aProfile;
	
	//NSLog(@"%s: %@", __PRETTY_FUNCTION__, profileName);
	
	if([profileName length] > 0)
	{
		aProfile = [profiles objectForKey: profileName];
		return ([aProfile count]);
	}
	else
		return (0);
}


- (void) addEntryForKeyCode: (unsigned int) hexCode 
				  modifiers: (unsigned int) modifiers
					 action: (unsigned int) action
					   text: (NSString *) text
					profile: (NSString *) profile
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void) addEntryForKey: (unsigned int) key 
			  modifiers: (unsigned int) modifiers
				 action: (unsigned int) action
				   text: (NSString *) text
				profile: (NSString *) profile
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
	
	NSMutableDictionary *aProfile, *keyBinding;
	unsigned int keyModifiers;
	unichar keyUnicode;
	NSString *keyString;
	
	aProfile = [profiles objectForKey: profile];
	keyModifiers = modifiers;
	
	if(key >= KEY_NUMERIC_0 && key <= KEY_NUMERIC_PERIOD)
		keyModifiers |= NSNumericPadKeyMask;
	
	switch (key)
	{
		case KEY_CURSOR_DOWN:
			keyUnicode = NSDownArrowFunctionKey;
			break;
		case KEY_CURSOR_LEFT:
			keyUnicode = NSLeftArrowFunctionKey;
			break;
		case KEY_CURSOR_RIGHT:
			keyUnicode = NSRightArrowFunctionKey;
			break;
		case KEY_CURSOR_UP:
			keyUnicode = NSUpArrowFunctionKey;
			break;
		case KEY_DEL:
			keyUnicode = NSDeleteFunctionKey;
			break;
		case KEY_DELETE:
			keyUnicode = 0x7f;
			break;
		case KEY_END:
			keyUnicode = NSEndFunctionKey;
			break;
		case KEY_F1:
		case KEY_F2:
		case KEY_F3:
		case KEY_F4:
		case KEY_F5:
		case KEY_F6:
		case KEY_F7:
		case KEY_F8:
		case KEY_F9:
		case KEY_F10:
		case KEY_F11:
		case KEY_F12:
		case KEY_F13:
		case KEY_F14:
		case KEY_F15:
		case KEY_F16:
		case KEY_F17:
		case KEY_F18:
		case KEY_F19:
		case KEY_F20:
			keyUnicode = NSF1FunctionKey + (key - KEY_F1);
			break;
		case KEY_HOME:
			keyUnicode = NSHomeFunctionKey;
			break;
		case KEY_NUMERIC_0:
		case KEY_NUMERIC_1:
		case KEY_NUMERIC_2:
		case KEY_NUMERIC_3:
		case KEY_NUMERIC_4:
		case KEY_NUMERIC_5:
		case KEY_NUMERIC_6:
		case KEY_NUMERIC_7:
		case KEY_NUMERIC_8:
		case KEY_NUMERIC_9:
			keyUnicode = '0' + (key - KEY_NUMERIC_0);
			break;
		case KEY_NUMERIC_EQUAL:
			keyUnicode = '=';
			break;
		case KEY_NUMERIC_DIVIDE:
			keyUnicode = '/';
			break;
		case KEY_NUMERIC_MULTIPLY:
			keyUnicode = '*';
			break;
		case KEY_NUMERIC_MINUS:
			keyUnicode = '-';
			break;
		case KEY_NUMERIC_PLUS:
			keyUnicode = '+';
			break;
		case KEY_NUMERIC_PERIOD:
			keyUnicode = '.';
			break;
		case KEY_NUMLOCK:
			keyUnicode = NSClearLineFunctionKey;
			break;
		case KEY_PAGE_DOWN:
			keyUnicode = NSPageDownFunctionKey;
			break;
		case KEY_PAGE_UP:
			keyUnicode = NSPageUpFunctionKey;
			break;
		default:
			NSLog(@"%s: unknown key %d", __PRETTY_FUNCTION__, key);
			return;
	}
	
	keyString = [NSString stringWithFormat: @"0x%x-0x%x", keyUnicode, keyModifiers];
	keyBinding = [[NSMutableDictionary alloc] init];
	[keyBinding setObject: [NSNumber numberWithInt: action] forKey: @"Action"];
	if([text length] > 0)
		[keyBinding setObject:[[text copy] autorelease] forKey: @"Text"];
	[aProfile setObject: keyBinding forKey: keyString];
	[keyBinding release];
	
}

- (int) actionForKeyEvent: (NSEvent *) anEvent escapeSequence: (NSString **) escapeSequence hexCode: (int *) hexCode
{
	return (0);
}

- (int) entryAtIndex: (int) index key: (NSString *) unmodkeystr modifiers: (int *) modifiers
{
	return (0);
}


@end
