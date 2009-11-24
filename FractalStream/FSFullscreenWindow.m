//
//  FSFullscreenWindow.m
//  FractalStream
//
//  Created by Matthew Noonan on 3/15/09.
//  Copyright 2009 Cornell University. All rights reserved.
//

#import "FSFullscreenWindow.h"


@implementation FSFullscreenWindow


- (id) init { 
	self = [super init];
	isFullscreen = NO;
	return self;
}

- (id) initForWindow: (NSWindow*) w {
	self = [super init];
	isFullscreen = NO;
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(restoreMenu:) name: @"NSWindowWillCloseNotification" object: w];	
	return self;
}

- (void) restoreMenu: (NSNotification*) note {
	if(isFullscreen)
		if([[[savedView window] screen] isEqual: [[NSScreen screens] objectAtIndex: 0]]) [NSMenu setMenuBarVisible: YES];
}

- (void) startFullscreenWithView: (NSView*) view {
	savedFrame = [[view window] frame];
	savedView = view;
	[[view window] setFrame: [[view window] frameRectForContentRect: [[[view window] screen] frame]] display: YES animate: YES];
	if([[[view window] screen] isEqual: [[NSScreen screens] objectAtIndex: 0]]) [NSMenu setMenuBarVisible: NO];
	isFullscreen = YES;
}

- (void) endFullscreenView {
	[[savedView window] setFrame: savedFrame display: YES animate: YES];
	if([[[savedView window] screen] isEqual: [[NSScreen screens] objectAtIndex: 0]]) [NSMenu setMenuBarVisible: YES];
	isFullscreen = NO;
}

- (void) toggleFullscreenWithView: (NSView*) view {
	if(isFullscreen) [self endFullscreenView];
	else [self startFullscreenWithView: view];
}


@end
