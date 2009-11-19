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
	NSLog(@"tools %@ awoke from nib\n", self);

}

- (void) setSession: (FSSession*) newSession {
	theSession = newSession;
	[theSession retain];
}

- (IBAction) resetTrace: (id) sender {
	traces = 0;
	traceSteps = [stepsBox intValue];
//	NSLog(@"traceSteps = %i, found in object %@ with value %@\n", traceSteps, stepsBox, [stepsBox objectValue]);
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
	
	switch([popupMenu indexOfSelectedItem]) {

			case 0: /* zoom tool */
				break;
			
			case 1: /* dynamical plane */
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
					if(probeResult[2] == 0.0)
						[probeTextField setStringValue: [NSString
							stringWithFormat: @"%1.4e + %1.4e i", probeResult[0], probeResult[1]]];
					else if(probeResult[2] == 1.0)
						[probeTextField setStringValue: [NSString
							stringWithFormat: @"%1.4e", probeResult[0]]];
					else if(probeResult[2] == 2.0)
						[probeTextField setStringValue: [NSString
							stringWithFormat: @"%i / %i", (int) probeResult[0], (int) probeResult[1]]];
					else if(probeResult[2] == 3.0)
						[probeTextField setStringValue: [NSString
							stringWithFormat: @"%i", (int) probeResult[0]]];
					else [probeTextField setStringValue: @"? ? ?"];
					break;
				}
//				NSLog(@"-> mouseDown to tool %i (%@)\n", [popupMenu indexOfSelectedItem] - builtInTools, tool[[popupMenu indexOfSelectedItem] - builtInTools]);
				[tool[[popupMenu indexOfSelectedItem] - builtInTools] mouseDown: theEvent];
//				NSLog(@"<- mouseDown to tool %i (%@)\n", [popupMenu indexOfSelectedItem] - builtInTools, tool[[popupMenu indexOfSelectedItem] - builtInTools]);
				break;
	}
}

- (void) mouseUp: (NSEvent*) theEvent
{
	double p[2]; NSPoint center;
	double size, x, y;
	FSViewerData theData;
	
	if(ignoreMouseUp == YES) ignoreMouseUp = NO;
	else switch([popupMenu indexOfSelectedItem]) {

		case 0: /* zoom tool */
			if(inDrag) {
				center.x = (lastClick.x + [theEvent locationInWindow].x) / 2;
				center.y = (lastClick.y + [theEvent locationInWindow].y) / 2;
				x = fabs((float)(lastClick.x - [theEvent locationInWindow].x) / [viewport bounds].size.width);
				y = fabs((float)(lastClick.y - [theEvent locationInWindow].y) / [viewport bounds].size.height);
				size = sqrt(x*y);
				[theBrowser putCurrentDataIn: &theData];
				if(size < 0.001) break;
				[viewport convertLocation: center toPoint: p];
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

- (void) scrollWheel: (NSEvent*) theEvent {
	/* eat scrolling, at least for now. */
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
	
	/***** broken for cocotron :( *****/
#ifdef WINDOWS
	NSLog(@"FSTools in Cocotron\n");
	toolsLoaded = YES;
#else
	if(toolsLoaded == NO) {
		toolsLoaded = YES;

		librarySearchPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask - NSSystemDomainMask, YES);
//		librarySearchPaths = [NSArray arrayWithObject: @"/Library"]; 

		[bundleSearchPaths addObject: [[[NSBundle mainBundle] builtInPlugInsPath] stringByAppendingPathComponent: @"Tools/"]];
		NSLog(@"bundleSearchPaths is %@\n", bundleSearchPaths);
		searchPathEnum = [librarySearchPaths objectEnumerator];
//		while(currPath = [searchPathEnum nextObject])
//			[bundleSearchPaths addObject: [currPath stringByAppendingPathComponent:appSupportSubpath]];
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
				if([aTool respondsToSelector: @selector(setDataManager:)]) [aTool setDataManager: dataManager];
				[aTool unfreeze];
				[tools addObject: aTool];
				NSLog(@"added tool %@ of class %@ found at %@\n", [aTool name], pclass, pluginPath);
				[aTool release];
			}
		}
		tool = (id*) malloc([tools count] * sizeof(id));
		toolEnum = [tools objectEnumerator];
		i = 0; while(aTool = [toolEnum nextObject]) tool[i++] = aTool;
		NSLog(@"setupMenu: tools is %@\n", tools);
		NSLog(@"done\n");
	}
#endif	
	probeTools = [[theBrowser namedProbes] count];
	
	[popupMenu removeAllItems];
	[popupMenu addItemWithTitle: @"Zoom"];
	[popupMenu addItemWithTitle: @"Dynamics"];
	builtInTools = 2 + probeTools;
	NSLog(@"probeTools is %i\n", probeTools);
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
	NSLog(@"tools did set up menu\n");
}

- (void) addTools: (NSFileWrapper*) toolWrapper {
	NSEnumerator* en;
	NSString* bundleName, *bundleDir, *filename;
	NSBundle* toolBundle;
	id <FSTool> aTool;
	Class pclass;
	int i;

	bundleDir = [NSString stringWithFormat: @"%@fstool%i/", NSTemporaryDirectory(), rand()];
	[toolWrapper writeToFile: bundleDir atomically: YES updateFilenames: NO];
	en = [[NSBundle pathsForResourcesOfType: @"fstool" inDirectory: bundleDir] objectEnumerator];
	while(bundleName = [en nextObject]) {
		/* Write the tool bundle to a temp location, load the bundle, add menu items */
		toolBundle = [NSBundle bundleWithPath: bundleName];
		pclass = [toolBundle principalClass];
//		NSLog(@"Found an extra tool with class %@\n", pclass);
		[toolClasses addObject: pclass];
		[pclass preload: toolBundle];
		aTool = [[pclass alloc] init];
		[aTool setOwnerTo: viewport];
		if([aTool respondsToSelector: @selector(setDataManager:)]) [aTool setDataManager: dataManager];
		[aTool unfreeze];
		[tools addObject: aTool];
		[popupMenu addItemWithTitle: [aTool menuName]];
		[[popupMenu itemWithTitle: [aTool menuName]] setKeyEquivalent: [aTool keyEquivalent]];
		[aTool release];
	}
	tool = (id*) malloc([tools count] * sizeof(id));
	en = [tools objectEnumerator];
	i = 0; while(aTool = [en nextObject]) tool[i++] = aTool;
	NSLog(@"addTools: tools is %@\n", tools);
}

- (void) addSpecialTools: (NSArray*) specialTools {
	NSEnumerator* en;
	NSString* bundleName, *bundleDir, *filename;
	NSBundle* toolBundle;
	NSString* toolName;
	id <FSTool> aTool;
	Class pclass;
	int i;
	
	NSLog(@"FSTools was asked to load the special tools %@\n", specialTools);
	en = [specialTools objectEnumerator];
	while(toolName = [en nextObject]) {
		bundleName = [NSString stringWithFormat: @"%@/%@.fstool",
			[[[NSBundle mainBundle] builtInPlugInsPath] stringByAppendingPathComponent: @"Special Tools/"],
			toolName
		];
		NSLog(@"trying %@\n", bundleName);
		toolBundle = [NSBundle bundleWithPath: bundleName];
		if(toolBundle == nil) { NSLog(@"failed\n"); continue; }
		pclass = [toolBundle principalClass];
		//		NSLog(@"Found an extra tool with class %@\n", pclass);
		[toolClasses addObject: pclass];
		[pclass preload: toolBundle];
		aTool = [[pclass alloc] init];
		NSLog(@"a tool is %@\n", aTool);
		[aTool setOwnerTo: viewport];
		if([aTool respondsToSelector: @selector(setDataManager:)]) [aTool setDataManager: dataManager];
		[aTool unfreeze];
		[tools addObject: aTool];
		[popupMenu addItemWithTitle: [aTool menuName]];
		[[popupMenu itemWithTitle: [aTool menuName]] setKeyEquivalent: [aTool keyEquivalent]];
		[aTool release];
	}
	tool = (id*) malloc([tools count] * sizeof(id));
	en = [tools objectEnumerator];
	i = 0; while(aTool = [en nextObject]) tool[i++] = aTool;
	NSLog(@"addSpecialTools is %@\n", tools);
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
		if(selected >= builtInTools) {
			NSLog(@"telling additional tool %i (%@) to activate\n", selected - builtInTools, tool[selected - builtInTools]);
			[tool[selected - builtInTools] activate];
		}
		else if(selected > 1) {
			[probeTextField setStringValue: @"-"];
			[[probeTextField window] setTitle: [NSString stringWithFormat: @"Probe: %@", [popupMenu titleOfSelectedItem]]];
			[[probeTextField window] orderFront: self];
		}
		currentTool = selected;
	}
}

- (void) setDataManager: (FSCustomDataManager*) dm { dataManager = dm; }

@end
