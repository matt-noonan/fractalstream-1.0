//
//  FSColor.h
//  FractalStream
//
//  Created by Matthew Noonan on 7/7/09.
//  Copyright 2009 Cornell University. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FSThreading.h"

@interface FSGradient : NSObject <NSCoding> {
	NSString* name;
	NSMutableArray* stopArray;
	NSMutableArray* colorArray;
	int smoothing;
	BOOL linear;
	int subdivisions;
	float* cache;
	BOOL cacheDirty;
}

- (id) init;
- (void) dealloc;
- (id) initWithR: (float) r G: (float) g B: (float) b;
- (NSString*) name;
- (void) setColorName: (NSString*) newName;
- (NSColor*) colorForOffset: (float) offset;
- (void) addColor: (NSColor*) color atStop: (float) offset;
- (void) resetToColor: (NSColor*) c;
- (void) setSmoothing: (int) sm;
- (int) smoothing;
- (void) setLinear: (BOOL) li;
- (BOOL) isLinear;
- (int) subdivisions;
- (void) setSubdivisions: (int) sd;
- (float*) getColorCache;
- (NSArray*) stopArray;
- (NSArray*) colorArray;
- (void) setStops: (NSArray*) stops andColors: (NSArray*) colors;

@end

@interface FSGradientControl : NSView {
	FSGradient* gradient;
	IBOutlet NSColorWell* colorWell; 
	BOOL connectedToLibrary;
	id library, noteSender;
}

- (void) connectToLibrary: (id) lib;
- (void) setNotificationSender: (id) ns;
- (void) setGradient: (FSGradient*) grad;
- (void) insertGradient: (FSGradient*) grad;
- (IBAction) fill: (id) sender;
- (void) drawRect: (NSRect) rect;
- (void) mouseDown: (NSEvent*) theEvent;

@end

@interface FSColor : NSObject <NSCoding> {
	NSString* name;
	FSGradient* gradient;		// When gradient is nil, we are an autocolorer and
	NSMutableArray* subcolor;	//		subcolor will contain our array of FSColors 
	double x, y;
	BOOL locked, ac, infinity;
	int nextAutocolor;
}

- (id) init;
- (void) dealloc;
- (FSColor*) nextColorForX: (double) X Y: (double) Y;
- (void) createNewSubcolorForX: (double) X Y: (double) Y;
- (FSGradient*) gradientForX: (double) X Y: (double) Y withTolerance: (double) epsilon allowNew: (BOOL) allow;
- (BOOL) isNearX: (double) X Y: (double) Y withTolerance: (double) epsilon;
- (void) setGradient: (FSGradient*) grad;
- (void) setGradient: (FSGradient*) grad forColor: (int) color;
- (BOOL) isLocked;
- (void) setLocked: (BOOL) l;
- (void) useAutocolor: (BOOL) a;
- (BOOL) usesAutocolor;
- (void) removeAllSubcolors;
- (void) removeSubcolorAtIndex: (int) i;
- (NSString*) name;
- (void) setName: (NSString*) n;
- (FSGradient*) gradient;
- (FSColor*) subcolor: (int) i;
- (NSArray*) subcolors;
- (double) xVal;
- (double) yVal;
- (BOOL) hasInfinity;
- (void) setHasInfinity: (BOOL) inf;

@end