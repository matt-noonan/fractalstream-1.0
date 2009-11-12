//
//  FSFullscreenWindow.h
//  FractalStream
//
//  Created by Matthew Noonan on 3/15/09.
//  Copyright 2009 Cornell University. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>

@interface FSFullscreenWindow : NSObject {
	NSWindow* window;
	NSRect savedFrame;
	NSView* savedView;
	BOOL isFullscreen;
}


- (void) startFullscreenWithView: (NSView*) view;
- (void) endFullscreenView;
- (void) toggleFullscreenWithView: (NSView*) view;

@end
