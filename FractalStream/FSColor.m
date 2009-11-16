//
//  FSColor.m
//  FractalStream
//
//  Created by Matthew Noonan on 7/7/09.
//  Copyright 2009 Cornell University. All rights reserved.
//

#import "FSColor.h"

@implementation FSGradient 

- (id) initWithR: (float) r G: (float) g B: (float) b {
	self = [super init];
	[self resetToColor: [NSColor colorWithCalibratedRed: r*0.5 green: g*0.5 blue: b*0.5 alpha: 1.0]];
	[self addColor: [NSColor colorWithCalibratedRed: r + 0.5*g green: g+0.4*b blue: b+0.2*r alpha: 1.0] atStop: 0.5];
	smoothing = 0;
	linear = YES;
	subdivisions = 16;
	cacheDirty = YES;
	cache = malloc(subdivisions * 3 * sizeof(float));
	return self;
}

- (id) init {
 	self = [super init];
	[self resetToColor: [NSColor colorWithCalibratedRed: 1.0 green: 1.0 blue: 1.0 alpha: 1.0]];
	name = [[NSString stringWithString: @"< please name me >"] retain];
	smoothing = 0;
	linear = YES;
	subdivisions = 16;
	cacheDirty = YES;
	cache = malloc(subdivisions * 3 * sizeof(float));
	return self;
}

- (void) dealloc {
	free(cache);
	[name release];
	[stopArray release];
	[colorArray release];
	[super dealloc];
}

- (id) initWithCoder: (NSCoder*) coder {
	self = [super init];
	name = [[coder decodeObjectForKey: @"name"] retain];
	stopArray = [[coder decodeObjectForKey: @"stops"] retain];
	colorArray = [[coder decodeObjectForKey: @"colors"] retain];
	smoothing = [[coder decodeObjectForKey: @"isSmooth"] intValue];
	linear = [[coder decodeObjectForKey: @"isLinear"] boolValue];
	subdivisions = [[coder decodeObjectForKey: @"subdivisions"] intValue];
	cacheDirty = YES;
	cache = malloc(subdivisions * 3 * sizeof(float));
	return self;
}

- (void) encodeWithCoder: (NSCoder*) coder {
	[coder encodeObject: name forKey: @"name"];
	[coder encodeObject: stopArray forKey: @"stops"];
	[coder encodeObject: colorArray forKey: @"colors"];
	[coder encodeObject: [NSNumber numberWithInt: smoothing] forKey: @"isSmooth"];
	[coder encodeObject: [NSNumber numberWithBool: linear] forKey: @"isLinear"];
	[coder encodeObject: [NSNumber numberWithInt: subdivisions] forKey: @"subdivisions"];
	return;
}

- (NSString*) name { return name; }
- (void) setColorName: (NSString*) newName {
	[name release];
	name = [[NSString stringWithString: newName] retain];
}


- (void) resetToColor: (NSColor*) c {
	NSColor* cd;
	cd = [NSColor colorWithCalibratedRed: [c redComponent]
		green: [c greenComponent]
		blue: [c blueComponent]
		alpha: 1.0
	];
	stopArray = [[NSMutableArray arrayWithObjects: [NSNumber numberWithFloat: 0.0], [NSNumber numberWithFloat: 1.0], nil] retain];
	colorArray = [[NSMutableArray arrayWithObjects: cd, cd, nil] retain];
	cacheDirty = YES;
}

- (NSColor*) colorForOffset: (float) offset {
	NSNumber* stop;
	NSColor *c0, *c1, *c;
	NSEnumerator* stopEnumerator, *colorEnumerator;
	float r, g, b, x, x0, x1;
	int index;
	stopEnumerator = [stopArray objectEnumerator];
	colorEnumerator = [colorArray objectEnumerator];
	c0 = [colorEnumerator nextObject]; c1 = nil;
	x0 = 0.0; [stopEnumerator nextObject];
	index = 0;
	offset -= (float)((int) offset);
	while ((stop = [stopEnumerator nextObject])) {
		++index;
		c1 = [colorEnumerator nextObject];
		x1 = [stop floatValue];
		if(x1 >= offset) break;
		c0 = c1;		
		x0 = x1;
	}
	x = 1.0 - (offset - x0) / (x1 - x0);
	r = [c0 redComponent] * x + [c1 redComponent] * (1.0 - x);
	g = [c0 greenComponent] * x + [c1 greenComponent] * (1.0 - x);
	b = [c0 blueComponent] * x + [c1 blueComponent] * (1.0 - x);
	return [NSColor colorWithCalibratedRed: r green: g blue: b alpha: 1.0];
}

- (void) addColor: (NSColor*) color atStop: (float) offset {
	NSNumber* stop;
	NSColor *c0, *c1, *c;
	NSEnumerator* stopEnumerator, *colorEnumerator;
	float r, g, b, x, x0, x1;
	int index;
	stopEnumerator = [stopArray objectEnumerator];
	colorEnumerator = [colorArray objectEnumerator];
	c0 = [colorEnumerator nextObject];
	x0 = 0.0; [stopEnumerator nextObject];
	index = 0;
	while ((stop = [stopEnumerator nextObject])) {
		++index;
		c1 = [colorEnumerator nextObject];
		x1 = [stop floatValue];
		if(x1 >= offset) break;
		c0 = c1;		
		x0 = x1;
	}
	[colorArray insertObject: color atIndex: index];
	[stopArray insertObject: [NSNumber numberWithFloat: offset] atIndex: index];
	cacheDirty = YES;
}

- (void) setSmoothing: (int) sm { smoothing = sm; cacheDirty = YES; }
- (int) smoothing { return smoothing; }

- (void) setLinear: (BOOL) li { linear = li; cacheDirty = YES; }
- (BOOL) isLinear { return linear; }

- (int) subdivisions { return subdivisions; }
- (void) setSubdivisions: (int) sd {
	subdivisions = sd;
	if((subdivisions <= 0) || subdivisions > 1024) subdivisions = 1024;
	cacheDirty = YES;
}

- (float*) getColorCache {
	int i;
	float t, dt;
	NSColor* c;
	if(cacheDirty == NO) return cache;
	cache = realloc(cache, 3 * 8 * subdivisions * sizeof(float));
	for(i = 0, t = 0.0, dt = 1.0 / (float) subdivisions; i < subdivisions; i++, t += dt) {
		c = [self colorForOffset: t];
		cache[3 * i + 0] = [c redComponent];
		cache[3 * i + 1] = [c greenComponent];
		cache[3 * i + 2] = [c blueComponent];
	}
	cacheDirty = NO;
	return cache;
}

- (NSArray*) stopArray { return stopArray; }
- (NSArray*) colorArray { return colorArray; }
- (void) setStops: (NSArray*) stops andColors: (NSArray*) colors {
	if(stopArray) [stopArray release];
	if(colorArray) [colorArray release];
	stopArray = [[NSMutableArray arrayWithArray: stops] retain];
	colorArray = [[NSMutableArray arrayWithArray: colors] retain];
	cacheDirty = YES;
}

@end

@implementation FSGradientControl

- (void) awakeFromNib { 
	gradient = [[FSGradient alloc] init];
	[self setNeedsDisplay: YES];
}

- (void) connectToLibrary: (id) lib {
	library = lib;
}

- (void) setNotificationSender: (id) ns { noteSender = ns; }

- (void) setGradient: (FSGradient*) grad { 
	[gradient release];
	gradient = [grad retain];
	[self setNeedsDisplay: YES];
}

- (void) insertGradient: (FSGradient*) grad {
//	NSLog(@"telling gradient %@ to copy from gradient %@\n", gradient, grad);
	[gradient setStops: [grad stopArray] andColors: [grad colorArray]];
	if(noteSender) [[NSNotificationCenter defaultCenter] postNotificationName: @"FSColorsChanged" object: noteSender];
	[self setNeedsDisplay: YES];
}

- (IBAction) fill: (id) sender {
	[gradient resetToColor: [colorWell color]];
	if(library != nil) [library saveColor: gradient];
	if(noteSender) [[NSNotificationCenter defaultCenter] postNotificationName: @"FSColorsChanged" object: noteSender];
	[self setNeedsDisplay: YES];
}

- (void) mouseDown: (NSEvent*) theEvent {
	float stop;
	NSPoint clickInView;
	clickInView = [self convertPoint: [theEvent locationInWindow] fromView: nil];
	stop = (float) (clickInView.x - [self bounds].origin.x) / (float) [self bounds].size.width;
	if((stop >= 0.0) && (stop <= 1.0)) {
		[gradient addColor: [colorWell color] atStop: stop];
		if(library != nil) [library saveColor: gradient];
		if(noteSender) [[NSNotificationCenter defaultCenter] postNotificationName: @"FSColorsChanged" object: noteSender];
		[self setNeedsDisplay: YES];
	}
}


- (void) drawRect: (NSRect) rect {
	int i;
	float x, dx;
	int width, height;
	NSRect slice;
	width = [self bounds].size.width;
	height = [self bounds].size.height;
	x = 0.0;
	dx = 1.0 / (float) [self bounds].size.width;
	for(i = 0; i < width; i++, x += dx) {
		slice = NSMakeRect([self bounds].origin.x + (float) i + 0.5, [self bounds].origin.y + 0.5, 1, [self bounds].size.height);
		[[gradient colorForOffset: x] set];
		[NSBezierPath fillRect: slice];
	}
	[[NSColor blackColor] set];
	[NSBezierPath strokeRect: 
		NSMakeRect([self bounds].origin.x + 0.5, [self bounds].origin.y + 0.5, [self bounds].size.width - 1.0, [self bounds].size.height - 1.0)
	];
	[NSBezierPath fillRect: 
		NSMakeRect([self bounds].origin.x + (float) (width / 2), [self bounds].origin.y + 0.5, 1.0, [self bounds].size.height / 6.0)
	];
	[NSBezierPath fillRect: 
		NSMakeRect([self bounds].origin.x + (float) (width / 4), [self bounds].origin.y + 0.5, 1.0, [self bounds].size.height / 8.0)
	];
	[NSBezierPath fillRect: 
		NSMakeRect([self bounds].origin.x + 3.0 * (float) (width / 4), [self bounds].origin.y + 0.5, 1.0, [self bounds].size.height / 8.0)
	];
}

@end

@implementation FSColor

- (FSColor*) nextColorForX: (double) X Y: (double) Y {
	FSColor* c;
	float r, g, b;
	c = [[FSColor alloc] init];
	c -> x = X; c -> y = Y;
	switch(nextAutocolor & 7) {
		case 0:		r = 0.0;	g = 0.0;	b = 1.0;	break;
		case 1:		r = 0.0;	g = 1.0;	b = 0.0;	break;
		case 2:		r = 1.0;	g = 0.0;	b = 0.0;	break;
		case 3:		r = 0.0;	g = 1.0;	b = 1.0;	break;
		case 4:		r = 1.0;	g = 1.0;	b = 0.0;	break;
		case 5:		r = 1.0;	g = 0.0;	b = 1.0;	break;
		case 6:		r = 1.0;	g = 0.5;	b = 0.5;	break;
		case 7:		r = 1.0;	g = 1.0;	b = 1.0;	break;
	}
	if(nextAutocolor & 8) { r *= 0.5; g *= 0.5; b *= 0.5; }
	c -> gradient = [[FSGradient alloc] initWithR: r G: g B: b];
	if(gradient) {
		[c -> gradient setSmoothing: [gradient smoothing]];
		[c -> gradient setSubdivisions: [gradient subdivisions]];
		[c -> gradient setLinear: [gradient isLinear]];
	}
	else {
		[c -> gradient setSmoothing: 0];
		[c -> gradient setSubdivisions: 16];
		[c -> gradient setLinear: YES];
	}
	++nextAutocolor;
	return [c autorelease];
}

- (BOOL) hasInfinity { return infinity; }
- (void) setHasInfinity: (BOOL) inf { 
	if((infinity != inf) && (inf == YES)) {
		infinity = inf;
		[[NSNotificationCenter defaultCenter] postNotificationName: @"FSAutocolorChanged" object: self];
	}
	else infinity = inf;
}

- (FSColor*) subcolor: (int) i { return ((i < 0) || (i >= [subcolor count]))? nil : [subcolor objectAtIndex: i]; }

- (void) removeAllSubcolors {
	[subcolor release];
	subcolor = [[NSMutableArray alloc] init];
}

- (void) removeSubcolorAtIndex: (int) i {
	[subcolor removeObjectAtIndex: i];
}

- (NSArray*) subcolors { return subcolor; }
- (double) xVal { return x; }
- (double) yVal { return y; }

- (id) init {
	self = [super init];
	name = nil;
	subcolor = [[NSMutableArray alloc] init];
	gradient = nil;
	locked = NO;
	nextAutocolor = 0;
	ac = NO;
	infinity = NO;
	return self;
}

- (void) dealloc {
	[super dealloc];
}


- (id) initWithCoder: (NSCoder*) coder {
	self = [super init];
	name = [[coder decodeObjectForKey: @"name"] retain];
	//subcolor = [[coder decodeObjectForKey: @"subcolor"] retain];
	//nextAutocolor = [[coder decodeObjectForKey: @"nextAutocolor"] intValue];
	// ignore saved autocolors
	subcolor = [[NSMutableArray alloc] init];
	nextAutocolor = 0;
	gradient = [[coder decodeObjectForKey: @"color"] retain];
	locked = [[coder decodeObjectForKey: @"locked"] boolValue];
	ac = [[coder decodeObjectForKey: @"useAutocolor"] boolValue];
	infinity = NO;
	
	return self;
}

- (void) encodeWithCoder: (NSCoder*) coder {
	[coder encodeObject: name forKey: @"name"];
	[coder encodeObject: subcolor forKey: @"subcolor"];
	[coder encodeObject: gradient forKey: @"color"];
	[coder encodeObject: [NSNumber numberWithBool: locked] forKey: @"locked"];
	[coder encodeObject: [NSNumber numberWithBool: ac] forKey: @"useAutocolor"];
	[coder encodeObject: [NSNumber numberWithInt: nextAutocolor] forKey: @"nextAutocolor"];
	return;
}

- (void) createNewSubcolorForX: (double) X Y: (double) Y {
	[subcolor addObject: [self nextColorForX: X Y: Y]]; 
	NSLog(@"createNewSubcolorForX: %f Y: %f\n", X, Y);
	// tell the world: we made a new color
	[self performSelectorOnMainThread: @selector(notifyAutocolorChanged) withObject: nil waitUntilDone: NO];
}

- (FSGradient*) gradientForX: (double) X Y: (double) Y withTolerance: (double) epsilon allowNew: (BOOL) allow {
	NSEnumerator* en;
	FSColor* c;
	
	if(ac == NO) return gradient;
	en = [subcolor objectEnumerator];
	if((locked == NO) && (allow == YES)) {
		synchronizeTo(subcolor) {
			while((c = [en nextObject])) if([c isNearX: X Y: Y withTolerance: epsilon]) return [c gradient];
			if([subcolor count] >= 100) return [[[FSGradient alloc] initWithR: 0.4 G: 0.4 B: 0.4] autorelease];
			c = [self nextColorForX: X Y: Y];
			[subcolor addObject: c]; 
			// tell the world: we made a new color
			[self performSelectorOnMainThread: @selector(notifyAutocolorChanged) withObject: nil waitUntilDone: NO];
			return [c gradient];
		}
	}
	else {
		// create blended gradient
		int i,j;
		double weight;
		double w[1024];
		double d;
		float r, g, b, t, dt;
		int s;
		FSGradient* gr;
		NSColor* co;
		weight = 0.0; i = 0;
		while((c = [en nextObject])) { 
			d = (([c xVal] - X) * ([c xVal] - X) + ([c yVal] - Y) * ([c yVal] - Y)); 
			if(d <= 0.00000001) d = 0.00000001;
			weight += 1.0 / d; 
			w[i++] = 1.0 / d;
		}
		if(weight <= 0.0) { 
			gr = [[FSGradient alloc] initWithR: 0.2 G: 0.2 B: 0.2];
			return [gr autorelease];
		}
		gr = [[FSGradient alloc] init];
		s = [[self baseGradient] subdivisions]; if(s <= 0) s = 1;
		t = 0.0; dt = 1.0 / (float) s;
		for(i = 0; i < s; i++) {
			r = 0.0; g = 0.0; b = 0.0;
			j = 0;
			en = [subcolor objectEnumerator];
			while((c = [en nextObject])) {
				co = [[[c baseGradient] colorArray] objectAtIndex: j];
				r += w[j] * [co redComponent] / weight;
				g += w[j] * [co greenComponent] / weight;
				b += w[j] * [co blueComponent] / weight;
				++j;
			}
			if(i == 0) [gr resetToColor: [NSColor colorWithDeviceRed: r green: g blue: b alpha: 1.0]];
			else [gr addColor: [NSColor colorWithDeviceRed: r green: g blue: b alpha: 1.0] atStop: t];
		}
		return [gr autorelease];
	}
}

- (void) notifyAutocolorChanged {
	[[NSNotificationCenter defaultCenter] postNotificationName: @"FSAutocolorChanged" object: self];
}

- (BOOL) isNearX: (double) X Y: (double) Y withTolerance: (double) epsilon {
	return (((x - X)*(x - X) + (y - Y)*(y - Y)) <= (epsilon*epsilon))? YES : NO;
}

- (void) setGradient: (FSGradient*) grad {
	[self setGradient: grad forColor: -1];
}

- (void) setGradient: (FSGradient*) grad forColor: (int) color {
	if(color < 0) { if(gradient) [gradient release]; gradient = [grad retain]; }
	else if(color < [subcolor count]) [[subcolor objectAtIndex: color] setGradient: grad];
}

- (FSGradient*) gradient {
	return ac? nil : gradient;
}

- (FSGradient*) baseGradient {
	return gradient;
}

- (void) useAutocolor: (BOOL) a { ac = a; }
- (BOOL) usesAutocolor { return ac; }

- (BOOL) isLocked { return locked; }
- (void) setLocked: (BOOL) l { locked = l; }
- (NSString*) name { return name; }
- (void) setName: (NSString*) n {
	if(name) [name release];
	name = [n retain];
}

@end

