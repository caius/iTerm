// -*- mode:objc -*-
// $Id: VT100Terminal.m,v 1.4 2002-12-18 02:28:31 yfabian Exp $
//
//  VT100Terminal.m
//  JTerminal
//
//  Created by kuma on Thu Nov 22 2001.
//  Copyright (c) 2001 Kiichi Kusama. All rights reserved.
//

#import "VT100Terminal.h"
#import "NSStringITerm.h"

/*
  Traditional Chinese (Big5)
    1st   0xa1-0xfe
    2nd   0x40-0x7e || 0xa1-0xfe

  Simplifed Chinese (EUC_CN)
    1st   0x81-0xfe
    2nd   0x40-0x7e || 0x80-0xfe
*/

static NSString *NSBlinkAttributeName=@"NSBlinkAttributeName";

@implementation VT100Terminal

#define iscontrol(c)  (((c) <= 0x1f) || ((c) == 0x7f))

#define iseuccn(c)   ((c) >= 0x81 && (c) <= 0xfe)
#define isbig5(c)    ((c) >= 0xa1 && (c) <= 0xfe)
#define issjiskanji(c)  (((c) >= 0x81 && (c) <= 0x9f) ||  \
                         ((c) >= 0xe0 && (c) <= 0xef))
#define iseuckr(c)   ((c) >= 0xa1 && (c) <= 0xfe)

#define isGBEncoding(e) 	((e)==0x80000019||(e)==0x80000421|| \
                                 (e)==0x80000631||(e)==0x80000632|| \
                                 (e)==0x80000930)
#define isBig5Encoding(e) 	((e)==0x80000002||(e)==0x80000423|| \
                                 (e)==0x80000931||(e)==0x80000a03|| \
                                 (e)==0x80000a06)
#define isJPEncoding(e) 	((e)==0x80000001||(e)==0x8||(e)==0x15)
#define isSJISEncoding(e)	((e)==0x80000628||(e)==0x80000a01)
#define isKREncoding(e)		((e)==0x80000422||(e)==0x80000003|| \
                                 (e)==0x80000840||(e)==0x80000940)
#define ESC  0x1b
#define DEL  0x7f

#define CURSOR_SET_DOWN      "\033OB"
#define CURSOR_SET_UP        "\033OA"
#define CURSOR_SET_RIGHT     "\033OC"
#define CURSOR_SET_LEFT      "\033OD"
#define CURSOR_RESET_DOWN    "\033[B"
#define CURSOR_RESET_UP      "\033[A"
#define CURSOR_RESET_RIGHT   "\033[C"
#define CURSOR_RESET_LEFT    "\033[D"

#define KEY_INSERT           "\033[2~"
#define KEY_PAGE_UP          "\033[5~"
#define KEY_PAGE_DOWN        "\033[6~"
#define KEY_HOME             "\033[1~"
#define KEY_END              "\033[4~"
#define KEY_DEL		     "\033[3~"

#define KEY_FUNCTION_FORMAT  "\033[%d~"

#define REPORT_POSITION      "\033[%d;%dR"
#define REPORT_STATUS        "\033[0n"
#define REPORT_WHATAREYOU    "\033[?1;0c"
#define REPORT_VT52          "\033/Z"

#define conststr_sizeof(n)   ((sizeof(n)) - 1)


typedef struct {
    int p[VT100CSIPARAM_MAX];
    int count;
    int cmd;
    BOOL question;
} CSIParam;

static NSColor *DEFAULT_BLACK  = nil;
static NSColor *DEFAULT_RED    = nil;
static NSColor *DEFAULT_GREEN  = nil;
static NSColor *DEFAULT_YELLOW = nil;
static NSColor *DEFAULT_BLUE   = nil;
static NSColor *DEFAULT_PURPLE = nil;
static NSColor *DEFAULT_WATER  = nil;
static NSColor *DEFAULT_WHITE  = nil;

// functions
static BOOL isCSI(unsigned char *, size_t);
static BOOL isXTERM(unsigned char *, size_t);
static BOOL isString(unsigned char *, NSStringEncoding);
static size_t getCSIParam(unsigned char *, size_t, CSIParam *);
static VT100TCC decode_csi(unsigned char *, size_t, size_t *);
static VT100TCC decode_xterm(unsigned char *, size_t, size_t *,NSStringEncoding);
static VT100TCC decode_other(unsigned char *, size_t, size_t *);
static VT100TCC decode_control(unsigned char *, size_t, size_t *,NSStringEncoding);
static VT100TCC decode_ascii(unsigned char *, size_t, size_t *);
static int utf8_reqbyte(unsigned char);
static VT100TCC decode_utf8(unsigned char *, size_t, size_t *);
static VT100TCC decode_euccn(unsigned char *, size_t, size_t *);
static VT100TCC decode_big5(unsigned char *,size_t, size_t *);
static VT100TCC decode_string(unsigned char *, size_t, size_t *,
			      NSStringEncoding);


static BOOL isCSI(unsigned char *code, size_t len)
{
    if (len >= 2 && code[0] == ESC && (code[1] == '['))
	return YES;
    return NO;
}

static BOOL isXTERM(unsigned char *code, size_t len)
{
    if (len >= 2 && code[0] == ESC && (code[1] == ']'))
        return YES;
    return NO;
}

static BOOL isString(unsigned char *code,
		    NSStringEncoding encoding)
{
    BOOL result = NO;

//    NSLog(@"%@",[NSString localizedNameOfStringEncoding:encoding]);
    if (isascii(*code)) {
        result = YES;
    }
    else if (encoding== NSUTF8StringEncoding) {
        if (*code >= 0x80)
            result = YES;
    }
    else if (isGBEncoding(encoding)) {
        if (iseuccn(*code))
            result = YES;
    }
    else if (isBig5Encoding(encoding)) {
        if (isbig5(*code))
            result = YES;
    }
    else if (isJPEncoding(encoding)) {
        if (*code ==0x8e || *code==0x8f|| (*code>=0xa1&&*code<=0xfe))
            result = YES;
    }
    else if (isSJISEncoding(encoding)) {
        if (*code >= 0x80)
            result = YES;
    }
    else if (isKREncoding(encoding)) {
        if (iseuckr(*code))
            result = YES;
    }
    else if (*code>=0x20) {
        result = YES;
    }

    return result;
}

static size_t getCSIParam(unsigned char *datap,
			  size_t datalen,
			  CSIParam *param)
{
    int i;
    BOOL unrecognized=NO;
    unsigned char *orgp = datap;

    NSCParameterAssert(datap != NULL);
    NSCParameterAssert(datalen >= 2);
    NSCParameterAssert(param != NULL);

    param->count = 0;
    param->cmd = 0;
    for (i = 0; i < VT100CSIPARAM_MAX; ++i )
	param->p[i] = -1;

    NSCParameterAssert(datap[0] == ESC);
    NSCParameterAssert(datap[1] == '[');
    datap += 2;
    datalen -= 2;

    if (datalen > 0 && *datap == '?') {
	param->question = YES;
	datap ++;
	datalen --;
    }
    else
	param->question = NO;

    while (datalen > 0) {
	if (isdigit(*datap)) {
	    int n = *datap++ - '0';
	    datalen--;

	    while (datalen > 0 && isdigit(*datap)) {
		n = n * 10 + *datap - '0';

		datap++;
		datalen--;
	    }
	    if (param->count == 0 )
		param->count = 1;
	    param->p[param->count - 1] = n;
	}
	else if (*datap == ';') {
	    datap++;
	    datalen--;

	    param->count++;
	    if (param->count >= VT100CSIPARAM_MAX) {
		// broken
		//param->cmd = 0xff;
                unrecognized=YES;
		//break;
	    }
	}
	else if (isalpha(*datap)||*datap=='@') {
	    datalen--;
            param->cmd = unrecognized?0xff:*datap;
            *datap++;
	    break;
	}
	else {
            datalen--;
            *datap++;
            unrecognized=YES;
	}
    }
    return datap - orgp;
}

#define SET_PARAM_DEFAULT(pm,n,d) \
    (((pm).p[(n)] = (pm).p[(n)] < 0 ? (d):(pm).p[(n)]), \
     ((pm).count  = (pm).count > (n) + 1 ? (pm).count : (n) + 1 ))

static VT100TCC decode_csi(unsigned char *datap,
			   size_t datalen,
			   size_t *rmlen)
{
    VT100TCC result;
    CSIParam param;
    size_t paramlen;
    int i;

    paramlen = getCSIParam(datap, datalen, &param);
    if (paramlen > 0 && param.cmd > 0) {
        if (!param.question) {
            switch (param.cmd) {
                case 'D':		// Cursor Backward
                    result.type = VT100TCC_CUB;
                    SET_PARAM_DEFAULT(param, 0, 1);
                    break;

                case 'B':		// Cursor Down
                    result.type = VT100TCC_CUD;
                    SET_PARAM_DEFAULT(param, 0, 1);
                    break;

                case 'C':		// Cursor Forward
                    result.type = VT100TCC_CUF;
                    SET_PARAM_DEFAULT(param, 0, 1);
                    break;

                case 'A':		// Cursor Up
                    result.type = VT100TCC_CUU;
                    SET_PARAM_DEFAULT(param, 0, 1);
                    break;

                case 'H':
                    result.type = VT100TCC_CUP;
                    SET_PARAM_DEFAULT(param, 0, 1);
                    SET_PARAM_DEFAULT(param, 1, 1);
                    break;

                case 'c':
                    result.type = VT100TCC_DA;
                    SET_PARAM_DEFAULT(param, 0, 0);
                    break;

                case 'q':
                    result.type = VT100TCC_DECLL;
                    SET_PARAM_DEFAULT(param, 0, 0);
                    break;

                case 'x':
                    if (param.count == 1)
                        result.type = VT100TCC_DECREQTPARM;
                    else
                        result.type = VT100TCC_DECREPTPARM;
                    break;

                case 'r':
                    result.type = VT100TCC_DECSTBM;
                    SET_PARAM_DEFAULT(param, 0, 0);
                    SET_PARAM_DEFAULT(param, 1, 0);
                    break;

                case 'y':
                    if (param.count == 2)
                        result.type = VT100TCC_DECTST;
                    else
                        result.type = VT100TCC_NOTSUPPORT;
                    break;

                case 'n':
                    result.type = VT100TCC_DSR;
                    SET_PARAM_DEFAULT(param, 0, 0);
                    break;

                case 'J':
                    result.type = VT100TCC_ED;
                    SET_PARAM_DEFAULT(param, 0, 0);
                    break;

                case 'K':
                    result.type = VT100TCC_EL;
                    SET_PARAM_DEFAULT(param, 0, 0);
                    break;

                case 'f':
                    result.type = VT100TCC_HVP;
                    SET_PARAM_DEFAULT(param, 0, 1);
                    SET_PARAM_DEFAULT(param, 1, 1);
                    break;

                case 'l':
                    result.type = VT100TCC_RM;
                    break;

                case 'm':
                    result.type = VT100TCC_SGR;
                    for (i = 0; i < param.count; ++i)
                        SET_PARAM_DEFAULT(param, i, 0);
                        break;

                case 'h':
                    result.type = VT100TCC_SM;
                    break;

                case 'g':
                    result.type = VT100TCC_TBC;
                    SET_PARAM_DEFAULT(param, 0, 0);
                    break;

                    // these are xterm controls
                case '@':
                    result.type = XTERMCC_INSBLNK;
                    SET_PARAM_DEFAULT(param,0,1);
                    break;
                case 'L':
                    result.type = XTERMCC_INSLN;
                    SET_PARAM_DEFAULT(param,0,1);
                    break;
                case 'P':
                    result.type = XTERMCC_DELCH;
                    SET_PARAM_DEFAULT(param,0,1);
                    break;
                case 'M':
                    result.type = XTERMCC_DELLN;
                    SET_PARAM_DEFAULT(param,0,1);
                    break;

                default:
                    result.type = VT100TCC_NOTSUPPORT;
                    break;
            }
        }
        else {
            switch (param.cmd) {
                case 'h':		// Dec private mode set
                    result.type = VT100TCC_DECSET;
                    SET_PARAM_DEFAULT(param, 0, 0);
                    break;
                case 'l':		// Dec private mode reset
                    result.type = VT100TCC_DECRST;
                    SET_PARAM_DEFAULT(param, 0, 0);
                    break;
                default:
                    result.type = VT100TCC_NOTSUPPORT;
                    break;
                    
            }       
        }
	
	// copy CSI parameter
	for (i = 0; i < VT100CSIPARAM_MAX; ++i)
	    result.u.csi.p[i] = param.p[i];
	result.u.csi.count = param.count;
	result.u.csi.question = param.question;

	*rmlen = paramlen;
    }
    else {
	result.type = VT100TCC_WAIT;
    }
    return result;
}


static VT100TCC decode_xterm(unsigned char *datap,
                             size_t datalen,
                             size_t *rmlen,
                             NSStringEncoding enc)
{
    int mode=0;
    VT100TCC result;
    NSData *data;
    BOOL unrecognized=NO;
    char s[100]={0}, *c=nil;

    NSCParameterAssert(datap != NULL);
    NSCParameterAssert(datalen >= 2);
    NSCParameterAssert(datap[0] == ESC);
    NSCParameterAssert(datap[1] == ']');
    datap += 2;
    datalen -= 2;
    *rmlen=2;
    
    while (isdigit(*datap)) {
        int n = *datap++ - '0';
        datalen--;
        (*rmlen)++;
        while (datalen > 0 && isdigit(*datap)) {
            n = n * 10 + *datap - '0';

            (*rmlen)++;
            datap++;
            datalen--;
        }
        mode=n;
    }
    if (datalen>0) {
        if (*datap != ';') {
            unrecognized=YES;
        }
        else {
            c=s;
            datalen--;
            datap++;
            (*rmlen)++;
            while (*datap!=0x007&&c-s<100&&datalen>0) {
                *c=*datap;
                datalen--;
                datap++;
                (*rmlen)++;
                c++;
            }
            if (*datap!=0x007) {
                if (datalen>0) unrecognized=YES;
                else {
                    *rmlen=0;
                }
            }
            else {
                *datap++;
                datalen--;
                (*rmlen)++;
            }
        }
    }
    else {
        *rmlen=0;
    }

    if (unrecognized||!(*rmlen)) {
        result.type = VT100TCC_WAIT;
        NSLog(@"invalid: %d",*rmlen);
    }
    else {
        data = [NSData dataWithBytes:s length:c-s];
        result.u.string = [[[NSString alloc] initWithData:data
                                                 encoding:enc] autorelease];
        result.type = XTERMCC_TITLE;
//        NSLog(@"result: %d[%@],%d",result.type,result.u.string,*rmlen);
    }

    return result;
}

static VT100TCC decode_other(unsigned char *datap,
			     size_t datalen,
			     size_t *rmlen)
{
    VT100TCC result;
    int c1, c2, c3;

    NSCParameterAssert(datap[0] == ESC);
    NSCParameterAssert(datalen > 1);

    c1 = (datalen >= 2 ? datap[1]: -1);
    c2 = (datalen >= 3 ? datap[2]: -1);
    c3 = (datalen >= 4 ? datap[3]: -1);

    switch (c1) {
    case '#':  
	if (c2 < 0) {
	    result.type = VT100TCC_WAIT;
	}
	else {
	    result.type = VT100TCC_NOTSUPPORT;
	    *rmlen = 2;
	}
	break;

    case '=':
	result.type = VT100TCC_DECKPAM;
	*rmlen = 2;
	break;

    case '>':
	result.type = VT100TCC_DECKPNM;
	*rmlen = 2;
	break;

    case ')': case '(':
	if (c2 < 0 || c3 < 0) {
	    result.type = VT100TCC_WAIT;
	}
	else {
	    result.type = VT100TCC_NOTSUPPORT;
	    *rmlen = 3;
	}
	break;

    case '8':
	result.type = VT100TCC_DECRC;
	*rmlen = 2;
	break;

    case '7':
	result.type = VT100TCC_DECSC;
	*rmlen = 2;
	break;

    case 'D':
	result.type = VT100TCC_IND;
	*rmlen = 2;
	break;

    case 'E':
	result.type = VT100TCC_NEL;
	*rmlen = 2;
	break;

    case 'H':
	result.type = VT100TCC_HTS;
	*rmlen = 2;
	break;

    case 'M':
	result.type = VT100TCC_RI;
	*rmlen = 2;
	break;

    case 'Z': 
	result.type = VT100TCC_DECID;
	*rmlen = 2;
	break;

    case 'c':
	result.type = VT100TCC_RIS;
	*rmlen = 2;
	break;

    default:
	result.type = VT100TCC_NOTSUPPORT;
	*rmlen = 2;
	break;
    }

    return result;
}

static VT100TCC decode_control(unsigned char *datap,
			       size_t datalen,
			       size_t *rmlen,
                               NSStringEncoding enc)
{
    VT100TCC result;

    if (isCSI(datap, datalen)) {
	result = decode_csi(datap, datalen, rmlen);
    }
    else if (isXTERM(datap,datalen)) {
        result = decode_xterm(datap,datalen,rmlen,enc);
    }
    else {
	NSCParameterAssert(datalen > 0);

	switch ( *datap ) {
	case 0:
	    result.type = VT100TCC_SKIP;
	    *rmlen = 0;
	    while (datalen > 0 && *datap == '\0') {
		++datap;
		--datalen;
		++ *rmlen;
	    }
	    break;

	case ESC:
	    if (datalen == 1) {
		result.type = VT100TCC_WAIT;
	    }
	    else {
		result = decode_other(datap, datalen, rmlen);
	    }
	    break;

	case '\n':
	    result.type = VT100TCC_LF;
	    *rmlen = 1;
	    break;

	case '\r':
	    result.type = VT100TCC_CR;
	    *rmlen = 1;
	    break;

        case 0x07:
            result.type = VT100TCC_BELL;
	    *rmlen = 1;
            break;

	case 0x08:
	    result.type = VT100TCC_BS;
	    *rmlen = 1;
	    break;

	case 0x09:
	    result.type = VT100TCC_TAB;
	    *rmlen = 1;
	    break;

	case 0x7f:
	    result.type = VT100TCC_DEL;
	    *rmlen = 1;
	    break;

	default:
	    result.type = VT100TCC_UNKNOWNCHAR;
	    *rmlen = 1;
	    break;
	}
    }
    return result;
}

static VT100TCC decode_ascii(unsigned char *datap,
			     size_t datalen,
			     size_t *rmlen)
{
    unsigned char *last = datap;
    size_t len = datalen;
    VT100TCC result;

    while (len > 0 && *last >= 0x20 && *last < 0x7f) {
	++last;
	--len;
    }

    *rmlen = datalen - len;
    result.type = VT100TCC_STRING;
    result.u.string = [NSString stringWithCString:datap length:*rmlen];
    
    return result;
}


static int utf8_reqbyte(unsigned char f)
{
    int result;

    if (isascii(f))
        result = 1;
    else if ((f & 0xe0) == 0xc0)
        result = 2;
    else if ((f & 0xf0) == 0xe0)
        result = 3;
    else if ((f & 0xf8) == 0xf0)
        result = 4;
    else if ((f & 0xfc) == 0xf8)
        result = 5;
    else 
        result = 6;

    return result;
}

static VT100TCC decode_utf8(unsigned char *datap,
                            size_t datalen ,
                            size_t *rmlen)
{
    VT100TCC result;
    unsigned char *p = datap;
    size_t len = datalen;
    int reqbyte;

    while (len > 0) {
        if (*p>=0x20&&*p<0x7f) {
            p++;
            len--;
        }
        else if (*p>=0x80) {
            reqbyte = utf8_reqbyte(*datap);
            if (len>reqbyte) {
                p += reqbyte;
                len -= reqbyte;
            }
            else break;
        }
        else break;
    }
    if (len == datalen) {
        *rmlen = 0;
        result.type = VT100TCC_WAIT;
    }
    else {
        *rmlen = datalen - len;
        result.type = VT100TCC_STRING;
    }

    return result;
 
  
}


static VT100TCC decode_euccn(unsigned char *datap,
			     size_t datalen,
			     size_t *rmlen)
{
    VT100TCC result;
    unsigned char *p = datap;
    size_t len = datalen;


    while (len > 0) {
        if (*p>=0x20&&*p<0x7f) {
            p++;
            len--;
        }
        else if (iseuccn(*p)&&len>1) {
            if ((*(p+1)>=0x40&&*(p+1)<=0x7e)||*(p+1)>=0x80&&*(p+1)<=0xfe) {
                p += 2;
                len -= 2;
            }
            else {
                *p='?';
                p++;
                len--;
            }
        }
        else break;
    }
    if (len == datalen) {
	*rmlen = 0;
	result.type = VT100TCC_WAIT;
    }
    else {
	*rmlen = datalen - len;
	result.type = VT100TCC_STRING;
    }

    return result;
}

static VT100TCC decode_big5(unsigned char *datap,
			    size_t datalen,
			    size_t *rmlen)
{
    VT100TCC result;
    unsigned char *p = datap;
    size_t len = datalen;
    
    while (len > 0) {
        if (*p>=0x20&&*p<0x7f) {
            p++;
            len--;
        }
        else if (isbig5(*p)&&len>1) {
            if ((*(p+1)>=0x40&&*(p+1)<=0x7e)||*(p+1)>=0xa1&&*(p+1)<=0xfe) {
                p += 2;
                len -= 2;
            }
            else {
                *p='?';
                p++;
                len--;
            }
        }
        else break;
    }
    if (len == datalen) {
	*rmlen = 0;
	result.type = VT100TCC_WAIT;
    }
    else {
	*rmlen = datalen - len;
	result.type = VT100TCC_STRING;
    }

    return result;
}

static VT100TCC decode_euc_jp(unsigned char *datap,
                                   size_t datalen ,
                                   size_t *rmlen)
{
    VT100TCC result;
    unsigned char *p = datap;
    size_t len = datalen;

    while (len > 0) {
        if (*p>=0x20&&*p<0x7f) {
            p++;
            len--;
        }
        else if  (len > 1 && *p == 0x8e) {
                p += 2;
                len -= 2;
        }
        else if (len > 2  && *p == 0x8f ) {
            p += 3;
            len -= 3;
        }
        else if (len > 1 && *p >= 0xa1 && *p <= 0xfe ) {
            p += 2;
            len -= 2;
        }
        else break;
    }
    if (len == datalen) {
        *rmlen = 0;
        result.type = VT100TCC_WAIT;
    }
    else {
        *rmlen = datalen - len;
        result.type = VT100TCC_STRING;
    }

    return result;
}


static VT100TCC decode_sjis(unsigned char *datap,
                                  size_t datalen ,
                                  size_t *rmlen)
{
    VT100TCC result;
    unsigned char *p = datap;
    size_t len = datalen;

    while (len > 0) {
        if (*p>=0x20&&*p<0x7f) {
            p++;
            len--;
        }
        else if (issjiskanji(*p)&&len>1) {
            p += 2;
            len -= 2;
        }
        else if (*p>=0x80) {
            p++;
            len--;
        }
        else break;
    }

    if (len == datalen) {
        *rmlen = 0;
        result.type = VT100TCC_WAIT;
    }
    else {
        *rmlen = datalen - len;
        result.type = VT100TCC_STRING;
    }

    return result;
}


static VT100TCC decode_euckr(unsigned char *datap,
                             size_t datalen,
                             size_t *rmlen)
{
    VT100TCC result;
    unsigned char *p = datap;
    size_t len = datalen;

    while (len > 0) {
        if (*p>=0x20&&*p<0x7f) {
            p++;
            len--;
        }
        else if (iseuckr(*p)&&len>1) {
                p += 2;
                len -= 2;
        }
        else break;
    }
    if (len == datalen) {
        *rmlen = 0;
        result.type = VT100TCC_WAIT;
    }
    else {
        *rmlen = datalen - len;
        result.type = VT100TCC_STRING;
    }

    return result;
}

static VT100TCC decode_other_enc(unsigned char *datap,
                             size_t datalen,
                             size_t *rmlen)
{
    VT100TCC result;
    unsigned char *p = datap;
    size_t len = datalen;

    while (len > 0) {
        if (*p>=0x20) {
            p++;
            len--;
        }
        else break;
    }
    if (len == datalen) {
        *rmlen = 0;
        result.type = VT100TCC_WAIT;
    }
    else {
        *rmlen = datalen - len;
        result.type = VT100TCC_STRING;
    }

    return result;
}

static VT100TCC decode_string(unsigned char *datap,
			     size_t datalen,
			     size_t *rmlen,
			     NSStringEncoding encoding)
{
    VT100TCC result;
    NSData *data;

    *rmlen = 1;
    result.type = VT100TCC_UNKNOWNCHAR;
    result.u.code = datap[0];

//    NSLog(@"data: %@",[NSData dataWithBytes:datap length:datalen]);
    if (encoding == NSUTF8StringEncoding) {
        result = decode_utf8(datap, datalen, rmlen);
    }
//    else if (encoding == 0x80000930) {
    else if (isGBEncoding(encoding)) {
//        NSLog(@"Chinese-GB!");
        result = decode_euccn(datap, datalen, rmlen);
    }
    else if (isBig5Encoding(encoding)) {
        result = decode_big5(datap, datalen, rmlen);
    }
    else if (isJPEncoding(encoding)) {
//        NSLog(@"decoding euc-jp");
        result = decode_euc_jp(datap, datalen, rmlen);
    }
    else if (isSJISEncoding(encoding)) {
//        NSLog(@"decoding j-jis");
        result = decode_sjis(datap, datalen, rmlen);
    }
    else if (isKREncoding(encoding)) {
//        NSLog(@"decoding korean");
        result = decode_euckr(datap, datalen, rmlen);
    }
    else {
//        NSLog(@"%s(%d):decode_string()-support character encoding(%@d)",
//              __FILE__, __LINE__, [NSString localizedNameOfStringEncoding:encoding]);
        result = decode_other_enc(datap, datalen, rmlen);
    }

    if (result.type != VT100TCC_WAIT) {
        data = [NSData dataWithBytes:datap length:*rmlen];
        result.u.string = [[[NSString alloc]
                                   initWithData:data
                                       encoding:encoding]
            autorelease];

        if (result.u.string==nil) {
            NSLog(@"Null:%@",data);
        }
    }
    return result;
}

+ (void)initialize
{
    DEFAULT_BLACK  = [[NSColor blackColor] retain];
    DEFAULT_RED    = [[NSColor redColor] retain];
    DEFAULT_GREEN  = [[NSColor colorWithCalibratedRed:0.0f
						green:0.8f
						 blue:0.0f 
						alpha:1.0f] 
			 retain];
    DEFAULT_YELLOW = [[NSColor yellowColor] retain];
    DEFAULT_BLUE   = [[NSColor blueColor] retain];
    DEFAULT_PURPLE = [[NSColor purpleColor] retain];
    DEFAULT_WATER  = [[NSColor colorWithCalibratedRed:0.5f
						green:0.5f 
						 blue:1.0f
						alpha:1.0f]
			 retain];
    DEFAULT_WHITE  = [[NSColor whiteColor] retain];
}

- (id)init
{
    if ([super init] == nil)
	return nil;

    ENCODING = NSASCIIStringEncoding;
    STREAM   = [[NSMutableData data] retain];
    COLOR_BLACK  = [DEFAULT_BLACK copy];
    COLOR_RED    = [DEFAULT_RED copy];
    COLOR_GREEN  = [DEFAULT_GREEN copy];
    COLOR_YELLOW = [DEFAULT_YELLOW copy];
    COLOR_BLUE   = [DEFAULT_BLUE copy];
    COLOR_PURPLE = [DEFAULT_PURPLE copy];
    COLOR_WATER  = [DEFAULT_WATER copy];
    COLOR_WHITE  = [DEFAULT_WHITE copy];

    LINE_MODE = NO;
    CURSOR_MODE = NO;
    COLUMN_MODE = NO;
    SCROLL_MODE = NO;
    SCREEN_MODE = NO;
    ORIGIN_MODE = NO;
    WRAPAROUND_MODE = NO;
    AUTOREPEAT_MODE = NO;
    INTERLACE_MODE = NO;
    KEYPAD_MODE = NO;
    INSERT_MODE = NO;
    CHARATTR = 0;
    FG_COLORCODE = COLORCODE_FG_DEFAULT;
    BG_COLORCODE = COLORCODE_BG_DEFAULT;
    DefaultFG = COLOR_WHITE;
    DefaultBG = COLOR_BLACK;

    TRACE = NO;

    return self;
}

- (void)dealloc
{
    [STREAM autorelease];

    [super dealloc];
}

- (BOOL)trace
{
    return TRACE;
}

- (void)setTrace:(BOOL)flag
{
    TRACE = flag;
}

- (NSStringEncoding)encoding
{
    return ENCODING;
}

- (void)setEncoding:(NSStringEncoding)encoding
{
    ENCODING = encoding;
}

- (void)cleanStream
{
    [STREAM autorelease];
    STREAM = [[NSMutableData data] retain];
}

- (void)putStreamData:(NSData *)data
{
    [STREAM appendData:data];
}

- (VT100TCC)getNextToken
{
    unsigned char *datap;
    size_t datalen;
    VT100TCC result;

#if 0
    NSLog(@"buffer data = %@", STREAM);
#endif
    datap = (unsigned char *)[STREAM bytes];
    datalen = (size_t)[STREAM length];

    if (datalen == 0) {
	result.type = VT100TCC_NULL;
    }
    else {
	size_t rmlen = 0;

	if (iscontrol(datap[0])) {
	    result = decode_control(datap, datalen, &rmlen, ENCODING);
	}
	else {
	    if (isString(datap,ENCODING)) {
		result = decode_string(datap, datalen, &rmlen, ENCODING);
	    }
	    else {
		result.type = VT100TCC_UNKNOWNCHAR;
		result.u.code = datap[0];
		rmlen = 1;
	    }
	}

	if (rmlen > 0) {
	    NSParameterAssert(datalen - rmlen >= 0);
	    if (TRACE && result.type == VT100TCC_UNKNOWNCHAR) {
//		NSLog(@"INPUT-BUFFER %@, read %d byte, type %d", 
//                      STREAM, rmlen, result.type);
	    }
	    [STREAM autorelease];
	    STREAM = [[NSMutableData dataWithBytes:&(datap[rmlen]) 
					    length:datalen - rmlen] 
			 retain];
	}
    }

    [self _setMode:result];
    [self _setCharAttr:result];

    return result;
}

- (NSData *)keyArrowUp
{
    if (CURSOR_MODE) 
	return [NSData dataWithBytes:CURSOR_SET_UP
			      length:conststr_sizeof(CURSOR_SET_UP)];
    else
	return [NSData dataWithBytes:CURSOR_RESET_UP
			      length:conststr_sizeof(CURSOR_RESET_UP)];
}

- (NSData *)keyArrowDown
{
    if (CURSOR_MODE) 
	return [NSData dataWithBytes:CURSOR_SET_DOWN
			      length:conststr_sizeof(CURSOR_SET_DOWN)];
    else
	return [NSData dataWithBytes:CURSOR_RESET_DOWN
			      length:conststr_sizeof(CURSOR_RESET_DOWN)];
}

- (NSData *)keyArrowLeft
{
    if (CURSOR_MODE) 
	return [NSData dataWithBytes:CURSOR_SET_LEFT
			      length:conststr_sizeof(CURSOR_SET_LEFT)];
    else
	return [NSData dataWithBytes:CURSOR_RESET_LEFT
			      length:conststr_sizeof(CURSOR_RESET_LEFT)];
}

- (NSData *)keyArrowRight
{
    if (CURSOR_MODE) 
	return [NSData dataWithBytes:CURSOR_SET_RIGHT
			      length:conststr_sizeof(CURSOR_SET_RIGHT)];
    else
	return [NSData dataWithBytes:CURSOR_RESET_RIGHT
			      length:conststr_sizeof(CURSOR_RESET_RIGHT)];
}

- (NSData *)keyInsert
{
    return [NSData dataWithBytes:KEY_INSERT length:conststr_sizeof(KEY_INSERT)];
}

- (NSData *)keyHome
{
    return [NSData dataWithBytes:KEY_HOME length:conststr_sizeof(KEY_HOME)];
}

- (NSData *)keyDelete
{
//    unsigned char del = 0x7f;
//    return [NSData dataWithBytes:&del length:1];
    return [NSData dataWithBytes:KEY_DEL length:conststr_sizeof(KEY_DEL)];
}

- (NSData *)keyEnd
{
    return [NSData dataWithBytes:KEY_END length:conststr_sizeof(KEY_END)];
}

- (NSData *)keyPageUp
{
    return [NSData dataWithBytes:KEY_PAGE_UP 
		   length:conststr_sizeof(KEY_PAGE_UP)];
}

- (NSData *)keyPageDown
{
    return [NSData dataWithBytes:KEY_PAGE_DOWN 
		   length:conststr_sizeof(KEY_PAGE_DOWN)];
}

- (NSData *)keyFunction:(int)no
{
    char str[256];
    size_t len;

    sprintf(str, KEY_FUNCTION_FORMAT, no + 10);
    len = strlen(str);
    return [NSData dataWithBytes:str length:len];
}

- (BOOL)lineMode
{
    return LINE_MODE;
}

- (BOOL)cursorMode
{
    return CURSOR_MODE;
}

- (BOOL)columnMode
{
    return COLUMN_MODE;
}

- (BOOL)scrollMode
{
    return SCROLL_MODE;
}

- (BOOL)screenMode
{
    return SCREEN_MODE;
}

- (BOOL)originMode
{
    return ORIGIN_MODE;
}

- (BOOL)wraparoundMode
{
    return WRAPAROUND_MODE;
}

- (BOOL)autorepeatMode
{
    return AUTOREPEAT_MODE;
}

- (BOOL)interlaceMode
{
    return INTERLACE_MODE;
}

- (BOOL)keypadMode
{
    return KEYPAD_MODE;
}

- (BOOL)insertMode
{
    return INSERT_MODE;
}

- (int)foregroundColorCode
{
    return FG_COLORCODE;
}

- (int)backgroundColorCode
{
    return BG_COLORCODE;
}

- (NSColor *)blackColor
{
    return COLOR_BLACK;
}

- (NSColor *)redColor
{
    return COLOR_RED;
}

- (NSColor *)greenColor
{
    return COLOR_GREEN;
}

- (NSColor *)yellowColor
{
    return COLOR_YELLOW;
}

- (NSColor *)blueColor
{
    return COLOR_BLUE;
}

- (NSColor *)purpleColor
{
    return COLOR_PURPLE;
}

- (NSColor *)waterColor
{
    return COLOR_WATER;
}

- (NSColor *)whiteColor
{
    return COLOR_WHITE;
}

- (NSColor *)colorWithCode:(int)code
{
    NSColor *result = nil;

    switch (code) {
    case COLORCODE_BLACK:   result = DEFAULT_BLACK; break;
    case COLORCODE_RED:     result = DEFAULT_RED; break;
    case COLORCODE_GREEN:   result = DEFAULT_GREEN; break;
    case COLORCODE_YELLOW:  result = DEFAULT_YELLOW; break;
    case COLORCODE_BLUE:    result = DEFAULT_BLUE; break;
    case COLORCODE_PURPLE:  result = DEFAULT_PURPLE; break;
    case COLORCODE_WATER:   result = DEFAULT_WATER; break;
    case COLORCODE_WHITE:   result = DEFAULT_WHITE; break;
    case COLORCODE_FG_DEFAULT: result = DefaultFG; break;
    case COLORCODE_BG_DEFAULT: result = DefaultBG; break;
    }

    NSParameterAssert(result != nil);

    return result;
}

- (NSData *)reportActivePositionWithX:(int)x Y:(int)y
{
    char buf[64];

    snprintf(buf, sizeof(buf), REPORT_POSITION, y, x);

    return [NSData dataWithBytes:buf length:strlen(buf)];
}

- (NSData *)reportStatus
{
    return [NSData dataWithBytes:REPORT_STATUS
			  length:conststr_sizeof(REPORT_STATUS)];
}

- (NSData *)reportDeviceAttribute
{
    return [NSData dataWithBytes:REPORT_WHATAREYOU
			  length:conststr_sizeof(REPORT_WHATAREYOU)];
}

- (unsigned int)characterAttribute
{
    return CHARATTR;
}

- (NSMutableDictionary *)characterAttributeDictionary
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    int under = 0,blink=0;
    NSParameterAssert(dic != nil);

    if (CHARATTR & VT100CHARATTR_BOLDMASK)
	;
    if (CHARATTR & VT100CHARATTR_UNDERMASK )
	under = 1;
    if (CHARATTR & VT100CHARATTR_BLINKMASK )
	blink = 1;
    if (CHARATTR & VT100CHARATTR_REVERSEMASK ) {
	[dic setObject:[self colorWithCode:BG_COLORCODE]
		forKey:NSForegroundColorAttributeName];
	[dic setObject:[self colorWithCode:FG_COLORCODE]
		forKey:NSBackgroundColorAttributeName];
    }
    else {
	[dic setObject:[self colorWithCode:FG_COLORCODE]
		forKey:NSForegroundColorAttributeName];
	[dic setObject:[self colorWithCode:BG_COLORCODE]
		forKey:NSBackgroundColorAttributeName];
    }

    [dic setObject:[NSNumber numberWithInt:under]
	    forKey:NSUnderlineStyleAttributeName];
    [dic setObject:[NSNumber numberWithInt:blink]
                   forKey:NSBlinkAttributeName];

    return dic;
}

- (void)_setMode:(VT100TCC)token
{

    if (token.type == VT100TCC_DECSET ||
	token.type == VT100TCC_DECRST) 
    {
	BOOL mode=(token.type == VT100TCC_DECSET);

	switch (token.u.csi.p[0]) {
	case 20: LINE_MODE = mode; break;
	case 1:  CURSOR_MODE = mode; break;
	case 3:  COLUMN_MODE = mode; break;
	case 4:  SCROLL_MODE = mode; break;
	case 5:  SCREEN_MODE = mode; break;
	case 6:  ORIGIN_MODE = mode; break;
	case 7:  WRAPAROUND_MODE = mode; break;
	case 8:  AUTOREPEAT_MODE = mode; break;
	case 9:  INTERLACE_MODE  = mode; break;
	}
    }
    else if (token.type == VT100TCC_SM||token.type==VT100TCC_RM) {
        BOOL mode=(token.type == VT100TCC_SM);

        switch (token.u.csi.p[0]) {
            case 4:
                INSERT_MODE = mode; break;
        }
    }
    else if (token.type == VT100TCC_DECKPAM)
	KEYPAD_MODE = YES;
    else if (token.type == VT100TCC_DECKPNM)
	KEYPAD_MODE = NO;
}

- (void)_setCharAttr:(VT100TCC)token
{
    if (token.type == VT100TCC_SGR) {

        if (token.u.csi.count == 0) {
            // all attribute off
            CHARATTR = 0;       
	    FG_COLORCODE = COLORCODE_FG_DEFAULT;
	    BG_COLORCODE = COLORCODE_BG_DEFAULT;
        }
        else {
            int i;
            for (i = 0; i < token.u.csi.count; ++i) {
                int n = token.u.csi.p[i];
                switch (n) {
                case VT100CHARATTR_ALLOFF:
                    // all attribute off
                    CHARATTR = 0;
		    FG_COLORCODE = COLORCODE_FG_DEFAULT;
		    BG_COLORCODE = COLORCODE_BG_DEFAULT;
                    break;

                case VT100CHARATTR_BOLD: 
                    CHARATTR |= VT100CHARATTR_BOLDMASK;
                    break;
                case VT100CHARATTR_UNDER:
                    CHARATTR |= VT100CHARATTR_UNDERMASK;
                    break;
                case VT100CHARATTR_BLINK:
                    CHARATTR |= VT100CHARATTR_BLINKMASK;
                    break;
                case VT100CHARATTR_REVERSE:
                    CHARATTR |= VT100CHARATTR_REVERSEMASK;
                    break;

		case VT100CHARATTR_FG_BLACK:
                    FG_COLORCODE = COLORCODE_BLACK;
                    break;
		case VT100CHARATTR_FG_DEFAULT:
                    FG_COLORCODE = COLORCODE_FG_DEFAULT;
		    break;
		case VT100CHARATTR_FG_RED:
		    FG_COLORCODE = COLORCODE_RED;
		    break;
		case VT100CHARATTR_FG_GREEN:
		    FG_COLORCODE = COLORCODE_GREEN;
		    break;
		case VT100CHARATTR_FG_YELLOW:
		    FG_COLORCODE = COLORCODE_YELLOW;
		    break;
		case VT100CHARATTR_FG_BLUE:
		    FG_COLORCODE = COLORCODE_BLUE;
		    break;
		case VT100CHARATTR_FG_PURPLE:
		    FG_COLORCODE = COLORCODE_PURPLE;
		    break;
		case VT100CHARATTR_FG_WATER:
		    FG_COLORCODE = COLORCODE_WATER;
		    break;
		case VT100CHARATTR_FG_WHITE:
		    FG_COLORCODE = COLORCODE_WHITE;
		    break;

		case VT100CHARATTR_BG_BLACK:
		    BG_COLORCODE = COLORCODE_BLACK;
		    break;
		case VT100CHARATTR_BG_RED:
		    BG_COLORCODE = COLORCODE_RED;
		    break;
		case VT100CHARATTR_BG_GREEN:
		    BG_COLORCODE = COLORCODE_GREEN;
		    break;
		case VT100CHARATTR_BG_YELLOW:
		    BG_COLORCODE = COLORCODE_YELLOW;
		    break;
		case VT100CHARATTR_BG_BLUE:
		    BG_COLORCODE = COLORCODE_BLUE;
		    break;
		case VT100CHARATTR_BG_PURPLE:
		    BG_COLORCODE = COLORCODE_PURPLE;
		    break;
		case VT100CHARATTR_BG_WATER:
		    BG_COLORCODE = COLORCODE_WATER;
		    break;
		case VT100CHARATTR_BG_DEFAULT:
                    BG_COLORCODE = COLORCODE_BG_DEFAULT;
                    break;
                case VT100CHARATTR_BG_WHITE:
		    BG_COLORCODE = COLORCODE_WHITE;
		    break;
                }
            }
        }
    }
}

- (void) setFGColor:(NSColor*)color
{
    [DefaultFG autorelease];
    DefaultFG=[color copy];
}

- (void) setBGColor:(NSColor*)color
{
    [DefaultBG autorelease];
    DefaultBG=[color copy];
}

- (NSColor *) defaultFGColor
{
    return DefaultFG;
}

- (NSColor *) defaultBGColor
{
    return DefaultBG;
}

@end
