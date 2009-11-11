//
//  FSPanel.h
//  FractalStream
//
//  Created by Matthew Noonan on 3/19/09.
//  Copyright 2009 Cornell University. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface FSPanelHelper : NSObject {
	NSMutableArray* panels;
}

- (void) addPanel: (id) sender;
- (void) associatePanelsToDocument: (id) sender;

@end

@interface FSPanel : NSPanel {
	BOOL isVisible;
	IBOutlet FSPanelHelper* helper;
}

- (void) awakeFromNib;
- (void) registerForNotifications: (id) owningDocument;
- (void) activate: (NSNotification*) note; 
- (void) deactivate: (NSNotification*) note;

@end
