//
//  FSColorWidget.m
//  FractalStream
//
//  Created by Matt Noonan on 1/14/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "FSColorWidget.h"
#import "FSCWNamedColors.H"


@implementation FSColorWidget

- (id) init {
	self = [super init];
	colors = nil;
	unarchiving = NO;
	
	colorsCached = NO;
	colorCache.color = NULL;
	colorCache.colorIndex = NULL;
	colorCache.subdivisions = NULL;
	colorCache.smoothing = NULL;
	colorCache.usesAutocolor = NULL;
	colorCache.locked = NULL;
	colorCache.locationIndex = NULL;
	colorCache.X = NULL;
	colorCache.Y = NULL;
	colorCache.subcolors = NULL;
	colorCache.lock = [[NSConditionLock alloc] initWithCondition: 0];
	return self;
}

- (void) dealloc {
	NSLog(@"color widget dealloc\n");
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[super dealloc];
}

- (void) awakeFromNib {
	[[NSNotificationCenter defaultCenter] addObserver: self
		selector: @selector(updateAutocolorList:)
		name: @"FSAutocolorChanged"
		object: nil
	];
	[gradientControl setNotificationSender: self];
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

- (void) lockAllAutocolor {
	NSEnumerator* en;
	id ob;
	en = [colors objectEnumerator];
	while((ob = [en nextObject])) [ob setLocked: YES];
	[self updateColorInformation: self];
}

- (IBAction) updateAutocolorLockState: (id) sender {
	lockedAutocolor[[colorButton indexOfSelectedItem]] = ([acLockButton state] == NSOnState)? YES : NO;
	[[colors objectAtIndex: [colorButton indexOfSelectedItem]] setLocked: ([acLockButton state] == NSOnState)? YES : NO];
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

	NSLog(@"****** got change from %@ ******\n", sender);
	return;

	newColor = [colorButton indexOfSelectedItem];
	
	smoothness[currentColor] = [smoothnessField intValue];
	[smoothnessField setIntValue: smoothness[newColor]]; 
	acChanged = usesAutocolor[currentColor];
	usesAutocolor[currentColor] = ([autocolorBox state] == NSOnState)? YES : NO;
	acChanged = (acChanged == usesAutocolor[currentColor])? NO : YES;
	if([[colors objectAtIndex: currentColor] usesAutocolor]) {
		NSEnumerator* acEnum;
		id ob;
		[acList setEnabled: YES];
		[acEditButton setEnabled: NO];
		[acRefineButton setEnabled: NO];
		[acDeleteButton setEnabled: YES];
		[acDeleteAllButton setEnabled: YES];
		[autocolorBox setState: NSOnState];
		[acLockButton setEnabled: YES];
		[acLockButton setState: [[colors objectAtIndex: currentColor] isLocked]? NSOnState : NSOffState];
		if(acChanged || (newColor != currentColor) || ([[[colors objectAtIndex: newColor] subcolors] count] != [acList numberOfItems])) {
			acEnum = [[[colors objectAtIndex: newColor] subcolors] objectEnumerator];
			[acList removeAllItems];
			while(ob = [acEnum nextObject]) 
				[acList addItemWithTitle: [NSString stringWithFormat: @"%0.3e + %0.3e i", [ob xVal], [ob yVal]]];
			[acList selectItemAtIndex: 0];
		}
/*
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
*/
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
/*
 for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) for(k = 0; k < 3; k++) {
			fullColorArray[currentColor][i][j][k] = colorArray[i][j][k];
			colorArray[i][j][k] = fullColorArray[newColor][i][j][k];
			[[colorMatrix cellAtRow: i column: j] setColorToR: colorArray[i][j][0] G: colorArray[i][j][1] B: colorArray[i][j][2] ];	
			[[colorMatrix cellAtRow: i column: j] untoggle];
			[colorMatrix drawCellAtRow: i column: j];
		}
*/
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
	if([acList indexOfSelectedItem] >= 0) {
		if([acList indexOfSelectedItem] == [[[colors objectAtIndex: currentColor] subcolors] count])
			[[colors objectAtIndex: currentColor] setHasInfinity: NO];
		else [[colors objectAtIndex: currentColor] removeSubcolorAtIndex: [acList indexOfSelectedItem]];
	}
	[self updateColorInformation: self];
}

- (IBAction) acDeleteAll: (id) sender {
	[[colors objectAtIndex: currentColor] setHasInfinity: NO];
	[[colors objectAtIndex: currentColor] removeAllSubcolors];
	[self updateColorInformation: self];
}

- (void) waitForColoringToFinish {
	synchronizeTo(colors) {
		[colorCache.lock lockWhenCondition: 0];
	}
}

- (void) makeColorCache {
	NSEnumerator *en, *suben;
	FSColor *color, *subcolor;
	int totalColors = 0, totalSubcolors = 0;
	int colorSize = 0;
	int i, j, k, m;
	NSColor* c;
	float x, dx;
	en = [colors objectEnumerator];
	while((color = [en nextObject])) {
		++totalColors;
		colorSize += (1 + [[color subcolors] count]) * [[color baseGradient] subdivisions];
		totalSubcolors += [[color subcolors] count];
	}
	[colorCache.lock lockWhenCondition: 0];
	{
		colorCache.dependencies = 0;
		free(colorCache.color);
		free(colorCache.colorIndex);
		free(colorCache.subdivisions);
		free(colorCache.smoothing);
		free(colorCache.locked);
		free(colorCache.usesAutocolor);
		free(colorCache.locationIndex);
		free(colorCache.X);
		free(colorCache.Y);
		free(colorCache.subcolors);
		colorCache.totalColors = totalColors;
		colorCache.color = (float*) malloc(colorSize * 3 * sizeof(float));
		colorCache.colorIndex = (int*) malloc(totalColors * sizeof(int));
		colorCache.subcolors = (int*) malloc(totalColors * sizeof(int));
		colorCache.subdivisions = (int*) malloc(totalColors * sizeof(int));
		colorCache.smoothing = (BOOL*) malloc(totalColors * sizeof(BOOL));
		colorCache.locked = (BOOL*) malloc(totalColors * sizeof(BOOL));
		colorCache.usesAutocolor = (BOOL*) malloc(totalColors * sizeof(BOOL));
		colorCache.locationIndex = (int*) malloc(totalColors * sizeof(int));
		colorCache.X = (double*) malloc(totalSubcolors * sizeof(double));
		colorCache.Y = (double*) malloc(totalSubcolors * sizeof(double));
		colorCache.needsLock = NO;
		i = j = m = 0;
		en = [colors objectEnumerator];
		while((color = [en nextObject])) {
			colorCache.colorIndex[i] = j;
			colorCache.subdivisions[i] = [[color baseGradient] subdivisions];
			if(colorCache.subdivisions[i] <= 0) colorCache.subdivisions[i] = 1;
			colorCache.smoothing[i] = [[color baseGradient] smoothing];
			colorCache.locked[i] = [color isLocked];
			colorCache.usesAutocolor[i] = [color usesAutocolor];
			colorCache.subcolors[i] = 0;
			if(colorCache.usesAutocolor[i] && (colorCache.locked[i] == NO)) colorCache.needsLock = YES;
			x = 0.0; dx = 1.0 / (float) colorCache.subdivisions[i];
			for(k = 0; k < colorCache.subdivisions[i]; k++) {
				c = [[color baseGradient] colorForOffset: x];
				colorCache.color[j++] = [c redComponent];
				colorCache.color[j++] = [c greenComponent];
				colorCache.color[j++] = [c blueComponent];
				x += dx;
			}
			suben = [[color subcolors] objectEnumerator];
			colorCache.locationIndex[i] = m;
			while((subcolor = [suben nextObject])) {
				++colorCache.subcolors[i];
				x = 0.0; dx = 1.0 / (float) colorCache.subdivisions[i];
				for(k = 0; k < colorCache.subdivisions[i]; k++) {
					c = [[subcolor baseGradient] colorForOffset: x];
					colorCache.color[j++] = [c redComponent];
					colorCache.color[j++] = [c greenComponent];
					colorCache.color[j++] = [c blueComponent];
					x += dx;
				}
				colorCache.X[m] = [subcolor xVal];
				colorCache.Y[m] = [subcolor yVal];
				m++;
			}
			++i;
		}
		colorsCached = YES;
	}
	[colorCache.lock unlockWithCondition: 0];
}

- (FSColorCache*) getColorCache {
	if(colorsCached == NO) {
		[self makeColorCache];
	}
	++colorCache.dependencies;
	return &colorCache;
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
	FSGradient* gradient;
	float r, g, b;
	NSArray* rawNames;
	NSMutableArray* cleanedNames;
	NSArray* subNames;
	BOOL makeNewColors;
	
	cleanedNames = [[NSMutableArray alloc] init];
	nameEnum = [newNames objectEnumerator];
	i = 0;
	makeNewColors = NO;
	NSLog(@"setting names to %@, colors is %@\n", newNames, colors);
	if((colors == nil) || ([newNames count] != [colors count])) { colors = [[NSMutableArray alloc] init]; makeNewColors = YES; }
	unarchiving = NO;
	while(name = [nameEnum nextObject]) {
		subNames = [name componentsSeparatedByString: @"|"];
		NSLog(@"subnames is %@\n", subNames);
		name = [[subNames objectAtIndex: [subNames count] - 1] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
		NSLog(@"name is %@\n", name);
		[cleanedNames addObject: [[subNames objectAtIndex: 0] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]]];
		k = 0;
		namedColor = NO;
		while(named_color[k].name != nil) {
			if([name caseInsensitiveCompare: named_color[k].name] == NSOrderedSame) {
				namedColor = YES;
				break;
			}
			++k;
		}
		if(namedColor) {
			r = named_color[k].r;
			g = named_color[k].g;
			b = named_color[k].b;
		}
		else {
			switch(i & 7) {
				case 0:		r = 0.0;	g = 0.0;	b = 1.0;	break;
				case 1:		r = 0.0;	g = 1.0;	b = 0.0;	break;
				case 2:		r = 1.0;	g = 0.0;	b = 0.0;	break;
				case 3:		r = 0.0;	g = 1.0;	b = 1.0;	break;
				case 4:		r = 1.0;	g = 1.0;	b = 0.0;	break;
				case 5:		r = 1.0;	g = 0.0;	b = 1.0;	break;
				case 6:		r = 1.0;	g = 0.5;	b = 0.5;	break;
				case 7:		r = 1.0;	g = 1.0;	b = 1.0;	break;
			}
			if(i & 8) { r *= 0.5; g *= 0.5; b *= 0.5; }	
		}
		color = [[FSColor alloc] init];
		gradient = [[FSGradient alloc] initWithR: r G: g B: b];
		[color setGradient: gradient];
		if(makeNewColors) [colors addObject: color];
		[gradient release];
		[color release];
		i++;
	}
	names = [[NSArray arrayWithArray: cleanedNames] retain];
	[self setup];
	[self updateColorInformation: self];
}

- (IBAction) updateColorInformation: (id) sender {
	FSGradient* gradient;
	BOOL wasChanged;
	
	wasChanged = NO;
	if(colors == nil) return;
	synchronizeTo(colors) {
		gradient = [[colors objectAtIndex: currentColor] gradient];
		if(gradient == nil) {
			if([acList indexOfSelectedItem] == [[[colors objectAtIndex: currentColor] subcolors] count]) {
				// selected infinity
				gradient = [[colors objectAtIndex: currentColor] baseGradient];
			}
			else gradient = [[[colors objectAtIndex: currentColor] subcolor: [acList indexOfSelectedItem]] gradient];
		}
		if(sender == smoothnessField) {
			if([gradient smoothing] != [smoothnessField intValue]) wasChanged = YES;
			[gradient setSmoothing: [smoothnessField intValue]];
		}
		if(sender == subdivisionField) {
			if([gradient subdivisions] != [subdivisionField intValue]) wasChanged = YES;
			[gradient setSubdivisions: [subdivisionField intValue]];
		}
		if(sender == acLockButton) [[colors objectAtIndex: currentColor] setLocked: ([acLockButton state] == NSOnState)? YES : NO];
		currentColor = [colorButton indexOfSelectedItem];
		if(currentColor < 0) currentColor = 0;
		if((sender == autocolorBox) || (sender == self)) {
			BOOL state = ([autocolorBox state] == NSOnState)? YES : NO;
			if((sender == autocolorBox) && ([[colors objectAtIndex: currentColor] usesAutocolor] != state)) {
				if(([[colors objectAtIndex: currentColor] usesAutocolor] == NO) && ([[colors objectAtIndex: currentColor] hasInfinity] == NO)) { // autocolor just got turned on for this color
					[[[colors objectAtIndex: currentColor] baseGradient] resetToColor: [NSColor colorWithDeviceRed: 0.7 green: 0.7 blue: 0.7 alpha: 1.0]];
					[[[colors objectAtIndex: currentColor] baseGradient] addColor: [NSColor colorWithDeviceRed: 1.0 green: 1.0 blue: 1.0 alpha: 1.0] atStop: 0.5];
				}
				wasChanged = YES;
			}
			[[colors objectAtIndex: currentColor] useAutocolor: state];
			[acList removeAllItems];
			NSEnumerator* en = [[[colors objectAtIndex: currentColor] subcolors] objectEnumerator];
			FSColor* c;
			while((c = [en nextObject])) {
				[acList addItemWithTitle: 
					[NSString stringWithFormat: @"%0.3e + i %0.3e", [c xVal], [c yVal]]
				];
			}
			if([[colors objectAtIndex: currentColor] hasInfinity]) [acList addItemWithTitle: @"infinity"];
			if([[[colors objectAtIndex: currentColor] subcolors] count]) [acList selectItemAtIndex: 0];
			[acList setEnabled: state];
			[acEditButton setEnabled: state];
			[acRefineButton setEnabled: state];
			[acDeleteButton setEnabled: state];
			[acDeleteAllButton setEnabled: state];
			[acLockButton setEnabled: state];
		}
		if(([autocolorBox state] == NSOnState) && [[[colors objectAtIndex: currentColor] subcolors] count])
			[acLockButton setState: [[colors objectAtIndex: currentColor] isLocked]? NSOnState : NSOffState];
		gradient = [[colors objectAtIndex: currentColor] gradient];
		if(gradient == nil) {
			if([acList indexOfSelectedItem] == [[[colors objectAtIndex: currentColor] subcolors] count]) {
				// selected infinity
				gradient = [[colors objectAtIndex: currentColor] baseGradient];
			}
			else gradient = [[[colors objectAtIndex: currentColor] subcolor: [acList indexOfSelectedItem]] gradient];
		}		
		[gradientControl setGradient: gradient];
		[smoothnessField setIntValue: [gradient smoothing]];
		[subdivisionField setIntValue: [gradient subdivisions]];
	}
	if(wasChanged) {
		[[NSNotificationCenter defaultCenter] postNotificationName: @"FSColorsChanged" object: self];
	}
}

- (void) setup {
	NSEnumerator* namesEnumerator;
	NSString* aName;
	int i;
	i = 0;
	namesEnumerator = [names objectEnumerator];
	[colorButton removeAllItems];
	while(aName = [namesEnumerator nextObject]) { [colorButton addItemWithTitle: aName]; }
	[colorButton selectItemAtIndex: 0];
	currentColor = 0;
}

- (void) getColorsFrom: (FSColorWidget*) cw {
	[self setNamesTo: [cw names]];
	colors = [(cw->colors) retain];
	[self updateColorInformation: self];
}

- (void) encodeWithCoder: (NSCoder*) coder {
	[coder encodeObject: [NSNumber numberWithBool: YES] forKey: @"keyed"];
	[coder encodeObject: names forKey: @"names"];
	[coder encodeObject: colors forKey: @"colors"];
}

- (id) initWithCoder: (NSCoder*) coder
{
	float* flat;
	NSArray* floats;
	NSEnumerator* en;
	int i, j, k, c, l, size;
	float r, g, b;
	self = [super init];
	colors = [[NSMutableArray alloc] init];
	
	if([coder containsValueForKey: @"keyed"]) {
		names = [[coder decodeObjectForKey: @"names"] retain];
		colors = [[coder decodeObjectForKey: @"colors"] retain];
	}
	else {
		FSColor* c;
		FSGradient* gradient;
		names = [[coder decodeObject] retain];

		for(k = 0; k < [self numberOfColors]; k++) for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) {
			r = [[coder decodeObject] floatValue];
			g = [[coder decodeObject] floatValue];
			b = [[coder decodeObject] floatValue];
			if(i == 0) {
				if(j == 0) {
					c = [[FSColor alloc] init];
					gradient = [[FSGradient alloc] init];
					[gradient resetToColor: [NSColor colorWithCalibratedRed: r green: g blue: b alpha: 1.0]];
				}
				else {
					[gradient addColor: [NSColor colorWithCalibratedRed: r green: g blue: b alpha: 1.0] atStop: ((float) j) / 8.0];
				}
				if(j == 7) {
					[c setGradient: gradient];
					[colors addObject: c];
					[c release]; [gradient release];
				}
			}
		}
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
