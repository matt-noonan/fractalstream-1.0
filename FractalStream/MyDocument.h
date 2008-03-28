//
//  MyDocument.h
//  FractalStream
//
//  Created by Matt Noonan on 3/15/06.
//  Copyright __MyCompanyName__ 2006 . All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import "FSSession.h"
#import "FSViewport.h"
#import "FSTools.h"
#import "FSBrowser.h"
#import "FSSave.h"

@interface MyDocument : NSDocument
{
	IBOutlet FSSession *session;  /* session history */
	IBOutlet FSBrowser *browser;
	
	void (*kernel)(int, double*, int, double*, int, double); /* program kernel */
//	IBOutlet FSProgramList* kernelLoader;
//	IBOutlet FSConfigurationSheet* configSheet;
	BOOL configured;
	BOOL newSession;
	FSSave* savedData;
	
	IBOutlet FSViewport* viewport;
	IBOutlet FSEController* editor;
	IBOutlet FSColorWidget* colorizer;
	IBOutlet FSTools* toolkit;
	
	IBOutlet NSTextField* iterationBox;
	IBOutlet NSTextField* radiusBox;
	IBOutlet NSTabView* mainTabView;
}

- (void) completeConfiguration;
- (void) iterations: (int*) it;
- (void) radius: (double*) rad;

@end
