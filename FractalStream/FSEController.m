#import "FSEController.h"

@implementation FSEController

- (void) awakeFromNib {
	[sourceView setRichText: NO];
}

- (IBAction)compile:(id)sender
{
	NSString* tmp;
	NSString* errorMessage;
	
	tmp = [NSString stringWithFormat: @"%@/FSEtemp%i", NSTemporaryDirectory(), rand()];
	[compiler 
		setTitle: [titleField stringValue]
		source: [sourceView string]
		andDescription: [descriptionView textStorage]
	];
	[compiler setOutputFilename: tmp];
	[compiler compile: sender];
	errorMessage = [compiler errorMessage];
	if(errorMessage != nil) {
		[errorField setStringValue: errorMessage];
		[sourceView setSelectedRange: [compiler errorRange]];
		return;
	}
	[browser setVariableNamesTo: [compiler parameters]];
	[[browser session] setFlags: [compiler flagArray]];
	[[browser session] readKernelFrom: tmp];
	[[[browser session] root] dataPtr] -> program = [compiler isParametric]? 1 : 3;
	[browser loadDataFromInterfaceTo: [[[browser session] root] dataPtr]];	
	[browser reloadSessionWithoutRefresh];
	[browser resetDefaults];
	[browser refreshAll];
	[browser changeTo: @"testing!" X: 0.0 Y: 0.0 p1: 0.0 p2: 0.0 pixelSize: (4.0 / 512.0) parametric: [compiler isParametric]];
	[enclosingView selectNextTabViewItem: self];
}

- (IBAction) insertPi: (id) sender {
	[sourceView insertText: [NSString stringWithFormat: @"%C", 0x03c0]];
}

- (IBAction)testProgram:(id)sender
{
}

- (void) restoreFrom: (NSArray*) savedState {
	NSRange range;
	[titleField setStringValue: [savedState objectAtIndex: 0]];
	[sourceView setString: [savedState objectAtIndex: 1]];
	[descriptionView selectAll: self];
	range = [descriptionView selectedRange];
	[descriptionView replaceCharactersInRange: range withRTFD: [savedState objectAtIndex: 2]];
}

- (NSArray*) state {
	NSMutableArray* savedState;
	NSRange range;
	
	savedState = [[NSMutableArray alloc] init];
	[savedState addObject: [titleField stringValue]];
	[savedState addObject: [sourceView string]];
	[descriptionView selectAll: self];
	range = [descriptionView selectedRange];
	[savedState addObject: [descriptionView RTFDFromRange: range]];
	range.length = 0;
	[descriptionView setSelectedRange: range];
	[savedState retain];
	return savedState;
}

@end
