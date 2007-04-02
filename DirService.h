//
//  DirService.h
//  iTerm
//
//  Created by David Nedrow on 3/21/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <DirectoryService/DirectoryService.h>


@interface DirService : NSObject {

}

+ (id) sharedInstance;

- (void) getNode;

@end
