//
//  FSScriptLibraryController.h
//  FractalStream
//
//  Created by Matthew Noonan on 1/27/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FSSave.h"
#import "FSDocument.h"

@interface FSScriptLibraryItem : NSObject {
	NSImage* preview;
	NSString* title;
	NSData* description;
	NSString* path;
	NSMutableArray* children;
	BOOL group;
}

- (void) loadChildren;
- (id) initWithPath: (NSString*) p file: (NSString*) f;
- (id) makeLibraryItemForPath: (NSString*) p;
- (BOOL) isGroup;
- (NSString*) title;
- (NSData*) description;
- (int) children;
- (id) child: (int) c;
- (NSString*) path;
- (NSImage*) image;

@end

@interface FSScriptLibraryController : NSObject {
	NSMutableArray* library;
	IBOutlet NSTextView* description;
	IBOutlet NSImageView* previewer;
	IBOutlet NSOutlineView* outline;
	IBOutlet FSDocument* theDoc;
	IBOutlet NSButton* openButton;
	IBOutlet NSButton* openEditorButton;
	BOOL useOutlineView;
}

- (IBAction) newScript: (id) sender;
- (IBAction) openScript: (id) sender;
- (IBAction) editScript: (id) sender;
- (IBAction) switchScriptView: (id) sender;

- (void) newSelection: (NSNotification*) note;
- (void) reload;
- (int) outlineView: (NSOutlineView*) outlineView numberOfChildrenOfItem: (id) item;
- (BOOL) outlineView: (NSOutlineView*) outlineView isItemExpandable: (id) item;
- (id) outlineView: (NSOutlineView*) outlineView child: (int) index ofItem: (id) item;
- (id) outlineView: (NSOutlineView*) outlineView objectValueForTableColumn: (NSTableColumn*) col byItem: (id) item;


@end
