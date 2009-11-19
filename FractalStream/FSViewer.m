//
//  FSViewer.m
//  FractalStream
//
//  Created by Matt Noonan on 11/24/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "FSViewer.h"

#import "debug.h"

#define LogBoxSize 7


@implementation FSViewerObject
- (FSViewerItem*) itemPtr { return &item; }
- (void) setItem: (FSViewerItem) newItem { item = newItem; }
- (int) batch { return item.batch; }
- (BOOL) isVisible { return item.visible; }
@end

@implementation FSViewer


- (id) initWithCoder: (NSCoder*) coder
{
	int i;
	self = [super initWithCoder: coder];

	Debug(@"this is viewer %@\n", self);

	return self;
}

- (void) awakeFromNib {
	int i, j, xBoxes, yBoxes;
	
	
	view = &fakeview;
	fakeview.eventManager = nil;
	
	fswindow = [[FSFullscreenWindow alloc] init];
	configured = NO;
	readyToRender = NO;
	readyToDisplay = NO;
	for(i = 0; i < 64; i++) {
		acCache[i].allocated_entries = 16;
		acCache[i].used_entries = 0; 
		acCache[i].color = malloc(8 * 8 * 3 * sizeof(float) * 16);
		acCache[i].x = malloc(sizeof(double) * 16);
		acCache[i].y = malloc(sizeof(double) * 16);
	}
	
	viewerColorizer = [[FSColorizer alloc] init];
	workQueue = [[FSOperationQueue alloc] init];
	[workQueue setMaxConcurrentOperationCount: NSOperationQueueDefaultMaxConcurrentOperationCount];
	drawing = [[NSString stringWithString: @"drawing"] retain]; // used as a semaphore
	[viewerColorizer setColorWidget: colorPicker autocolorCache: acCache];
	renderQueueEntries = 0;
	renderBatch = 0;
	
	renderingFinishedObject = nil;
	currentBatch = 1;
	displayList = [[NSMutableArray alloc] init];
	useFakeZoom = YES;
	
//	[[self window] makeFirstResponder: self];
	[[self window] setAcceptsMouseMovedEvents: NO];
	
	//[progress setDisplayedWhenStopped: NO];
	//[progress setUsesThreadedAnimation: YES];
	

	coordinateTracker = [self 
		addTrackingRect: [self bounds] 
		owner: self
		userData: NULL
		assumeInside: YES
	];


//	[[self window] setInitialFirstResponder: self];
//	[[self window] makeKeyAndOrderFront: self];
	[[self window] setTitle: @"FractalStream"];
	
	
	
	[progress setDisplayedWhenStopped: NO];
	readyToRender = NO;
	displayLocked = NO;	
	awake = YES;

	background = [[NSImage alloc] initWithSize: [self bounds].size];
#ifdef WINDOWS
	NSCachedImageRep* rep = [[NSCachedImageRep alloc] initWithSize: [self bounds].size depth: 8 separate: NO alpha: NO];
	[rep setColorSpaceName: NSDeviceRGBColorSpace];
	[rep setBitsPerSample: 8];
	[rep setAlpha: NO];
	[rep setOpaque: NO];
	[rep setPixelsHigh: [self bounds].size.height];
	[rep setPixelsWide: [self bounds].size.width];
	[background addRepresentation: rep];
#endif
	[background lockFocus];
	[[NSColor whiteColor] set];
	NSRectFill([self bounds]);
	[background unlockFocus];

#ifndef WINDOWS
//	[self allocateGState];
	[[self window] useOptimizedDrawing: YES];
#endif	
	
	queueLock = [[NSConditionLock alloc] initWithCondition: 0];
	inset = nil;
	showInset = NO;
}

- (void) stopAllRenderOperations: (NSNotification*) note {
//	NSLog(@"FSViewer %@ decided to stop rendering, controllingWindow is %@, note is %@.\n", self, controllingWindow, note);
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	++renderBatch;
	[workQueue cancelAllOperations];
//	[viewerColorizer setCurrentBatch: renderBatch+1];
	[queueLock lockWhenCondition: 0];
	[queueLock unlockWithCondition: 0];
}
	
																					
- (BOOL) isAwake { return awake; }

- (void) dealloc {
	[workQueue release];
	[queueLock release];
	[super dealloc];
}

- (id) document { return document; }
- (void) registerForNotifications: (id) owningDocument { }

- (void) reload: (NSNotification*) note {
	[self setViewerData: view];
}

- (void) setShowParameterLocation: (BOOL) doShow forView: (FSViewerData*) newView {
	synchronizeTo(drawing) {
		if(doShow) {
			NSPoint p;
			if(inset != nil) [inset release];
			inset = [[self snapshot] retain];
			p = [self locationOfPoint: newView -> par];
			insetMarker[0] = (p.x - [self bounds].origin.x) / [self bounds].size.width; 
			insetMarker[1] = (p.y - [self bounds].origin.y) / [self bounds].size.height; 
			showInset = ([insetButton state] == NSOnState)? YES : NO;
		}
		else {
			showInset = NO;
		}
	}
	[self setNeedsDisplay: YES];
}

- (void) setViewerData: (FSViewerData*) newData {
	readyToRender = YES;
	nodeChanged = YES;
	
	if(configured == NO) {
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(stopAllRenderOperations:) name: @"NSWindowWillCloseNotification" object: controllingWindow];
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(reload:) name: @"FSColorsChanged" object: colorPicker];
	}
	if((configured == YES) && (view -> program != newData -> program) && (view -> program == 3)) [self lockAllAutocolor];
	if(configured && (view -> program != newData -> program)) {
		[self setShowParameterLocation: (newData->program == 3)? YES : NO forView: newData];
		if(newData -> program != 3) [self removeObjectsBelowPlane: newData -> program];
	}
	/* If everything in the new view is the same except for zoom level / center, we can reuse the old texture as an approximation */
	if(
			(configured == YES) &&
			(view->pixelSize > 0.0) &&
			(newData->aspectRatio == view->aspectRatio) &&
			(newData->par[0] == view->par[0]) &&
			(newData->par[1] == view->par[1]) &&
			(newData->maxIters == view->maxIters) &&
			(newData->maxRadius == view->maxRadius) &&
			(newData->minRadius == view->minRadius) &&
			(newData->program == view->program) &&
			(newData->kernel == view->kernel)
	) [self zoomFrom: view->center to: newData->center scalingFrom: view->pixelSize to: newData->pixelSize];

	if(configured == YES) {
		if((newData -> program != view -> program) || (newData -> kernel != view -> kernel))
			[[NSNotificationCenter defaultCenter] postNotificationName: @"FSViewerDidChangePlane" object: self];	
		else [[NSNotificationCenter defaultCenter] postNotificationName: @"FSViewerDidChangeZoom" object: self];	
	}
	
	configured = YES; view = &fakeview; fakeview = *newData; 
	[self render: self];
//	NSLog(@"done setting data\n");
}
- (void) getViewerDataTo: (FSViewerData*) savedData { memmove(savedData, view, sizeof(FSViewerData)); }

- (FSViewerData) data { return fakeview; }
- (FSColorWidget*) colorPicker { return colorPicker; }
- (void) setColorPicker: (FSColorWidget*) newColorPicker { 
	colorPicker = newColorPicker;
	[viewerColorizer setColorWidget: colorPicker autocolorCache: acCache];
}


- (IBAction) render: (id) sender {
	int i; 
	int xBoxes, yBoxes, x, y, xRemainder, yRemainder;
	double dx, dy;
	float detailLevel; 
	FSRenderUnit unit;
	FSRenderOperation* op;
	NSPoint p;
	double z[2];
	double linearMultiplier;
	BOOL highDetail;
	BOOL noProgressive;
	
	if(readyToRender == NO) { 
		Debug(@"not ready to render\n");
		return;
	}

	[workQueue cancelAllOperations];
	
#ifndef WINDOWS
	[progress setUsesThreadedAnimation: YES];
	[progress setHidden: NO];
	[progress startAnimation: self];
#endif
	
	highDetail = (view -> detailLevel > 1.0)? YES : NO;
	noProgressive = (view -> detailLevel <= 0.0)? YES : NO;

	unit.viewerData = view;
	unit.origin[0] = view -> center[0] - ((double) [self bounds].size.width * view -> pixelSize * view -> aspectRatio / 2.0);
	unit.origin[1] = view -> center[1] + ((double) [self bounds].size.height * view -> pixelSize / 2.0);
	unit.offset[0] = 0.0;
	unit.offset[1] = 0.0;
	unit.step[0] = view -> pixelSize * view -> aspectRatio;
	unit.step[1] = -view -> pixelSize;
	unit.dimension[0] = [self bounds].size.width;		
	unit.dimension[1] = [self bounds].size.height;
	z[0] = unit.origin[0] + unit.offset[0];
	z[1] = unit.origin[1] + unit.offset[1];
	p = [self locationOfPoint: z];
	unit.location[0] = p.x;
	unit.location[1] = p.y - (float) unit.dimension[1];
	unit.owner = self;
	unit.freeResults = YES;
	unit.setting = setting;
	unit.settings = defaults;
	unit.parametric = (view -> program == 3)? NO : YES;
	unit.queueLock = queueLock;
	
	synchronizeTo([colorPicker colorArray]) {
		[colorPicker makeColorCache];
	}
	/* Set up the autocolor cache */
/*
 for(i = 0; i < 64; i++) {
		acCache[i].active = [colorPicker useAutocolorForColor: i];
		if(acCache[i].active) {
			int acCount;
			acCache[i].locked = [colorPicker useLockForColor: i];
			acCount = [colorPicker numberOfFixpointsForAutocolor: i];
			acCache[i].used_entries = acCount;
			if(acCount > acCache[i].allocated_entries) {
				acCache[i].allocated_entries = acCount + 16;
				realloc(acCache[i].color, 8 * 8 * 3 * sizeof(float) * acCache[i].allocated_entries);
				realloc(acCache[i].x, sizeof(double) * acCache[i].allocated_entries);
				realloc(acCache[i].y, sizeof(double) * acCache[i].allocated_entries);
			}
			[colorPicker cacheAutocolor: i to: acCache[i].color X: acCache[i].x Y: acCache[i].y];
		}
	}
*/	
	/* Subdivide the viewport into 128x128 regions (or smaller), give each one its own unit */
	xBoxes = (((int) [self bounds].size.width) >> LogBoxSize);
	yBoxes = (((int) [self bounds].size.height) >> LogBoxSize);
	xRemainder = ((int) [self bounds].size.width) - (xBoxes << LogBoxSize);
	yRemainder = ((int) [self bounds].size.height) - (yBoxes << LogBoxSize);
	if(xRemainder) ++xBoxes;
	if(yRemainder) ++yBoxes;
	dx = (double)(1 << LogBoxSize) * view -> pixelSize * view -> aspectRatio;
	dy = (double)(1 << LogBoxSize) * view -> pixelSize;
	
	synchronizeTo(workQueue) {
		if(highDetail) { renderQueueEntries = 3 * xBoxes * yBoxes; }
		else { renderQueueEntries = 2 * xBoxes * yBoxes; }
		++renderBatch;
	}
	synchronizeTo(drawing) { undrawnBlocks = 0; }
	[viewerColorizer setCurrentBatch: renderBatch];
	for(i = 0; i < 3; i++) {
		if(i == 0) linearMultiplier = 0.5;
		else if(i == 1) linearMultiplier = 1.0;
		else if(i == 2) linearMultiplier = 2.0;
		if((highDetail == NO) && (i > 1)) break;
		if(noProgressive && i) break;
		unit.offset[1] = 0.0;
		for(y = 0; y < yBoxes; y++) {
			unit.offset[0] = 0.0;
			for(x = 0; x < xBoxes; x++) {
				unit.dimension[0] = ((x == xBoxes - 1) && xRemainder)? xRemainder : (1 << LogBoxSize);	/* note: this ignores detailLevel */
				unit.dimension[1] = ((y == yBoxes - 1) && yRemainder)? yRemainder : (1 << LogBoxSize);
				unit.dimension[0] = (int)((double) unit.dimension[0] * linearMultiplier + 0.5);
				unit.dimension[1] = (int)((double) unit.dimension[1] * linearMultiplier + 0.5);
				unit.step[0] = view -> pixelSize * view -> aspectRatio / linearMultiplier;
				unit.step[1] = -view -> pixelSize / linearMultiplier;
				unit.multiplier = i - 1;
				unit.batch = renderBatch;
				z[0] = unit.origin[0] + unit.offset[0];
				z[1] = unit.origin[1] + unit.offset[1];
				p = [self locationOfPoint: z];
				unit.location[0] = p.x;
				unit.location[1] = p.y - (float) unit.dimension[1] / linearMultiplier;
				op = [[FSRenderOperation alloc] initWithUnit: unit colorizer: viewerColorizer];
				[workQueue addOperation: op];
				[op release];
				unit.offset[0] += dx;
			}
			unit.offset[1] -= dy;
		}
	}
	[workQueue go]; /* no-op if using threading */
	[viewDescription setString:
		[NSString stringWithFormat: @"Drawing %@\nCentered on (%1.4e, %1.4e)\nWidth is %1.4e, Height is %1.4e\n",
			(view -> program == 1)? @"parameter plane" : [NSString stringWithFormat: @"dynamical plane\nParameter is (%1.4e, %1.4e)", view -> par[0], view -> par[1]],
			view -> center[0],
			view -> center[1],
			(double) [self bounds].size.width * view -> pixelSize * view -> aspectRatio,
			(double) [self bounds].size.height * view -> pixelSize
		]
	];
}

- (void) renderOperationFinished: (id) op {
	unsigned char* planes[1];
	NSSize size;
	NSPoint p;
	NSRect r;
	NSBitmapImageRep* bitmap;
	NSImage* partialImage;
	
	if(([op unit] -> finished) && ([op unit] -> batch == renderBatch)) {
		size.width = [op unit] -> dimension[0];
		size.height = [op unit] -> dimension[1];
		planes[0] = (unsigned char*)([op unit] -> result);
#ifndef WINDOWS
		bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: planes
														 pixelsWide: size.width pixelsHigh: size.height bitsPerSample: 8
													samplesPerPixel: 3 hasAlpha: NO isPlanar: NO
													 colorSpaceName: NSDeviceRGBColorSpace
				  /*		bitmapFormat: NSFloatingPointSamplesBitmapFormat*/
														bytesPerRow: (size.width * 4)
													   bitsPerPixel: 32
				  ];
#else
		bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: planes
														 pixelsWide: size.width pixelsHigh: size.height bitsPerSample: 8
													samplesPerPixel: 3 hasAlpha: NO isPlanar: NO
													 colorSpaceName: NSDeviceRGBColorSpace
				  /*		bitmapFormat: NSFloatingPointSamplesBitmapFormat*/
														bytesPerRow: (size.width * 3)
													   bitsPerPixel: 24
				  ];
#endif
		synchronizeTo(drawing) {
			finalX = (int)([op unit] -> dimension[0] + 0.5);
			finalY = (int)([op unit] -> dimension[1] + 0.5);
			p.x = [op unit] -> location[0];
			p.y = [op unit] -> location[1];
			if([op unit] -> multiplier == -1) r = NSMakeRect(p.x, p.y, finalX * 2, finalY * 2);
			else if([op unit] -> multiplier == 1) r = NSMakeRect(p.x, p.y, finalX / 2, finalY / 2);
			else r = NSMakeRect(p.x, p.y, finalX, finalY);
			[background lockFocus];
			#ifdef WINDOWS
				partialImage = [[NSImage alloc] initWithSize: size];
				[partialImage addRepresentation: bitmap];
				[partialImage drawInRect: r fromRect: NSZeroRect operation: NSCompositeCopy fraction: 1.0];
				[partialImage autorelease];
			#else
				[bitmap drawInRect: r];
			#endif
			[background unlockFocus];
			[bitmap release];
			readyToDisplay = YES;
			[op release];
			[self setNeedsDisplay: YES];
			++undrawnBlocks;
			if(undrawnBlocks == 16) { [self display]; undrawnBlocks = 0; }
		}
//		[self performSelectorOnMainThread: @selector(viewerNeedsDisplay) withObject: nil waitUntilDone: NO];
	}
	synchronizeTo(workQueue) {
		if([op unit] -> batch == renderBatch) {
			--renderQueueEntries;
			if(renderQueueEntries == 0) {
				[progress stopAnimation: self];
				[progress setHidden: YES];
				if(renderingFinishedObject != nil)
					[renderingFinishedObject performSelector: renderingFinished];
			}
		}
	}
}

- (void) viewerNeedsDisplay { 
	[self setNeedsDisplay: YES];
}

- (void) setRenderCompletedMessage: (SEL) message forObject: (id) obj { renderingFinished = message; renderingFinishedObject = obj; }

- (void) setDefaultsTo: (double*) def count: (int) n {
	int i;
	defaults = n;
	if(n) for(i = 0; i < n; i++) { setting[i + 6] = def[i];  }
}

- (void) viewDidEndLiveResize {
	[super viewDidEndLiveResize];
	synchronizeTo(drawing) {
		[background release];
		background = [[NSImage alloc] initWithSize: [self bounds].size];
	}
	[self render: self];
}

/* Routines for drawing various objects into the view */

- (int) getBatchNumber { 
	int r;
	synchronizeTo(displayList) { r = currentBatch; ++currentBatch; }
	return r;
}

- (void) removeObjectsBelowPlane: (int) plane {
	NSEnumerator* objEnum;
	FSViewerObject* theObj;
	NSArray* oldDisplayList;
	synchronizeTo(displayList) {
		oldDisplayList = [NSArray arrayWithArray: displayList];
		[displayList release];
		displayList = [[NSMutableArray alloc] init];
		objEnum = [oldDisplayList objectEnumerator];
		while(theObj = (FSViewerObject*) [objEnum nextObject]) if(theObj->plane <= plane) [displayList addObject: theObj];
	}
}

- (void) deleteObjectsInBatch: (int) batch {
	NSEnumerator* objEnum;
	FSViewerObject* theObj;
	NSArray* oldDisplayList;
	synchronizeTo(displayList) {
		oldDisplayList = [NSArray arrayWithArray: displayList];
		[displayList release];
		displayList = [[NSMutableArray alloc] init];
		objEnum = [oldDisplayList objectEnumerator];
		while(theObj = [objEnum nextObject]) if([theObj batch] != batch) [displayList addObject: theObj];
	}
}

- (void) changeBatch: (int) batch to: (int) newBatch {
	NSEnumerator* objEnum;
	FSViewerObject* theObj;
	
	synchronizeTo(displayList) {
		objEnum = [displayList objectEnumerator];
		while(theObj = [objEnum nextObject]) if([theObj batch] == batch) [theObj itemPtr] -> batch = newBatch;
	}
}

- (void) makeBatch: (int) batch visible: (BOOL) vis {
	NSEnumerator* objEnum;
	FSViewerObject* theObj;
	
	synchronizeTo(displayList) {
		objEnum = [displayList objectEnumerator];
		while(theObj = [objEnum nextObject]) if([theObj batch] == batch) [theObj itemPtr] -> visible = vis;
	}
}

- (void) drawObject: (FSViewerObject*) newObject {
	synchronizeTo(displayList) {
		newObject->plane = view->program;
		[displayList addObject: newObject];
	}
} 

- (void) drawItem: (FSViewerItem) newItem {
	FSViewerObject* newObject;
	newObject = [[FSViewerObject alloc] init];
	[newObject setItem: newItem];
	[self drawObject: newObject];
	[newObject release];
}

- (NSImage*) snapshot {
	return [[background copy] autorelease];
	
/*
*/
}

/******* Convert these methods to use the FSViewerItem stack ******/
- (void) drawDotAt: (NSPoint) P withColor: (float*) rgb 
{
	float sx, sy, ex, ey;
	NSPoint p;
		
	p = [self convertPoint: P fromView: nil];
}

- (void) drawBoxFrom: (NSPoint) start to: (NSPoint) end withColor: (float*) rgb
{
	double sx, sy, ex, ey;
	float temp;
	FSViewerItem item;
	[self convertLocation: start toPoint: item.point[0]];
	[self convertLocation: end toPoint: item.point[1]];
	item.type = FSVO_Box;
	item.color[0][0] = rgb[0]; item.color[0][1] = rgb[1]; item.color[0][2] = rgb[2];
	item.color[0][3] = 0.8;
	item.color[1][0] = item.color[1][1] = item.color[1][2] = item.color[1][3] = 1.0;
	item.batch = 0;
	item.visible = YES;
	
	[self deleteObjectsInBatch: 0];
	[self drawItem: item];
	//[self setNeedsDisplay: YES];
	[self display];
}

- (void) draw: (int) nTraces tracesFrom: (NSPoint*) traceList steps: (int) nSteps {
}
	
- (void) traceFrom: (NSPoint) thePoint withColor: (float*) rgb {
}

/************/



- (void) runAt: (double*) p into: (double*) result probe: (int) pr steps: (int) ns {
	double in[512];
	int i;
	int length; int it;
	for(i = 0; i < 512; i++) in[i] = setting[i];
	in[0] = p[0]; in[1] = p[1];
	in[2] = view -> aspectRatio;
	in[3] = view -> par[0]; in[4] = view -> par[1];
	in[5] = view -> pixelSize; 
	if(pr == 0) { length = 1; it = ns; }
	else { length = -pr; it = view -> maxIters; }
	(view -> kernel)(view -> program, in, length, result, it, view -> maxRadius, view -> minRadius);
}

- (void) runAt: (double*) p into: (double*) result probe: (int) pr {
	[self runAt: p into: result probe: pr steps: view -> maxIters];
}

- (void) runAt: (double*) p withParameter: (double*) q into: (double*) result probe: (int) pr steps: (int) ns {
	double in[512];
	int i;
	int length; int it;
	for(i = 0; i < 512; i++) in[i] = setting[i];
	in[0] = p[0]; in[1] = p[1];
	in[2] = view -> aspectRatio;
	in[3] = q[0]; in[4] = q[1];
	in[5] = view -> pixelSize; 
	if(pr == 0) { length = 1; it = ns; }
	else { length = -pr; it = view -> maxIters; }
	(view -> kernel)(3, in, length, result, it, view -> maxRadius, view -> minRadius);
}

- (void) drawObjects {
	NSEnumerator* objEnum;
	FSViewerObject* obj;
	FSViewerItem* item;
	NSBezierPath* path;
	NSPoint s, e;
	double p[2];
	NSRect r;
	float t;
	NSPoint point[2];
	
	synchronizeTo(displayList) {
		objEnum = [displayList objectEnumerator];
		while(obj = [objEnum nextObject]) {
			item = [obj itemPtr];
			p[0] = item -> point[0][0]; p[1] = item -> point[0][1]; s = [self locationOfPoint: p];
			p[0] = item -> point[1][0]; p[1] = item -> point[1][1]; e = [self locationOfPoint: p];
			if([obj isVisible] == YES) switch(item -> type) {

				case FSVO_Point:
					r = NSMakeRect(s.x - 0.5, s.y - 0.5, 1.0, 1.0);
					[[NSColor colorWithCalibratedRed: item -> color[0][0]
						green: item -> color[0][1]
						blue: item -> color[0][2]
						alpha: item -> color[0][3]
					] set];
					NSRectFillUsingOperation(r, NSCompositeSourceOver);
					break;

				case FSVO_Dot:
					r = NSMakeRect(s.x - 2.0, s.y - 2.0, 5.0, 5.0);
					[[NSColor colorWithCalibratedRed: item -> color[0][0]
						green: item -> color[0][1]
						blue: item -> color[0][2]
						alpha: item -> color[0][3]
					] set];
					path = [NSBezierPath bezierPath];
					[path setLineWidth: 0.5];
					[path appendBezierPathWithOvalInRect: r];
					[path fill];
					[[NSColor colorWithCalibratedRed: item -> color[1][0]
						green: item -> color[1][1]
						blue: item -> color[1][2]
						alpha: item -> color[1][3]
					] set];
					[path stroke];
					break;

				case FSVO_Line:
					point[0] = s; point[1] = e;
					[[NSColor colorWithCalibratedRed: item -> color[0][0]
						green: item -> color[0][1]
						blue: item -> color[0][2]
						alpha: item -> color[0][3]
					] set];
					path = [NSBezierPath bezierPath];
					[path setLineWidth: 1];
					[path appendBezierPathWithPoints: point count: 2];
					[path stroke];				
					break;

				case FSVO_Box:
					if(s.x > e.x) { t = e.x; e.x = s.x; s.x = t; }
					if(s.y > e.y) { t = e.y; e.y = s.y; s.y = t; }
					r = NSMakeRect(s.x, s.y, e.x - s.x, e.y - s.y);
					[[NSColor colorWithCalibratedRed: item -> color[0][0]
						green: item -> color[0][1]
						blue: item -> color[0][2]
						alpha: item -> color[0][3]
					] set];
					NSRectFillUsingOperation(r, NSCompositeSourceOver);
					[[NSColor colorWithCalibratedRed: item -> color[1][0]
						green: item -> color[1][1]
						blue: item -> color[1][2]
						alpha: item -> color[1][3]
					] set];
					path = [NSBezierPath bezierPath];
					[path setLineWidth: 1.5];
					[path appendBezierPathWithRect: r];
					[path stroke];
					break;

				case FSVO_Circle:
					if(s.x > e.x) { t = e.x; e.x = s.x; s.x = t; }
					if(s.y > e.y) { t = e.y; e.y = s.y; s.y = t; }
					r = NSMakeRect(s.x, s.y, e.x - s.x, e.y - s.y);
					path = [NSBezierPath bezierPath];
					[path setLineWidth: 1.5];
					[path appendBezierPathWithOvalInRect: r];
					[[NSColor colorWithCalibratedRed: item -> color[0][0]
						green: item -> color[0][1]
						blue: item -> color[0][2]
						alpha: item -> color[0][3]
					] set];
					[path fill];
					[[NSColor colorWithCalibratedRed: item -> color[1][0]
						green: item -> color[1][1]
						blue: item -> color[1][2]
						alpha: item -> color[1][3]
					] set];
					[path stroke];
					break;

				case FSVO_Arrow:
					point[0] = s; point[1] = e;
					[[NSColor colorWithCalibratedRed: item -> color[0][0]
						green: item -> color[0][1]
						blue: item -> color[0][2]
						alpha: item -> color[0][3]
					] set];
					path = [NSBezierPath bezierPath];
					[path setLineWidth: 1];
					[path appendBezierPathWithPoints: point count: 2];
					[path stroke];				
					break;

			
				default:
					Debug(@"-drawObjects in FSViewer did not recognize object type %i\n", item -> type);
					break;
			}
			if(item -> batch == 0) item -> visible = NO;  // batch 0 items only drawn once
		}
	}
}

- (void) lockAllAutocolor {
	[colorPicker lockAllAutocolor];
}

- (void) setUsesFakeZoom: (BOOL) z { useFakeZoom = z; }

- (void) zoomFrom: (double*) start to: (double*) end scalingFrom: (double) startSize to: (double) endSize {
	double t[2];
	NSPoint p, q;
	int height, width;
	int i, j, k, s;
	float x, y, dx, dy, tw, th, zoom;
	NSRect rect;
	NSImage* backgroundCopy;

	NSBezierPath* path;
	if(useFakeZoom == NO) return;

	p = [self locationOfPoint: start];
	q = [self locationOfPoint: end];
	t[0] = q.x - p.x;
	t[1] = q.y - p.y;
	zoom = startSize / endSize;
	t[0] *= zoom;
	t[1] *= zoom;

	backgroundCopy = [background copy];
	if(zoom > 1.0) {
		rect = NSMakeRect(
			q.x - [self bounds].size.width / (2.0 * zoom),
			q.y - [self bounds].size.height / (2.0 * zoom),
			[self bounds].size.width / zoom,
			[self bounds].size.height / zoom
		);
		synchronizeTo(drawing) {
			[background lockFocus];
			[backgroundCopy drawInRect: [self bounds] fromRect: rect operation: NSCompositeCopy fraction: 1.0];
			[background unlockFocus];
		}
	}
	else {
		{ // switch p to new coordinate system
			double X, Y;
			X = end[0] - ((double) [self bounds].size.width * endSize * view -> aspectRatio / 2.0);
			Y = end[1] - ((double) [self bounds].size.height * endSize / 2.0);
			p.x = (start[0] - X) / (endSize * view -> aspectRatio);
			p.y = (start[1] - Y) / endSize;
		}
		rect = NSMakeRect(
			p.x - [self bounds].size.width * zoom / 2.0,
			p.y - [self bounds].size.height * zoom / 2.0,
			[self bounds].size.width * zoom,
			[self bounds].size.height * zoom
		);
	
		synchronizeTo(drawing) {
			[background lockFocus];
			[[NSColor grayColor] set];
			NSRectFill([self bounds]);
			if((zoom != 1.0) || ((p.x != q.x) && (p.y != q.y)))
				[backgroundCopy drawInRect: rect fromRect: [self bounds] 
					operation: NSCompositeCopy fraction: 1.0];
			[[NSColor redColor] set];
//			NSRectFill(rect);
			[background unlockFocus];
		}
	}
	[backgroundCopy release];
	
	
	[self performSelectorOnMainThread: @selector(viewerNeedsDisplay) withObject: nil waitUntilDone: NO];
}



- (IBAction) startFullScreen: (id) sender {
	[fswindow toggleFullscreenWithView: self];
	[self viewDidEndLiveResize];
	
}

- (IBAction) endFullScreen: (id) sender {
}

- (void) drawTexture {
	NSRect backgroundRect;
	backgroundRect.origin.x = 0.0;
	backgroundRect.origin.y = 0.0;
	synchronizeTo(drawing) {
		backgroundRect.size = [background size];
/*
		[background lockFocus];
		[[NSColor greenColor] set];
		[NSBezierPath fillRect: backgroundRect];
		[background unlockFocus];
*/
//		[background drawInRect: [self bounds] fromRect: backgroundRect operation: NSCompositeCopy fraction: 1.0];
		//NSLog(@"best image rep for %@ is %@\n", background, [background bestRepresentationForDevice: nil]);
#ifndef WINDOWS
		[background drawInRect: [self bounds] fromRect: backgroundRect operation: NSCompositeCopy fraction: 1.0];
#else
		[[background bestRepresentationForDevice: nil] drawInRect: [self bounds]];
#endif
	}
}

- (void) drawInset {
	float scale = 0.15;
	NSBezierPath* path;
	NSPoint pointList[3];
	
	if(inset && showInset) {
		[[NSColor whiteColor] set];
		pointList[0].x = [self bounds].origin.x + [self bounds].size.width*scale;
		pointList[0].y = [self bounds].origin.y;
		pointList[1].x = [self bounds].origin.x + [self bounds].size.width*scale;
		pointList[1].y = [self bounds].origin.y + [self bounds].size.height*scale;
		pointList[2].x = [self bounds].origin.x;
		pointList[2].y = [self bounds].origin.y + [self bounds].size.height*scale;
		path = [NSBezierPath bezierPath];
		[path setLineWidth: 3];
		[path appendBezierPathWithPoints: pointList count: 3];
		[path stroke];				
		[inset drawInRect: NSMakeRect([self bounds].origin.x, [self bounds].origin.y, [self bounds].size.width*scale, [self bounds].size.height*scale)
				 fromRect: NSZeroRect operation: NSCompositeCopy fraction: 0.75];
		path = [NSBezierPath bezierPath];
		[path setLineWidth: 1.5];
		[path appendBezierPathWithOvalInRect: NSMakeRect(
			[self bounds].origin.x + scale*[self bounds].size.width*insetMarker[0] - 2,
		    [self bounds].origin.y + scale*[self bounds].size.height*insetMarker[1] - 2,
			4, 4
		)];
		[path fill];
		
	}
}
	
- (IBAction) toggleInset: (id) sender 
{
	synchronizeTo(drawing) { 
		showInset = ([insetButton state] == NSOnState)? YES : NO;
	}
	[self setNeedsDisplay: YES];
}
/* drawRect */
- (void) drawRect: (NSRect) rect
{
	int i, j;
	if(readyToDisplay == NO) {
		[[NSColor whiteColor] set];
		NSRectFill(rect);
		return;
	}
	[self drawTexture];
	[self drawObjects]; 
	[self drawInset];

	if([self inLiveResize] == YES) {
		/* draw a transparent rect over the whole view */		
	}
}

- (void*) theKernel { return view -> kernel; }

/* pass mouse events off to event manager */
- (void) mouseEntered: (NSEvent*) theEvent {
	if(view -> eventManager != nil) {
		[[self window] setAcceptsMouseMovedEvents: YES];
		[view -> eventManager mouseEntered: theEvent];
	}
}
- (void) mouseExited: (NSEvent*) theEvent {
	if(view -> eventManager != nil) {
		[[self window] setAcceptsMouseMovedEvents: NO];
		[view -> eventManager mouseExited: theEvent];
	}
}
- (void) mouseMoved: (NSEvent*) theEvent { if(view -> eventManager != nil) [view -> eventManager mouseMoved: theEvent]; }
- (void) mouseDragged: (NSEvent*) theEvent { if(view -> eventManager != nil) [view -> eventManager mouseDragged: theEvent]; }
- (void) mouseUp: (NSEvent*) theEvent { if(view -> eventManager != nil) [view -> eventManager mouseUp: theEvent]; }
- (void) mouseDown: (NSEvent*) theEvent { if(view -> eventManager != nil) [view -> eventManager mouseDown: theEvent]; }
- (void) rightMouseDown: (NSEvent*) theEvent { if(view -> eventManager != nil) [view -> eventManager rightMouseDown: theEvent]; }
- (void) scrollWheel: (NSEvent*) theEvent { if(view -> eventManager != nil) [view -> eventManager scrollWheel: theEvent]; }
- (BOOL) acceptsFirstResponder { return YES; }

/* end of mouse events */

/* coordinate conversion methods */
- (void) convertEvent: (NSEvent*) theEvent toPoint: (double*) point {
	[self convertLocation: [theEvent locationInWindow] toPoint: point];
}

- (void) convertLocation: (NSPoint) theLocation toPoint: (double*) point {
	double X, Y; // real and imaginary coordinates of upper-left corner
	theLocation = [self convertPoint: theLocation fromView: nil];
	X = view -> center[0] - ((double) [self bounds].size.width * view -> pixelSize * view -> aspectRatio / 2.0);
	Y = view -> center[1] - ((double) [self bounds].size.height * view -> pixelSize / 2.0);
	point[0] = X + view -> pixelSize * view -> aspectRatio * theLocation.x;
	point[1] = Y + view -> pixelSize * theLocation.y;
}

- (NSPoint) locationOfPoint: (double*) point {
	NSPoint loc;
	double X, Y;
	X = view -> center[0] - ((double) [self bounds].size.width * view -> pixelSize * view -> aspectRatio / 2.0);
	Y = view -> center[1] - ((double) [self bounds].size.height * view -> pixelSize / 2.0);
	loc.x = (point[0] - X) / (view -> pixelSize * view -> aspectRatio);
	loc.y = (point[1] - Y) / view -> pixelSize;
	return loc;
}

- (void) convertPoint: (double*) point toGL: (double*) gl {
	NSLog(@"********* DO NOT USE FSViewer's convertPoint: toGL: method!\n");
	gl[0] = point[0] - view -> center[0];
	gl[1] = point[1] - view -> center[1];
	gl[0] /= ((double) [self bounds].size.width * view -> pixelSize * view -> aspectRatio / 2.0);
	gl[1] /= ((double) [self bounds].size.height * view -> pixelSize / 2.0);
}

/* end coordinate conversions */

- (IBAction) tTest: (id) sender { [tView setImage: [self snapshot]]; }

@end
