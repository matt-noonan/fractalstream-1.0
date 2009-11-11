//
//  FSStartup.m
//  FractalStream
//
//  Created by Matthew Noonan on 2/3/09.
//  Copyright 2009 Cornell University. All rights reserved.
//

#import "FSStartup.h"


@implementation FSStartup

- (void) awakeFromNib {
	[slsave setTarget: nil];
	[slsave setAction: @selector(saveToLibrary:)];
	[embedtool setTarget: nil];
	[embedtool setAction: @selector(embedTool:)];
}

- (IBAction) openLibrary: (id) sender {
	NSError* error;
	[[[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay: YES error: &error]
		openScriptLibrary];
}

@end
