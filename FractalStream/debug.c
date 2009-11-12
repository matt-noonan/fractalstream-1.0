/*
 *  debug.c
 *  FractalStream
 *
 *  Created by M Noonan on 11/12/09.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */

#include "debug.h"


#ifndef DEBUGGING
void inline Debug(void* s, ...) { }
#else
#define Debug NSLog
#endif

#ifndef WINDOWS
//	void inline WinLog(void* s, ...) { }
#define WinLog NSLog
#else
#define WinLog NSLog
#endif
