
#import "FSBrowser.h"
#import "FSSession.h"
#import "FSViewer.h"

@implementation FSBrowser

- (id) init {
	self = [super init];
	toolsWrapper = nil;
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[super dealloc];
}

- (void) awakeFromNib {
	NSString* path;
	void* loadedModule;
	NSLog(@"browser %@ awoke from nib\n", self);
	dataManager = [[FSCustomDataManager alloc] init];
	theKernel = [[FSKernel alloc] init];
	[theKernel setDataManager: dataManager];
	[theTools setDataManager: dataManager];
	[theTools setupMenu: self];
	
	/* Set up notifications so that whenever any of our settings change, we refresh */
	[[NSNotificationCenter defaultCenter]
		addObserver: self selector: @selector(testAndRefresh:)
		name: NSControlTextDidEndEditingNotification object: iterBox
	];
	[[NSNotificationCenter defaultCenter]
		addObserver: self selector: @selector(testAndRefresh:)
		name: NSControlTextDidEndEditingNotification object: radiusBox
	];
	[[NSNotificationCenter defaultCenter]
		addObserver: self selector: @selector(testAndRefresh:)
		name: NSControlTextDidEndEditingNotification object: minRadiusBox
	];
	[[NSNotificationCenter defaultCenter]
		addObserver: self selector: @selector(testAndRefresh:)
		name: NSControlTextDidEndEditingNotification object: aspectBox
	];
}

- (IBAction) hidePanels: (id) sender {
}

- (IBAction) revealPanels: (id) sender {
}

- (void) testAndRefresh: (NSNotification*) note {
	id control;
	control = [note object];
	if(
		( (control == iterBox) && (([theSession currentNode] -> data).maxIters != [iterBox intValue]) ) ||
		( (control == radiusBox) && (([theSession currentNode] -> data).maxRadius != [radiusBox doubleValue]) ) ||
		( (control == minRadiusBox) && (([theSession currentNode] -> data).minRadius != [minRadiusBox doubleValue]) ) ||
		( (control == aspectBox) && (([theSession currentNode] -> data).aspectRatio != [aspectBox doubleValue]) )
	) [self refresh: self];
}

- (FSKernel*) kernel { return theKernel; }

- (void) loadDataFromInterfaceTo: (FSViewerData*) theData {
	theData -> maxIters = [iterBox intValue];
	theData -> maxRadius = [radiusBox doubleValue];
	theData -> minRadius = [minRadiusBox doubleValue];
	theData -> aspectRatio = [aspectBox floatValue];
	theData -> eventManager = theTools;
	theData -> kernel = kernel;
}

- (void) reloadSessionWithoutRefresh { 
	void* loadedModule;
	NSString* tmp;
	FSViewerData d;

	d = [[theSession currentNode] data];
	memmove(&rootData, &d, sizeof(FSViewerData));
	[iterBox setIntValue: rootData.maxIters];
	[radiusBox setFloatValue: rootData.maxRadius];
	[minRadiusBox setFloatValue: rootData.minRadius];
	[aspectBox setFloatValue: rootData.aspectRatio];
	rootData.eventManager = theTools;

	if([theSession kernelIsCached] || [self editorDisabled]) {
		tmp = [NSString stringWithFormat: @"%@fskernel%i", NSTemporaryDirectory(), rand()];
		if([[theSession kernelWrapper] writeToFile: tmp atomically: YES updateFilenames: NO] == NO) {
			NSLog(@"writeToFile failed with session %@ and data %@ writing to %@\n", theSession, [theSession kernelWrapper], tmp);
		}
		[theKernel loadKernelFromFile: tmp];
	}
	else {
		[theCompiler buildScript: [theSession program]];
		specialTools = [[theCompiler specialTools] retain];
		[self loadTools];
		[theKernel buildKernelFromCompiler: theCompiler];
	}
	kernel = [theKernel kernelPtr];
	if(kernel == NULL) {
		return;
	}
	rootData.kernel = kernel;

	/* hack */
	kernel3 = kernel;
	
}

- (BOOL) editorDisabled { return ([editorButton isEnabled] == YES)? NO : YES; }
- (void) setAllowEditor: (BOOL) allow { [editorButton setEnabled: allow]; }
- (void) loadTools { [theTools addSpecialTools: specialTools]; }

- (void) reloadSession {
	[self reloadSessionWithoutRefresh];
	[theTools setupMenu: self];
	[colorWidget setNamesTo: [theSession flagNames]];
	[self refresh: self];
}

- (void) addTools: (NSFileWrapper*) toolWrapper { toolsWrapper = [toolWrapper retain]; [theTools addTools: toolWrapper]; }
- (NSFileWrapper*) extraTools { return toolsWrapper; }
- (IBAction) embedTool: (id) sender {
	NSOpenPanel* panel;
	panel = [NSOpenPanel openPanel];
	[panel setTitle: @"Select a Directory to Embed"];
	[panel setMessage: @"Select a folder.  The contents of the folder will be embedded into the current script.  Scripts may only contain one embedded directory, so all extra resources required (custom tools, etc) must be in this folder."];
	[panel setCanChooseDirectories: YES];
	[panel setCanChooseFiles: NO];
	/*** replaced if for COCOTRON ***/
	//if([panel runModal] == NSFileHandlingPanelOKButton) {
	if(0) {
		toolsWrapper = [[NSFileWrapper alloc] initWithPath: [panel filename]];
		[theTools addTools: toolsWrapper];
	}
}

- (void) refreshAll { 
	[theTools setupMenu: self];
	[colorWidget setNamesTo: [theSession flagNames]];
	[self refresh: self];
}

- (IBAction) goHome: (id) sender {
	[theSession goToRoot: sender];
	[theSession goForward: sender];
	[self sendDefaultsToViewer];
	[theViewer setViewerData: &([theSession currentNode] -> data)];
}

- (IBAction) goUp: (id) sender {
	int currentPlane;
	FSSessionNode* cn, *lastGood;
	lastGood = [theSession currentNode];
	currentPlane = ([theSession currentNode] -> data).program;
	while([theSession currentNode] != [theSession getRootNode]) {
		cn = [theSession currentNode];
		[theSession goBackward: self];
		if((([theSession currentNode] -> data).program != currentPlane)) break;
		if([theSession currentNode] == cn) break;
		lastGood = cn;
	}
//	if([theSession currentNode] == [theSession getRootNode]) [theSession goForward: self];
	[theViewer setViewerData: &([theSession currentNode] -> data)];
}

- (IBAction) goForward: (id) sender {
	[theSession goForward: sender];
	([theSession currentNode] -> data).kernel = kernel;
	([theSession currentNode] -> data).eventManager = theTools;
	[self sendDefaultsToViewer];
	[theViewer setViewerData: &([theSession currentNode] -> data)];
}

- (IBAction) goBackward: (id) sender {
	[theSession goBackward: sender];
	([theSession currentNode] -> data).kernel = kernel;
	([theSession currentNode] -> data).eventManager = theTools;
	[self sendDefaultsToViewer];
	[theViewer setViewerData: &([theSession currentNode] -> data)];
}

- (IBAction) refresh: (id) sender {
//	([theSession currentNode] -> data).kernel = ([programBox indexOfSelectedItem] == 0)? kernel1 : kernel2;
	/* hack */ ([theSession currentNode] -> data).kernel = kernel;
	([theSession currentNode] -> data).eventManager = theTools;
	([theSession currentNode] -> data).maxIters = [iterBox intValue];
	([theSession currentNode] -> data).maxRadius = [radiusBox doubleValue];
	([theSession currentNode] -> data).minRadius = [minRadiusBox doubleValue];
	([theSession currentNode] -> data).aspectRatio = [aspectBox floatValue];
	([theSession currentNode] -> data).detailLevel = ([detailBox state] == NSOnState) ? 2.0 : 1.0;
	[self sendDefaultsToViewer];
	[theViewer setViewerData: &([theSession currentNode] -> data)];
}


- (void) putCurrentDataIn: (FSViewerData*) p {
	FSViewerData d;
	d = [[theSession currentNode] data];
	memmove(p, &d, sizeof(FSViewerData));
}



- (void) changeTo: (NSString*) newName X: (double) x Y: (double) y 
					p1: (double) p1 p2: (double) p2 
					pixelSize: (double) pixelSize parametric: (BOOL) isPar
{
	FSViewerData data;
	data.par[0] = p1;
	data.par[1] = p2;
	data.detailLevel = ([detailBox state] == NSOnState) ? 2.0 : 1.0;
	data.pixelSize = pixelSize;
	
	data.center[0] = x;
	data.center[1] = y;
	data.program = (isPar == YES)? 1 : 3;
//	data.kernel = ([programBox indexOfSelectedItem] == 0)? kernel1 : kernel2;
	/* hack */ data.kernel = kernel3;
	data.maxIters = [iterBox intValue];
	data.maxRadius = [radiusBox doubleValue];
	data.minRadius = [minRadiusBox doubleValue];
	data.aspectRatio = [aspectBox floatValue];
	data.eventManager = theTools;
	[theSession addChildWithData: data andMakeCurrent: YES];
	[theTools updateMenuForParametric: isPar];
	[self sendDefaultsToViewer];
	[theViewer setViewerData: &data];
}

- (FSSession*) session { return theSession; }
- (FSViewer*) viewer { return theViewer; }

- (void) setVariableNamesTo: (NSArray*) names {
	NSEnumerator* nameEnum;
	NSString* curName;
	NSString* prevName;
	NSMutableArray* unique;
	
	unique = [[NSMutableArray alloc] init];
	variableNames = [[NSArray arrayWithArray: names] retain];
	nameEnum = [variableNames objectEnumerator];
	curName = [nameEnum nextObject];
	uniqueVariableNames = 0;
	while(curName) {
		++uniqueVariableNames;
		[unique addObject: curName];
		prevName = curName; curName = [nameEnum nextObject];
		if([curName isEqualToString: prevName]) curName = [nameEnum nextObject];
	}
	reducedVariableNames = [[NSArray arrayWithArray: unique] retain];
	[unique release], unique = nil;	
}

- (void) setProbeNamesTo: (NSArray*) names { probeNames = [[NSArray arrayWithArray: names] retain]; }
- (void) setSpecialToolsTo: (NSArray*) names { specialTools = [[NSArray arrayWithArray: names] retain]; }

- (void) setVariableValuesToReal: (NSArray*) rp imag: (NSArray*) ip {
	realPart = [[NSArray arrayWithArray: rp] retain];
	imagPart = [[NSArray arrayWithArray: ip] retain];
}

- (void) resetDefaults {
	double* defaults;
	double c;
	int i, j;
	NSMutableArray *re, *im, *rvn;
	NSString* prevName, *curName;
	NSEnumerator* nameEnum;
	
	kernel(-2, NULL, 0, &c, 0, 0.0, 0.0);
	if((int) c != [variableNames count])
		NSLog(@"***** kernel is reporting a different value than expected for parameter count (reported %i, expected %i)\n", (int) c, [variableNames count]);
	
	re = [[NSMutableArray alloc] init];
	im = [[NSMutableArray alloc] init];
	rvn = [[NSMutableArray alloc] init];
	defaults = malloc(2 * sizeof(double) * [variableNames count]);
	kernel(-3, NULL, 0, defaults, 0, 0.0, 0.0);
	prevName = @"";
	nameEnum = [variableNames objectEnumerator];
	curName = [nameEnum nextObject];
	uniqueVariableNames = 0; j = 0;
	while(curName) {
		[re addObject: [NSNumber numberWithDouble: defaults[j++]]];
		[rvn addObject: curName];
		++uniqueVariableNames;
		prevName = curName; curName = [nameEnum nextObject];
		if([curName isEqualToString: prevName]) {
			[im addObject: [NSNumber numberWithDouble: defaults[j++]]];
			curName = [nameEnum nextObject];
		}
		else [im addObject: [NSNull null]];
	}
	free(defaults);
	realPart = [[NSArray arrayWithArray: re] retain];
	imagPart = [[NSArray arrayWithArray: im] retain];
	reducedVariableNames = [[NSArray arrayWithArray: rvn] retain];
	[re release]; [im release]; [rvn release];
}

- (void) sendDefaultsToViewer {
	NSEnumerator *eE, *iE;
	id n;
	double* d;
	int i;
	if([variableNames count] == 0) { [theViewer setDefaultsTo: NULL count: 0]; return; }
	eE = [realPart objectEnumerator];
	iE = [imagPart objectEnumerator];
	d = malloc([variableNames count] * 2 * sizeof(double));
	i = 0;
	while(1) {
		n = [eE nextObject];
		if(n == nil) break;
		d[i++] = [n doubleValue];
		n = [iE nextObject];
		if(n == nil) break;
		if([n isEqual: [NSNull null]]) continue;
		d[i++] = [n doubleValue];
	}
	[theViewer setDefaultsTo: d count: i];
	free(d);
}

- (int) numberOfRowsInTableView: (NSTableView*) tableView { return uniqueVariableNames; }
- (id) tableView: (NSTableView*) tableView objectValueForTableColumn: (NSTableColumn*) tableColumn row: (int) row {
	int col;
	col = [[tableColumn identifier] intValue];
	switch(col) {
		case 0:
			return [NSString stringWithString: [reducedVariableNames objectAtIndex: row]];
		case 1:
			return [realPart objectAtIndex: row];
		case 2:
			return [imagPart objectAtIndex: row];
		default:
			return [NSString stringWithString: @"?"];
	}
}
- (void) tableView: (NSTableView*) tableView setObjectValue: (id) anObject forTableColumn: (NSTableColumn*) tableColumn row: (int) row {
	NSEnumerator* en;
	NSNumber* val;
	NSMutableArray* ar;
	int col, i;
	col = [[tableColumn identifier] intValue];
	switch(col) {
		case 1:
			i = 0;
			ar = [[NSMutableArray alloc] init];
			en = [realPart objectEnumerator];
			while(val = [en nextObject]) {
				if(i == row) [ar addObject: [NSNumber numberWithDouble: [anObject doubleValue]]];
				else [ar addObject: val];
				++i;
			}
			realPart = [[NSArray arrayWithArray: ar] retain];
			[ar release];
			break;
		case 2:
			i = 0;
			ar = [[NSMutableArray alloc] init];
			en = [imagPart objectEnumerator];
			while(val = [en nextObject]) {
				if(i == row) [ar addObject: [NSNumber numberWithDouble: [anObject doubleValue]]];
				else [ar addObject: val];
				++i;
			}
			imagPart = [[NSArray arrayWithArray: ar] retain];
			[ar release];
			break;
	}
	[self refresh: self];
}

- (NSArray*) specialTools { return specialTools; }
- (NSArray*) namedVariables { return variableNames; }
- (NSArray*) namedProbes { return probeNames; }
- (NSArray*) namedVariablesRealParts { return realPart; }
- (NSArray*) namedVariablesImagParts { return imagPart; }


@end
