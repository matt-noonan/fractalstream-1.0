//
//  FSColorLibraryController.h
//  FractalStream
//
//  Created by Matthew Noonan on 1/27/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FSColor.h"



@interface FSColorLibraryController : NSObject {
	NSMutableArray* library;
	IBOutlet FSGradientControl* editor;
	IBOutlet NSOutlineView* outline;
	IBOutlet NSPopUpButton* button;
	int index;
}

- (IBAction) newColor: (id) sender;
- (IBAction) deleteColor: (id) sender;
- (IBAction) changeColor: (id) sender;
- (IBAction) loadColorLibrary: (id) sender;
- (void) saveColor: (FSGradient*) grad;
- (void) outlineSelectedColor: (NSNotification*) note;
- (int) outlineView: (NSOutlineView*) outlineView numberOfChildrenOfItem: (id) item;
- (BOOL) outlineView: (NSOutlineView*) outlineView isItemExpandable: (id) item;
- (id) outlineView: (NSOutlineView*) outlineView child: (int) index ofItem: (id) item;
- (id) outlineView: (NSOutlineView*) outlineView objectValueForTableColumn: (NSTableColumn*) col byItem: (id) item;
- (void) outlineView: (NSOutlineView*) outlineView setObjectValue: (id) val forTableColumn: (NSTableColumn*) col byItem: (id) item;


@end
