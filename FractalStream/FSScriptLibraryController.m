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
	return [self makeLibraryItemForPath: [NSString stringWithFormat: @"%@%@", p, f]];
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
		array = [
			[NSKeyedUnarchiver unarchiveObjectWithData: [NSData dataWithContentsOfFile: p]]
		minidata];
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
					preview = [item copy];
					break; 
				default:
					break;
			}
			++i;
		}
	} 
	return self;
}

- loadChildren {
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
			[children addObject: [[FSScriptLibraryItem alloc]
				initWithPath: path file: item]];
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

@end

@implementation FSScriptLibraryController

- awakeFromNib {
	[[NSNotificationCenter defaultCenter]
		addObserver: self selector: @selector(newSelection:)
		name: NSOutlineViewSelectionDidChangeNotification object: outline
	];
	[self reload];
}

- (void) reload {
	NSFileManager* fs;
	NSArray* ar;
	id item;
	NSEnumerator* en;
	BOOL isDirectory;
	library = [[NSMutableArray alloc] init];
	fs = [NSFileManager defaultManager];
	ar = [fs directoryContentsAtPath: @"/Users/noonan/Desktop/Scripts/"];
	en = [ar objectEnumerator];
	while(item = [en nextObject]) {
		[fs fileExistsAtPath:
			[NSString stringWithFormat: @"/Users/noonan/Desktop/Scripts/%@", item]
			isDirectory: &isDirectory
		];	
		if([item hasSuffix: @".fs"] || isDirectory) 
			[library addObject: [[FSScriptLibraryItem alloc] initWithPath: @"/Users/noonan/Desktop/Scripts/" file: item]];
	}
}

- (int) outlineView: (NSOutlineView*) outlineView numberOfChildrenOfItem: (id) item {
	return (item == nil)? [library count] : (int) [item children]; 
}

- (BOOL) outlineView: (NSOutlineView*) outlineView isItemExpandable: (id) item {
	return (item == nil)? YES : [item isGroup];
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
	NSData* data;
	id item;
	item = [outline itemAtRow: [outline selectedRow]];
	if(item == nil) { NSLog(@"item was nil?\n"); return; }
	if([item path] == nil) return;
	if([item isGroup]) return;
	if([theDoc loadDataRepresentation: [NSData dataWithContentsOfFile: [item path]] ofType: @"DocumentType"])
		[theDoc doDocumentLoadWithLibrary: NO];
}

- (IBAction) editScript: (id) sender {
}

- (void) newSelection: (NSNotification*) note {
	id item;
	item = [outline itemAtRow: [outline selectedRow]];
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
