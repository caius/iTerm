//
//  PTToolbarController.h
//  iTerm
//
//  Created by Steve Gehrman on Mon Aug 11 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString *NewToolbarItem;
extern NSString *ABToolbarItem;
extern NSString *CloseToolbarItem;
extern NSString *ConfigToolbarItem;

@class PseudoTerminal;

@interface PTToolbarController : NSObject 
{
    NSToolbar* _toolbar;
    PseudoTerminal* _pseudoTerminal;
}

- (id)initWithPseudoTerminal:(PseudoTerminal*)terminal;

@end
