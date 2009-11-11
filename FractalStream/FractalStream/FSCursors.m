//
//  FSCursors.m
//  FractalStream
//
//  Created by Matt Noonan on 3/18/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "FSCursors.h"


@implementation NSCursor(FSCursors)

+ (NSCursor*) zoomInCursor
{
	static NSCursor *zoomInCursor = nil;
	if(zoomInCursor == nil) {
		NSImage *picture = [NSImage imageNamed: @"ZoomIn"];
		NSPoint hotspot = NSMakePoint(7.0, 7.0);		
		zoomInCursor = [[NSCursor alloc] initWithImage: picture hotSpot: hotspot];
	}
	return zoomInCursor;
}


@end
