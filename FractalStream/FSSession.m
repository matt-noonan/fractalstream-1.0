//
//  FSSession.m
//  FStream
//
//  Created by Matt Noonan on 8/1/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "FSSession.h"

@implementation FSSessionNode

+ (void) initialize { [FSSessionNode setVersion: 0]; }

- (id) init
{
	self = [super init];
	
	self -> upperLeft[0] = -2.0; self -> upperLeft[1] = 2.0;
	self -> lowerRight[0] = 2.0; self -> lowerRight[1] = -2.0;
	self -> scale = 2.0;
	self -> center[0] = 0.0; self -> center[1] = 0.0;
	self -> program = 1;
	self -> nodeNumber = 0;//GlobalNodeCount++;
	self -> title = [[NSString stringWithString: @"(no title)"] retain];
	self -> notes = [[NSString stringWithString: @"(no notes)"] retain];
	self -> firstChild = nil;
	self -> previousSibling = nil;
	self -> nextSibling = nil;
	self -> favoredChild = nil;
	self -> parent = nil;
	self -> children = 0;
	extra = nil;
	return self;
}

- (double) scale { return self -> scale; }
- (double) centerX { return self -> center[0]; }
- (double) centerY { return self -> center[1]; }

- (id) setViewportX: (double) x Y: (double) y scale: (double) c
{
	self -> scale = c;
	self -> center[0] = x; self -> center[0] = y;
	return self;
}

- (id) setTitle: (NSString*) newTitle
{
	[self -> title release];
	self -> title = newTitle;
	[self -> title retain];
	return self;
}

- (FSViewerData) data { return data; }
- (FSViewerData*) dataPtr { return &data; }
- (NSMutableDictionary*) extra { return extra; }

- (void) encodeWithCoder: (NSCoder*) coder
{
	/* version 0 */
	[coder encodeObject: [NSNumber numberWithBool: YES] forKey: @"keyed"];
	[coder encodeObject: [NSNumber numberWithDouble: upperLeft[0]] forKey: @"ul0"];
	[coder encodeObject: [NSNumber numberWithDouble: upperLeft[1]] forKey: @"ul1"];
	[coder encodeObject: [NSNumber numberWithDouble: lowerRight[0]] forKey: @"lr0"];
	[coder encodeObject: [NSNumber numberWithDouble: lowerRight[1]] forKey: @"lr1"];
	[coder encodeObject: [NSNumber numberWithDouble: scale] forKey: @"scale"];
	[coder encodeObject: [NSNumber numberWithDouble: center[0]] forKey: @"center0"];
	[coder encodeObject: [NSNumber numberWithDouble: center[1]] forKey: @"center1"];
	[coder encodeObject: [NSNumber numberWithInt: program] forKey: @"program"];

	[coder encodeObject: [NSNumber numberWithDouble: data.center[0]] forKey: @"data.center[0]"];
	[coder encodeObject: [NSNumber numberWithDouble: data.center[1]] forKey: @"data.center[1]"];
	[coder encodeObject: [NSNumber numberWithDouble: data.pixelSize] forKey: @"data.pixelSize"];
	[coder encodeObject: [NSNumber numberWithDouble: data.aspectRatio] forKey: @"data.aspectRatio"];
	[coder encodeObject: [NSNumber numberWithDouble: data.detailLevel] forKey: @"data.detailLevel"];
	[coder encodeObject: [NSNumber numberWithDouble: data.par[0]] forKey: @"data.par[0]"];
	[coder encodeObject: [NSNumber numberWithDouble: data.par[1]] forKey: @"data.par[1]"];
	[coder encodeObject: [NSNumber numberWithDouble: data.data[0]] forKey: @"data.data[0]"];
	[coder encodeObject: [NSNumber numberWithDouble: data.data[1]] forKey: @"data.data[1]"];
	[coder encodeObject: [NSNumber numberWithDouble: data.data[2]] forKey: @"data.data[2]"];
	[coder encodeObject: [NSNumber numberWithInt: data.maxIters] forKey: @"data.maxIters"];
	[coder encodeObject: [NSNumber numberWithDouble: data.maxRadius] forKey: @"data.maxRadius"];
	[coder encodeObject: [NSNumber numberWithDouble: data.minRadius] forKey: @"data.minRadius"];
	[coder encodeObject: [NSNumber numberWithInt: data.program] forKey: @"data.program"];

	[coder encodeObject: title forKey: @"title"];
	[coder encodeObject: notes forKey: @"notes"];
	[coder encodeObject: [NSNumber numberWithInt: children] forKey: @"children"];
	[coder encodeObject: nextSibling forKey: @"nextSibling"];
	[coder encodeObject: previousSibling forKey: @"previousSibling"];
	[coder encodeObject: parent forKey: @"parent"];
	[coder encodeObject: firstChild forKey: @"firstChild"];
	[coder encodeObject: favoredChild forKey: @"favoredChild"];
	if(extra != nil) [coder encodeObject: [NSNumber numberWithInt: nodeNumber] forKey: @"nodeNumber"];
	else {
		[coder encodeObject: [NSNumber numberWithInt: -1] forKey: @"nodeNumber"];
		[coder encodeObject: extra forKey: @"extra"];
	}
}

- (id) initWithCoder: (NSCoder*) coder {
	self = [super init];
	/* version 0 */
	if([coder containsValueForKey: @"keyed"]) {
		upperLeft[0] = [[coder decodeObjectForKey: @"ul0"] doubleValue];
		upperLeft[1] = [[coder decodeObjectForKey: @"ul1"] doubleValue];
		lowerRight[0] = [[coder decodeObjectForKey: @"lr0"] doubleValue];
		lowerRight[1] = [[coder decodeObjectForKey: @"lr1"] doubleValue];
		scale = [[coder decodeObjectForKey: @"scale"] doubleValue];
		center[0] = [[coder decodeObjectForKey: @"center0"] doubleValue];
		center[1] = [[coder decodeObjectForKey: @"center1"] doubleValue];
		program = [[coder decodeObjectForKey: @"program"] intValue];
		data.center[0] = [[coder decodeObjectForKey: @"data.center[0]"] doubleValue];
		data.center[1] = [[coder decodeObjectForKey: @"data.center[1]"] doubleValue];
		data.pixelSize = [[coder decodeObjectForKey: @"data.pixelSize"] doubleValue];
		data.aspectRatio = [[coder decodeObjectForKey: @"data.aspectRatio"] doubleValue];
		data.detailLevel = [[coder decodeObjectForKey: @"data.detailLevel"] doubleValue];
		data.par[0] = [[coder decodeObjectForKey: @"data.par[0]"] doubleValue];
		data.par[1] = [[coder decodeObjectForKey: @"data.par[1]"] doubleValue];
		data.data[0] = [[coder decodeObjectForKey: @"data.data[0]"] doubleValue];
		data.data[1] = [[coder decodeObjectForKey: @"data.data[1]"] doubleValue];
		data.data[2] = [[coder decodeObjectForKey: @"data.data[2]"] doubleValue];
		data.maxIters = [[coder decodeObjectForKey: @"data.maxIters"] intValue];
		data.maxRadius = [[coder decodeObjectForKey: @"data.maxRadius"] doubleValue];
		data.minRadius = [[coder decodeObjectForKey: @"data.minRadius"] doubleValue];
		data.program = [[coder decodeObjectForKey: @"data.program"] intValue];
		
		title = [[coder decodeObjectForKey: @"title"] retain];
		notes = [[coder decodeObjectForKey: @"notes"] retain];
		children = [[coder decodeObjectForKey: @"children"] intValue];
		nextSibling = [[coder decodeObjectForKey: @"nextSibling"] retain];
		previousSibling = [[coder decodeObjectForKey: @"previousSibling"] retain];
		parent = [[coder decodeObjectForKey: @"parent"] retain];
		firstChild = [[coder decodeObjectForKey: @"firstChild"] retain];
		favoredChild = [[coder decodeObjectForKey: @"favoredChild"] retain];
		nodeNumber = [[coder decodeObjectForKey: @"nodeNumber"] intValue];
		if(nodeNumber == -1) extra = [[coder decodeObjectForKey: @"extra"] retain];
		else extra = nil;
	}
	else {
		upperLeft[0] = [[coder decodeObject] doubleValue];
		upperLeft[1] = [[coder decodeObject] doubleValue];
		lowerRight[0] = [[coder decodeObject] doubleValue];
		lowerRight[1] = [[coder decodeObject] doubleValue];
		scale = [[coder decodeObject] doubleValue];
		center[0] = [[coder decodeObject] doubleValue];
		center[1] = [[coder decodeObject] doubleValue];
		program = [[coder decodeObject] intValue];
		data.center[0] = [[coder decodeObject] doubleValue];
		data.center[1] = [[coder decodeObject] doubleValue];
		data.pixelSize = [[coder decodeObject] doubleValue];
		data.aspectRatio = [[coder decodeObject] doubleValue];
		data.detailLevel = [[coder decodeObject] doubleValue];
		data.par[0] = [[coder decodeObject] doubleValue];
		data.par[1] = [[coder decodeObject] doubleValue];
		data.data[0] = [[coder decodeObject] doubleValue];
		data.data[1] = [[coder decodeObject] doubleValue];
		data.data[2] = [[coder decodeObject] doubleValue];
		data.maxIters = [[coder decodeObject] intValue];
		data.maxRadius = [[coder decodeObject] doubleValue];
		data.minRadius = [[coder decodeObject] doubleValue];
		data.program = [[coder decodeObject] intValue];
		
		title = [[coder decodeObject] retain];
		notes = [[coder decodeObject] retain];
		children = [[coder decodeObject] intValue]; //children = 0;
		nextSibling = [[coder decodeObject] retain]; //nextSibling = nil;
		previousSibling = [[coder decodeObject] retain]; //previousSibling = nil;
		parent = [[coder decodeObject] retain]; //parent = nil;
		firstChild = [[coder decodeObject] retain]; //firstChild = nil;
		favoredChild = [[coder decodeObject] retain]; //favoredChild = nil;
		nodeNumber = [[coder decodeObject] intValue];
		if(nodeNumber == -1) extra = [[coder decodeObject] retain];
		else extra = nil;
	}
	return self;
}

@end



@implementation FSSession 

- (id) init 
{
	self = [super init];
	root = [[FSSessionNode alloc] init];
	currentNode = root;
	sessionTitle = [[NSString stringWithString: @"FractalStream Beta Session"] retain];
	return self;
}

- (void) awakeFromNib
{ 
	[[historyView window] setTitle: sessionTitle];
}

- (void) setTitle: (NSString*) title { sessionTitle = title; }
- (void) setNotes: (NSData*) notes { sessionNotes = notes; }
- (void) setProgram: (NSString*) program { sessionProgram = program; }
- (void) readKernelFrom: (NSString*) path {
//	NSLog(@"reading kernel from %@\n", path);
	sessionKernel = [[NSFileWrapper alloc] init];
	sessionKernel = [sessionKernel initWithPath: path];
	if([sessionKernel isRegularFile] == NO) sessionKernel = nil;
//	NSLog(@"kernel has been read.\n");
}
- (void) setKernelIsCached: (BOOL) isCached { kernelIsCached = isCached; }
- (NSString*) title { return sessionTitle; }
- (NSString*) program { return sessionProgram; }
- (NSData*) notes { return sessionNotes; }
- (NSFileWrapper*) kernelWrapper { return sessionKernel; }
- (FSSessionNode*) root { return root; }



- (FSSessionNode*) getRootNode { return root; }

- (FSSessionNode*) getCurrentNode { return currentNode; }
- (FSSessionNode*) currentNode { return currentNode; }

- (IBAction) selectCurrentParent: (id) sender 
{ 
	if(currentNode != root) [self changeTo: currentNode -> parent];
}

- (IBAction) makeSelectedNodeCurrent: (id) sender {
	NSLog(@"*********** this routine does nothing yet!!!\n");
}

- (IBAction) goToRoot: (id) sender { [self changeTo: root]; }

- (IBAction) cloneCurrentNode: (id) sender { 
	FSSessionNode* node;
//	NSLog(@"cloneCurrentNode\n");
	
	node = currentNode; currentNode = currentNode -> parent;
	[self addChildNode: currentNode andMakeCurrent: YES]; // not right, make a copy of currentNode
	[historyView reloadItem: currentNode -> parent reloadChildren: YES];
}

// delete a node and link any children in as siblings of the deleted node.
- (IBAction) deleteCurrentNode: (id) sender {
	FSSessionNode* node;

//	NSLog(@"deleteCurrentNode\n");

	currentNode -> parent -> children--;
	if(currentNode -> children > 0) {
		if(currentNode -> previousSibling != nil) 
			currentNode -> firstChild -> previousSibling = currentNode -> previousSibling;
		node = currentNode -> firstChild;
		while(node -> nextSibling != nil) node = node -> nextSibling;
		node -> nextSibling = currentNode -> nextSibling;
		currentNode -> parent -> children += currentNode -> children;
	
		node = currentNode; [self changeTo: currentNode -> firstChild];
	}
	else { node = currentNode; [self changeTo: currentNode -> parent]; }
	// destroy 'node' here
	[historyView reloadItem: currentNode reloadChildren: YES];
}

- (IBAction) deleteCurrentChildren: (id) sender {
//	NSLog(@"deleteCurrentChildren\n");

	currentNode -> children = 0;
	// code to recursively destroy children here
	currentNode -> firstChild = nil;
	[historyView reloadItem: currentNode reloadChildren: YES];
}

- (IBAction) goForward: (id) sender
{
	if(currentNode -> favoredChild != nil) {
		[self changeTo: currentNode -> favoredChild];
	}
//	NSLog(@"going forward\n");
}

- (IBAction) goBackward: (id) sender
{
	if(currentNode->parent && (currentNode != root) && (currentNode->parent != root)) [self changeTo: currentNode -> parent];
//	NSLog(@"going backward\n");
}

- (FSSessionNode*) addChildNode: (FSSessionNode*) child andMakeCurrent: (BOOL) makeCurrent
{
	FSSessionNode* sibling;

//	NSLog(@"adding a new child, this child thinks that pixelSize is %f\n", (child -> data).pixelSize);
	if(currentNode -> children == 0) {
		[child retain];
		currentNode -> children = 1;
		currentNode -> firstChild = child;
		child -> parent = currentNode;
		child -> previousSibling = nil;
		child -> nextSibling = nil;
		child -> children = 0;
		(child -> parent) -> favoredChild = child;
		if(makeCurrent == YES) currentNode = child;
		return child;
	}
	
	[child retain];
	currentNode -> children++;
	sibling = currentNode -> firstChild;
	while(sibling -> nextSibling != nil) sibling = sibling -> nextSibling;
	sibling -> nextSibling = child;
	child -> previousSibling = sibling;
	child -> nextSibling = nil;
	child -> parent = currentNode;
	child -> children = 0;
	(child -> parent) -> favoredChild = child;
	if(makeCurrent == YES) [self changeTo: child];
	return child;
}

- (FSSessionNode*) addChildWithData: (FSViewerData) theData andMakeCurrent: (BOOL) makeCurrent {
	FSSessionNode* child;
	child = [[FSSessionNode alloc] init];
	child -> data = theData;
	if(theData.program == 0) 
		child -> title = [[NSString stringWithFormat: @"Parametric (%i)", child -> nodeNumber] retain];
	else if(theData.program == 1)
		child -> title = [[NSString stringWithFormat: @"Dynamic (%i)", child -> nodeNumber] retain];
	child -> notes = @"";
	[self addChildNode: child andMakeCurrent: makeCurrent];
	[historyView reloadItem: currentNode -> parent reloadChildren: YES];
	[historyView expandItem: currentNode -> parent];
	return child;
}

- (FSSessionNode*) addChildNodeWithLocation: (double*) box andProgram: (int) program
{
	FSSessionNode* child;
	child = [[FSSessionNode alloc] init];
	child -> upperLeft[0] = box[0]; child -> upperLeft[1] = box[1];
	child -> lowerRight[0] = box[2]; child -> lowerRight[1] = box[3];
	child -> program = program;
	if(program == 1) 
		child -> title = [[NSString stringWithFormat: @"Mandelbrot (%i)", child -> nodeNumber] retain];
	else if(program == 3)
		child -> title = [[NSString stringWithFormat: @"Julia (%i)", child -> nodeNumber] retain];
	child -> notes = @"";
	[self addChildNode: child andMakeCurrent: YES];
	[historyView reloadItem: currentNode -> parent reloadChildren: YES];
	[historyView expandItem: currentNode -> parent];
	return child;
}

- (FSSessionNode*) addChildNodeWithScale: (double) scale X: (double) x Y: (double) y flags: (int) flag
{
	FSSessionNode* child;
	child = [[FSSessionNode alloc] init];
	child -> center[0] = x; child -> center[1] = y;
	child -> scale = scale;
	child -> program = flag;
	if(flag == 1) child -> title = [[NSString stringWithString: @"Parameter Plane"] retain];
	else child -> title = [[NSString stringWithString: @"Dynamical Plane"] retain];
	child -> notes = [[NSString stringWithString: @""] retain];
	[self addChildNode: child andMakeCurrent: YES];
	[historyView reloadItem: currentNode -> parent reloadChildren: YES];
	[historyView expandItem: currentNode -> parent];
	return child;
}

- (BOOL) outlineView: (NSOutlineView*) outlineView isItemExpandable: (FSSessionNode*) item
{
	return (item -> children == 0)? NO : YES;
}

- (int) outlineView: (NSOutlineView*) outlineView numberOfChildrenOfItem: (FSSessionNode*) item
{
	if(item == nil) return 1; // number of root nodes
	return item -> children;
}

- (id) outlineView: (NSOutlineView*) outlineView child: (int) index ofItem: (FSSessionNode*) item
{
	int i;
	FSSessionNode* child;
	
	if(item == nil) return root; // modify this when more root nodes are possible
	
	if(index >= item -> children) return nil;
	child = item -> firstChild;
	if(index > 0) for(i = 0; i < index; i++) child = child -> nextSibling;
	return child;
}

- (id) outlineView: (NSOutlineView*) outlineView objectValueForTableColumn: (NSTableColumn*) tableColumn
	byItem: (FSSessionNode*) item
{
	switch([[tableColumn identifier] intValue]) {
		case 0:
			return item -> title;
		case 1:
			return [NSString stringWithFormat: @"%1.1e + i %1.1e", item -> center[0], item -> center[1]];
		case 2:
			return [NSString stringWithFormat: @"%1.1e", item -> scale];
		default:
			return nil;
	}
}

- (void) getSessionFrom: (FSSession*) session
{
	//root = session -> root;
	root = currentNode = session -> currentNode;
	currentNode->children = 0; currentNode->firstChild = nil;
	sessionTitle = session -> sessionTitle;
	sessionProgram = session -> sessionProgram;
	sessionNotes = session -> sessionNotes;
	sessionKernel = session -> sessionKernel;
	kernelIsCached = session -> kernelIsCached;
	historyView = nil;
}

- (void) setFlags: (NSArray*) flagArray { 
	flagNames = [NSArray arrayWithArray: flagArray];
} 
- (NSArray*) flagNames { return flagNames; }

- (BOOL) kernelIsCached { return kernelIsCached; }

+ (void) initialize { [FSSession setVersion: 0]; }

- (void) encodeWithCoder: (NSCoder*) coder
{
	// version 0
	[coder encodeObject: [NSNumber numberWithBool: YES] forKey: @"keyed"];
	[coder encodeObject: root forKey: @"root"];
	[coder encodeObject: currentNode forKey: @"current node"];
	[coder encodeObject: sessionTitle forKey: @"session title"];
	[coder encodeObject: sessionProgram forKey: @"session program"];
	[coder encodeObject: sessionNotes forKey: @"session notes"];
	if(kernelIsCached) [coder encodeObject: sessionKernel forKey: @"cached kernel"];
	[coder encodeObject: [NSNumber numberWithBool: kernelIsCached] forKey: @"kernel is cached?"];
}

- (id) initWithCoder: (NSCoder*) coder
{
	self = [super init];
	// version 0
	if([coder containsValueForKey: @"keyed"]) {
		root = [[coder decodeObjectForKey: @"root"] retain];
		currentNode = [[coder decodeObjectForKey: @"current node"] retain];
		sessionTitle = [[coder decodeObjectForKey: @"session title"] retain];
		sessionProgram = [[coder decodeObjectForKey: @"session program"] retain];
		sessionNotes = [[coder decodeObjectForKey: @"session notes"] retain];
		if([coder containsValueForKey: @"cached kernel"]) sessionKernel = [[coder decodeObjectForKey: @"cached kernel"] retain];
		else sessionKernel = nil;
		kernelIsCached = [[coder decodeObjectForKey: @"kernel is cached"] boolValue];
	}
	else {
		root = [[coder decodeObject] retain];
		currentNode = [[coder decodeObject] retain];
		sessionTitle = [[coder decodeObject] retain];
		sessionProgram = [[coder decodeObject] retain];
		sessionNotes = [[coder decodeObject] retain];
		sessionKernel = [[coder decodeObject] retain];
		kernelIsCached = [[coder decodeObject] boolValue];
	}
	return self;
}


- (void) changeTo: (FSSessionNode*) node {
	[[NSNotificationCenter defaultCenter]
		postNotificationName: @"FSSessionWillChangeNode"
		object: self
		userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
			owner,							@"document",
			currentNode,					@"node",
			nil
		]
	];
	currentNode = node;
	[[NSNotificationCenter defaultCenter]
		postNotificationName: @"FSSessionDidChangeNode"
		object: self
		userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
			owner,							@"document",
			currentNode,					@"node",
			nil
		]
	];
}



@end


