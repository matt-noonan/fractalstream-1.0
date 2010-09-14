//
//  FSInteraction.h
//  FractalStream
//
//  Created by Matt Noonan on 8/17/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FSViewer.h"
#import "FSDynamics.h"
#import "FSOverlay.h"
#import "FSWorkerManager.h"
#import "FSKernel.h"
#import "FSScene.h"
#import "FSComplexNumber.h"

@interface FSInteraction : NSResponder {
	IBOutlet FSViewer* viewer;
	IBOutlet FSDynamics* dynamics;
	IBOutlet FSOverlay* overlay;
	FSWorkerManager* manager;
	
	NSPoint lastMouseDown, lastRightMouseDown;
	
	FSKernel* kernel;
	FSScene* scene;

	BOOL ignoreNextMouseUp;
}

- (IBAction) runDynamics: (id) sender;
- (void) sendSceneNotification;
- (FSScene*) scene;

@end
