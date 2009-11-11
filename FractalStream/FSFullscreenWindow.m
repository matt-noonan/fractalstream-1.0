//
//  FSFullscreenWindow.m
//  FractalStream
//
//  Created by Matthew Noonan on 3/15/09.
//  Copyright 2009 Cornell University. All rights reserved.
//

#import "FSFullscreenWindow.h"

static BOOL _FSFullscreenWindow_usingFullscreen = NO;

@implementation FSFullscreenWindow
/*
- (void) startFullscreenWithView: (NSView*) view {
	int windowLevel;
	
	if(_FSFullscreenWindow_usingFullscreen) return;
	_FSFullscreenWindow_usingFullscreen = YES;
	CGDisplayCapture(kCGDirectMainDisplay);
	windowLevel = CGShieldingWindowLevel();
	window = [[NSWindow alloc] initWithContentRect: [[[view window] screen] frame]
		styleMask: NSBorderlessWindowMask
		backing: NSBackingStoreBuffered
		defer: NO
		screen: [[view window] screen]
	];
	[window setLevel: windowLevel];
	[window setBackgroundColor: [NSColor blackColor]];
	[window makeKeyAndOrderFront: nil];
	[window setContentView: view];
	[view setFrame: [[[view window] screen] frame]];
}

- (void) endFullscreenView {
	[window orderOut: self];
	[window release];
	CGDisplayRelease(kCGDirectMainDisplay);
	_FSFullscreenWindow_usingFullscreen = NO;	
}
*/
@end
