//
//  iTermTerminalProfileMgr.h
//  iTerm
//
//  Created by Tianming Yang on Sun Mar 14 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface iTermTerminalProfileMgr : NSObject {

	NSMutableDictionary *profiles;
}

// Class methods
+ (id) singleInstance;

	// Instance methods
- (id) init;
- (void) dealloc;

- (NSDictionary *) profiles;
- (void) setProfiles: (NSMutableDictionary *) aDict;
- (void) addProfileWithName: (NSString *) newProfile copyProfile: (NSString *) sourceProfile;
- (void) deleteProfileWithName: (NSString *) profileName;
- (BOOL) isDefaultProfile: (NSString *) profileName;


- (NSString *) typeForProfile: (NSString *) profileName;
- (void) setType: (NSString *) type forProfile: (NSString *) profileName;
- (NSStringEncoding) encodingForProfile: (NSString *) profileName;
- (void) setEncoding: (NSStringEncoding) encoding forProfile: (NSString *) profileName;
- (int) scrollbackLinesForProfile: (NSString *) profileName;
- (void) setScrollbackLines: (int) lines forProfile: (NSString *) profileName;
- (BOOL) silenceBellForProfile: (NSString *) profileName;
- (void) setSilenceBell: (BOOL) silent forProfile: (NSString *) profileName;
- (BOOL) blinkCursorForProfile: (NSString *) profileName;
- (void) setBlinkCursor: (BOOL) blink forProfile: (NSString *) profileName;
- (BOOL) closeOnSessionEndForProfile: (NSString *) profileName;
- (void) setCloseOnSessionEnd: (BOOL) close forProfile: (NSString *) profileName;
- (BOOL) doubleWidthForProfile: (NSString *) profileName;
- (void) setDoubleWidth: (BOOL) doubleWidth forProfile: (NSString *) profileName;
- (BOOL) sendIdleCharForProfile: (NSString *) profileName;
- (void) setSendIdleChar: (BOOL) sent forProfile: (NSString *) profileName;
- (char) idleCharForProfile: (NSString *) profileName;
- (void) setIdleChar: (char) idle forProfile: (NSString *) profileName;

@end

@interface iTermTerminalProfileMgr (Private)

- (float) _floatValueForKey: (NSString *) key inProfile: (NSString *) profileName;
- (void) _setFloatValue: (float) fval forKey: (NSString *) key inProfile: (NSString *) profileName;
- (int) _intValueForKey: (NSString *) key inProfile: (NSString *) profileName;
- (void) _setIntValue: (int) ival forKey: (NSString *) key inProfile: (NSString *) profileName;

@end
