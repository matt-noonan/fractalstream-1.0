//
//  MyDocument.h
//  FractalStream
//
//  Created by Matt Noonan on 3/15/06.
//  Copyright __MyCompanyName__ 2006 . All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import "FSSession.h"
#import "FSTools.h"
#import "FSBrowser.h"
#import "FSSave.h"
#import "FSPanel.h"

@interface FSDocument : NSDocument
{
	IBOutlet FSSession *session;  /* session history */
	IBOutlet FSBrowser *browser;
	
	void (*kernel)(int, double*, int, double*, int, double); /* program kernel */
//	IBOutlet FSProgramList* kernelLoader;
//	IBOutlet FSConfigurationSheet* configSheet;
	BOOL configured;
	BOOL newSession;
	FSSave* savedData;
	
	IBOutlet FSEController* editor;
	IBOutlet FSColorWidget* colorizer;
	IBOutlet FSTools* toolkit;
	
	IBOutlet NSTextField* iterationBox;
	IBOutlet NSTextField* radiusBox;
	IBOutlet NSTabView* mainTabView;
	
	IBOutlet NSView* librarySaveView;
	IBOutlet NSTextField* libraryTitleField;
	IBOutlet NSTextView* libraryDescriptionView;
	IBOutlet NSImageView* libraryPreview;
	
	IBOutlet FSPanelHelper* panelHelper;
	IBOutlet NSTextView* logView;
}

- (void) completeConfiguration;
- (void) iterations: (int*) it;
- (void) radius: (double*) rad;
- (void) doDocumentLoadWithLibrary: (BOOL) lib;
- (IBAction) saveToLibrary: (id) sender;
- (IBAction) embedTool: (id) sender;
- (void) openScriptLibrary;
- (void) openEditor;
- (void) log: (NSString*) str;

@end
