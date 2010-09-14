//
//  FSViewer.h
//  FractalStream
//
//  Created by Matt Noonan on 8/17/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FSDynamics.h"
#import "FSOverlay.h"
#import "FSScene.h"
#import "FSWorkerManager.h"
#import "FSComplexNumber.h"

@interface FSViewer : NSView {
	IBOutlet FSDynamics* dynamics;
	IBOutlet FSOverlay* overlay;
	IBOutlet NSResponder* interaction;
	IBOutlet FSWorkerManager* workManager;
	double panX, panY;
	double scale;
	NSImage* savedBackground;
	double savedPanX, savedPanY, savedScale;
	
	BOOL followingTouches;
	BOOL panningTouches;
	double initialTouchLocation[2];
}

- (void) panByX: (double) x Y: (double) y;
- (void) scaleBy: (double) factor fromX: (double) x Y: (double) y;
- (void) resetPanAndScale;
- (double) panX;
- (double) panY;
- (double) scale;

- (void) drawRect: (NSRect) rect;
- (void) drawScene: (FSScene*) scene;
- (void) drawSceneOnMainThread: (FSScene*) scene;

- (FSComplexNumber*) coordinateOfWindowLocation: (NSPoint) p forScene: (FSScene*) scene;

@end
