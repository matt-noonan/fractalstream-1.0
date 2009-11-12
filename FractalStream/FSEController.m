#import "FSEController.h"

@implementation FSEController

- (void) awakeFromNib {
	[sourceView setRichText: NO];
}

- (IBAction)compile:(id)sender
{
	NSString* tmp;
	NSString* errorMessage;
	
	tmp = [NSString stringWithFormat: @"%@FSEtemp%i", NSTemporaryDirectory(), rand()];
	[compiler 
		setTitle: [titleField stringValue]
		source: [sourceView string]
		andDescription: [descriptionView textStorage]
	];
	[[browser session] setProgram: [sourceView string]];
	[compiler setOutputFilename: tmp];
	[compiler compile: sender];
	errorMessage = [compiler errorMessage];
	if(errorMessage != nil) {
		[sourceView setSelectedRange: [compiler errorRange]];
		NSRunAlertPanel(@"Script Error", errorMessage, nil, nil, nil);
		return;
	}
	[browser setVariableNamesTo: [compiler parameters]];
	[browser setProbeNamesTo: [compiler probeArray]];
	NSLog(@"set probe names in the browser to %@\n", [compiler probeArray]);
	[[browser session] setFlags: [compiler flagArray]];
	NSLog(@"set flag names in the session to %@\n", [compiler flagArray]);
	if([compiler usesCustom] == YES) {
		[[browser session] readKernelFrom: [NSString stringWithFormat: @"%@kernel", [compiler customPath]]];
		[browser setAllowEditor: NO];
	}
	else [[browser session] readKernelFrom: tmp];
	[[[browser session] root] dataPtr] -> program = [compiler isParametric]? 1 : 3;
	[browser loadDataFromInterfaceTo: [[[browser session] root] dataPtr]];	
	[browser reloadSessionWithoutRefresh];
	[browser resetDefaults];
	[browser refreshAll];
	if([compiler usesCustom] == YES) [browser addTools: [[[NSFileWrapper alloc] initWithPath: [compiler customPath]] autorelease]];
	[browser changeTo: @"testing!" X: 0.0 Y: 0.0 p1: 0.0 p2: 0.0 pixelSize: (4.0 / 512.0) parametric: [compiler isParametric]];
	
	//[enclosingView selectNextTabViewItem: self];  
	// selectNextTabViewItem not implemented in Cocotron, so use this instead:
	NSLog(@"about to change tab, enclosingView is %@\n", enclosingView);
	[enclosingView selectTabViewItemAtIndex: [enclosingView indexOfTabViewItem: [enclosingView selectedTabViewItem]] + 1];
	NSLog(@"did it.\n");
}

- (IBAction) insertPi: (id) sender {
	[sourceView insertText: [NSString stringWithFormat: @"%C", 0x03c0]];
}

- (IBAction)testProgram:(id)sender
{
}

- (void) restoreFrom: (NSArray*) savedState {
	NSRange range;
	NSLog(@"savedState 0 = %@, 1 = %@\n", [savedState objectAtIndex: 0], [savedState objectAtIndex: 1]);
	[titleField setStringValue: [savedState objectAtIndex: 0]];
	[sourceView setString: [savedState objectAtIndex: 1]];
	[descriptionView selectAll: self];
	range = [descriptionView selectedRange];
	[descriptionView replaceCharactersInRange: range withRTF: [savedState objectAtIndex: 2]];
	[descriptionView setString: [NSString stringWithFormat: @"first 4 bytes are: %c %c %c %c\n",
		((char*) [[savedState objectAtIndex: 2] bytes])[0],
		((char*) [[savedState objectAtIndex: 2] bytes])[1],
		((char*) [[savedState objectAtIndex: 2] bytes])[2],
		((char*) [[savedState objectAtIndex: 2] bytes])[3]
	]];
}

- (NSArray*) state {
	NSMutableArray* savedState;
	NSRange range;
	NSImage* img;
	
	savedState = [[NSMutableArray alloc] init];
	[savedState addObject: [titleField stringValue]];
	[savedState addObject: [sourceView string]];
	[descriptionView selectAll: self];
	range = [descriptionView selectedRange];
	[savedState addObject: [descriptionView RTFFromRange: range]];
	range.length = 0;
	[descriptionView setSelectedRange: range];
	//img = [[browser viewer] snapshot];
	img = nil; // removes preview
	if(img) {
		[img setScalesWhenResized: YES];
		[img setSize: NSMakeSize(128, 128)];
		[savedState addObject: [img TIFFRepresentation]];
	}
//	[savedState retain]; // this should be autoreleased, check to see if other objects leak the returned state
	return [savedState autorelease];
}

- (void) setTitle: (NSString*) title description: (NSData*) description {
	[titleField setStringValue: title];
	[descriptionView setString: @""];
	[descriptionView replaceCharactersInRange: NSMakeRange(0,0) withRTF: description];
}

@end
