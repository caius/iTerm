// -*- mode:objc -*-
// $Id: PTYTask.h,v 1.1.1.1 2002-11-26 04:56:49 ujwal Exp $
//
//  PTYTask.h
//  JTerminal
//
//  Created by kuma on Thu Nov 22 2001.
//  Copyright (c) 2001 Kiichi Kusama. All rights reserved.
//

/*
  Delegate
      readTask:
      brokenPipe
*/

#import <Foundation/Foundation.h>

@interface PTYTask : NSObject
{
    pid_t PID;
    int FILDES;
    int STATUS;
    id DELEGATEOBJECT;
    NSMutableData *RECVDATA;
    NSString *TTY;
    NSString *PATH;
    NSPort *SENDPORT;
    NSPort *RECVPORT;
    NSConnection *CONNECTION;

    NSString *LOG_PATH;
    NSFileHandle *LOG_HANDLE;
}

- (id)init;
- (void)dealloc;

- (void)launchWithPath:(NSString *)progpath
	     arguments:(NSArray *)args
	   environment:(NSDictionary *)env
		 width:(int)width
		height:(int)height;

- (void)setDelegate:(id)object;
- (id)delegate;

- (NSData *)readData;
- (void)readTask:(NSData *)data;
- (void)writeTask:(NSData *)data;
- (void)brokenPipe;
- (void)sendSignal:(int)signo;
- (void)setWidth:(int)width height:(int)height;
- (pid_t)pid;
- (int)wait;
- (BOOL)exist;
- (void)stop;
- (void)stopNoWait;
- (int)status;
- (NSString *)tty;
- (NSString *)path;
- (BOOL)loggingStartWithPath:(NSString *)path;
- (void)loggingStop;
- (BOOL)logging;

- (NSString *)description;

@end
