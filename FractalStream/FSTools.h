//
//  FSTools.h
//  FractalStream
//
//  Created by Matt Noonan on 3/17/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <stdlib.h>
#import <string.h>
#import "FSCursors.h"
#import "FSSession.h"
#import "FSViewer.h"
#import "FSTool.h"
#import "FSCustomDataManager.h"

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
	IBOutlet NSTextField* probeTextField;
	IBOutlet FSSession* theSession;
	IBOutlet id <FSBrowserProtocol> theBrowser;
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
	int probeTools;
	
	NSPoint lastClick;
	NSCursor* currentCursor;
	BOOL ignoreMouseUp;
	BOOL inDrag;
	
	FSCustomDataManager* dataManager;
}

- (IBAction) resetTrace: (id) sender;
- (IBAction) registerTrace: (id) sender;
- (IBAction) setupMenu: (id) sender;
- (IBAction) configure: (id) sender;
- (IBAction) changeTool: (id) sender;
- (void) setSession: (FSSession*) newSession;
- (void) updateMenuForParametric: (BOOL) isPar;
- (void) addTools: (NSFileWrapper*) toolWrapper;
- (void) setDataManager: (FSCustomDataManager*) dm;

@end
