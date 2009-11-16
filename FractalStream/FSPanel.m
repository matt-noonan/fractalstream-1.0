//
//  FSPanel.m
//  FractalStream
//
//  Created by Matthew Noonan on 3/19/09.
//  Copyright 2009 Cornell University. All rights reserved.
//

#import "FSPanel.h"

@implementation FSPanelHelper

- (IBAction) addPanel: (id) sender {
	if(panels == nil) panels = [[NSMutableArray alloc] init];
	[panels addObject: sender];
}

- (void) associatePanelsToDocument: (id) sender {
	NSEnumerator* en;
	id panel;
	if(panels) {
		en = [panels objectEnumerator];
		while(panel = [en nextObject]) 
			if([panel respondsToSelector: @selector(registerForNotifications:)])
				[panel registerForNotifications: sender];
	}
}

@end


@implementation FSPanel

- (void) awakeFromNib {
	isVisible = [super isVisible];
	//if(helper) [helper addPanel: self];
}

- (void) registerForNotifications: (id) owningDocument {
	[[NSNotificationCenter defaultCenter] addObserver: self
		selector: @selector(activate:)
		name: @"FSDocumentDidBecomeActive"
		object: owningDocument
	];
	[[NSNotificationCenter defaultCenter] addObserver: self
		selector: @selector(deactivate:)
		name: @"FSDocumentDidResignActive"
		object: owningDocument
	];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[super dealloc];
}


- (void) activate: (NSNotification*) note {
	if(isVisible) [self orderFront: self];
}

- (void) deactivate: (NSNotification*) note {
	isVisible = [super isVisible];
	[self orderOut: self];
}

@end
