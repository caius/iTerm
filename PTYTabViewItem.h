//
//  PTYTabViewItem.h
//  iTerm
//
//  Created by Ujwal Sathyam on Thu Dec 19 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>


@interface PTYTabViewItem : NSTabViewItem {

    NSDictionary *labelAttributes;
    BOOL dragTarget;

}

- (id) initWithIdentifier: (id) anIdentifier;
- (void) dealloc;

// Override this to be able to customize the label attributes
- (void)drawLabel:(BOOL)shouldTruncateLabel inRect:(NSRect)tabRect;
- (NSSize) sizeOfLabel: (BOOL) shouldTruncateLabel;

// set/get custom label
- (NSDictionary *) labelAttributes;
- (void) setLabelAttributes: (NSDictionary *) theLabelAttributes;

// drag-n-drop utilities
- (void) becomeDragTarget;
- (void) resignDragTarget;

@end
