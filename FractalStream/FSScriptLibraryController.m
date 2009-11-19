//
//  FSScriptLibraryController.m
//  FractalStream
//
//  Created by Matthew Noonan on 1/27/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "FSScriptLibraryController.h"

@implementation FSScriptLibraryItem

- (id) initWithPath: (NSString*) p file: (NSString*) f {
	self = [super init];
	return [[self makeLibraryItemForPath: [NSString stringWithFormat: @"%@%@", p, f]] retain];
}

- (id) makeLibraryItemForPath: (NSString*) p {
	NSFileManager* fs;
	fs = [NSFileManager defaultManager];
	path = [p copy];
	children = nil;
	if([fs fileExistsAtPath: p isDirectory: &group] == NO) return nil;
	if(group == YES) {
		/* We are a directory, use the name as our title */
		title = [[path lastPathComponent] copy];
		path = [[NSString stringWithFormat: @"%@/", path] retain];
		description = nil; preview = nil;
	}
	else {
		NSArray* array;
		id item;
		NSEnumerator* en;
		int i;
		/* We are a script, load our data */
		[FSSave useMiniLoads: YES];
		array = [[NSKeyedUnarchiver unarchiveObjectWithData: [NSData dataWithContentsOfFile: p]] minidata];
		en = [array objectEnumerator];
		title = nil; description = nil; preview = nil;
		i = 0;
		while(item = [en nextObject]) {
			switch(i) {
				case 0:
					title = [[NSString stringWithString: item] retain];
					break;
				case 1:  // source
					break;
				case 2:
					description = [[NSData dataWithData: item] retain];
					break;
				case 3:
					if([item isKindOfClass: [NSImage class]]) preview = [item copy];
					else preview = [[NSImage alloc] initWithData: item];
					break; 
				default:
					break;
			}
			++i;
		}
	} 
	return self;
}

- (void) loadChildren {
	NSFileManager* fs;
	NSArray* ar;
	id item;
	NSEnumerator* en;
	BOOL isDirectory;
	children = [[NSMutableArray alloc] init];
	fs = [NSFileManager defaultManager];
	ar = [fs directoryContentsAtPath: path];
	en = [ar objectEnumerator];
	while(item = [en nextObject]) {
		[fs fileExistsAtPath:
			[NSString stringWithFormat: @"%@%@", path, item]
			isDirectory: &isDirectory
		];	
		if([item hasSuffix: @".fs"] || isDirectory) 
			[children addObject: [[[FSScriptLibraryItem alloc]
				initWithPath: path file: item] autorelease]];
	}

}

- (BOOL) isGroup { return group; }
- (NSString*) title { return title; }
- (NSData*) description { return description; }
- (NSString*) path { return path; }
- (NSImage*) image { return preview; }
- (int) children { 
	if(group == NO) return 0;
	if(children == nil) [self loadChildren];
	return [children count];
}
- (id) child: (int) c {
	if(children == nil) [self loadChildren];
	return [children objectAtIndex: c];
}

- (void) dealloc {
	[children release];
	[super dealloc];
}

@end

@implementation FSScriptLibraryController

- (void) awakeFromNib {
	useOutlineView = YES;
	[[NSNotificationCenter defaultCenter]
		addObserver: self selector: @selector(newSelection:)
		name: NSOutlineViewSelectionDidChangeNotification object: outline
	];
	library = nil;
	[self reload];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter]
		removeObserver: self
		name: NSOutlineViewSelectionDidChangeNotification object: outline
	];
	[super dealloc];
}

- (void) reload {
	NSFileManager* fs;
	NSArray* ar;
	id item;
	NSEnumerator* en;
	BOOL isDirectory;
	NSString* path;
	
#ifdef WINDOWS
	NSLog(@"FSScriptLibraryController needs builtInPlugInsPath, not available in Cocotron\n");
	library = nil;
	return;
#endif
	path = [NSString stringWithFormat: @"%@/", [[[NSBundle mainBundle] builtInPlugInsPath] stringByAppendingPathComponent: @"Scripts/"]];
	if(library) [library release];
	library = [[NSMutableArray alloc] init];
	fs = [NSFileManager defaultManager];
	if(useOutlineView) ar = [fs directoryContentsAtPath: path];
	else ar = [fs subpathsAtPath: path];
	en = [ar objectEnumerator];
	while(item = [en nextObject]) {
		[fs fileExistsAtPath:
			[NSString stringWithFormat: @"%@%@", path, item]
			isDirectory: &isDirectory
		];	
		if([item hasSuffix: @".fs"] || (isDirectory && useOutlineView)) {
			[library addObject: [[[FSScriptLibraryItem alloc] initWithPath: path file: item] autorelease]];
		}
	}
	[outline reloadData];
}

- (int) outlineView: (NSOutlineView*) outlineView numberOfChildrenOfItem: (id) item {
	return (item == nil)? ((library == nil)? 0 : [library count]) : (int) [item children]; 
}

- (BOOL) outlineView: (NSOutlineView*) outlineView isItemExpandable: (id) item {
	return (item == nil)? YES : (useOutlineView? [item isGroup] : NO);
}

- (id) outlineView: (NSOutlineView*) outlineView child: (int) index ofItem: (id) item {
	return (item == nil)? [library objectAtIndex: index] : [item child: index];
}

- (id) outlineView: (NSOutlineView*) outlineView objectValueForTableColumn: (NSTableColumn*) col byItem: (id) item {
	return (item == nil)? @"FractalStream Script Library" : [item title];
}

- (IBAction) newScript: (id) sender {
	[theDoc doDocumentLoadWithLibrary: NO];
}

- (IBAction) openScript: (id) sender {
	id item;
	item = [outline itemAtRow: [outline selectedRow]];
	if(item == nil) { NSLog(@"item was nil?\n"); return; }
	if([item path] == nil) return;
	if([item isGroup]) return;
	if([theDoc loadDataRepresentation: [NSData dataWithContentsOfFile: [item path]] ofType: @"FractalStream Script"])
		[theDoc doDocumentLoadWithLibrary: NO];
}

- (IBAction) editScript: (id) sender {
	id item;
	item = [outline itemAtRow: [outline selectedRow]];
	if(item == nil) { NSLog(@"item was nil?\n"); return; }
	if([item path] == nil) return;
	if([item isGroup]) return;
	if([theDoc loadDataRepresentation: [NSData dataWithContentsOfFile: [item path]] ofType: @"FractalStream Script"])
		[theDoc openEditor];
}

- (IBAction) switchScriptView: (id) sender {
	useOutlineView = ([sender indexOfSelectedItem] == 0)? YES : NO;
	[self reload];
}


- (void) newSelection: (NSNotification*) note {
	id item;
	item = [outline itemAtRow: [outline selectedRow]];
	if (item == nil) {
		[openButton setEnabled: NO];
		[openEditorButton setEnabled: NO];
		[description setString: @""];
		[previewer setImage: [NSImage imageNamed: @"NSRemoveTemplate"]];
		return;
	}
	if ([item isGroup]) {
		[openButton setEnabled: NO];
		[openEditorButton setEnabled: NO];
	}
	else {
		[openButton setEnabled: YES];
		[openEditorButton setEnabled: YES];
	}
	if([item description]) { 
		[description selectAll: self];
		[description replaceCharactersInRange: [description selectedRange]
			withRTFD: (NSData*) [item description]];
	}
	else [description setString: @""];
	if([item image]) [previewer setImage: [item image]];
	else {
		if([item isGroup]) [previewer setImage: [NSImage imageNamed: @"NSMultipleDocuments"]];
		else [previewer setImage: [NSImage imageNamed: @"NSRemoveTemplate"]];
	}
}


@end
