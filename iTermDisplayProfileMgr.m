/*
 **  iTermDisplayProfileMgr.m
 **
 **  Copyright (c) 2002, 2003, 2004
 **
 **  Author: Ujwal S. Sathyam
 **
 **  Project: iTerm
 **
 **  Description: implements the display profile manager.
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

#import <iTerm/iTermDisplayProfileMgr.h>

static iTermDisplayProfileMgr *singleInstance = nil;


@implementation iTermDisplayProfileMgr

+ (id) singleInstance;
{
	if(singleInstance == nil)
	{
		singleInstance = [[iTermDisplayProfileMgr alloc] init];
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
	
	// recursively copy the dictionary to ensure mutability
	if(aDict != nil)
	{
		[profiles setDictionary: aDict];
	}	
}

- (void) addProfileWithName: (NSString *) newProfile copyingProfile: (NSString *) sourceProfile
{
	NSMutableDictionary *aMutableDict, *aProfile;
	
	if([sourceProfile length] > 0 && [newProfile length] > 0)
	{
		aProfile = [profiles objectForKey: sourceProfile];
		aMutableDict = [[NSMutableDictionary alloc] initWithDictionary: aProfile];
		[aMutableDict removeObjectForKey: @"Default Profile"];
		[profiles setObject: aMutableDict forKey: newProfile];
		[aMutableDict release];
	}
}

- (void) deleteProfileWithName: (NSString *) profileName
{
	
	if([profileName length] <= 0)
		return;
	
	[profiles removeObjectForKey: profileName];
}

- (BOOL) isDefaultProfile: (NSString *) profileName
{
	NSDictionary *aProfile;
	
	if([profileName length] <= 0)
		return (NO);
	
	aProfile = [profiles objectForKey: profileName];
	
	return ([[aProfile objectForKey: @"Default Profile"] isEqualToString: @"Yes"]);
}


- (NSColor *) color: (int) type ForProfile: (NSString *) profileName
{
	NSDictionary *aProfile;
	NSColor *aColor;
	
	if([profileName length] <= 0)
		return (nil);
	
	aProfile = [profiles objectForKey: profileName];
	
	if(aProfile == nil)
		return (nil);
	
	switch (type)
	{
		case TYPE_FOREGROUND_COLOR:
			aColor = [aProfile objectForKey: @"Foreground Color"];
			break;
		case TYPE_BACKGROUND_COLOR:
			aColor = [aProfile objectForKey: @"Background Color"];
			break;
		case TYPE_BOLD_COLOR:
			aColor = [aProfile objectForKey: @"Bold Color"];
			break;
		case TYPE_SELECTION_COLOR:
			aColor = [aProfile objectForKey: @"Selection Color"];
			break;
		case TYPE_SELECTED_TEXT_COLOR:
			aColor = [aProfile objectForKey: @"Selected Text Color"];
			break;
		case TYPE_CURSOR_COLOR:
			aColor = [aProfile objectForKey: @"Cursor Color"];
			break;
		case TYPE_CURSOR_TEXT_COLOR:
			aColor = [aProfile objectForKey: @"Cursor Text Color"];
			break;
		default:
			aColor = nil;
			break;
	}
	
	return (aColor);
}

- (void) setColor: (NSColor *) aColor forType: (int) type forProfile: (NSString *) profileName
{
	NSMutableDictionary *aProfile;
	NSString *key = nil;

	if(aColor == nil)
		return;
	
	if([profileName length] <= 0)
		return;
	
	aProfile = [profiles objectForKey: profileName];
	
	if(aProfile == nil)
		return;
	
	switch (type)
	{
		case TYPE_FOREGROUND_COLOR:
			key =  @"Foreground Color";
			break;
		case TYPE_BACKGROUND_COLOR:
			key =  @"Background Color";
			break;
		case TYPE_BOLD_COLOR:
			key =  @"Bold Color";
			break;
		case TYPE_SELECTION_COLOR:
			key =  @"Selection Color";
			break;
		case TYPE_SELECTED_TEXT_COLOR:
			key =  @"Selected Text Color";
			break;
		case TYPE_CURSOR_COLOR:
			key =  @"Cursor Color";
			break;
		case TYPE_CURSOR_TEXT_COLOR:
			key =  @"Cursor Text Color";
			break;
		default:
			key = nil;
			break;
	}
	
	if(key != nil)
		[aProfile setObject: aColor forKey: key];
	
}

- (NSColor *) ansiColor: (int) index highlight: (BOOL) highlight forProfile: (NSString *) profileName
{
	NSDictionary *aProfile;
	NSColor *aColor;
	NSString *key = nil;
	
	if([profileName length] <= 0)
		return (nil);
	
	aProfile = [profiles objectForKey: profileName];
	
	if(aProfile == nil)
		return (nil);
	
	if(highlight)
		key = [NSString stringWithFormat: @"Ansi %dh Color", index];
	else
		key = [NSString stringWithFormat: @"Ansi %dh Color", index];
	
	aColor = [aProfile objectForKey: key];
	
	return (aColor);
}

- (void) setAnsiColor: (NSColor *) aColor forIndex: (int) index highlight: (BOOL) highlight forProfile: (NSString *) profileName
{
	NSMutableDictionary *aProfile;
	NSString *key = nil;
	
	if([profileName length] <= 0)
		return;
	
	aProfile = [profiles objectForKey: profileName];
	
	if(aProfile == nil)
		return;
	
	if(highlight)
		key = [NSString stringWithFormat: @"Ansi %dh Color", index];
	else
		key = [NSString stringWithFormat: @"Ansi %dh Color", index];
	
	[profiles setObject: aColor forKey: key];
	
}

- (float) transparencyForProfile: (NSString *) profileName
{
	return ([self _floatValueForKey: @"Transparency" inProfile: profileName]);
}

- (void) setTransparency: (float) transparency forProfile: (NSString *) profileName
{
	[self _setFloatValue: transparency forKey: @"Transparceny" inProfile: profileName];
}

- (NSString *) backgroundImageForProfile: (NSString *) profileName
{
	NSDictionary *aProfile;
	
	if([profileName length] <= 0)
		return (nil);
	
	aProfile = [profiles objectForKey: profileName];
	
	if(aProfile == nil)
		return (nil);
	
	return ([aProfile objectForKey: @"Background Image"]);
}

- (void) setBackgroundImage: (NSString *) imagePath forProfile: (NSString *) profileName
{
	NSMutableDictionary *aProfile;
	
	if([profileName length] <= 0 || [imagePath length]  <= 0)
		return;
	
	aProfile = [profiles objectForKey: profileName];
	
	if(aProfile == nil)
		return;
		
	[aProfile setObject: imagePath forKey: @"Background Image"];
}

- (int) windowColumnsForProfile: (NSString *) profileName
{
	return ([self _intValueForKey: @"Columns" inProfile: profileName]);
}

- (void) setWindowColumns: (int) columns forProfile: (NSString *) profileName
{
	[self _setIntValue: columns forKey: @"Columns" inProfile: profileName];
}

- (int) windowRowsForProfile: (NSString *) profileName
{
	return ([self _intValueForKey: @"Rows" inProfile: profileName]);
}

- (void) setWindowRows: (int) rows forProfile: (NSString *) profileName
{
	[self _setIntValue: rows forKey: @"Rows" inProfile: profileName];
}

- (NSFont *) windowFontForProfile: (NSString *) profileName
{
	NSDictionary *aProfile;
	float fontSize;
	const char *utf8String;
	char utf8FontName[128];
	NSFont *aFont;
	
	if([profileName length] <= 0)
		return ([NSFont userFixedPitchFontOfSize: 0.0]);
	
	aProfile = [profiles objectForKey: profileName];
	
	if(aProfile == nil)
		return ([NSFont userFixedPitchFontOfSize: 0.0]);
	
	if([aProfile objectForKey: @"Font"] == nil)
		return ([NSFont userFixedPitchFontOfSize: 0.0]);
	
	utf8String = [[aProfile objectForKey: @"Font"] UTF8String];
	sscanf(utf8String, "%s-%f", utf8FontName, &fontSize);
	
	aFont = [NSFont fontWithName: [NSString stringWithFormat: @"%s", utf8FontName] size: fontSize];
	
	return (aFont);
}

- (void) setWindowFont: (NSFont *) font forProfile: (NSString *) profileName
{
	NSMutableDictionary *aProfile;
	
	if([profileName length] <= 0 || font == nil)
		return;
	
	aProfile = [profiles objectForKey: profileName];
	
	if(aProfile == nil)
		return;
	
	[aProfile setObject: [NSString stringWithFormat: @"%@-%f", [font fontName], [font pointSize]] forKey: @"Font"];
}

- (NSFont *) windowNAFontForProfile: (NSString *) profileName
{
	NSDictionary *aProfile;
	float fontSize;
	const char *utf8String;
	char utf8FontName[128];
	NSFont *aFont;
	
	if([profileName length] <= 0)
		return ([NSFont userFixedPitchFontOfSize: 0.0]);
	
	aProfile = [profiles objectForKey: profileName];
	
	if(aProfile == nil)
		return ([NSFont userFixedPitchFontOfSize: 0.0]);
	
	if([aProfile objectForKey: @"NAFont"] == nil)
		return ([NSFont userFixedPitchFontOfSize: 0.0]);
	
	utf8String = [[aProfile objectForKey: @"NAFont"] UTF8String];
	sscanf(utf8String, "%s-%f", utf8FontName, &fontSize);
	
	aFont = [NSFont fontWithName: [NSString stringWithFormat: @"%s", utf8FontName] size: fontSize];
	
	return (aFont);
}

- (void) setWindowNAFont: (NSFont *) font forProfile: (NSString *) profileName
{
	NSMutableDictionary *aProfile;
	
	if([profileName length] <= 0 || font == nil)
		return;
	
	aProfile = [profiles objectForKey: profileName];
	
	if(aProfile == nil)
		return;
	
	[aProfile setObject: [NSString stringWithFormat: @"%@-%f", [font fontName], [font pointSize]] forKey: @"NAFont"];
}

- (float) windowHorizontalCharSpacingForProfile: (NSString *) profileName
{
	return ([self _floatValueForKey: @"Horizontal Character Spacing" inProfile: profileName]);
}

- (void) setWindowHorizontalCharSpacing: (float) spacing forProfile: (NSString *) profileName
{
	[self _setFloatValue: spacing forKey: @"Horizontal Character Spacing" inProfile: profileName];
}

- (float) windowVerticalCharSpacingForProfile: (NSString *) profileName
{
	return ([self _floatValueForKey: @"Vertical Character Spacing" inProfile: profileName]);
}

- (void) setWindowVerticalCharSpacing: (float) spacing forProfile: (NSString *) profileName
{
	[self _setFloatValue: spacing forKey: @"Vertical Character Spacing" inProfile: profileName];
}

@end


@implementation iTermDisplayProfileMgr (Private)

- (float) _floatValueForKey: (NSString *) key inProfile: (NSString *) profileName
{
	NSDictionary *aProfile;
	
	if([profileName length] <= 0 || [key length] <= 0)
		return (0.0);
	
	aProfile = [profiles objectForKey: profileName];
	
	if(aProfile == nil)
		return (0.0);
	
	return ([[aProfile objectForKey: key] floatValue]);
}

- (void) _setFloatValue: (float) fval forKey: (NSString *) key inProfile: (NSString *) profileName
{
	NSMutableDictionary *aProfile;
	NSNumber *aNumber;
	
	if([profileName length] <= 0 || [key length] <= 0)
		return;
	
	aProfile = [profiles objectForKey: profileName];
	
	if(aProfile == nil)
		return;
	
	aNumber = [NSNumber numberWithFloat: fval];
	
	[aProfile setObject: aNumber forKey: key];	
}

- (int) _intValueForKey: (NSString *) key inProfile: (NSString *) profileName
{
	NSDictionary *aProfile;
	
	if([profileName length] <= 0 || [key length] <= 0)
		return (0);
	
	aProfile = [profiles objectForKey: profileName];
	
	if(aProfile == nil)
		return (0);
	
	return ([[aProfile objectForKey: key] intValue]);	
}

- (void) _setIntValue: (int) ival forKey: (NSString *) key inProfile: (NSString *) profileName
{
	NSMutableDictionary *aProfile;
	NSNumber *aNumber;
	
	if([profileName length] <= 0 || [key length] <= 0)
		return;
	
	aProfile = [profiles objectForKey: profileName];
	
	if(aProfile == nil)
		return;
	
	aNumber = [NSNumber numberWithInt: ival];
	
	[aProfile setObject: aNumber forKey: key];	
}


@end
