//
//  MyDocument.m
//  FractalStream
//
//  Created by Matt Noonan on 3/15/06.
//  Copyright __MyCompanyName__ 2006 . All rights reserved.
//

#import "FSDocument.h"

@implementation FSDocument

- (id)init
{
    self = [super init];
    if (self) {
    
        // Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
		newSession = YES;
    }
    return self;
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"FSDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
	[self doDocumentLoadWithLibrary: YES];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
}

- (void) doDocumentLoadWithLibrary: (BOOL) lib {
	if(newSession == NO) { 
		[editor restoreFrom: [savedData editor]];
		if([savedData session] != nil) {
			[colorizer getColorsFrom: [savedData colorizer]];
			[session getSessionFrom: [savedData session]];
			[session setFlags: [colorizer names]];
			[browser setVariableNamesTo: [savedData variableNames]];
			[browser setVariableValuesToReal: [savedData variableReal] imag: [savedData variableImag]];
			[browser setProbeNamesTo: [savedData probeNames]];
			[browser setAllowEditor: [savedData allowEditor]];
			[browser reloadSession];
			if([savedData hasTools]) [browser addTools: [savedData customTools]];
			[mainTabView selectTabViewItemAtIndex: 1];
		}
		else [mainTabView selectTabViewItemAtIndex: 0];
	}
	else [mainTabView selectTabViewItemAtIndex: (lib == YES)? 3 : 0];
}


- (void) completeConfiguration 
{
}

- (NSString*) fileType { return @"fs"; }

- (NSData *)dataRepresentationOfType:(NSString *)aType
{
	FSSave* save;
	
	save = [[FSSave alloc] init];
	NSLog(@"about to set type, going to send to object %@", save);
	if([mainTabView indexOfTabViewItem: [mainTabView selectedTabViewItem]] == 0) 
		[save setType: @"editor" session: nil colorizer: nil editor: editor browser: nil];
	else
		[save setType: @"full session [22oct]" session: session colorizer: colorizer editor: editor browser: browser];
    return [NSKeyedArchiver archivedDataWithRootObject: save];
}

- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)aType
{
	NSLog(@"##### start NSKeyedUnarchiver, type is %@\n", aType);
	[FSSave useMiniLoads: NO];
	savedData = [[NSKeyedUnarchiver unarchiveObjectWithData: data] retain];
	NSLog(@"##### NSKeyedUnarchiver finished\n");
	newSession = NO;
    return YES;
}

- (void) iterations: (int*) it
{
	*it = [iterationBox intValue];
}

- (void) radius: (double*) rad
{
	*rad = [radiusBox doubleValue];
}

@end
