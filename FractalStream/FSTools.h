//
//  FSTools.h
//  FractalStream
//
//  Created by Matt Noonan on 3/17/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FSViewport.h"
#import "FSCursors.h"
#import "FSSession.h"
#import "FSViewer.h"
#import "FSTool.h"

#ifndef FSTool_Type_Definitions
#define FSTool_Type_Definitions
#define FSTool_Parametric	1
#define FSTool_Dynamical	2
#define FSTool_Real			3
#define FSTool_Complex		4
#endif

@interface FSTools : NSObject {

	IBOutlet FSViewer* viewport;
	IBOutlet NSPopUpButton* popupMenu;
	IBOutlet NSTextField* coordinates;
	IBOutlet FSSession* theSession;
	IBOutlet id theBrowser;
	IBOutlet NSTextField* periodField;
	IBOutlet NSTextField* stepsBox;
	
	id <FSTool> theTool;
	NSBundle* toolbundle;	
	NSMutableArray* toolClasses;
	NSMutableArray* tools;
	id <FSTool> * tool;
	int currentTool;
	BOOL toolsLoaded;
	
	NSPoint savedTrace[9];
	int traces, traceSteps;
	NSPoint lastTrace;
	float wheel[8][3];
	int builtInTools;
	
	NSPoint lastClick;
	NSCursor* currentCursor;
	BOOL ignoreMouseUp;
	BOOL inDrag;
}

- (IBAction) resetTrace: (id) sender;
- (IBAction) registerTrace: (id) sender;
- (IBAction) setupMenu: (id) sender;
- (IBAction) configure: (id) sender;
- (IBAction) goForward: (id) sender;
- (IBAction) goBackward: (id) sender;
- (IBAction) changeTool: (id) sender;
- (void) setSession: (FSSession*) newSession;

@end
