//
//  FSBrowser.h
//  FractalStream
//
//  Created by Matt Noonan on 11/25/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <stdlib.h>
#import <string.h>
#import <dlfcn.h>
#import "FSTools.h"
#import "FSViewer.h"
#import "FSSession.h"


@interface FSBrowser : NSObject {
	IBOutlet FSViewer* theViewer;
	IBOutlet FSViewer* preview;
	IBOutlet FSViewer* historyView;
	FSViewerData viewerData;
	FSViewerData previewData;
	FSViewerData historyData;
	FSViewerData rootData;
	void (*kernel)(int, double*, int, double*, int, double, double);
	void (*kernel1)(int, double*, int, double*, int, double, double);
	void (*kernel2)(int, double*, int, double*, int, double, double);
	void (*kernel3)(int, double*, int, double*, int, double, double);
	
	IBOutlet FSTools* theTools;
	IBOutlet FSSession* theSession;
	
	IBOutlet NSPopUpButton* programBox;
	IBOutlet NSTextField* iterBox;
	IBOutlet NSTextField* radiusBox;
	IBOutlet NSTextField* minRadiusBox;
	IBOutlet NSButton* detailBox;
	IBOutlet NSTextField* aspectBox;
	IBOutlet FSColorWidget* colorWidget;
	
	NSArray* variableNames;
	NSArray* realPart;
	NSArray* imagPart;
	int uniqueVariableNames;
	
	BOOL configured;
}

- (IBAction) goForward: (id) sender;
- (IBAction) goBackward: (id) sender;
- (IBAction) refresh: (id) sender;
- (IBAction) goHome: (id) sender;
- (void) changeToName: (NSString*) newName X: (double) x Y: (double) y center: (double) center parametric: (BOOL) isPar;
- (void) reloadSession;
- (FSSession*) session;
- (void) setVariableNamesTo: (NSArray*) names;

- (int) numberOfRowsInTableView: (NSTableView*) tableView;
- (id) tableView: (NSTableView*) tableView objectValueForTableColumn: (NSTableColumn*) tableColumn row: (int) row;
- (id) tableView: (NSTableView*) tableView setObjectValue: (id) anObject forTableColumn: (NSTableColumn*) tableColumn row: (int) row;
- (NSArray*) namedVariables;
- (NSArray*) namedVariablesRealParts;
- (NSArray*) namedVariablesImagParts;

@end
