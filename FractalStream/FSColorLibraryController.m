//
//  FSColorLibraryController.m
//  FractalStream
//
//  Created by Matthew Noonan on 1/27/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "FSColorLibraryController.h"

@implementation FSColorLibraryController

- (void) awakeFromNib {
	library = [[NSMutableArray alloc] init];
	if(outline) [[NSNotificationCenter defaultCenter]
		addObserver: self selector: @selector(outlineSelectedColor:)
		name: NSOutlineViewSelectionDidChangeNotification object: outline
	];
	[self loadColorLibrary: self];
	if(outline) [editor connectToLibrary: self];
	else [editor connectToLibrary: nil];
}

- (IBAction) newColor: (id) sender {
	[library addObject: [[[FSGradient alloc] init] autorelease]];
	[outline reloadData];
}

- (IBAction) deleteColor: (id) sender {
}

- (IBAction) changeColor: (id) sender {
	[editor insertGradient: [library objectAtIndex: [button indexOfSelectedItem] - 1]];
}

- (IBAction) loadColorLibrary: (id) sender {
	NSFileManager* fs;
	NSArray* ar;
	id item;
	NSEnumerator* en;
	BOOL isDirectory;
	NSString* path;
	
	NSLog(@"color library %@ got loadColorLibrary from %@\n", self, sender);
	path = [NSString stringWithFormat: @"%@/", [[[NSBundle mainBundle] builtInPlugInsPath] stringByAppendingPathComponent: @"Colors/"]];
	if(library) [library release];
	library = [[NSMutableArray alloc] init];
	fs = [NSFileManager defaultManager];
	ar = [fs subpathsAtPath: path];
	if(outline == nil) { [button removeAllItems]; [button addItemWithTitle: @"< click to use color from library >"]; }
	en = [ar objectEnumerator];
	while(item = [en nextObject]) {
		[fs fileExistsAtPath:
			[NSString stringWithFormat: @"%@%@", path, item]
			isDirectory: &isDirectory
		];	
		if([item hasSuffix: @".fscolor"] && (isDirectory == NO)) {
			[library addObject: [NSKeyedUnarchiver unarchiveObjectWithFile: [NSString stringWithFormat: @"%@%@", path, item]]];
			NSLog(@"adding color: %@\n", [[library objectAtIndex: [library count] - 1] name]);
			if(outline == nil) {
				[button addItemWithTitle: [[library objectAtIndex: [library count] - 1] name]];
			}
		}
	}
	if(outline) [outline reloadData];
	NSLog(@"loadColorLibrary finished\n");
}

- (void) saveColor: (FSGradient*) grad {
	[NSKeyedArchiver
		archiveRootObject: grad
		toFile: [NSString stringWithFormat: @"%@%@.fscolor", 
			[NSString stringWithFormat: @"%@/", [[[NSBundle mainBundle] builtInPlugInsPath] stringByAppendingPathComponent: @"Colors/"]],
			[grad name]
		]
	];
}

- (void) outlineSelectedColor: (NSNotification*) note {
	[editor insertGradient: [outline itemAtRow: [outline selectedRow]]];
}

- (int) outlineView: (NSOutlineView*) outlineView numberOfChildrenOfItem: (id) item {
	return (item == nil)? [library count] : 0;
}

- (BOOL) outlineView: (NSOutlineView*) outlineView isItemExpandable: (id) item { return (item == nil)? YES : NO; }

- (id) outlineView: (NSOutlineView*) outlineView child: (int) index ofItem: (id) item { 
	if (item == nil) return [library objectAtIndex: index];
	return nil;
}

- (id) outlineView: (NSOutlineView*) outlineView objectValueForTableColumn: (NSTableColumn*) col byItem: (id) item {
	return [item name]; 
}

- (void) outlineView: (NSOutlineView*) outlineView setObjectValue: (id) val forTableColumn: (NSTableColumn*) col byItem: (id) item {
	[item setColorName: val];
	[outline reloadData];
}

@end