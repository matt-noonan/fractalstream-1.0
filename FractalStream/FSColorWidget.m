//
//  FSColorWidget.m
//  FractalStream
//
//  Created by Matt Noonan on 1/14/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "FSColorWidget.h"
#import "FSCWNamedColors.H"

/*
@implementation FSColor

- (id) init {
	int i, j, c;
	for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) for(c = 0; c < 3; c++) color[(8*3*j) + 3*i + c] = 0.75;
	return self;
}

- (id) colorFromR: (float) r G: (float) g B: (float) b {
	float shade, fill;
	int i, j;
	
	for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) {
		shade = 0.5;
		fill = (float) i / 4.0;
		if(fill > 1.0) fill = 2.0 - fill;
		fill *= 0.4;
	
		shade = fill;
		shade += 0.7;
		fill = 0.0;
		color[(8*3*j) + 3*((i+4)&7) + 0] = r * shade + fill;
		color[(8*3*j) + 3*((i+4)&7) + 1] = g * shade + fill;
		color[(8*3*j) + 3*((i+4)&7) + 2] = b * shade + fill;
	}
	return self;
}

- (void) putRGBAtMagnitude: (int) m andPhase: (int) p into: (float*) c {
	c[0] = color[(8*3*p) + 3*m + 0];
	c[1] = color[(8*3*p) + 3*m + 1];
	c[2] = color[(8*3*p) + 3*m + 2];
}

- (void) setRGBAtMagnitude: (int) m andPhase: (int) p to: (float*) c {
	color[(8*3*p) + 3*m + 0] = c[0];
	color[(8*3*p) + 3*m + 1] = c[1];
	color[(8*3*p) + 3*m + 2] = c[2];
}

- (void) cacheInto: (float*) c {
	int i, j, k;
	for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) for(k = 0; k < 3; k++)
		c[(i*8*3) + (j * 3) + k] = color[(i*8*3) + (j * 3) + k];
}

- (void) encodeWithCoder: (NSCoder*) coder {
}

- (id) initWithCoder: (NSCoder*) coder {
}



@end
*/

@implementation FSColorWidget

- (id) init {
	self = [super init];
	colors = [[NSMutableArray alloc] init];
	return self;
}

- (void) awakeFromNib {
	[[NSNotificationCenter defaultCenter] addObserver: self
		selector: @selector(updateAutocolorList:)
		name: @"FSAutocolorChanged"
		object: nil
	];
	NSLog(@"color widget done awaking\n");
}

- (void) reset: (id) sender {
}

- (void) submit: (id) sender {
}

- (void) colorArrayValue: (float*) cA {
	int c, i, j, k;
	for(c = 0; c < 64; c++) for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) for(k = 0; k < 3; k++)
		cA[(8*8*3*c) + (i*8*3) + (j * 3) + k] = fullColorArray[c][i][j][k];
}

- (float*) colorArrayPtr {
	if(cachedColorArrayNeedsUpdate == YES) {
		[self colorArrayValue: cachedColorArray];
		cachedColorArrayNeedsUpdate = NO;
	}
	return cachedColorArray;
}

- (NSArray*) colorArray { return colors; }

- (BOOL) useAutocolorForColor: (int) c {
	return usesAutocolor[c];
}

- (BOOL) useLockForColor: (int) c {
	return lockedAutocolor[c];
}

- (void) setAutocolor: (int) c toLocked: (BOOL) lk {
	lockedAutocolor[c] = lk;
}

- (IBAction) updateAutocolorLockState: (id) sender {
	lockedAutocolor[[colorButton indexOfSelectedItem]] = ([acLockButton state] == NSOnState)? YES : NO;
}

- (IBAction) smoothnessChanged: (id) sender { smoothness[currentColor] = [smoothnessField intValue]; }

- (int*) smoothnessPtr { return smoothness; }

- (void) updateAutocolorList: (NSNotification*) note {
	[self updateColorInformation: autocolorBox];
}

- (IBAction) change: (id) sender {
	/* user selected a different color */
	int newColor, i, j, k;
	float c[3];
	BOOL acChanged;
	
	newColor = [colorButton indexOfSelectedItem];
	
	smoothness[currentColor] = [smoothnessField intValue];
	[smoothnessField setIntValue: smoothness[newColor]]; 
	acChanged = usesAutocolor[currentColor];
	usesAutocolor[currentColor] = ([autocolorBox state] == NSOnState)? YES : NO;
	acChanged = (acChanged == usesAutocolor[currentColor])? NO : YES;
	if(usesAutocolor[newColor]) {
		NSEnumerator* acEnum;
		id ob;
		[acList setEnabled: YES];
		[acEditButton setEnabled: NO];
		[acRefineButton setEnabled: NO];
		[acDeleteButton setEnabled: YES];
		[acDeleteAllButton setEnabled: YES];
		[autocolorBox setState: NSOnState];
		[acLockButton setEnabled: YES];
		[acLockButton setState: (lockedAutocolor[currentColor] == YES)? NSOnState : NSOffState];
		if(acChanged || (newColor != currentColor) || ([autocolor[newColor] count] / 4 != [acList numberOfItems])) {
			acEnum = [autocolor[newColor] objectEnumerator];
			[acList removeAllItems];
			while(ob = [acEnum nextObject]) {
				[acList addItemWithTitle: ob];
				[acEnum nextObject]; [acEnum nextObject]; [acEnum nextObject];
			}
			[acList selectItemAtIndex: 0];
		}
		for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) for(k = 0; k < 3; k++) {
			if([acList indexOfSelectedItem] != -1) 
				[[autocolor[newColor] objectAtIndex: 1 + 4 * [acList indexOfSelectedItem]]
					putRGBAtMagnitude: j andPhase: i into: c
				];
			else c[0] = c[1] = c[2] = 0.0;
			fullColorArray[currentColor][i][j][k] = colorArray[i][j][k];
			colorArray[i][j][k] = c[k];
			[[colorMatrix cellAtRow: i column: j] setColorToR: colorArray[i][j][0] G: colorArray[i][j][1] B: colorArray[i][j][2] ];	
			[[colorMatrix cellAtRow: i column: j] untoggle];
			[colorMatrix drawCellAtRow: i column: j];
		}
	}
	else {
		[acList setEnabled: NO];
		[acEditButton setEnabled: NO];
		[acRefineButton setEnabled: NO];
		[acDeleteButton setEnabled: NO];
		[acDeleteAllButton setEnabled: NO];
		[autocolorBox setState: NSOffState];
		[acLockButton setState: NSOffState];
		[acLockButton setEnabled: NO];
		[acList removeAllItems];
		
		[gradientControl setGradient: [[colors objectAtIndex: currentColor] gradient]];
		for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) for(k = 0; k < 3; k++) {
			fullColorArray[currentColor][i][j][k] = colorArray[i][j][k];
			colorArray[i][j][k] = fullColorArray[newColor][i][j][k];
			[[colorMatrix cellAtRow: i column: j] setColorToR: colorArray[i][j][0] G: colorArray[i][j][1] B: colorArray[i][j][2] ];	
			[[colorMatrix cellAtRow: i column: j] untoggle];
			[colorMatrix drawCellAtRow: i column: j];
		}
	}
	currentColor = newColor;
}

- (int) numberOfFixpointsForAutocolor: (int) c { return [autocolor[c] count] / 4; }

- (void) cacheAutocolor: (int) c to: (float*) cache X: (double*) x Y: (double*) y {
}

- (void) addFixpointWithX: (double) x Y: (double) y name: (NSString*) name toAutocolor: (int) c {
}

- (IBAction) acRefine: (id) sender {
}

- (IBAction) acEdit: (id) sender {
}

- (IBAction) acDelete: (id) sender {
}

- (IBAction) acDeleteAll: (id) sender {
}


- (int) numberOfColors { return [names count]; }

- (NSArray*) names { return names; }

- (void) setNamesTo: (NSArray*) newNames {
	NSString* name;
	NSEnumerator* nameEnum;
	BOOL namedColor;
	int k, i, j, c;
	float shade;
	FSColor* color;

	color = [[FSColor alloc] init];
	names = [[NSArray arrayWithArray: newNames] retain];
	[self setup];
	nameEnum = [names objectEnumerator];
	while(name = [nameEnum nextObject]) {
		k = 0;
		namedColor = NO;
/*		while(named_color[k].name != nil) {
			if([name caseInsensitiveCompare: named_color[k].name] == NSOrderedSame) {
				namedColor = YES;
				break;
			}
			++k;
		}
		if(namedColor) {
			c = [names indexOfObject: name];
			for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) {
				shade = (float) i / 4.0;
				if(shade > 1.0) shade = 2.0 - shade;
				shade *= 0.5;
				shade += 0.5;
				fullColorArray[c][j][(i+4)&7][0] = named_color[k].r * shade;
				fullColorArray[c][j][(i+4)&7][1] = named_color[k].g * shade;
				fullColorArray[c][j][(i+4)&7][2] = named_color[k].b * shade;
			}
		}
		else */[colors addObject: [color nextColorForX: 0.0 Y: 0.0]];
	}
	[color release];
	[self updateColorInformation: self];
}

- (IBAction) updateColorInformation: (id) sender {
	FSGradient* gradient;
	gradient = [[colors objectAtIndex: currentColor] gradient];
	if(gradient == nil) gradient = [[[colors objectAtIndex: currentColor] subcolor: [acList indexOfSelectedItem]] gradient];
	if((sender == smoothnessField) || (sender == self)) [gradient setSmoothing: [smoothnessField intValue]];
	if((sender == subdivisionField) || (sender == self)) [gradient setSubdivisions: [subdivisionField intValue]];
	currentColor = [colorButton indexOfSelectedItem];
	if(currentColor < 0) currentColor = 0;
	if((sender == autocolorBox) || (sender == self)) {
		BOOL state = ([autocolorBox state] == NSOnState)? YES : NO;
		[[colors objectAtIndex: currentColor] useAutocolor: state];
		[acList removeAllItems];
		NSEnumerator* en = [[[colors objectAtIndex: currentColor] subcolors] objectEnumerator];
		FSColor* c;
		while((c = [en nextObject])) {
			[acList addItemWithTitle: 
				[NSString stringWithFormat: @"%0.3e + i %0.3e", [c xVal], [c yVal]]
			];
		}
		if([[[colors objectAtIndex: currentColor] subcolors] count]) [acList selectItemAtIndex: 0];
		[acList setEnabled: state];
		[acEditButton setEnabled: state];
		[acRefineButton setEnabled: state];
		[acDeleteButton setEnabled: state];
		[acDeleteAllButton setEnabled: state];
		[acLockButton setEnabled: state];
	}
	gradient = [[colors objectAtIndex: currentColor] gradient];
	if(gradient == nil) gradient = [[[colors objectAtIndex: currentColor] subcolor: [acList indexOfSelectedItem]] gradient];
	[gradientControl setGradient: gradient];
	[smoothnessField setIntValue: [gradient smoothing]];
	[subdivisionField setIntValue: [gradient subdivisions]];
}

- (void) setup {
	NSEnumerator* namesEnumerator;
	NSString* aName;
	int i;
	i = 0;
	NSLog(@"FSColorWidget setup got names = %@\n", names);
	namesEnumerator = [names objectEnumerator];
	[colorButton removeAllItems];
	while(aName = [namesEnumerator nextObject]) { [colorButton addItemWithTitle: aName]; }
	[colorButton selectItemAtIndex: 0];
	currentColor = 0;
	[smoothnessField setIntValue: smoothness[currentColor]]; 
}

- (void) getColorsFrom: (FSColorWidget*) cw {
	[self setNamesTo: [cw names]];
	NSLog(@"***** Active FSColorWidget should take gradients from unarchived FSColorWidget!\n");
}

- (void) encodeWithCoder: (NSCoder*) coder
{
	NSMutableArray* floats;
	int i, j, k, c, l, size;
	
	// version 0
	size = 8 * 8 * 3 * [self numberOfColors];
	l = 0;
	floats = [[NSMutableArray alloc] init];
	for(k = 0; k < [self numberOfColors]; k++) for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) for(c = 0; c < 3; c++) 
		[floats addObject: [NSNumber numberWithFloat: fullColorArray[k][i][j][c]]];
	[coder encodeObject: [NSNumber numberWithBool: YES] forKey: @"keyed"];
	[coder encodeObject: names forKey: @"names"];
	[coder encodeObject: floats forKey: @"data"];
	[floats release];
}

- (id) initWithCoder: (NSCoder*) coder
{
	float* flat;
	NSArray* floats;
	NSEnumerator* en;
	int i, j, k, c, l, size;
	self = [super init];

	// version 0
	if([coder containsValueForKey: @"keyed"]) {
		names = [[coder decodeObjectForKey: @"names"] retain];
		floats = [coder decodeObjectForKey: @"data"];
		en = [floats objectEnumerator];
		for(k = 0; k < [self numberOfColors]; k++) for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) for(c = 0; c < 3; c++) 
			fullColorArray[k][i][j][c] = [[en nextObject] floatValue];
	}
	else {
		names = [[coder decodeObject] retain];
		NSLog(@"FSColorWidget decoded the names %@\n", names);
		size = 8 * 8 * 3 * [self numberOfColors];
		flat = malloc(sizeof(float) * size);
		for(i = 0; i < size; i++) flat[i] = [[coder decodeObject] floatValue];
		l = 0;
		for(k = 0; k < [self numberOfColors]; k++) for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) for(c = 0; c < 3; c++) 
			fullColorArray[k][i][j][c] = flat[l++];
		free(flat);
	}
	[self clearSmoothnessArray];
	cachedColorArrayNeedsUpdate = YES;	
	return self;
}

- (int) numberOfRowsInTableView: (NSTableView*) tableView {
}
- (id) tableView: (NSTableView*) tableView objectValueForTableColumn: (NSTableColumn*) tableColumn row: (int) row {
}

- (id) tableView: (NSTableView*) tableView setObjectValue: (id) anObject forTableColumn: (NSTableColumn*) tableColumn row: (int) row {
}

- (NSArray*) smoothnessArray {
}

- (NSArray*) gradientArray { }

- (void) readSmoothnessFrom: (NSArray*) smoothArray {
}

- (void) clearSmoothnessArray {
}

@end
