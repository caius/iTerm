/*
 **  iTermDisplayProfileMgr.h
 **
 **  Copyright (c) 2002, 2003, 2004
 **
 **  Author: Ujwal S. Sathyam
 **
 **  Project: iTerm
 **
 **  Description: Header file for display profile manager.
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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#define TYPE_FOREGROUND_COLOR			0
#define TYPE_BACKGROUND_COLOR			1
#define TYPE_BOLD_COLOR					2
#define TYPE_SELECTION_COLOR			3
#define TYPE_SELECTED_TEXT_COLOR		4
#define TYPE_CURSOR_COLOR				5
#define TYPE_CURSOR_TEXT_COLOR			6

@interface iTermDisplayProfileMgr : NSObject 
{
	NSMutableDictionary *profiles;
}

// Class methods
+ (id) singleInstance;

// Instance methods
- (id) init;
- (void) dealloc;

- (NSDictionary *) profiles;
- (void) setProfiles: (NSMutableDictionary *) aDict;
- (void) addProfileWithName: (NSString *) newProfile copyingProfile: (NSString *) sourceProfile;
- (void) deleteProfileWithName: (NSString *) profileName;
- (BOOL) isDefaultProfile: (NSString *) profileName;


- (NSColor *) color: (int) type ForProfile: (NSString *) profileName;
- (void) setColor: (NSColor *) aColor forType: (int) type forProfile: (NSString *) profileName;
- (NSColor *) ansiColor: (int) index highlight: (BOOL) highlight forProfile: (NSString *) profileName;
- (void) setAnsiColor: (NSColor *) aColor forIndex: (int) index highlight: (BOOL) highlight forProfile: (NSString *) profileName;

- (float) transparencyForProfile: (NSString *) profileName;
- (void) setTransparency: (float) transparency forProfile: (NSString *) profileName;

- (NSString *) backgroundImageForProfile: (NSString *) profileName;
- (void) setBackgroundImage: (NSString *) imagePath forProfile: (NSString *) profileName;

- (int) windowColumnsForProfile: (NSString *) profileName;
- (void) setWindowColumns: (int) columns forProfile: (NSString *) profileName;
- (int) windowRowsForProfile: (NSString *) profileName;
- (void) setWindowRows: (int) rows forProfile: (NSString *) profileName;
- (NSFont *) windowFontForProfile: (NSString *) profileName;
- (void) setWindowFont: (NSFont *) font forProfile: (NSString *) profileName;
- (NSFont *) windowNAFontForProfile: (NSString *) profileName;
- (void) setWindowNAFont: (NSFont *) font forProfile: (NSString *) profileName;
- (float) windowHorizontalCharSpacingForProfile: (NSString *) profileName;
- (void) setWindowHorizontalCharSpacing: (float) spacing forProfile: (NSString *) profileName;
- (float) windowVerticalCharSpacingForProfile: (NSString *) profileName;
- (void) setWindowVerticalCharSpacing: (float) spacing forProfile: (NSString *) profileName;

@end

@interface iTermDisplayProfileMgr (Private)

- (float) _floatValueForKey: (NSString *) key inProfile: (NSString *) profileName;
- (void) _setFloatValue: (float) fval forKey: (NSString *) key inProfile: (NSString *) profileName;
- (int) _intValueForKey: (NSString *) key inProfile: (NSString *) profileName;
- (void) _setIntValue: (int) ival forKey: (NSString *) key inProfile: (NSString *) profileName;

@end

