//
//  FSViewer.m
//  FractalStream
//
//  Created by Matt Noonan on 11/24/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "FSViewer.h"

//#define DEBUGGING

#ifndef DEBUGGING
	void inline Debug(NSString* s, ...) { }
#else
	#define Debug NSLog
#endif

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
	int i, j;
	
	
	Debug(@"FSViewer %@ is awaking from nib\n", self);
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
	workQueue = [[NSOperationQueue alloc] init];
	[workQueue setMaxConcurrentOperationCount: NSOperationQueueDefaultMaxConcurrentOperationCount];
	drawing = [[NSString stringWithString: @"drawing"] retain];
	[viewerColorizer setColorWidget: colorPicker autocolorCache: acCache];

	renderingFinishedObject = nil;
	currentBatch = 1;
	displayList = [[NSMutableArray alloc] init];
	useFakeZoom = YES;
	
//	[[self window] makeFirstResponder: self];
	[[self window] setAcceptsMouseMovedEvents: YES];
	
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
	[self allocateGState];
	[[self window] useOptimizedDrawing: YES];
}

- (BOOL) isAwake { return awake; }

- (void) setViewerData: (FSViewerData*) newData {
	Debug(@"somebody set the viewer data with pixelSize %f\n", newData -> pixelSize);
	readyToRender = YES;
	nodeChanged = YES;
	
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

	configured = YES; view = &fakeview; fakeview = *newData; 
	[self render: self];
}
- getViewerDataTo: (FSViewerData*) savedData { memmove(savedData, view, sizeof(FSViewerData)); }

- (FSViewerData) data { return fakeview; }
- (FSColorWidget*) colorPicker { return colorPicker; }
- setColorPicker: (FSColorWidget*) newColorPicker { colorPicker = newColorPicker; }

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
	
	if(readyToRender == NO) { 
		Debug(@"not ready to render\n");
		return;
	}

	[workQueue cancelAllOperations];
	
	highDetail = (view -> detailLevel > 1.0)? YES : NO;
	
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
	
	/* Set up the autocolor cache */
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
	
	/* Subdivide the viewport into 128x128 regions (or smaller), give each one its own unit */
	xBoxes = (((int) [self bounds].size.width) >> 7);
	yBoxes = (((int) [self bounds].size.height) >> 7);
	xRemainder = ((int) [self bounds].size.width) - (xBoxes << 7);
	yRemainder = ((int) [self bounds].size.height) - (yBoxes << 7);
	if(xRemainder) ++xBoxes;
	if(yRemainder) ++yBoxes;
	dx = 128.0 * view -> pixelSize * view -> aspectRatio;
	dy = 128.0 * view -> pixelSize;
	
	if(highDetail) { renderQueueEntries = 3 * xBoxes * yBoxes; }
	else { renderQueueEntries = 2 * xBoxes * yBoxes; }
	for(i = 0; i < 3; i++) {
		if(i == 0) linearMultiplier = 0.5;
		else if(i == 1) linearMultiplier = 1.0;
		else if(i == 2) linearMultiplier = 2.0;
		if((highDetail == NO) && (i > 1)) break;
		unit.offset[1] = 0.0;
		for(y = 0; y < yBoxes; y++) {
			unit.offset[0] = 0.0;
			for(x = 0; x < xBoxes; x++) {
				unit.dimension[0] = ((x == xBoxes - 1) && xRemainder)? xRemainder : 128;	/* note: this ignores detailLevel */
				unit.dimension[1] = ((y == yBoxes - 1) && yRemainder)? yRemainder : 128;
				unit.dimension[0] = (int)((double) unit.dimension[0] * linearMultiplier + 0.5);
				unit.dimension[1] = (int)((double) unit.dimension[1] * linearMultiplier + 0.5);
				unit.step[0] = view -> pixelSize * view -> aspectRatio / linearMultiplier;
				unit.step[1] = -view -> pixelSize / linearMultiplier;
				unit.multiplier = i - 1;
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
}

- (void) renderOperationFinished: (id) op {
	unsigned char* planes[1];
	NSSize size;
	NSPoint p;
	NSRect r;
	NSBitmapImageRep* bitmap;
	
	size.width = [op unit] -> dimension[0];
	size.height = [op unit] -> dimension[1];
	planes[0] = (unsigned char*)([op unit] -> result);
	bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: planes
		pixelsWide: size.width pixelsHigh: size.height bitsPerSample: 8
		samplesPerPixel: 3 hasAlpha: NO isPlanar: NO
		colorSpaceName: NSDeviceRGBColorSpace
/*		bitmapFormat: NSFloatingPointSamplesBitmapFormat*/
		bytesPerRow: (size.width * 4)
		bitsPerPixel: 32
	];
	@synchronized(drawing) {
		finalX = (int)([op unit] -> dimension[0] + 0.5);
		finalY = (int)([op unit] -> dimension[1] + 0.5);
		p.x = [op unit] -> location[0];
		p.y = [op unit] -> location[1];
		if([op unit] -> multiplier == -1) r = NSMakeRect(p.x, p.y, finalX * 2, finalY * 2);
		else if([op unit] -> multiplier == 1) r = NSMakeRect(p.x, p.y, finalX / 2, finalY / 2);
		else r = NSMakeRect(p.x, p.y, finalX, finalY);
		[background lockFocus];
		[bitmap drawInRect: r];
		[background unlockFocus];
		[bitmap release];
		readyToDisplay = YES;
	}
	@synchronized(workQueue) {
		--renderQueueEntries;
		if(renderQueueEntries == 0) {
			if(renderingFinishedObject != nil)
				[renderingFinishedObject performSelector: renderingFinished];
		}
	}
	[self setNeedsDisplay: YES];
}


- setRenderCompletedMessage: (SEL) message forObject: (id) obj { renderingFinished = message; renderingFinishedObject = obj; }

- setDefaultsTo: (double*) def count: (int) n {
	int i;
	Debug(@"setDefaultsTo got count %i\n", n);
	defaults = n;
	if(n) for(i = 0; i < n; i++) { setting[i + 6] = def[i]; Debug(@"viewer set default %i to %f\n", i, def[i]); }
}

- (void) viewDidEndLiveResize {
	[super viewDidEndLiveResize];
	Debug(@"viewDidEndLiveResize\n");
	[background release];
	background = [[NSImage alloc] initWithSize: [self bounds].size];	
	[self render: self];
}

/* Routines for drawing various objects into the view */

- (int) getBatchNumber { 
	int r;
	@synchronized(displayList) { r = currentBatch; ++currentBatch; }
	return r;
}

- (void) deleteObjectsInBatch: (int) batch {
	NSEnumerator* objEnum;
	FSViewerObject* theObj;
	NSArray* oldDisplayList;
	@synchronized(displayList) {
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
	
	@synchronized(displayList) {
		objEnum = [displayList objectEnumerator];
		while(theObj = [objEnum nextObject]) if([theObj batch] == batch) [theObj itemPtr] -> batch = newBatch;
	}
}

- (void) makeBatch: (int) batch visible: (BOOL) vis {
	NSEnumerator* objEnum;
	FSViewerObject* theObj;
	
	@synchronized(displayList) {
		objEnum = [displayList objectEnumerator];
		while(theObj = [objEnum nextObject]) if([theObj batch] == batch) [theObj itemPtr] -> visible = vis;
	}
}

- (void) drawObject: (FSViewerObject*) newObject {
	@synchronized(displayList) {
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
	return [background copy];
	
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
	[self setNeedsDisplay: YES];
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
	
	@synchronized(displayList) {
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
					] setFill];
					[[NSColor colorWithCalibratedRed: item -> color[1][0]
						green: item -> color[1][1]
						blue: item -> color[1][2]
						alpha: item -> color[1][3]
					] setStroke];
					NSRectFillUsingOperation(r, NSCompositeSourceOver);
					path = [NSBezierPath bezierPath];
					[path setLineWidth: 0.5];
					[path appendBezierPathWithOvalInRect: r];
					[path fill];
					[path stroke];
					break;

				case FSVO_Line:
					point[0] = s; point[1] = e;
					[[NSColor colorWithCalibratedRed: item -> color[0][0]
						green: item -> color[0][1]
						blue: item -> color[0][2]
						alpha: item -> color[0][3]
					] setStroke];
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
					] setFill];
					[[NSColor colorWithCalibratedRed: item -> color[1][0]
						green: item -> color[1][1]
						blue: item -> color[1][2]
						alpha: item -> color[1][3]
					] setStroke];
					NSRectFillUsingOperation(r, NSCompositeSourceOver);
					path = [NSBezierPath bezierPath];
					[path setLineWidth: 1.5];
					[path appendBezierPathWithRect: r];
					[path stroke];
					break;

				case FSVO_Circle:
					if(s.x > e.x) { t = e.x; e.x = s.x; s.x = t; }
					if(s.y > e.y) { t = e.y; e.y = s.y; s.y = t; }
					r = NSMakeRect(s.x, s.y, e.x - s.x, e.y - s.y);
					[[NSColor colorWithCalibratedRed: item -> color[0][0]
						green: item -> color[0][1]
						blue: item -> color[0][2]
						alpha: item -> color[0][3]
					] setFill];
					[[NSColor colorWithCalibratedRed: item -> color[1][0]
						green: item -> color[1][1]
						blue: item -> color[1][2]
						alpha: item -> color[1][3]
					] setStroke];
					path = [NSBezierPath bezierPath];
					[path setLineWidth: 1.5];
					[path appendBezierPathWithOvalInRect: r];
					[path fill];
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

- (void) setUsesFakeZoom: (BOOL) z { useFakeZoom = z; }

- zoomFrom: (double*) start to: (double*) end scalingFrom: (double) startSize to: (double) endSize {
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

	Debug(@"[self bounds].origin = (%f, %f), [self bounds].size = (%f, %f)\n",
		(double) [self bounds].origin.x,
		(double) [self bounds].origin.y,
		(double) [self bounds].size.width,
		(double) [self bounds].size.height
	);
	Debug(@"p = (%f, %f), q = (%f, %f)\n", (double) p.x, (double) p.y, (double) q.x, (double) q.y);
	Debug(@"pixelSize is %f, aspectRatio is %f\n", view -> pixelSize, view -> aspectRatio);

	backgroundCopy = [background copy];
	if(zoom > 1.0) {
		rect = NSMakeRect(
			q.x - [self bounds].size.width / (2.0 * zoom),
			q.y - [self bounds].size.height / (2.0 * zoom),
			[self bounds].size.width / zoom,
			[self bounds].size.height / zoom
		);
		@synchronized(drawing) {
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
	
		@synchronized(drawing) {
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
	
	
	[self setNeedsDisplay: YES];
}


- (void) drawTexture {
	NSRect backgroundRect;
	backgroundRect.origin.x = 0.0;
	backgroundRect.origin.y = 0.0;
	@synchronized(drawing) {
		backgroundRect.size = [background size];
		[background drawInRect: [self bounds] fromRect: backgroundRect operation: NSCompositeCopy fraction: 1.0];
	}
}

/* drawRect */
- (void) drawRect: (NSRect) rect
{
	if(readyToDisplay == NO) {
		[[NSColor grayColor] set];
		NSRectFill(rect);
		return;
	}

	[self drawTexture];
	[self drawObjects];
	
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

@end
