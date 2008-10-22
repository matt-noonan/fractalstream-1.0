//
//  FSTools.m
//  FractalStream
//
//  Created by Matt Noonan on 3/17/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "FSTools.h"


@implementation FSTools

- (void) awakeFromNib
{
	toolClasses = [[NSMutableArray alloc] init];
	tools = [[NSMutableArray alloc] init];
	toolsLoaded = NO;
	traces = 0;

	wheel[0][0] = 1.0;
	wheel[0][1] = 1.0;
	wheel[0][2] = 1.0;

	wheel[1][0] = 1.0;
	wheel[1][1] = 0.0;
	wheel[1][2] = 0.0;

	wheel[2][0] = 0.0;
	wheel[2][1] = 1.0;
	wheel[2][2] = 0.0;

	wheel[3][0] = 0.0;
	wheel[3][1] = 0.0;
	wheel[3][2] = 1.0;

	wheel[4][0] = 1.0;
	wheel[4][1] = 1.0;
	wheel[4][2] = 0.0;

	wheel[5][0] = 0.0;
	wheel[5][1] = 1.0;
	wheel[5][2] = 1.0;

	wheel[6][0] = 1.0;
	wheel[6][1] = 0.0;
	wheel[6][2] = 1.0;

	wheel[7][0] = 1.0;
	wheel[7][1] = 0.5;
	wheel[7][2] = 0.0;

	wheel[8][0] = 0.0;
	wheel[8][1] = 0.0;
	wheel[8][2] = 0.0;

}

- (void) setSession: (FSSession*) newSession {
	theSession = newSession;
	[theSession retain];
}

- (IBAction) resetTrace: (id) sender {
	traces = 0;
	traceSteps = [stepsBox intValue];
	NSLog(@"traceSteps = %i, found in object %@ with value %@\n", traceSteps, stepsBox, [stepsBox objectValue]);
}

- (IBAction) registerTrace: (id) sender {
	if(traces < 8) ++traces;
}

- (IBAction) configure: (id) sender {
	switch([popupMenu indexOfSelectedItem]) {
			case 0:
			case 1:
				break;
			default:
				[[tools objectAtIndex: [popupMenu indexOfSelectedItem] - builtInTools] configure];
				break;
	}
}

- (void) rightMouseDown: (NSEvent*) theEvent {
	void (*kernel)(int, double*, int, double*, int, double);
	double x, y, in[9], out[6], p[2];					
	float c[3];
	int i; 
	NSImage* snapshot;

	lastClick = [theEvent locationInWindow];
	inDrag = NO;
	ignoreMouseUp = NO;
	
	NSLog(@"indexOfSelectedItem: %i\n", [popupMenu indexOfSelectedItem]);
	switch([popupMenu indexOfSelectedItem]) {

			case 0: /* zoom tool */
				[viewport convertLocation: [theEvent locationInWindow] toPoint: p];
				[theBrowser changeTo: [NSString stringWithFormat: @"Dynamical Plane for C = %f + %fi", x, y]
					X: 0.0 Y: 0.0
					p1: p[0] p2: p[1]
					pixelSize: 4.0 / 512.0 parametric: NO
				];
				[popupMenu selectItemWithTitle: @"Zoom"];
				[[viewport window] setTitle: 
					[NSString stringWithFormat: 
						@"Dynamical Plane for %1.4e + i %1.4e", p[0], p[1]
					]
				];
				ignoreMouseUp = YES;
				break;
			
			case 1:
				break;

			default:
				if([popupMenu indexOfSelectedItem] < builtInTools) break;
				[tool[[popupMenu indexOfSelectedItem] - builtInTools] rightMouseDown: theEvent];
				break;
	}
}

- (void) mouseDown: (NSEvent*) theEvent
{
	void (*kernel)(int, double*, int, double*, int, double, double);
	double x, y, in[9], out[6], p[2];					
	float c[3];
	int i; 
	FSViewerItem item;
	double probeResult[16];
	
	lastClick = [theEvent locationInWindow];
	inDrag = NO;
	ignoreMouseUp = NO;
	
	NSLog(@"indexOfSelectedItem: %i\n", [popupMenu indexOfSelectedItem]);
	switch([popupMenu indexOfSelectedItem]) {

			case 0: /* zoom tool */
				break;
			
			case 1: /* dynamical plane */
				NSLog(@"dyn click down\n");
				[viewport convertLocation: [theEvent locationInWindow] toPoint: p];
				[theBrowser changeTo: [NSString stringWithFormat: @"Dynamical Plane for C = %f + %fi", x, y]
					X: 0.0 Y: 0.0
					p1: p[0] p2: p[1]
					pixelSize: 4.0 / 512.0 parametric: NO
				];
				[popupMenu selectItemWithTitle: @"Zoom"];
				[[viewport window] setTitle: 
					[NSString stringWithFormat: 
						@"Dynamical Plane for %1.4e + i %1.4e", p[0], p[1]
					]
				];
				ignoreMouseUp = YES;
				break;
							
			default:
				if([popupMenu indexOfSelectedItem] < builtInTools) {
					[viewport convertLocation: [theEvent locationInWindow] toPoint: p];
					[viewport
						runAt: p
						into: probeResult
						probe: [popupMenu indexOfSelectedItem] - 1
					];
					if(probeResult[3] == 0.0)
						[probeTextField setStringValue: [NSString
							stringWithFormat: @"%1.4e + %1.4e i", probeResult[0], probeResult[1]]];
					else if(probeResult[3] == 1.0)
						[probeTextField setStringValue: [NSString
							stringWithFormat: @"%1.4e", probeResult[0]]];
					else if(probeResult[3] == 2.0)
						[probeTextField setStringValue: [NSString
							stringWithFormat: @"%i / %i", (int) probeResult[0], (int) probeResult[1]]];
					else if(probeResult[3] == 3.0)
						[probeTextField setStringValue: [NSString
							stringWithFormat: @"%i", (int) probeResult[0]]];
					else [probeTextField setStringValue: @"? ? ?"];
					break;
				}
				[tool[[popupMenu indexOfSelectedItem] - builtInTools] mouseDown: theEvent];
				break;
	}
}

- (void) mouseUp: (NSEvent*) theEvent
{
	double p[2]; NSPoint center;
	double size, x, y;
	FSViewerData theData;
	
	NSLog(@"mouseUp\n");
	if(ignoreMouseUp == YES) ignoreMouseUp = NO;
	else switch([popupMenu indexOfSelectedItem]) {

		case 0: /* zoom tool */
			if(inDrag) {
				NSLog(@"(in drag!)\n");
				center.x = (lastClick.x + [theEvent locationInWindow].x) / 2;
				center.y = (lastClick.y + [theEvent locationInWindow].y) / 2;
				x = fabs((float)(lastClick.x - [theEvent locationInWindow].x) / [viewport bounds].size.width);
				y = fabs((float)(lastClick.y - [theEvent locationInWindow].y) / [viewport bounds].size.height);
				size = sqrt(x*y);
				NSLog(@"about to memmove, theBrowser is %@\n", theBrowser);
				[theBrowser putCurrentDataIn: &theData];
				NSLog(@"size is %f\n", size);
				if(size < 0.001) break;
				[viewport convertLocation: center toPoint: p];
				NSLog(@"ready to change to a new zoom\n");
				NSLog(@"FSTools think that size is %f and pixelSize is currently %f\n", size, theData.pixelSize);
				NSLog(@"X: %f Y: %f\n", p[0], p[1]);
				[theBrowser changeTo: @"zoomed"
					X: p[0] Y: p[1]
					p1: theData.par[0] p2: theData.par[1]
					pixelSize: size * theData.pixelSize parametric: (theData.program == 1)? YES : NO
				];		
			}
			else if([theEvent modifierFlags] & NSCommandKeyMask) {
				[theBrowser putCurrentDataIn: &theData];
				[viewport convertLocation: [theEvent locationInWindow] toPoint: p];
				[theBrowser changeTo: @"zoomed out"
					X: p[0] Y: p[1]
					p1: theData.par[0] p2: theData.par[1]
					pixelSize: theData.pixelSize * 4.0 parametric: (theData.program == 1)? YES : NO
				];		

			}
			else {
				[theBrowser putCurrentDataIn: &theData];
				[viewport convertLocation: [theEvent locationInWindow] toPoint: p];
				[theBrowser changeTo: @"moved"
					X: p[0] Y: p[1]
					p1: theData.par[0] p2: theData.par[1]
					pixelSize: theData.pixelSize parametric: (theData.program == 1)? YES : NO
				];		
			}
			break;
		
		case 1:
			break;

		default:
			if([popupMenu indexOfSelectedItem] < builtInTools) break;
			[tool[[popupMenu indexOfSelectedItem] - builtInTools] mouseUp: theEvent];
			break;
	}
	
	inDrag = NO;
}


- (void) mouseEntered: (NSEvent*) theEvent
{
	[currentCursor push];
}

- (void) mouseMoved: (NSEvent*) theEvent
{
	double p[2];
	[viewport convertLocation: [theEvent locationInWindow] toPoint: p];	
	[coordinates setStringValue: [NSString stringWithFormat: @"%1.4e + %1.4ei", p[0], p[1]]];
}

- (void) mouseDragged: (NSEvent*) theEvent
{
	float c[3];
	if(ignoreMouseUp == NO) {
		switch([popupMenu indexOfSelectedItem]) {
			case 0:
				c[0] = 0.2; c[1] = 0.5; c[2] = 0.8;
			//	[viewport drawDotAt: [theEvent locationInWindow] withColor: c];
				
				[viewport drawBoxFrom: lastClick to: [theEvent locationInWindow] withColor: c];
				break;
			case 1:
				break;
			default:
				if([popupMenu indexOfSelectedItem] < builtInTools) break;
				[tool[[popupMenu indexOfSelectedItem] - builtInTools] mouseDragged: theEvent];
				break;
		}
		inDrag = YES;
	}
}


- (void) mouseExited: (NSEvent*) theEvent
{
	[coordinates setStringValue: @"-----"];
	[currentCursor pop];
}

- (IBAction) setupMenu: (id) sender
{
	NSString* appSupportSubpath = @"Application Support/FractalStream/PlugIns";
	NSArray* librarySearchPaths;
	NSEnumerator* searchPathEnum;
	NSEnumerator* pluginEnum;
	NSEnumerator* directoryEnum;
	NSEnumerator* toolEnum;
	NSString* currPath;
	NSString* pluginPath;
	NSMutableArray* bundleSearchPaths = [NSMutableArray array];
	NSBundle* toolBundle;
	Class pclass;
	id <FSTool> aTool;
	int i;
	
	if(toolsLoaded == NO) {
		toolsLoaded = YES;

		/***** broken for cocotron :( *****/
#ifdef __WIN32__
		librarySearchPaths = [NSArray arrayWithObject: @"/Library"];
#else
		librarySearchPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask - NSSystemDomainMask, YES);
#endif
//		librarySearchPaths = [NSArray arrayWithObject: @"/Library"]; 


		[bundleSearchPaths addObject: [[NSBundle mainBundle] builtInPlugInsPath]];
		searchPathEnum = [librarySearchPaths objectEnumerator];
		while(currPath = [searchPathEnum nextObject])
			[bundleSearchPaths addObject: [currPath stringByAppendingPathComponent:appSupportSubpath]];
//	NSLog(@"bundle search path array is %@\n", bundleSearchPaths);
		directoryEnum = [bundleSearchPaths objectEnumerator];
		while(currPath = [directoryEnum nextObject]) {
			pluginEnum = [[NSBundle pathsForResourcesOfType:@"fstool" inDirectory:currPath] objectEnumerator];
			while(pluginPath = [pluginEnum nextObject]) {
				toolBundle = [NSBundle bundleWithPath: pluginPath];
				pclass = [toolBundle principalClass];
				[toolClasses addObject: pclass];
				[pclass preload: toolBundle];
				aTool = [[pclass alloc] init];
				[aTool setOwnerTo: viewport];
				[aTool unfreeze];
				[tools addObject: aTool];
				NSLog(@"added tool %@ of class %@ found at %@\n", [aTool name], pclass, pluginPath);
			}
		}
		tool = (id*) malloc([tools count] * sizeof(id));
		toolEnum = [tools objectEnumerator];
		i = 0; while(aTool = [toolEnum nextObject]) tool[i++] = aTool;
	}
	
	probeTools = [[theBrowser namedProbes] count];
	[popupMenu removeAllItems];
	[popupMenu addItemWithTitle: @"Zoom"];
	[popupMenu addItemWithTitle: @"Dynamics"];
	builtInTools = 2 + probeTools;
	if(probeTools > 0) {
		NSEnumerator* probeEnumerator;
		NSString* probeName;
		probeEnumerator = [[theBrowser namedProbes] objectEnumerator];
		while(probeName = [probeEnumerator nextObject]) [popupMenu addItemWithTitle: probeName];
	}
	toolEnum = [tools objectEnumerator];
	while(aTool = [toolEnum nextObject]) [popupMenu addItemWithTitle: [aTool menuName]];
	
	currentTool = 0;
	[popupMenu selectItemWithTitle: @"Zoom"];

	[[popupMenu itemWithTitle: @"Dynamics"] setKeyEquivalent: @"d"];
	[[popupMenu itemWithTitle: @"Zoom"] setKeyEquivalent: @"z"];
	toolEnum = [tools objectEnumerator];
	while(aTool = [toolEnum nextObject]) [[popupMenu itemWithTitle: [aTool menuName]] setKeyEquivalent: [aTool keyEquivalent]];
	
	currentCursor = [NSCursor crosshairCursor];
}

- (void) addTools: (NSFileWrapper*) toolWrapper {
	NSEnumerator* en;
	NSString* bundleName, *bundleDir, *filename;
	NSBundle* toolBundle;
	id <FSTool> aTool;
	Class pclass;

	bundleDir = [[NSString stringWithFormat: @"%@fstool%i/", NSTemporaryDirectory(), rand()] autorelease];
	[toolWrapper writeToFile: bundleDir atomically: YES updateFilenames: NO];
	en = [[NSBundle pathsForResourcesOfType: @"fstool" inDirectory: bundleDir] objectEnumerator];
	while(bundleName = [en nextObject]) {
		/* Write the tool bundle to a temp location, load the bundle, add menu items */
		toolBundle = [NSBundle bundleWithPath: bundleName];
		pclass = [toolBundle principalClass];
		NSLog(@"Found an extra tool with class %@\n", pclass);
		[toolClasses addObject: pclass];
		[pclass preload: toolBundle];
		aTool = [[pclass alloc] init];
		[aTool setOwnerTo: viewport];
		[aTool unfreeze];
		[tools addObject: aTool];
		[popupMenu addItemWithTitle: [aTool menuName]];
		[[popupMenu itemWithTitle: [aTool menuName]] setKeyEquivalent: [aTool keyEquivalent]];
	}
	
}

- (void) updateMenuForParametric: (BOOL) isPar {
	NSEnumerator* toolEnum;
	id <FSTool> aTool;
	
	return;
	toolEnum = [tools objectEnumerator];
	if(isPar == YES) {
		[[popupMenu itemWithTitle: @"Zoom"] setEnabled: YES];
		[[popupMenu itemWithTitle: @"Dynamics"] setEnabled: YES];
		while(aTool = [toolEnum nextObject]) 
			[[popupMenu itemWithTitle: [aTool menuName]] setEnabled: ([aTool is: FSTool_Parametric] == YES)? NO : YES];
	}
	if(isPar == NO) {
		[[popupMenu itemWithTitle: @"Zoom"] setEnabled: YES];
		[[popupMenu itemWithTitle: @"Dynamics"] setEnabled: NO];
		while(aTool = [toolEnum nextObject]) 
			[[popupMenu itemWithTitle: [aTool menuName]] setEnabled: ([aTool is: FSTool_Dynamical] == YES)? NO : YES];
	}
}

- (IBAction) changeTool: (id) sender {
	int selected;
	selected = [popupMenu indexOfSelectedItem];
	if(selected != currentTool) {
		if(currentTool >= builtInTools) [tool[currentTool - builtInTools] deactivate];
		else if(currentTool > 1) {
			[probeTextField setStringValue: @"-"];
			[[probeTextField window] orderOut: self];
		}
		if(selected >= builtInTools) [tool[selected - builtInTools] activate];
		else if(selected > 1) {
			[probeTextField setStringValue: @"-"];
			[[probeTextField window] setTitle: [NSString stringWithFormat: @"Probe: %@", [popupMenu titleOfSelectedItem]]];
			[[probeTextField window] orderFront: self];
		}
		currentTool = selected;
	}
}

@end
