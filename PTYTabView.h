//
//  PTYTabView.h
//  iTerm
//
//  Created by Ujwal Sathyam on Thu Dec 19 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>


@interface PTYTabView : NSTabView {

    NSMenu *cMenu;

}

- (id)initWithFrame: (NSRect) aFrame;
- (void) dealloc;

// contextual menu
- (NSMenu *) menuForEvent: (NSEvent *) theEvent;
- (void) selectTab: (id) sender;

@end
