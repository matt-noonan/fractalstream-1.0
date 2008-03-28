//
//  FSViewManager.m
//  FractalStream
//
//  Created by Matt Noonan on 4/14/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "FSViewManager.h"

@implementation FSViewManager
	
- (IBAction) updateViewport: (id) sender
{
	[viewport 
		setScale:	[[session getCurrentNode] scale]
		X:			[[session getCurrentNode] centerX]
		Y:			[[session getCurrentNode] centerY]
	];
	if([session getCurrentNode] -> program == 1)
		[[viewport window] setTitle: @"Parameter Plane"];
	else if([session getCurrentNode] -> program == 3)
		[[viewport window] setTitle: [NSString stringWithFormat: 
		@"Dynamical Plane for %1.3e + i %1.3e", [viewport pX], [viewport pY]]]; 
		/* that is SO DUMB. */
		
	[viewport setNeedsDisplay: YES];
}

@end

