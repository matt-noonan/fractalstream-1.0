//
//  FSEditController.h
//  FractalStream
//
//  Created by Matt Noonan on 8/15/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "FSWorkerManager.h"
#import "FSKernelData.h"
#import "FSWorker.h"

@interface FSEditController : NSObject {
	IBOutlet NSView* codeView;
	IBOutlet NSView* descriptionView;
	IBOutlet NSTextField* titleView;

	char test[64][64];
	FSWorkerManager* manager;
}

- (IBAction) compile: (id) sender;
- (IBAction) displayHelp: (id) sender;
- (void) processResults: (FSWorker*) worker;

@end
