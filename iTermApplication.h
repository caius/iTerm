//
//  iTermApplication.h
//  iTerm
//
//  Created by Ujwal Setlur on Sat Apr 10 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface iTermApplication : NSApplication {

}

- (void)sendEvent:(NSEvent *)anEvent;

@end
