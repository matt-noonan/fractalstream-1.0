//
//  FSColorWidget.h
//  FractalStream
//
//  Created by Matt Noonan on 1/14/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <stdlib.h>
#import "FSColorLibraryController.h"
#import "FSThreading.h"

typedef struct {
	NSString* name;
	float r, g, b;
} FSCW_named_color;

typedef struct {
	float* color;
	int* colorIndex;
	int* subdivisions;
	BOOL* smoothing;
	BOOL* locked;
	BOOL* usesAutocolor;
	int* subcolors;
	int* locationIndex;
	double* X;
	double* Y;
	int totalColors;
	BOOL needsLock;
	int dependencies;
	NSConditionLock* lock;
} FSColorCache;

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
	IBOutlet NSButton* smoothnessBox;
	IBOutlet NSTextField* smoothnessField;
	IBOutlet NSTextField* subdivisionField;
	IBOutlet FSGradientControl* gradientControl;
	
	NSMutableArray* names;
	NSMutableArray* colors;
	float colorArray[8][8][3];
	float fullColorArray[64][8][8][3];
	float cachedColorArray[64*8*8*3];
	BOOL cachedColorArrayNeedsUpdate;
	BOOL usesAutocolor[64];
	BOOL lockedAutocolor[64];
	NSMutableArray* autocolor[64];
	int namedColorCount;
	
	int currentColor;
	int smoothness[64];
	
	FSColorCache colorCache;
	BOOL colorsCached;
	BOOL unarchiving;
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
- (void) setAutocolor: (int) c toLocked: (BOOL) lk;
- (void) colorArrayValue: (float*) cA;
- (void) setNamesTo: (NSArray*) newNames;
- (void) setup;
- (void) getColorsFrom: (FSColorWidget*) cw;
- (NSArray*) smoothnessArray;
- (void) readSmoothnessFrom: (NSArray*) smoothArray;
- (IBAction) smoothnessChanged: (id) sender;
- (int*) smoothnessPtr; 
- (void) clearSmoothnessArray;
- (float*) colorArrayPtr;
- (IBAction) updateColorInformation: (id) sender;
- (void) updateAutocolorList: (NSNotification*) note; 

- (NSArray*) names;
- (NSArray*) gradientArray;
- (NSArray*) colorArray;

- (void) encodeWithCoder: (NSCoder*) coder;
- (id) initWithCoder: (NSCoder*) coder;

- (int) numberOfRowsInTableView: (NSTableView*) tableView;
- (id) tableView: (NSTableView*) tableView objectValueForTableColumn: (NSTableColumn*) tableColumn row: (int) row;
- (id) tableView: (NSTableView*) tableView setObjectValue: (id) anObject forTableColumn: (NSTableColumn*) tableColumn row: (int) row;

@end

/*
@interface FSColorWidgetCell : NSCell {
	NSColor* color;
	BOOL active;
	NSColorWell* colorWell;
}

- (NSColor*) color;
- (BOOL) active;
- (void) setnrColorToR: (float) r G: (float) g B: (float) b;
- (void) setColorToR: (float) r G: (float) g B: (float) b;
- (void) setColorWellTo: (NSColorWell*) cw;
- (void) untoggle;
- (void) retoggle;

@end
*/