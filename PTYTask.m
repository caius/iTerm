// -*- mode:objc -*-
// $Id: PTYTask.m,v 1.16 2003-09-14 21:39:07 yfabian Exp $
//
/*
 **  PTYTask.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Sathyam
 **	     Initial code by Kiichi Kusama
 **
 **  Project: iTerm
 **
 **  Description: Implements the interface to the pty session.
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

// Debug option
#define DEBUG_THREAD          0
#define DEBUG_ALLOC           0
#define DEBUG_METHOD_TRACE    0

#import <stdio.h>
#import <stdlib.h>
#import <unistd.h>
#import <util.h>
#import <sys/ioctl.h>
#import <sys/types.h>
#import <sys/wait.h>
#import <sys/time.h>

#import <iTerm/PTYTask.h>

@implementation PTYTask

#define CTRLKEY(c)   ((c)-'A'+1)

#define MEASURE_PROCESSING_TIME		1

static void setup_tty_param(struct termios *term,
			    struct winsize *win,
			    int width,
			    int height)
{
    memset(term, 0, sizeof(struct termios));
    memset(win, 0, sizeof(struct winsize));

    term->c_iflag = ICRNL | IXON | IXANY | IMAXBEL | BRKINT;
    term->c_oflag = OPOST | ONLCR;
    term->c_cflag = CREAD | CS8 | HUPCL;
    term->c_lflag = ICANON | ISIG | IEXTEN | ECHO | ECHOE | ECHOKE | ECHOCTL;

    term->c_cc[VEOF]      = CTRLKEY('D');
    term->c_cc[VEOL]      = -1;
    term->c_cc[VEOL2]     = -1;
    term->c_cc[VERASE]    = 0x7f;	// DEL
    term->c_cc[VWERASE]   = CTRLKEY('W');
    term->c_cc[VKILL]     = CTRLKEY('U');
    term->c_cc[VREPRINT]  = CTRLKEY('R');
    term->c_cc[VINTR]     = CTRLKEY('C');
    term->c_cc[VQUIT]     = 0x1c;	// Control+backslash
    term->c_cc[VSUSP]     = CTRLKEY('Z');
    term->c_cc[VDSUSP]    = CTRLKEY('Y');
    term->c_cc[VSTART]    = CTRLKEY('Q');
    term->c_cc[VSTOP]     = CTRLKEY('S');
    term->c_cc[VLNEXT]    = -1;
    term->c_cc[VDISCARD]  = -1;
    term->c_cc[VMIN]      = 1;
    term->c_cc[VTIME]     = 0;
    term->c_cc[VSTATUS]   = -1;

    term->c_ispeed = B38400;
    term->c_ospeed = B38400;

    win->ws_row = height;
    win->ws_col = width;
    win->ws_xpixel = 0;
    win->ws_ypixel = 0;
}

static int writep(int fds, char *buf, size_t len)
{
    int wrtlen = len;
    int result = 0;
    int sts = 0;
    char *tmpPtr = buf;
    int chunk;
    struct timeval tv;
    fd_set wfds,efds;

    while (wrtlen > 0) {

	FD_ZERO(&wfds);
	FD_ZERO(&efds);
	FD_SET(fds, &wfds);
	FD_SET(fds, &efds);	
	
	tv.tv_sec = 0;
	tv.tv_usec = 100000;

	sts = select(fds + 1, NULL, &wfds, &efds, &tv);

	if (sts == 0) {
	    NSLog(@"Write timeout!");
	    break;
	}	

	if(wrtlen > 1024)
	    chunk = 1024;
	else
	    chunk = wrtlen;
	sts = write(fds, tmpPtr, wrtlen);
	if (sts <= 0)
	    break;

	wrtlen -= sts;
	tmpPtr += sts;

    }
    if (sts <= 0)
	result = sts;
    else
	result = len;

    return result;
}

+ (void)_processReadThread:(PTYTask *)boss
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSConnection *serverConnection;
    id rootProxy;
    NSData *data = nil;
    BOOL exitf = NO;
    NSAutoreleasePool *arPool;
#if MEASURE_PROCESSING_TIME
    struct timeval tv;
    BOOL newOutput = NO;
#endif

#if DEBUG_THREAD
    NSLog(@"%s(%d):+[PTYTask _processReadThread:%@] start",
	  __FILE__, __LINE__, [boss description]);
#endif

    serverConnection = [[NSConnection alloc] 
               initWithReceivePort:boss->SENDPORT
			  sendPort:boss->RECVPORT];
    rootProxy = [serverConnection rootProxy];

    /*
      data receive loop
    */
    while (exitf == NO) {
	fd_set rfds,efds;
	int sts;
	char readbuf[4096];

        arPool = [[NSAutoreleasePool alloc] init];

	FD_ZERO(&rfds);
	FD_ZERO(&efds);
	FD_SET(boss->FILDES, &rfds);
	FD_SET(boss->FILDES, &efds);

#if MEASURE_PROCESSING_TIME
	tv.tv_sec = 0;
	tv.tv_usec = 100000;

	sts = select(boss->FILDES + 1, &rfds, NULL, &efds, &tv);
#else
	sts = select(boss->FILDES + 1, &rfds, NULL, &efds, NULL);
#endif
	
	if (sts < 0) {
	    [arPool release];
	    break;
	}
	else if (FD_ISSET(boss->FILDES, &efds)) {
	    sts = read(boss->FILDES, readbuf, 1);
#if 0 // debug
	    fprintf(stderr, "read except:%d byte ", sts);
	    if (readbuf[0] & TIOCPKT_FLUSHREAD)
		fprintf(stderr, "TIOCPKT_FLUSHREAD ");
	    if (readbuf[0] & TIOCPKT_FLUSHWRITE)
		fprintf(stderr, "TIOCPKT_FLUSHWRITE ");
	    if (readbuf[0] & TIOCPKT_STOP)
		fprintf(stderr, "TIOCPKT_STOP ");
	    if (readbuf[0] & TIOCPKT_START)
		fprintf(stderr, "TIOCPKT_START ");
	    if (readbuf[0] & TIOCPKT_DOSTOP)
		fprintf(stderr, "TIOCPKT_DOSTOP ");
	    if (readbuf[0] & TIOCPKT_NOSTOP)
		fprintf(stderr, "TIOCPKT_NOSTOP ");
	    fprintf(stderr, "\n");
#endif
	    if (sts == 0) {
		// session close
		exitf = YES;
                [rootProxy readTask: nil];
	    }
	}
	else if (FD_ISSET(boss->FILDES, &rfds)) {
	    sts = read(boss->FILDES, readbuf, sizeof(readbuf));

	    if (sts == 1 && readbuf[0] != '\0') {
		data = nil;
	    }
	    else if (sts > 1) {
		data = [NSData dataWithBytes:readbuf +1 length:sts - 1];
	    }
            else if (sts == 0) {
                data = nil;

		exitf = YES;
            }
	    else {
		data = nil;
            }

#if MEASURE_PROCESSING_TIME
	    // measure processing time if we want to.
	    if(newOutput == NO)
	    {
		//NSLog(@"PTYTask: Start new output");
		newOutput = YES;
	    }
#endif

            if (data != nil) {
                [boss setHasOutput: YES];
		[rootProxy readTask:data];
            }
            else
                [boss setHasOutput: NO];

	}
#if MEASURE_PROCESSING_TIME
	else if (sts == 0)
	{
	    // time out; do some other tasks in this idle time
            [boss setHasOutput: NO];

	    // measure processing time if we want to.
	    if(newOutput == YES)
	    {
		//NSLog(@"PTYTask: End new output");
                [rootProxy doIdleTasks];
		newOutput = NO;
	    }	    
	}
#endif
        [arPool release];

    }

    [rootProxy brokenPipe];

    [serverConnection release];

#if DEBUG_THREAD
    NSLog(@"%s(%d):+[PTYTask _processReadThread:] finish",
	  __FILE__, __LINE__);
#endif

    [pool release];
    [NSThread exit];
}

- (id)init
{
#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[PTYTask init]", __FILE__, __LINE__);
#endif
    if ([super init] == nil)
	return nil;

    PID = (pid_t)-1;
    STATUS = 0;
    DELEGATEOBJECT = nil;
    RECVDATA = [[NSMutableData data] retain];
    FILDES = -1;
    TTY = nil;
    SENDPORT = nil;
    RECVPORT = nil;
    CONNECTION = nil;
    LOG_PATH = nil;
    LOG_HANDLE = nil;
    hasOutput = NO;

    return self;
}

- (void)dealloc
{
#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[PTYTask dealloc]", __FILE__, __LINE__);
#endif
    if (PID > 0)
	kill(PID, SIGKILL);
    if (FILDES >= 0)
	close(FILDES);

    [DELEGATEOBJECT release];
    [RECVDATA release];
    [TTY release];
    [PATH release];
    [SENDPORT release];
    [RECVPORT release];
    //[CONNECTION release];

    [super dealloc];
}

- (void)launchWithPath:(NSString *)progpath
	     arguments:(NSArray *)args
	   environment:(NSDictionary *)env
		 width:(int)width
		height:(int)height
{
    struct termios term;
    struct winsize win;
    char ttyname[PATH_MAX];
    int sts;
    int one = 1;

    PATH = [progpath copy];

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[launchWithPath:%@ arguments:%@ environment:%@ width:%d height:%d", __FILE__, __LINE__, progpath, args, env, width, height);
#endif    
    setup_tty_param(&term, &win, width, height);
    PID = forkpty(&FILDES, ttyname, &term, &win);
    if (PID == (pid_t)0) {
	const char *path = [[progpath stringByStandardizingPath] cString];
	int max = args == nil ? 0: [args count];
	const char *argv[max + 2];

	argv[0] = path;
	if (args != nil) {
            int i;
	    for (i = 0; i < max; ++i)
		argv[i + 1] = [[args objectAtIndex:i] cString];
	}
	argv[max + 1] = NULL;

	// set the PATH to something sensible since the inherited path seems to have the user's home directory.
	setenv("PATH", "/usr/bin:/bin:/usr/sbin:/sbin", 1);
	
	if (env != nil ) {
	    NSArray *keys = [env allKeys];
	    int i, max = [keys count];
	    for (i = 0; i < max; ++i) {
		NSString *key, *value;
		key = [keys objectAtIndex:i];
		value = [env objectForKey:key];
		if (key != nil && value != nil) 
		    setenv([key cString], [value cString], 1);
	    }
	}
        chdir([[[env objectForKey:@"PWD"] stringByExpandingTildeInPath] cString]);
	sts = execvp(path, (char * const *) argv);

	/*
	  exec error
	*/
	fprintf(stdout, "## exec failed ##\n");
	fprintf(stdout, "%s %s\n", path, strerror(errno));

	sleep(1);
	_exit(-1);
    }
    else if (PID < (pid_t)0) {
	NSLog(@"%@ %s", progpath, strerror(errno));
    }

    sts = ioctl(FILDES, TIOCPKT, &one);
    NSParameterAssert(sts >= 0);

    TTY = [[NSString stringWithCString:ttyname] retain];
    NSParameterAssert(TTY != nil);

    /*
      create data receive thread 
    */
    SENDPORT = [NSPort port]; 
    RECVPORT = [NSPort port];
    CONNECTION = [[NSConnection alloc] initWithReceivePort:RECVPORT
						  sendPort:SENDPORT];
    [CONNECTION setRootObject:self];
    [self release];

    NSParameterAssert(SENDPORT != nil && RECVPORT != nil);
    NSParameterAssert(CONNECTION != nil);

    [NSThread detachNewThreadSelector:@selector(_processReadThread:)
            	             toTarget:[PTYTask class]
	                   withObject:self];
}

- (BOOL) hasOutput
{
    return (hasOutput);
}

- (void) setHasOutput: (BOOL) flag
{
    hasOutput = flag;
}


- (void)setDelegate:(id)object
{
    [DELEGATEOBJECT release];
    DELEGATEOBJECT = object;
    [DELEGATEOBJECT retain];
}

- (id)delegate
{
    return DELEGATEOBJECT;
}

- (void) doIdleTasks
{
    if ([DELEGATEOBJECT respondsToSelector:@selector(doIdleTasks)]) {
	[DELEGATEOBJECT doIdleTasks];
    }
}

- (NSData *)readData
{
    NSData *result = [NSData dataWithData:RECVDATA];

    [RECVDATA release];
    RECVDATA = [[NSMutableData data] retain];
    NSParameterAssert(RECVDATA != nil);

    return result;
}

- (void)readTask:(NSData *)data
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTask readTask:%@]", __FILE__, __LINE__, data);
#endif
    [LOG_HANDLE writeData:data];

    if (DELEGATEOBJECT == nil) {
	[RECVDATA appendData:data];
    }
    else {
	if ([DELEGATEOBJECT respondsToSelector:@selector(readTask:)]) {
	    [DELEGATEOBJECT readTask:data];
	}
    }
}

- (void)writeTask:(NSData *)data
{
    const void *datap = [data bytes];
    size_t len = [data length];
    int sts;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTask writeTask:%@]", __FILE__, __LINE__, data);
#endif

    sts = writep(FILDES, (char *)datap, len);
    if (sts < 0 ) {
	NSLog(@"%s(%d): writep() %s", __FILE__, __LINE__, strerror(errno));
    }
    else if (sts == 0) {
	[self brokenPipe];
    }
}

- (void)brokenPipe
{
    if ([DELEGATEOBJECT respondsToSelector:@selector(brokenPipe)]) {
	[DELEGATEOBJECT brokenPipe];
    }
}

- (void)sendSignal:(int)signo
{
    if (PID >= 0)
	kill(PID, signo);
}

- (void)setWidth:(int)width height:(int)height
{
    struct winsize winsize;

    if(FILDES == -1)
	return;

    ioctl(FILDES, TIOCGWINSZ, &winsize);
    winsize.ws_col = width;
    winsize.ws_row = height;
    ioctl(FILDES, TIOCSWINSZ, &winsize);
}

- (pid_t)pid
{
    return PID;
}

- (int)wait
{
    if (PID >= 0) 
	waitpid(PID, &STATUS, WNOHANG);

    return STATUS;
}

- (BOOL)exist
{
    BOOL result;

    if (WIFEXITED(STATUS))
	result = YES;
    else
	result = NO;

    return result;
}

- (void)stop
{
    [self sendSignal:SIGQUIT];
    [self wait];
}

- (void)stopNoWait
{
    [self sendSignal:SIGQUIT];
}

- (int)status
{
    return STATUS;
}

- (NSString *)tty
{
    return TTY;
}

- (NSString *)path
{
    return PATH;
}

- (BOOL)loggingStartWithPath:(NSString *)path
{
    [LOG_PATH autorelease];
    LOG_PATH = [[path stringByStandardizingPath ] copy];

    [LOG_HANDLE autorelease];
    LOG_HANDLE = [NSFileHandle fileHandleForWritingAtPath:LOG_PATH];
    if (LOG_HANDLE == nil) {
	NSFileManager *fm = [NSFileManager defaultManager];
	[fm createFileAtPath:LOG_PATH
		    contents:nil
		  attributes:nil];
	LOG_HANDLE = [NSFileHandle fileHandleForWritingAtPath:LOG_PATH];
    }
    [LOG_HANDLE retain];
    [LOG_HANDLE seekToEndOfFile];

    return LOG_HANDLE == nil ? NO:YES;
}

- (void)loggingStop
{
    [LOG_HANDLE closeFile];

    [LOG_PATH autorelease];
    [LOG_HANDLE autorelease];
    LOG_PATH = nil;
    LOG_HANDLE = nil;
}

- (BOOL)logging
{
    return LOG_HANDLE == nil ? NO : YES;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"PTYTask(pid %d, fildes %d)", PID, FILDES];
}

@end
