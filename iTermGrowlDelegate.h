// -*- mode:objc -*-
// $Id: iTermGrowlDelegate.h,v 1.3 2006-08-04 15:58:14 dnedrow Exp $
//
/*
 **  iTermGrowlDelegate.h
 **
 **  Copyright (c) 2006
 **
 **  Author: David E. Nedrow
 **
 **  Project: iTerm
 **
 **  Description: Implements the delegate for Growl notifications.
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
#import <Growl/Growl.h>

#define OURGROWLAPPNAME  @"iTerm"
#define DEFAULTNOTIFICATION @"Miscellaneous"

@interface iTermGrowlDelegate : NSObject <GrowlApplicationBridgeDelegate> {
	BOOL enabled;
	NSArray * notifications;
}

+ (id) sharedInstance;

  /**
   **  Used by the class to indicate the current status of the Growl preference
   **  in iTerm.
   **  This is generally only for use with the class.
   **/
- (BOOL) isEnabled;

  /**
   **  Used by the prefs class to toggle the Growl state when the user makes
   **  changes to the iTerm prefs that impact Growl.
   **/
- (void) setEnabled: (BOOL) newState;

  /**
   **  Generate a Growl message with no description and a notification type
   **  of "Miscellaneous".
   **/
- (void) growlNotify: (NSString *) title;

  /**
   **  Generate a Growl message with a notification type of "Miscellaneous".
   **/
- (void) growlNotify: (NSString *) title withDescription: (NSString *) description;

  /**
   **  Generate a 'full' Growl message with a specified notification type.
   **/
- (void) growlNotify: (NSString *) title withDescription: (NSString *) description andNotification: (NSString *) notification;

@end
