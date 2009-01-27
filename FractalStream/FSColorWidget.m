//
//  FSColorWidget.m
//  FractalStream
//
//  Created by Matt Noonan on 1/14/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "FSColorWidget.h"
#import "FSCWNamedColors.H"

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


@implementation FSColorWidget

- (id) init {
	self = [super init];
	cachedColorArrayNeedsUpdate = YES;
	return self;
}

- (void) awakeFromNib {
	int c, i, j;
	float shade, fill, r, g, b;
	
	cachedColorArrayNeedsUpdate = YES;
	[smoothnessField setIntValue: smoothness[0]]; 

	c = 0;
	while(named_color[c].name) ++c;
	namedColorCount = c;
	for(c = 0; c < 64; c++) {
		usesAutocolor[c] = NO;
		lockedAutocolor[c] = NO;
		autocolor[c] = [[[NSMutableArray alloc] init] retain];
		for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) {
			shade = (c & 8)? 0.9 : 0.5;
			fill = (float) i / 4.0;
			if(fill > 1.0) fill = 2.0 - fill;
			fill *= 0.4;
			
			shade = fill;
			shade += 0.7 - 0.4 * (float)((c >> 3) & 1);
			fill = 0.0;
			switch((c - 1) & 0x7) {
				case 0:		r = 1.0;	g = 0.0;	b = 0.0;	break;
				case 1:		r = 0.0;	g = 1.0;	b = 0.0;	break;
				case 2:		r = 0.0;	g = 0.0;	b = 1.0;	break;
				case 3:		r = 1.0;	g = 1.0;	b = 0.0;	break;
				case 4:		r = 0.5;	g = 0.0;	b = 1.0;	break;
				case 5:		r = 0.0;	g = 0.8;	b = 1.0;	break;
				case 6:		r = 1.0;	g = 0.4;	b = 0.0;	break;
				case 7:		r = 1.0;	g = 1.0;	b = 1.0;	break;
			}
			fullColorArray[c][j][i][0] = r * shade + fill;
			fullColorArray[c][j][i][1] = g * shade + fill;
			fullColorArray[c][j][i][2] = b * shade + fill;
		}
	}


	/* set up the color picker */
	[colorMatrix setCellClass: [FSColorWidgetCell class]];
	[colorMatrix setPrototype: [FSColorWidgetCell new]];
	[colorMatrix setCellSize: NSMakeSize(20.0, 20.0)];
	for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) [colorMatrix addColumn];
	for(i = 0; i < 8; i++) [colorMatrix removeColumn: 0];

	[colorMatrix selectCellAtRow: -1 column: -1];
	[colorMatrix selectCellAtRow: 0 column: 0];
	[colorMatrix sendAction];
	
	for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) {
		[[colorMatrix cellAtRow: i column: j] setColorWellTo: colorWell]; 
		[[colorMatrix cellAtRow: i column: j] 
			setnrColorToR: 0.0
			G: 0.0
			B: 0.0
		];
		[[colorMatrix cellAtRow: i column: j] untoggle];
	}

	[[colorMatrix cellAtRow: 0 column: 0] 
		setColorToR: 0.0
		G: 0.0
		B: 1.0
	];
	[[colorMatrix cellAtRow: 0 column: 4] 
		setColorToR: 0.0
		G: 1.0
		B: 1.0
	];
	[[colorMatrix cellAtRow: 0 column: 0] retoggle];
	[[colorMatrix cellAtRow: 0 column: 4] retoggle];
	[self submit: self];
	
}

- (void) reset: (id) sender {
	int i, j;
	for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) {
		[[colorMatrix cellAtRow: i column: j] setColorToR: 0.0 G: 0.0 B: 0.0 ];	
		[[colorMatrix cellAtRow: i column: j] untoggle];
		[colorMatrix drawCellAtRow: i column: j];
	}
}

- (void) submit: (id) sender {
	int i, j, n, I, J;
	float tcolor[8][8][3];
	float count;
	BOOL touch[8][8], ttouch[8][8], touched;
	int tlog, phaseGradientOn;
	float r, g, b;
	
	tlog = 0;
	phaseGradientOn = ([phaseGradient state] == NSOnState)? 1 : 0;
	
	for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) {
		[[[colorMatrix cellAtRow: i column: j] color] getRed: &r green: &g blue: &b alpha: NULL];
		colorArray[i][j][0] = r;
		colorArray[i][j][1] = g;
		colorArray[i][j][2] = b;
		touch[i][j] = [[colorMatrix cellAtRow: i column: j] active];
	}
	for(n = 0; n < 100; n++) {
	for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) {
		if((touch[i][j] == NO) || (tlog != 0)) {
			r = g = b = 0.0;
			count = 0.0;
			
			I = i - 1; 
			J = j;
			if((tlog == 0) || phaseGradientOn) {
			if(I < 0) I = 7; if(J < 0) J = 7; if(I > 7) I = 0; if(J > 7) J = 0;
			if(touch[I][J] == YES) {
				count += 1.0;
				r += colorArray[I][J][0];
				g += colorArray[I][J][1];
				b += colorArray[I][J][2];
			}
			I = i + 1; 
			J = j;
			if(I < 0) I = 7; if(J < 0) J = 7; if(I > 7) I = 0; if(J > 7) J = 0;
			if(touch[I][J] == YES) {
				count += 1.0;
				r += colorArray[I][J][0];
				g += colorArray[I][J][1];
				b += colorArray[I][J][2];
			}
			I = i; 
			J = j - 1;
			if(I < 0) I = 7; if(J < 0) J = 7; if(I > 7) I = 0; if(J > 7) J = 0;
			if(touch[I][J] == YES) {
				count += 1.0;
				r += colorArray[I][J][0];
				g += colorArray[I][J][1];
				b += colorArray[I][J][2];
			}
			}
			I = i; 
			J = j + 1;
			if(I < 0) I = 7; if(J < 0) J = 7; if(I > 7) I = 0; if(J > 7) J = 0;
			if(touch[I][J] == YES) {
				count += 1.0;
				r += colorArray[I][J][0];
				g += colorArray[I][J][1];
				b += colorArray[I][J][2];
			}
			ttouch[i][j] = touch[i][j];
			if(tlog) {
				count += 2.0;
				r += 2.0 * colorArray[i][j][0];
				g += 2.0 * colorArray[i][j][1];
				b += 2.0 * colorArray[i][j][2];
			}
			if(count != 0.0) {
				r /= count;
				g /= count;
				b /= count;
				ttouch[i][j] = YES;
			}
		}
		else { r = colorArray[i][j][0]; g = colorArray[i][j][1]; b = colorArray[i][j][2]; ttouch[i][j] = YES; }
		
		tcolor[i][j][0] = r;
		tcolor[i][j][1] = g;
		tcolor[i][j][2] = b;
	}
	touched = YES;
	for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) {
		touch[i][j] = ttouch[i][j];
		if(touch[i][j] == NO) touched = NO;
	}
	if(tlog == 2) break;
	if(touched == YES) tlog++; 
	for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) {
		colorArray[i][j][0] = tcolor[i][j][0];
		colorArray[i][j][1] = tcolor[i][j][1];
		colorArray[i][j][2] = tcolor[i][j][2];
		if(usesAutocolor[currentColor]) {
			int ac;  float acColor[3];
			acColor[0] = colorArray[i][j][0];
			acColor[1] = colorArray[i][j][1];
			acColor[2] = colorArray[i][j][2];
			ac = [acList indexOfSelectedItem];
			if(ac >= 0) {
				[[autocolor[currentColor] objectAtIndex: 1 + ac * 4]
					setRGBAtMagnitude: j andPhase: i to: acColor					
				];
			}
		}
		else {
			fullColorArray[currentColor][i][j][0] = colorArray[i][j][0];
			fullColorArray[currentColor][i][j][1] = colorArray[i][j][1];
			fullColorArray[currentColor][i][j][2] = colorArray[i][j][2];
		}
	}
	}
	for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) {
		[[colorMatrix cellAtRow: i column: j] setColorToR: tcolor[i][j][0] G: tcolor[i][j][1] B: tcolor[i][j][2] ];
		[[colorMatrix cellAtRow: i column: j] untoggle];
		[colorMatrix drawCellAtRow: i column: j];		
	}
	cachedColorArrayNeedsUpdate = YES;	
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
	NSEnumerator *acEnum;
	FSColor* col;
	NSNumber* n;
	int i, count, index;
	count = [autocolor[c] count] / 4;
	if(count == 0) return;
	acEnum = [autocolor[c] objectEnumerator];
	index = 0;
	for(i = 0; i < count; i++) {
		[acEnum nextObject];
		col = [acEnum nextObject];
		[col cacheInto: &(cache[index])];
		index += 8 * 8 * 3;
		n = [acEnum nextObject];
		x[i] = [n doubleValue];
		n = [acEnum nextObject];
		y[i] = [n doubleValue];
	}
}

- (void) addFixpointWithX: (double) x Y: (double) y name: (NSString*) name toAutocolor: (int) c {
	FSColor* col;
	int i;
	col = [[FSColor alloc] init];
	i = ([autocolor[c] count] / 4) % namedColorCount;
	[autocolor[c] addObject: name];
	[autocolor[c] addObject: [col colorFromR: named_color[i].r G: named_color[i].g B: named_color[i].b]];
	[autocolor[c] addObject: [NSNumber numberWithDouble: x]];
	[autocolor[c] addObject: [NSNumber numberWithDouble: y]];
	return;
}

- (IBAction) acRefine: (id) sender {
}

- (IBAction) acEdit: (id) sender {
}

- (IBAction) acDelete: (id) sender {
	int index, c;
	unsigned int indices[4];
	indices[0] = [acList indexOfSelectedItem] * 4;
	indices[1] = indices[0] + 1;
	indices[2] = indices[0] + 2;
	indices[3] = indices[0] + 3;
	c = [colorButton indexOfSelectedItem];
	[autocolor[c] removeObjectsFromIndices: indices numIndices: 4];
	[self change: self];
}

- (IBAction) acDeleteAll: (id) sender {
	[autocolor[[colorButton indexOfSelectedItem]] removeAllObjects];
	[self change: self];
}


- (int) numberOfColors { return [names count]; }

- (NSArray*) names { return names; }

- (void) setNamesTo: (NSArray*) newNames {
	NSString* name;
	NSEnumerator* nameEnum;
	BOOL namedColor;
	int k, i, j, c;
	float shade;
	
	names = [[NSArray arrayWithArray: newNames] retain];
	[self setup];
	nameEnum = [names objectEnumerator];
	while(name = [nameEnum nextObject]) {
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
	[smoothnessField setIntValue: smoothness[currentColor]]; 
}

- (void) getColorsFrom: (FSColorWidget*) cw {
	int i, j, k, c;
	names = [[NSArray arrayWithArray: cw->names] retain];
	for(k = 0; k < [self numberOfColors]; k++) for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) for(c = 0; c < 3; c++) {
			fullColorArray[k][i][j][c] = cw->fullColorArray[k][i][j][c];
			if(k == 0) colorArray[i][j][c] = fullColorArray[k][i][j][c];
	}
	[self setup];
	for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) {
		[[colorMatrix cellAtRow: i column: j] setColorToR: fullColorArray[0][i][j][0] G:  fullColorArray[0][i][j][1] B:  fullColorArray[0][i][j][2] ];
		[[colorMatrix cellAtRow: i column: j] untoggle];
		[colorMatrix drawCellAtRow: i column: j];		
	}
	for(i = 0; i < 64; i++) smoothness[i] = (cw->smoothness)[i];
	cachedColorArrayNeedsUpdate = YES;	
}

- (void) encodeWithCoder: (NSCoder*) coder
{
	int i, j, k, c, l, size;
	float* flat;
	
	// version 0
	size = 8 * 8 * 3 * [self numberOfColors];
	flat = malloc(sizeof(float) * size);
	l = 0;
	for(k = 0; k < [self numberOfColors]; k++) for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) for(c = 0; c < 3; c++) 
		flat[l++] = fullColorArray[k][i][j][c];
	[coder encodeObject: names];
	for(i = 0; i < size; i++) [coder encodeObject: [NSNumber numberWithFloat: flat[i]]];
	free(flat);
}

- (id) initWithCoder: (NSCoder*) coder
{
	float* flat;
	int i, j, k, c, l, size;
	self = [super init];

	// version 0
	names = [[coder decodeObject] retain];
	size = 8 * 8 * 3 * [self numberOfColors];
	flat = malloc(sizeof(float) * size);
	for(i = 0; i < size; i++) flat[i] = [[coder decodeObject] floatValue];
	l = 0;
	for(k = 0; k < [self numberOfColors]; k++) for(i = 0; i < 8; i++) for(j = 0; j < 8; j++) for(c = 0; c < 3; c++) 
		fullColorArray[k][i][j][c] = flat[l++];
	free(flat);
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
	NSMutableArray* array;
	int i;
	array = [[[NSMutableArray alloc] init] autorelease];
	for(i = 0; i < [self numberOfColors]; i++) [array addObject: [NSNumber numberWithInt: smoothness[i]]];
	return array;
}

- (void) readSmoothnessFrom: (NSArray*) smoothArray {
	NSEnumerator* en;
	NSNumber* n;
	int i;
	en = [smoothArray objectEnumerator];
	i = 0;
	while(n = [en nextObject]) smoothness[i++] = [n intValue];
}

- (void) clearSmoothnessArray {
	int i;
	for(i = 0; i < 64; i++) smoothness[i] = 0;
}

@end

@implementation FSColorWidgetCell

- (id) initImageCell: (NSImage*) image {
	NSLog(@"FSColorWidgetCell got initImageCell\n");
	return self;
}

- (id) initTextCell: (NSString*) string {
	NSLog(@"FSColorWidgetCell got initImageCell\n");
	return self;
}

- (SEL) action { return @selector(toggle:); }
- (id) target { return self; }

- (id) init {
	float r, g, b;
	self = [super init]; 
	
	r = (float) rand() / (float) RAND_MAX;
	g = (float) rand() / (float) RAND_MAX;
	b = (float) rand() / (float) RAND_MAX;
	color = [[NSColor colorWithCalibratedRed: r green: g blue: b alpha: 1.0] retain];	
	active = NO;
	return self;
}

- (void) setnrColorToR: (float) r G: (float) g B: (float) b {
	color = [[NSColor colorWithCalibratedRed: r green: g blue: b alpha: 1.0] retain];
}

- (void) setColorToR: (float) r G: (float) g B: (float) b {
	[color release];
	color = [[NSColor colorWithCalibratedRed: r green: g blue: b alpha: 1.0] retain];
}

- (void) drawInteriorWithFrame: (NSRect) frame inView: (NSView*) view
{
	if(active == YES) {
		[[NSColor whiteColor] set];
		NSRectFill(frame);
		frame = NSInsetRect(frame, 2.0, 2.0);
		[[NSColor blackColor] set];
		NSRectFill(frame);
		frame = NSInsetRect(frame, 2.0, 2.0);
	}
	[color set];
	NSRectFill(frame);
	
}

- (void) setColorWellTo: (NSColorWell*) cw { colorWell = [cw retain]; }

- (NSColor*) color { return color; }
- (BOOL) active { return active; }
- (void) toggle: (id) sender {
	if(active == NO) {
		[color release];
		color = [[colorWell color] retain];
	}
	active = (active == YES)? NO: YES;
}
- (void) untoggle { active = NO; }
- (void) retoggle { active = YES; }

@end
