
#import "FSBrowser.h"
#import "FSSession.h"
#import "FSViewer.h"

@implementation FSBrowser

- (id) init {
	self = [super init];
	toolsWrapper = nil;
	return self;
}

- (void) awakeFromNib {
	NSString* path;
	void* loadedModule;
	
	[theTools setupMenu: self];
}

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
	tmp = [NSString stringWithFormat: @"%@fskernel%i", NSTemporaryDirectory(), rand()];
	if([[theSession kernelWrapper] writeToFile: tmp atomically: YES updateFilenames: NO] == NO) {
		NSLog(@"writeToFile failed with session %@ and data %@ writing to %@\n", theSession, [theSession kernelWrapper], tmp);
	}
	NSLog(@"Trying dlopen on \"%@\"\n", tmp);

#ifdef __WIN32__
	NSLog(@"-----> NO SUPPORT FOR DYNAMIC LOADING ON WINDOWS YET!!!\n");
	loadedModule = kernel = NULL;
	return;
#else
	loadedModule = dlopen([tmp cString], RTLD_NOW);
	if(loadedModule == NULL) { 
		NSLog(@"loadedModule was null, error code %s\n", dlerror());
		return;
	}
	kernel = dlsym(loadedModule, "kernel");
#endif
	if(kernel == NULL) {
		NSLog(@"could not extract kernel routine\n");
		return;
	}
	rootData.kernel = kernel;

	/* hack */
	kernel3 = kernel;
	
}

- (BOOL) editorDisabled { return ([editorButton isEnabled] == YES)? NO : YES; }
- (void) setAllowEditor: (BOOL) allow { [editorButton setEnabled: allow]; }

- (void) reloadSession {
	[self reloadSessionWithoutRefresh];
	[theTools setupMenu: self];
	[colorWidget setNamesTo: [theSession flagNames]];
	[self refresh: self];
}

- (void) addTools: (NSFileWrapper*) toolWrapper { toolsWrapper = [toolWrapper retain]; [theTools addTools: toolWrapper]; }
- (NSFileWrapper*) extraTools { return toolsWrapper; }

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
	NSLog(@"FSBrowser set variable names to %@ (%i unique names)\n", variableNames, uniqueVariableNames);
}

- (void) setProbeNamesTo: (NSArray*) names { probeNames = [[NSArray arrayWithArray: names] retain]; }

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
	NSLog(@"uniqueVariableNames = %i, reducedVariableNames = %@\n", uniqueVariableNames, rvn);
	free(defaults);
	realPart = [[NSArray arrayWithArray: re] retain];
	imagPart = [[NSArray arrayWithArray: im] retain];
	reducedVariableNames = [[NSArray arrayWithArray: rvn] retain];
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
- (id) tableView: (NSTableView*) tableView setObjectValue: (id) anObject forTableColumn: (NSTableColumn*) tableColumn row: (int) row {
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
			break;
	}

}

- (NSArray*) namedVariables { return variableNames; }
- (NSArray*) namedProbes { return probeNames; }
- (NSArray*) namedVariablesRealParts { return realPart; }
- (NSArray*) namedVariablesImagParts { return imagPart; }

@end
