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

- (void) encodeWithCoder: (NSCoder*) coder
{
	/* version 0 */
	[coder encodeValueOfObjCType: @encode(double) at: &(upperLeft[0])];
	[coder encodeValueOfObjCType: @encode(double) at: &(upperLeft[1])];
	[coder encodeValueOfObjCType: @encode(double) at: &(lowerRight[0])];
	[coder encodeValueOfObjCType: @encode(double) at: &(lowerRight[1])];
	[coder encodeValueOfObjCType: @encode(double) at: &scale];
	[coder encodeValueOfObjCType: @encode(double) at: &(center[0])];
	[coder encodeValueOfObjCType: @encode(double) at: &(center[1])];
	[coder encodeValueOfObjCType: @encode(int) at: &program];
	[coder encodeArrayOfObjCType: @encode(char) count: sizeof(FSViewerData) at: &data];
	[coder encodeObject: title];
	[coder encodeObject: notes];
	[coder encodeValueOfObjCType: @encode(int) at: &children];
	[coder encodeObject: nextSibling];
	[coder encodeObject: previousSibling];
	[coder encodeObject: parent];
	[coder encodeObject: firstChild];
	[coder encodeObject: favoredChild];
	[coder encodeValueOfObjCType: @encode(int) at: &nodeNumber];
}

- (id) initWithCoder: (NSCoder*) coder {
	self = [super init];
	/* version 0 */
	[coder decodeValueOfObjCType: @encode(double) at: &(upperLeft[0])];
	[coder decodeValueOfObjCType: @encode(double) at: &(upperLeft[1])];
	[coder decodeValueOfObjCType: @encode(double) at: &(lowerRight[0])];
	[coder decodeValueOfObjCType: @encode(double) at: &(lowerRight[1])];
	[coder decodeValueOfObjCType: @encode(double) at: &scale];
	[coder decodeValueOfObjCType: @encode(double) at: &(center[0])];
	[coder decodeValueOfObjCType: @encode(double) at: &(center[1])];
	[coder decodeValueOfObjCType: @encode(int) at: &program];
	[coder decodeArrayOfObjCType: @encode(char) count: sizeof(FSViewerData) at: &data];
	title = [[coder decodeObject] retain];
	notes = [[coder decodeObject] retain];
	[coder decodeValueOfObjCType: @encode(int) at: &children];
	nextSibling = [[coder decodeObject] retain];
	previousSibling = [[coder decodeObject] retain];
	parent = [[coder decodeObject] retain];
	firstChild = [[coder decodeObject] retain];
	favoredChild = [[coder decodeObject] retain];
	[coder decodeValueOfObjCType: @encode(int) at: &nodeNumber];
	
	NSLog(@"decoded FSSessionNode to %@\n", self);
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
	NSLog(@"reading kernel from %@\n", path);
	sessionKernel = [[NSFileWrapper alloc] init];
	sessionKernel = [sessionKernel initWithPath: path];
	if([sessionKernel isRegularFile] == NO) sessionKernel = nil;
	NSLog(@"kernel has been read.\n");
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
	if(currentNode != root) currentNode = currentNode -> parent;
}

- (IBAction) makeSelectedNodeCurrent: (id) sender {
	NSLog(@"*********** this routine does nothing yet!!!\n");
}

- (IBAction) goToRoot: (id) sender { currentNode = root; }

- (IBAction) cloneCurrentNode: (id) sender { 
	FSSessionNode* node;
	NSLog(@"cloneCurrentNode\n");
	
	node = currentNode; currentNode = currentNode -> parent;
	[self addChildNode: currentNode andMakeCurrent: YES]; // not right, make a copy of currentNode
	[historyView reloadItem: currentNode -> parent reloadChildren: YES];
}

// delete a node and link any children in as siblings of the deleted node.
- (IBAction) deleteCurrentNode: (id) sender {
	FSSessionNode* node;

	NSLog(@"deleteCurrentNode\n");

	currentNode -> parent -> children--;
	if(currentNode -> children > 0) {
		if(currentNode -> previousSibling != nil) 
			currentNode -> firstChild -> previousSibling = currentNode -> previousSibling;
		node = currentNode -> firstChild;
		while(node -> nextSibling != nil) node = node -> nextSibling;
		node -> nextSibling = currentNode -> nextSibling;
		currentNode -> parent -> children += currentNode -> children;
	
		node = currentNode; currentNode = currentNode -> firstChild;
	}
	else { node = currentNode; currentNode = currentNode -> parent; }
	// destroy 'node' here
	[historyView reloadItem: currentNode reloadChildren: YES];
}

- (IBAction) deleteCurrentChildren: (id) sender {
	NSLog(@"deleteCurrentChildren\n");

	currentNode -> children = 0;
	// code to recursively destroy children here
	currentNode -> firstChild = nil;
	[historyView reloadItem: currentNode reloadChildren: YES];
}

- (IBAction) goForward: (id) sender
{
	if(currentNode -> favoredChild != nil) currentNode = currentNode -> favoredChild;
	NSLog(@"going forward\n");
}

- (IBAction) goBackward: (id) sender
{
	if(currentNode -> parent != nil) currentNode = currentNode -> parent;
	NSLog(@"going backward\n");
}

- (FSSessionNode*) addChildNode: (FSSessionNode*) child andMakeCurrent: (BOOL) makeCurrent
{
	FSSessionNode* sibling;

	NSLog(@"adding a new child, this child thinks that pixelSize is %f\n", (child -> data).pixelSize);

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
	if(makeCurrent == YES) currentNode = child;
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
	root = session -> root;
	currentNode = session -> currentNode;
	sessionTitle = session -> sessionTitle;
	sessionProgram = session -> sessionProgram;
	sessionNotes = session -> sessionNotes;
	sessionKernel = session -> sessionKernel;
	kernelIsCached = session -> kernelIsCached;
	historyView = nil;
}

- (void) setFlags: (NSArray*) flagArray { flagNames = [NSArray arrayWithArray: flagArray]; }
- (NSArray*) flagNames { return flagNames; }

+ (void) initialize { [FSSession setVersion: 0]; }

- (void) encodeWithCoder: (NSCoder*) coder
{
	// version 0
	[coder encodeObject: root];
	[coder encodeObject: currentNode];
	[coder encodeObject: sessionTitle];
	[coder encodeObject: sessionProgram];
	[coder encodeObject: sessionNotes];
	[coder encodeObject: sessionKernel];
	[coder encodeValueOfObjCType: @encode(BOOL) at: &kernelIsCached];
}

- (id) initWithCoder: (NSCoder*) coder
{
	self = [super init];
	// version 0
	root = [[coder decodeObject] retain];
	currentNode = [[coder decodeObject] retain];
	sessionTitle = [[coder decodeObject] retain];
	sessionProgram = [[coder decodeObject] retain];
	sessionNotes = [[coder decodeObject] retain];
	sessionKernel = [[coder decodeObject] retain];
	[coder decodeValueOfObjCType: @encode(BOOL) at: &kernelIsCached];
	NSLog(@"loaded session instance %@ has sessionKernel %@\n", self, sessionKernel);
	return self;
}






@end


