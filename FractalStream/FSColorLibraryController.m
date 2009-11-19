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
	index = -1;
	if(outline) [[NSNotificationCenter defaultCenter]
		addObserver: self selector: @selector(outlineSelectedColor:)
		name: NSOutlineViewSelectionDidChangeNotification object: outline
	];
	[self loadColorLibrary: self];
	if(outline) [editor connectToLibrary: self];
	else [editor connectToLibrary: nil];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[super dealloc];
}

- (IBAction) newColor: (id) sender {
	[library addObject: [[[FSGradient alloc] init] autorelease]];
	[outline reloadData];
	[self saveColor: nil];
}

- (IBAction) deleteColor: (id) sender {
	if([outline selectedRow] >= 0) [library removeObjectAtIndex: [outline selectedRow]];
	[outline reloadData];
	[self saveColor: nil];
}

- (IBAction) changeColor: (id) sender {
	if([button indexOfSelectedItem]) {
		[editor insertGradient: [library objectAtIndex: [button indexOfSelectedItem] - 1]];
		[button selectItemAtIndex: 0];
	}
}

- (IBAction) loadColorLibrary: (id) sender {
	NSFileManager* fs;
	NSArray* ar;
	id item;
	NSEnumerator* en;
	BOOL isDirectory;
	NSString* path;
	
#ifdef WINDOWS
	NSLog(@"FSColorLibraryController needed plugins, broken on Cocotron\n");
	return;
#endif
//	NSLog(@"color library %@ got loadColorLibrary from %@\n", self, sender);
	path = [NSString stringWithFormat: @"%@/", [[[NSBundle mainBundle] builtInPlugInsPath] stringByAppendingPathComponent: @"Colors/"]];
	if(library) [library release];

	library = [[NSKeyedUnarchiver unarchiveObjectWithFile: [NSString stringWithFormat: @"%@%@", path, @"ColorLibrary"]] retain];
	if(library == nil) library = [[NSMutableArray alloc] init];
	if(outline == nil) {
		en = [library objectEnumerator];
		while((item = [en nextObject])) [button addItemWithTitle: [item name]];
	}
	if(outline) { [outline reloadData]; [editor setGradient: [outline itemAtRow: [outline selectedRow]]]; }
//	NSLog(@"loadColorLibrary finished\n");
}

- (void) saveColor: (FSGradient*) grad {
	NSString* path;
#ifdef WINDOWS
	return;
#endif
	path = [NSString stringWithFormat: @"%@/ColorLibrary", [[[NSBundle mainBundle] builtInPlugInsPath] stringByAppendingPathComponent: @"Colors/"]];
	[NSKeyedArchiver archiveRootObject: library toFile: path];
	[self loadColorLibrary: self];
}

- (void) outlineSelectedColor: (NSNotification*) note {
	if([outline selectedRow] >= 0) [editor setGradient: [outline itemAtRow: [outline selectedRow]]];
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