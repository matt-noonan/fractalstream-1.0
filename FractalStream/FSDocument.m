//
//  MyDocument.m
//  FractalStream
//
//  Created by Matt Noonan on 3/15/06.
//  Copyright __MyCompanyName__ 2006 . All rights reserved.
//

#import "FSDocument.h"

@implementation FSDocument

- (id) init
{
    self = [super init];
    if (self) {
    
        // Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
		newSession = YES;
    }
    return self;
}

+ (BOOL) isNativeType: (NSString*) type { return YES; } // need this for GNUstep?  maybe a problem with Info-gnustep.plist?

- (void) awakeFromNib { 
}

- (void) windowDidBecomeMain: (NSNotification*) notification {
	[[NSNotificationCenter defaultCenter] postNotificationName: @"FSDocumentDidBecomeActive" object: self];
}

- (void) windowDidResignMain: (NSNotification*) notification {
	[[NSNotificationCenter defaultCenter] postNotificationName: @"FSDocumentDidResignActive" object: self];
}

- (void) windowWillClose: (NSNotification*) notification {
}

- (void) log: (NSString*) str {
	[logView insertText: str];
	NSLog(@"%@", str);
}

- (IBAction) showLog: (id) sender {
	[[logView window] orderFront: sender];
}

- (IBAction) hideLog: (id) sender {
	[[logView window] orderOut: sender];
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"FSDocument";
}

- (void) windowControllerDidLoadNib: (NSWindowController *) aController {
    [super windowControllerDidLoadNib:aController];
	[self doDocumentLoadWithLibrary: YES];
	[panelHelper associatePanelsToDocument: self];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
}

- (void) doDocumentLoadWithLibrary: (BOOL) lib {
	if(newSession == NO) { 
		[editor restoreFrom: [savedData editor]];
		if([savedData session] != nil) {
			[self log: @"Loading saved FractalStream document"];
			[colorizer getColorsFrom: [savedData colorizer]]; [self log: @"."];
			[session getSessionFrom: [savedData session]]; [self log: @"."];
			[session setFlags: [colorizer names]]; [self log: @"."];
			[browser setVariableNamesTo: [savedData variableNames]]; [self log: @"."];
			[browser setVariableValuesToReal: [savedData variableReal] imag: [savedData variableImag]]; [self log: @"."];
			[browser setProbeNamesTo: [savedData probeNames]]; [self log: @"."];
			[browser setAllowEditor: [savedData allowEditor]]; [self log: @"."];
			[browser reloadSession]; [self log: @"."];
			if([savedData hasTools]) [browser addTools: [savedData customTools]];
//			[browser loadTools];
			[self log: @"ok\n"];
			[mainTabView selectTabViewItemAtIndex: 2];
		}
		else {
			[self log: @"Loading uncompiled FractalStream script...\n"];
			[mainTabView selectTabViewItemAtIndex: 1];
			[self log: @"ok"];
		}
	}
	else {
		if(lib) [self log: @"Opening script library.\n"];
		else [self log: @"Opening blank FractalStream script.\n"];
		[mainTabView selectTabViewItemAtIndex: (lib == YES)? 0 : 1];
	}
}

- (void) openEditor {
	[editor restoreFrom: [savedData editor]];
	[mainTabView selectTabViewItemAtIndex: 1];
}

- (void) openScriptLibrary {
	[self log: @"Opening script library.\n"];
	[mainTabView selectTabViewItemAtIndex: 0];
}

- (void) completeConfiguration 
{
}

- (NSString*) fileType { return @"fs"; }

- (NSData *)dataRepresentationOfType:(NSString *)aType
{
	FSSave* save;
	
	save = [[FSSave alloc] init];
	if([mainTabView indexOfTabViewItem: [mainTabView selectedTabViewItem]] == 1) 
		[save setType: @"editor" session: nil colorizer: nil editor: editor browser: nil];
	else
		[save setType: @"full session [22oct]" session: session colorizer: colorizer editor: editor browser: browser];
    return [NSKeyedArchiver archivedDataWithRootObject: [save autorelease]];
}

- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)aType
{
	[FSSave useMiniLoads: NO];
	savedData = [[NSKeyedUnarchiver unarchiveObjectWithData: data] retain];
	newSession = NO;
    return YES;
}

- (IBAction) saveToLibrary: (id) sender {
	NSSavePanel* panel;
	NSArray* editorState;
	NSRange range;
	NSString* file;
	panel = [NSSavePanel savePanel];
	editorState = [editor state];
	[libraryTitleField setStringValue: [editorState objectAtIndex: 0]];
	[libraryDescriptionView setString: @""];
	[libraryDescriptionView replaceCharactersInRange: NSMakeRange(0,0) withRTFD: [editorState objectAtIndex: 2]];
	if([editorState count] > 3) {
		id ob;
		ob = [editorState objectAtIndex: 3];
		if(![ob isKindOfClass: [NSImage class]]) {
			ob = [[NSImage alloc] initWithData: ob];
			[libraryPreview setImage: ob];
			[ob release];
		}
		else [libraryPreview setImage: ob];
	}
	else [libraryPreview setImage: [NSImage imageNamed: @"NSRemoveTemplate"]];
	[librarySaveView retain]; // gets released by save panel
	[panel setTitle: @"Save to Library"];
	[panel setAccessoryView: librarySaveView];
	[panel setRequiredFileType: @"fs"];
	file = @"";
	/*** next section broken for COCOTRON ***/
#ifndef WINDOWS
	while([panel  runModalForDirectory: [[[NSBundle mainBundle] builtInPlugInsPath]
									stringByAppendingPathComponent: @"Scripts/"] file: file] == NSFileHandlingPanelOKButton) {
		// clicked the OK button
		[libraryDescriptionView selectAll: self];
		[editor setTitle: [libraryTitleField stringValue] description: [libraryDescriptionView RTFFromRange: [libraryDescriptionView selectedRange]]];
		[libraryDescriptionView setSelectedRange: NSMakeRange(0,0)];
		if([libraryTitleField stringValue] == @"") {
			file = [panel filename];
			NSRunAlertPanel(@"No Title", @"Please enter a title for the script.  This title will be displayed in the script library.", nil, nil, nil);
			continue;
		}
		[[self dataRepresentationOfType: @"FractalStream Script"] writeToFile: [panel filename] atomically: YES];
		break;
	}
#endif
}

- (IBAction) embedTool: (id) sender { [browser embedTool: sender]; }

- (void) iterations: (int*) it
{
	*it = [iterationBox intValue];
}

- (void) radius: (double*) rad
{
	*rad = [radiusBox doubleValue];
}


@end
