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
#ifdef __WIN32__
#else
#import <dlfcn.h>
#endif
#import "FSTools.h"
#import "FSViewer.h"
#import "FSSession.h"
#import "FSKernel.h"
#import "FSCustomDataManager.h"

@interface FSBrowser : NSObject {
	IBOutlet FSViewer* theViewer;
	IBOutlet FSViewer* preview;
	IBOutlet FSViewer* historyView;
	IBOutlet NSButton* editorButton;
	IBOutlet id theCompiler;
	
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
	IBOutlet NSTableView* varTable;
	
	NSFileWrapper* toolsWrapper;
 	NSArray* variableNames;
	NSArray* reducedVariableNames;
	NSArray* realPart;
	NSArray* imagPart;
	NSArray* probeNames;
	NSArray* specialTools;
	int uniqueVariableNames;
	FSKernel* theKernel;
	FSCustomDataManager* dataManager;
	
	BOOL configured;
}

- (IBAction) goForward: (id) sender;
- (IBAction) goBackward: (id) sender;
- (IBAction) refresh: (id) sender;
- (IBAction) goHome: (id) sender;
- (IBAction) goUp: (id) sender;

- (void) testAndRefresh: (NSNotification*) note ;
- (void) changeTo: (NSString*) newName X: (double) x Y: (double) y p1: (double) p1 p2: (double) p2 pixelSize: (double) pixelSize parametric: (BOOL) isPar;
- (void) sendDefaultsToViewer;
- (void) putCurrentDataIn: (FSViewerData*) p;
- (void) refreshAll;
- (void) setProbeNamesTo: (NSArray*) names;
- (void) setVariableNamesTo: (NSArray*) names;
- (void) setVariableValuesToReal: (NSArray*) rp imag: (NSArray*) ip;
- (void) resetDefaults;
- (BOOL) editorDisabled;
- (void) setAllowEditor: (BOOL) allow;
- (void) addTools: (NSFileWrapper*) toolWrapper;
- (NSFileWrapper*) extraTools;
- (FSKernel*) kernel;
- (IBAction) embedTool: (id) sender;
- (IBAction) hidePanels: (id) sender;
- (IBAction) revealPanels: (id) sender;

- (void) reloadSession;
- (void) reloadSessionWithoutRefresh;
- (FSSession*) session;
- (void) setVariableNamesTo: (NSArray*) names;
- (void) loadDataFromInterfaceTo: (FSViewerData*) theData;
- (FSViewer*) viewer;

- (int) numberOfRowsInTableView: (NSTableView*) tableView;
- (id) tableView: (NSTableView*) tableView objectValueForTableColumn: (NSTableColumn*) tableColumn row: (int) row;
- (void) tableView: (NSTableView*) tableView setObjectValue: (id) anObject forTableColumn: (NSTableColumn*) tableColumn row: (int) row;
- (NSArray*) namedVariables;
- (NSArray*) namedVariablesRealParts;
- (NSArray*) namedVariablesImagParts;
- (NSArray*) namedProbes;
@end
