//
//  FSColorWidget.h
//  FractalStream
//
//  Created by Matt Noonan on 1/14/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <stdlib.h>


typedef struct {
	NSString* name;
	float r, g, b;
} FSCW_named_color;

@interface FSColor : NSObject {
	float color[8 * 8 * 3];
}

- (void) setRGBAtMagnitude: (int) m andPhase: (int) p to: (float*) c;
- (void) putRGBAtMagnitude: (int) m andPhase: (int) p into: (float*) c;
- (void) cacheInto: (float*) c;
- (id) colorFromR: (float) r G: (float) g B: (float) b;

- (void) encodeWithCoder: (NSCoder*) coder;
- (id) initWithCoder: (NSCoder*) coder;

@end

@interface FSColorWidget : NSObject <NSCoding> {
	IBOutlet NSMatrix* colorMatrix;
	IBOutlet NSColorWell* colorWell;
	IBOutlet NSButton* magGradient;
	IBOutlet NSButton* magShade;
	IBOutlet NSButton* phaseGradient;
	IBOutlet NSButton* phaseShade;
	IBOutlet NSPopUpButton* colorButton;
	IBOutlet NSButton* autocolorBox;
	IBOutlet NSPopUpButton* acList;
	IBOutlet NSButton* acEditButton;
	IBOutlet NSButton* acRefineButton;
	IBOutlet NSButton* acDeleteButton;
	IBOutlet NSButton* acDeleteAllButton;
	IBOutlet NSButton* acLockButton;
	
	NSArray* names;
	float colorArray[8][8][3];
	float fullColorArray[64][8][8][3];
	BOOL usesAutocolor[64];
	BOOL lockedAutocolor[64];
	NSMutableArray* autocolor[64];
	int namedColorCount;
	
	int currentColor;
}

- (IBAction) reset: (id) sender;
- (IBAction) submit: (id) sender;
- (IBAction) change: (id) sender;
- (IBAction) updateAutocolorLockState: (id) sender;
- (IBAction) acRefine: (id) sender;
- (IBAction) acEdit: (id) sender;
- (IBAction) acDelete: (id) sender;
- (IBAction) acDeleteAll: (id) sender;
- (int) numberOfFixpointsForAutocolor: (int) c;
- (void) addFixpointWithX: (double) x Y: (double) y name: (NSString*) name toAutocolor: (int) c;
- (void) cacheAutocolor: (int) c to: (float*) cache X: (double*) x Y: (double*) y;
- (BOOL) useAutocolorForColor: (int) c;
- (BOOL) useLockForColor: (int) c;
- (void) colorArrayValue: (float*) cA;
- (void) setNamesTo: (NSArray*) newNames;
- (void) setup;
- (void) getColorsFrom: (FSColorWidget*) cw;

- (NSArray*) names;

- (void) encodeWithCoder: (NSCoder*) coder;
- (id) initWithCoder: (NSCoder*) coder;

- (int) numberOfRowsInTableView: (NSTableView*) tableView;
- (id) tableView: (NSTableView*) tableView objectValueForTableColumn: (NSTableColumn*) tableColumn row: (int) row;
- (id) tableView: (NSTableView*) tableView setObjectValue: (id) anObject forTableColumn: (NSTableColumn*) tableColumn row: (int) row;

@end

@interface FSColorWidgetCell : NSCell {
	NSColor* color;
	BOOL active;
	NSColorWell* colorWell;
}

- (NSColor*) color;
- (BOOL) active;
- (void) setColorToR: (float) r G: (float) g B: (float) b;
- (void) setColorWellTo: (NSColorWell*) cw;
- (void) untoggle;
- (void) retoggle;

@end
