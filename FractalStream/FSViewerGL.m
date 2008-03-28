//
//  FSViewer.m
//  FractalStream
//
//  Created by Matt Noonan on 11/24/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "FSViewer.h"

#define NSLog //
#undef NSLog

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
	configured = NO;
	readyToRender = NO;
	readyToDisplay = NO;
	threadCount = 0;
/*
*/
	renderLock = [[NSLock alloc] init];
	NSLog(@"renderLock: %@\n", renderLock);

	for(i = 0; i < 4; i++) {
		subtextureSize[i] = 0;
		subtexture[i] = NULL;
		subtextureLock[i] = [[NSLock alloc] init];
		NSLog(@"subtextureLock[%i]: %@\n", i, subtextureLock[i]);
		changed[i] = YES;
	}


	return self;
}

- (void) awakeFromNib {
	int i, j;
	
	[renderLock lock]; // lock the rendering engine.  unlocking will then cause the engine to render a new frame.
	currentBatch = 0;
	displayList = [[NSMutableArray alloc] init];
	
	[[self window] makeFirstResponder: self];
	[[self window] setAcceptsMouseMovedEvents: YES];
	
	[progress setDisplayedWhenStopped: NO];
	//[progress setUsesThreadedAnimation: YES];
	
	coordinateTracker = [self 
		addTrackingRect: [self bounds] 
		owner: self
		userData: NULL
		assumeInside: YES
	];
	[[self window] setInitialFirstResponder: self];
	[[self window] makeKeyAndOrderFront: self];
	[[self window] setTitle: @"FractalStream Test, January 2008"];
	
	
	glConfigured = NO;
	glLock = [[NSLock alloc] init];
	finishedLock = [[NSLock alloc] init];
	NSLog(@"glLock: %@\n", glLock);
	NSLog(@"finishedLock: %@\n", finishedLock);
#define NSLog //
	[NSThread detachNewThreadSelector: @selector(renderEngine:) toTarget: self withObject: self];
	for(i = 0; i < 4; i++) {
		[NSThread detachNewThreadSelector: @selector(renderQuarter:) toTarget: self withObject: self];
	}
	
	displayLocked = NO;	
	awake = YES;
}

- (BOOL) isAwake { return awake; }

- (void) setViewerData: (FSViewerData*) newData {
	NSLog(@"somebody set the viewer data\n");
	configured = YES; view = &fakeview; fakeview = *newData; 
	nodeChanged = YES;
	[[self window] setAcceptsMouseMovedEvents: YES];	
	[self render: self];
}

- (FSViewerData) data { return fakeview; }

- (IBAction) render: (id) sender {
	int i; float detailLevel; 
	if(glConfigured == NO) {
		[[self openGLContext] makeCurrentContext];
		glEnable(GL_TEXTURE_2D);
		texture = NULL;
		textureSize = 0;
		textureReadyLock = [[NSLock alloc] init];
		textureReady = NO;	
		glGenTextures(1, &textureHandle);
		glConfigured = YES;
		NSLog(@"readyToDisplay says %@\n", (readyToDisplay == YES)? @"yes" : @"no");
	}

	if(readyToRender == NO) { NSLog(@"not ready to render\n"); return; }
	NSLog(@"render: dropping\n");
	[finishedLock lock];
	[finishedLock unlock];
	[renderLock unlock];
	while(rendering == NO) ;				/***** change this! wait for some condition, then pick up lock *****/
//	NSLog(@"render: waiting\n");
//	[renderLock lock];
//	NSLog(@"render: holding lock\n");
//	[self setNeedsDisplay: YES];
}

- (IBAction) renderEngine: (id) sender {
	int i, j, k;
	int height, width, xMax, yMax, blockSize, size;
	double detailLevel;
	int loop;
	
	readyToRender = YES;
	for(i = 0; i < 4; i++) [subtextureLock[i] lock];
	while(1) {
		NSLog(@"engine: waiting\n");
		[renderLock lock]; // try to aquire the render lock.  can only do this if the browser releases this lock to request a new frame
//		[progress startAnimation: self];
		nodeChanged = NO;
		detailLevel = view -> detailLevel / 4.0;
		for(loop = 0; loop < 3; loop++) { if(nodeChanged == YES) break; view -> detailLevel = detailLevel; detailLevel *= 2.0; 
		[finishedLock lock];
		NSLog(@"engine: holding lock, configured = %@\n", (configured == YES)? @"yes" : @"no");
		rendering = YES;
		height = [self bounds].size.height;
		width = [self bounds].size.width;
		xMax = (int)(width * view -> detailLevel + 0.5);
		yMax = (int)(height * view -> detailLevel + 0.5);
		size = xMax * yMax * sizeof(float) * 3;
		if(size > textureSize) {
			free(texture);
			textureSize = size;
			texture = (float*) malloc(size);
			NSLog(@"allocating %i bytes for texture at %x\n", size, texture);
			if(texture == NULL) NSLog(@"failed!\n");
		}

		activeSubtasks = 0;
		for(i = 0; i < 4; i++) { // start the four subtasks which do the actual rendering
			[subtextureLock[i] unlock];
		}
		/* rendering happens here */
		while(activeSubtasks < 4) ; // make sure everybody has grabbed their lock before going on
		for(i = 0; i < 4; i++) { // reaquire the four subtask locks
			[subtextureLock[i] lock];
		}
		/* rendering subtasks are finished, reassemble the results. */
		if(nodeChanged == YES) {
			// scrap our work and start over
			rendering = NO;
			readyToDisplay = NO;
			[finishedLock unlock];
			while(activeSubtasks > 0) ;
			continue;
		}
		[glLock lock];
			finalX = xMax; finalY = yMax;
			NSLog(@"rendering engine creating OpenGL texture of size (%f, %f)\n", finalX, finalY);
			[[self openGLContext] makeCurrentContext];
			glEnable(GL_TEXTURE_RECTANGLE_EXT);
			glBindTexture(GL_TEXTURE_RECTANGLE_EXT, textureHandle);
			glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
//			glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_DECAL);
			glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, 3, xMax, yMax, 0, GL_RGB, GL_FLOAT, texture);
		[glLock unlock];
		NSLog(@"texture created.\n");
		rendering = NO;
		readyToDisplay = YES;
		[self setNeedsDisplay: YES];
		NSLog(@"engine: dropping\n");
		[finishedLock unlock];
		while(activeSubtasks > 0) ;
		}
//		[progress stopAnimation: self];
	}
}

- (IBAction) renderQuarter: (id) sender
{
	int size;
	int thisThread;
	int x, y, height, width, xMax, yMax, k, phase, flag;
	float c;
	double step, X, Y, oX, oY;
	float r, g, b;
	double in[8], *out;
	int startLine, endLine;
	BOOL firstLoop;
	float colorArray[16*8*8*3];
	
	thisThread = threadCount++;
	
	firstLoop = YES;
	
	while(1) { [subtextureLock[thisThread] lock];  // wait for permission to start
		if(view -> kernel == NULL) { NSLog(@"thread %i is not ready\n", thisThread); [subtextureLock[thisThread] unlock]; continue; }
		NSLog(@"thread %i is active, activeSubtasks = %i, texture = %x\n", thisThread, activeSubtasks + 1, texture);
		++activeSubtasks;
		[colorPicker colorArrayValue: colorArray];
	
		
		height = [self bounds].size.height;
		width = [self bounds].size.width;
		xMax = (int)(width * view -> detailLevel + 0.5);
		yMax = (int)(height * view -> detailLevel + 0.5);
	
		startLine = (yMax / 4) * thisThread;
		endLine = (thisThread + 1) * (yMax / 4);
	
		X = view -> center[0] - ((double) width * view -> pixelSize * view -> aspectRatio / 2.0);
		Y = view -> center[1] + ((double) height * view -> pixelSize / 2.0);
		Y -= (float) thisThread * view -> pixelSize * (float) yMax / (4.0 * view -> detailLevel);
		step = view -> pixelSize / view -> detailLevel;
	
		out = (double*) malloc(3 * xMax * sizeof(double));
		size = xMax * yMax * 3 * sizeof(float) / 4;
		if(size > subtextureSize[thisThread]) {  /* decide if this is really the behavior you want... */
//			free(subtexture[thisThread]);
//			subtexture[thisThread] = (float*) malloc(size);
			subtextureSize[thisThread] = size;
//			if(subtexture[thisThread] == NULL) { NSLog(@"****** subtexture malloc failed!!! *******\n"); while(1); }		
		}
	
		in[5] = view -> data[0]; in[6] = view -> data[1]; in[7] = view -> data[2];
		
		for(y = startLine; y < endLine; y++) {
			in[0] = X; in[1] = Y; in[2] = step * view -> aspectRatio; in[3] = view -> par[0]; in[4] = view -> par[1];
			(view -> kernel)(view -> program, in, xMax, out, view -> maxIters, view -> maxRadius, view -> minRadius);
			for(x = 0; x < xMax; x++) {
				oX = out[(3*x) + 0];
				oY = out[(3*x) + 1];
				k = out[(3*x) + 2];
				flag = k & 0xff;  flag &= 0x0f;
				k >>= 8;
				if(k == -1) { r = g = b = 1.0; }
				else if(k == view -> maxIters) { 
					r = g = b = 0.0;
				}
				else {
					phase = 0;
					if((oX > 0.0) && (oY > 0.0)) phase = 0;
					if((oX < 0.0) && (oY > 0.0)) phase = 2;
					if((oX < 0.0) && (oY < 0.0)) phase = 4;
					if((oX > 0.0) && (oY < 0.0)) phase = 6;
					if(((phase & 2)) && ((oY * oY) < (oX * oX))) phase += 1;
					else if(((phase & 2) == 0) && ((oX * oX) < (oY * oY))) phase += 1; 
					r = colorArray[(8*8*3)*flag + (phase*8*3) + (((k >> 1) & 0x7) * 3) + 0];
					g = colorArray[(8*8*3)*flag + (phase*8*3) + (((k >> 1) & 0x7) * 3) + 1];
					b = colorArray[(8*8*3)*flag + (phase*8*3) + (((k >> 1) & 0x7) * 3) + 2];
					if(k & 1) {
						r += colorArray[(8*8*3)*flag + (phase*8*3) + ((((k+1) >> 1) & 0x7) * 3) + 0];
						g += colorArray[(8*8*3)*flag + (phase*8*3) + ((((k+1) >> 1) & 0x7) * 3) + 1];
						b += colorArray[(8*8*3)*flag + (phase*8*3) + ((((k+1) >> 1) & 0x7) * 3) + 2];
						r /= 2.0; g /= 2.0; b /= 2.0;
					}
					c = (k & 0xf) / 15.0; 
					if(k & 0x10) c = 1.0 - c;
				}
				if(nodeChanged == YES) break;
				if((3 * x) + (y * 3 * xMax) + 2 < textureSize) {
					texture[(3 * x) + (y * 3 * xMax) + 0] = r;
					texture[(3 * x) + (y * 3 * xMax) + 1] = g;
					texture[(3 * x) + (y * 3 * xMax) + 2] = b;
				}
				else NSLog(@"thread %i tried to overrun the texture: textureSize is %i, tried %i\n", thisThread, textureSize, (3 * x) + (y * 3 * xMax));
			}
			Y -= step;
			if(nodeChanged == YES) break;
		}

/*
		NSLog(@"%i is aquiring glLock...\n", thisThread);
		[glLock lock];
		NSLog(@"%i got it!\n", thisThread);
		[[self openGLContext] makeCurrentContext];
		NSLog(@"A\n");
		glEnable(GL_TEXTURE_2D);
		NSLog(@"B\n");
		glBindTexture(GL_TEXTURE_2D, subtextureHandle[thisThread]);
		NSLog(@"C\n");
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		NSLog(@"D\n");
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		NSLog(@"E\n");
//		glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_DECAL);
		NSLog(@"F\n");
//		glTexImage2D(GL_TEXTURE_2D, 0, 3, xMax, yMax, 0, GL_RGB, GL_FLOAT, subtexture[thisThread]);
	gluBuild2DMipmaps(GL_TEXTURE_2D, 3, xMax, yMax, GL_RGB, GL_FLOAT, subtexture[thisThread]);
		NSLog(@"G\n");
		[glLock unlock];
		NSLog(@"H\n");
*/	
	
		free(out);
		firstLoop = NO;

	[subtextureLock[thisThread] unlock];
	NSLog(@"thread %i: waiting for finishedLock\n", thisThread);
	[finishedLock lock]; 
	NSLog(@"thread %i: holding the finishedLock\n", thisThread);
	[finishedLock unlock];
	NSLog(@"thread %i: dropping the finishedLock\n", thisThread);
	--activeSubtasks;
	 }
}

- (void) viewDidEndLiveResize {
	[super viewDidEndLiveResize];
	NSLog(@"viewDidEndLiveResize\n");
	[self render: self];
}

/* Routines for drawing various objects into the view */

- (int) getBatchNumber { return currentBatch++; }

- (void) deleteObjectsInBatch: (int) batch {
	NSEnumerator* objEnum;
	FSViewerObject* theObj;
	
	objEnum = [displayList objectEnumerator];
	while(theObj = [objEnum nextObject]) if([theObj batch] == batch) [displayList removeObject: theObj];
}

- (void) makeBatch: (int) batch visible: (BOOL) vis {
	NSEnumerator* objEnum;
	FSViewerObject* theObj;
	
	objEnum = [displayList objectEnumerator];
	while(theObj = [objEnum nextObject]) if([theObj batch] == batch) [theObj itemPtr] -> visible = vis;
}

- (void) drawObject: (FSViewerObject*) newObject {
	[displayList addObject: newObject];
} 

- (void) drawItem: (FSViewerItem) newItem {
	FSViewerObject* newObject;
	newObject = [[FSViewerObject alloc] init];
	[newObject setItem: newItem];
	[self drawObject: newObject];
}

- (NSImage*) snapshot {
	NSBitmapImageRep* bitmap;
	NSColor* c;
	int i, j, k;
	float r, g, b;
	int xMax, yMax;
	int width, height;
	NSRect bounds;
	
	bounds = [self bounds];
	width = [self bounds].size.width;
	height = [self bounds].size.height;
	xMax = (int)(width * view -> detailLevel + 0.5);
	yMax = (int)(height * view -> detailLevel + 0.5);
	bitmap = [self bitmapImageRepForCachingDisplayInRect: [self bounds]];
	k = 0;
	for(j = 0; j < yMax; j++) for(i = 0; i < xMax; i++) {
		c = [NSColor colorWithDeviceRed: texture[k] green: texture[k+1] blue: texture[k+2] alpha: 1.0];
		[bitmap setColor: c atX: i y: j];
		k += 3;
	}
	[[bitmap TIFFRepresentation] writeToFile: @"/Users/noonan/Desktop/snap.tiff" atomically: YES];
	return nil;
}

- (void) drawDotAt: (NSPoint) P withColor: (float*) rgb 
{
	float sx, sy, ex, ey;
	NSPoint p;
	
	[glLock lock];
	[[self openGLContext] makeCurrentContext];
	
	p = [self convertPoint: P fromView: nil];
	sx = (2.0 * p.x  / [self bounds].size.width) - 1.0;
	sy = (2.0 * p.y / [self bounds].size.height) - 1.0;
	ex = sx + 0.01;
	ey = sy + 0.01;
	sx -= 0.01; sy -= 0.01;
	
	glViewport(0, 0, [self bounds].size.width, [self bounds].size.height);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(-1.0, 1.0, -1.0, 1.0, 0.0, 1.0);
	glMatrixMode(GL_MODELVIEW);
	
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);

	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	[self drawTexture];

	glBegin(GL_QUADS);
		glColor4f(rgb[0], rgb[1], rgb[2], 0.8);
		glVertex3f(sx, ey, -1.0);
		glVertex3f(sx, sy, -1.0);
		glVertex3f(ex, sy, -1.0);
		glVertex3f(ex, ey, -1.0);
	glEnd();

	glFlush();
	
	[glLock unlock];
}

- (void) drawBoxFrom: (NSPoint) start to: (NSPoint) end withColor: (float*) rgb
{
	double sx, sy, ex, ey;
	NSPoint p;
	
	/* convert to internal coordinates */

	p = [self convertPoint: start fromView: nil];
	sx = (2.0 * p.x  / [self bounds].size.width) - 1.0;
	sy = (2.0 * p.y / [self bounds].size.height) - 1.0;
	p = [self convertPoint: end fromView: nil];
	ex = (2.0 * p.x  / [self bounds].size.width) - 1.0;
	ey = (2.0 * p.y / [self bounds].size.height) - 1.0;
	
	[glLock lock];
	[[self openGLContext] makeCurrentContext];
	
	glViewport(0, 0, [self bounds].size.width, [self bounds].size.height);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(-1.0, 1.0, -1.0, 1.0, 0.0, 1.0);
	glMatrixMode(GL_MODELVIEW);
	
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);

	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	[self drawTexture];

	glBegin(GL_QUADS);
		glColor4f(rgb[0], rgb[1], rgb[2], 0.5);
		glVertex3f(sx, ey, -1.0);
		glVertex3f(sx, sy, -1.0);
		glVertex3f(ex, sy, -1.0);
		glVertex3f(ex, ey, -1.0);
	glEnd();

	glBegin(GL_LINES);
		glColor4f(1.0, 1.0, 1.0, 0.8);
		glVertex3f(sx, sy, -1.0);
		glVertex3f(sx, ey, -1.0);
	glEnd();
	glBegin(GL_LINES);
		glColor4f(1.0, 1.0, 1.0, 0.8);
		glVertex3f(sx, ey, -1.0);
		glVertex3f(ex, ey, -1.0);
	glEnd();
	glBegin(GL_LINES);
		glColor4f(1.0, 1.0, 1.0, 0.8);
		glVertex3f(ex, ey, -1.0);
		glVertex3f(ex, sy, -1.0);
	glEnd();
	glBegin(GL_LINES);
		glColor4f(1.0, 1.0, 1.0, 0.8);
		glVertex3f(ex, sy, -1.0);
		glVertex3f(sx, sy, -1.0);
	glEnd();
	
	glFlush();
	[glLock unlock];
}

-(void) draw: (int) nTraces tracesFrom: (NSPoint*) traceList steps: (int) nSteps {
	double p[2];
	double in[9], out[3], x, y;
	double sx, sy, ex, ey;
	int i, j, k;
	NSPoint P;
	float wheel[9][3];
	
	wheel[0][0] = 1.0;
	wheel[0][1] = 0.0;
	wheel[0][2] = 0.0;

	wheel[1][0] = 0.0;
	wheel[1][1] = 1.0;
	wheel[1][2] = 0.0;

	wheel[2][0] = 0.0;
	wheel[2][1] = 0.0;
	wheel[2][2] = 1.0;

	wheel[3][0] = 1.0;
	wheel[3][1] = 1.0;
	wheel[3][2] = 0.0;

	wheel[4][0] = 0.0;
	wheel[4][1] = 1.0;
	wheel[4][2] = 1.0;

	wheel[5][0] = 1.0;
	wheel[5][1] = 0.0;
	wheel[5][2] = 1.0;

	wheel[6][0] = 1.0;
	wheel[6][1] = 0.5;
	wheel[6][2] = 0.0;

	wheel[7][0] = 1.0;
	wheel[7][1] = 1.0;
	wheel[7][2] = 1.0;

	wheel[8][0] = 0.2;
	wheel[8][1] = 0.2;
	wheel[8][2] = 0.2;
	
	
	[glLock lock];
	[[self openGLContext] makeCurrentContext];
	glViewport(0, 0, [self bounds].size.width, [self bounds].size.height);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(-1.0, 1.0, -1.0, 1.0, 0.0, 1.0);
	glMatrixMode(GL_MODELVIEW);
	
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);

	[self drawTexture];
	
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	k = view -> program;
	
	in[5] = view -> data[0]; in[6] = view -> data[1]; in[7] = view -> data[2]; 
	
	for(j = 0; j < nTraces; j++) {
		[self convertLocation: traceList[j] toPoint: p];
		in[0] = p[0];
		in[1] = p[1];
		in[2] = 0.0;
		in[3] = view -> par[0]; in[4] = view -> par[1];
	for(i = 0; i < nSteps; i++) {
		(view -> kernel)(k, in, 1, out, 1, view -> maxRadius, view -> minRadius);
		if(out[2] == -1) break;
		if((out[0] * out[0] + out[1] * out[1]) > (view -> maxRadius * view -> maxRadius)) break;
		p[0] = in[0]; p[1] = in[1];
		P = [self locationOfPoint: p];
//		P = [[self window] convertPoint: P fromView: self];
		sx = (2.0 * P.x  / [self bounds].size.width) - 1.0;
		sy = (2.0 * P.y / [self bounds].size.height) - 1.0;
		if([boxButton state] != NSOnState) {
		glBegin(GL_POINTS);
			glColor4f(wheel[j][0], wheel[j][1], wheel[j][2], 1.0);
			glVertex3f(sx, sy, -1.0);
		glEnd();
		}
		else {
		sx -= 0.008 * (double) [self bounds].size.height / (double) [self bounds].size.width; sy -= 0.008;
		ex = sx + 0.008 * (double) [self bounds].size.height / (double) [self bounds].size.width;
		ey = sy + 0.008;
		glBegin(GL_QUADS);
			glColor4f(wheel[j][0], wheel[j][1], wheel[j][2], 0.6);
			glVertex3f(sx, ey, -1.0);
			glVertex3f(sx, sy, -1.0);
			glVertex3f(ex, sy, -1.0);
			glVertex3f(ex, ey, -1.0);
		glEnd();
	glBegin(GL_LINES);
		glColor4f(wheel[j][0], wheel[j][1], wheel[j][2], 0.8);
		glVertex3f(sx, sy, -1.0);
		glVertex3f(sx, ey, -1.0);
	glEnd();
	glBegin(GL_LINES);
		glColor4f(wheel[j][0], wheel[j][1], wheel[j][2], 0.8);
		glVertex3f(sx, ey, -1.0);
		glVertex3f(ex, ey, -1.0);
	glEnd();
	glBegin(GL_LINES);
		glColor4f(wheel[j][0], wheel[j][1], wheel[j][2], 0.8);
		glVertex3f(ex, ey, -1.0);
		glVertex3f(ex, sy, -1.0);
	glEnd();
	glBegin(GL_LINES);
		glColor4f(wheel[j][0], wheel[j][1], wheel[j][2], 0.8);
		glVertex3f(ex, sy, -1.0);
		glVertex3f(sx, sy, -1.0);
	glEnd();
	}
	
		in[0] = out[0]; in[1] = out[1];
	}
	}
	glDisable(GL_BLEND);
	
	glFlush();
	[glLock unlock];
	
}
	


- (void) traceFrom: (NSPoint) thePoint withColor: (float*) rgb {
	double p[2];
	double in[9], out[3], x, y;
	double sx, sy, ex, ey;
	int i, k;
	NSPoint P;
	
	[self convertLocation: thePoint toPoint: p];

	in[0] = p[0];
	in[1] = p[1];
	in[2] = 0.0;
	in[3] = view -> par[0]; in[4] = view -> par[1];
	
	[glLock lock];
	[[self openGLContext] makeCurrentContext];
	glViewport(0, 0, [self bounds].size.width, [self bounds].size.height);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(-1.0, 1.0, -1.0, 1.0, 0.0, 1.0);
	glMatrixMode(GL_MODELVIEW);
	
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);

	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	[self drawTexture];
	
	k = view -> program;
	
	in[5] = view -> data[0]; in[6] = view -> data[1]; in[7] = view -> data[2]; 
	
	for(i = 0; i < 100; i++) {
		(view -> kernel)(k, in, 1, out, 1, view -> maxRadius, view -> minRadius);
		if(out[2] == -1) break;
		if((out[0] * out[0] + out[1] * out[1]) > (view -> maxRadius * view -> maxRadius)) break;
		p[0] = in[0]; p[1] = in[1];
		P = [self locationOfPoint: p];
//		P = [[self window] convertPoint: P fromView: self];
		sx = (2.0 * P.x  / [self bounds].size.width) - 1.0;
		sy = (2.0 * P.y / [self bounds].size.height) - 1.0;
		ex = sx + 0.01;
		ey = sy + 0.01;
		sx -= 0.01; sy -= 0.01;

		glBegin(GL_QUADS);
			glColor4f(rgb[0], rgb[1], rgb[2], 0.6);
			glVertex3f(sx, ey, -1.0);
			glVertex3f(sx, sy, -1.0);
			glVertex3f(ex, sy, -1.0);
			glVertex3f(ex, ey, -1.0);
		glEnd();
	glBegin(GL_LINES);
		glColor4f(rgb[0], rgb[1], rgb[2], 0.8);
		glVertex3f(sx, sy, -1.0);
		glVertex3f(sx, ey, -1.0);
	glEnd();
	glBegin(GL_LINES);
		glColor4f(rgb[0], rgb[1], rgb[2], 0.8);
		glVertex3f(sx, ey, -1.0);
		glVertex3f(ex, ey, -1.0);
	glEnd();
	glBegin(GL_LINES);
		glColor4f(rgb[0], rgb[1], rgb[2], 0.8);
		glVertex3f(ex, ey, -1.0);
		glVertex3f(ex, sy, -1.0);
	glEnd();
	glBegin(GL_LINES);
		glColor4f(rgb[0], rgb[1], rgb[2], 0.8);
		glVertex3f(ex, sy, -1.0);
		glVertex3f(sx, sy, -1.0);
	glEnd();
		
		in[0] = out[0]; in[1] = out[1];
	}
	glDisable(GL_BLEND);
	glFlush();
	[glLock unlock];
	
}

- (void) drawObjects {
	NSEnumerator* objEnum;
	FSViewerObject* obj;
	FSViewerItem* item;
	double s[2], e[2];
	double p[2];
	
	glEnable(GL_BLEND);
	objEnum = [displayList objectEnumerator];
	while(obj = [objEnum nextObject]) {
		item = [obj itemPtr];
		p[0] = item -> point[0][0]; p[1] = item -> point[0][1]; [self convertPoint: p toGL: s];
		p[0] = item -> point[1][0]; p[1] = item -> point[1][1]; [self convertPoint: p toGL: e];
		if([obj isVisible] == YES) switch(item -> type) {

			case FSVO_Point:
				glBegin(GL_POINTS);
					glColor4f(item -> color[0][0], item -> color[0][1], item -> color[0][2], item -> color[0][3]);
					glVertex3f(s[0], s[1], -1.0);
				glEnd();
				break;

			case FSVO_Dot:
				#define FSVO_Dot_Size (1.0/256.0)
				e[0] = s[0] + FSVO_Dot_Size; e[1] = s[1] + FSVO_Dot_Size;
				s[0] -= FSVO_Dot_Size; s[1] -= FSVO_Dot_Size;
				glBegin(GL_QUADS);
					glColor4f(item -> color[0][0], item -> color[0][1], item -> color[0][2], item -> color[0][3]);
					glVertex3f(s[0], e[1], -1.0);
					glVertex3f(s[0], s[1], -1.0);
					glVertex3f(e[0], s[1], -1.0);
					glVertex3f(e[0], e[1], -1.0);
				glEnd();
				glBegin(GL_LINES);
					glColor4f(item -> color[1][0], item -> color[1][1], item -> color[1][2], item -> color[1][3]);
					glVertex3f(s[0], s[1], -1.0);
					glVertex3f(s[0], e[1], -1.0);
				glEnd();
				glBegin(GL_LINES);
					glColor4f(item -> color[1][0], item -> color[1][1], item -> color[1][2], item -> color[1][3]);
					glVertex3f(s[0], e[1], -1.0);
					glVertex3f(e[0], e[1], -1.0);
				glEnd();
				glBegin(GL_LINES);
					glColor4f(item -> color[1][0], item -> color[1][1], item -> color[1][2], item -> color[1][3]);
					glVertex3f(e[0], e[1], -1.0);
					glVertex3f(e[0], s[1], -1.0);
				glEnd();
				glBegin(GL_LINES);
					glColor4f(item -> color[1][0], item -> color[1][1], item -> color[1][2], item -> color[1][3]);
					glVertex3f(e[0], s[1], -1.0);
					glVertex3f(s[0], s[1], -1.0);
				glEnd();
				break;

			case FSVO_Line:
				glBegin(GL_LINES);
					glColor4f(item -> color[0][0], item -> color[0][1], item -> color[0][2], item -> color[0][3]);
					glVertex3f(s[0], s[1], -1.0);
					glVertex3f(e[0], e[1], -1.0);
				glEnd();
				break;

			case FSVO_Box:
				glBegin(GL_QUADS);
					glColor4f(item -> color[0][0], item -> color[0][1], item -> color[0][2], item -> color[0][3]);
					glVertex3f(s[0], e[1], -1.0);
					glVertex3f(s[0], s[1], -1.0);
					glVertex3f(e[0], s[1], -1.0);
					glVertex3f(e[0], e[1], -1.0);
				glEnd();
				glBegin(GL_LINES);
					glColor4f(item -> color[1][0], item -> color[1][1], item -> color[1][2], item -> color[1][3]);
					glVertex3f(s[0], s[1], -1.0);
					glVertex3f(s[0], e[1], -1.0);
				glEnd();
				glBegin(GL_LINES);
					glColor4f(item -> color[1][0], item -> color[1][1], item -> color[1][2], item -> color[1][3]);
					glVertex3f(s[0], e[1], -1.0);
					glVertex3f(e[0], e[1], -1.0);
				glEnd();
				glBegin(GL_LINES);
					glColor4f(item -> color[1][0], item -> color[1][1], item -> color[1][2], item -> color[1][3]);
					glVertex3f(e[0], e[1], -1.0);
					glVertex3f(e[0], s[1], -1.0);
				glEnd();
				glBegin(GL_LINES);
					glColor4f(item -> color[1][0], item -> color[1][1], item -> color[1][2], item -> color[1][3]);
					glVertex3f(e[0], s[1], -1.0);
					glVertex3f(s[0], s[1], -1.0);
				glEnd();
				break;

			case FSVO_Circle:
			default:
				NSLog(@"-drawObjects in FSViewer did not recognize object type %i\n", item -> type);
				break;
		}
	}
	glDisable(GL_BLEND);
}

- (void) drawTexture {
	glEnable(GL_TEXTURE_RECTANGLE_EXT);
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, textureHandle);
		NSLog(@"coordinates are (%f, %f)\n", finalX, finalY);
		glColor4f(1.0, 1.0, 1.0, 1.0);
		glBegin(GL_QUADS);
			glTexCoord2d(0.0, 0.0); glVertex3f(-1.0, 1.0, -0.5);
			glTexCoord2d(finalX, 0.0); glVertex3f(1.0, 1.0, -0.5);
			glTexCoord2d(finalX, finalY); glVertex3f(1.0, -1.0, -0.5);
			glTexCoord2d(0.0, finalY); glVertex3f(-1.0, -1.0, -0.5);
		glEnd();	
	glDisable(GL_TEXTURE_RECTANGLE_EXT);
}

/* drawRect */
- (void) drawRect: (NSRect) rect
{
	int height, width;
	int i, j, k, s;
	float x, y, dx, dy, tw, th;
			
	[glLock lock];
	

	height = [self bounds].size.height;
	width = [self bounds].size.width;
	dx = 2.0 / (float) width;
	dy = 2.0 / (float) height;
	
	glViewport(0, 0, width, height);
	
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(-1.0, 1.0, -1.0, 1.0, 0.0, 1.0);
	glMatrixMode(GL_MODELVIEW);
	
	glClearColor(0.0, 0.0, 1.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);
	
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glDisable(GL_BLEND);
	
	if(readyToDisplay == NO) {
		glBegin(GL_QUADS);
			glColor3f(0.0, 0.0, 0.0);
			glVertex3f(-1.0, 1.0, -0.5);
			glVertex3f(1.0, 1.0, -0.5);
			glColor3f(1.0, 1.0, 1.0);
			glVertex3f(1.0, -1.0, -0.5);
			glVertex3f(-1.0, -1.0, -0.5);
		glEnd();
		glFlush();
		[glLock unlock];
		return;
	}

/*
	glColor3f(1.0, 1.0, 1.0);
	glBegin(GL_QUADS);
		glTexCoord2d(0.0, 1.0); glVertex3f(-1.0, -1.0, -0.5);
		glTexCoord2d(1.0, 1.0); glVertex3f(1.0, -1.0, -0.5);
		glTexCoord2d(1.0, 0.0); glVertex3f(1.0, 1.0, -0.5);
		glTexCoord2d(0.0, 0.0); glVertex3f(-1.0, 1.0, -0.5);
	glEnd();
*/	

//	if(displayLocked == NO) {
		[self drawTexture];
		[self drawObjects];
		
		glEnable(GL_BLEND);
			if([self inLiveResize] == YES) {
				glColor4f(1.0, 0.5, 0.0, 0.5);
				glBegin(GL_QUADS);
					glTexCoord2d(0.0, 0.0); glVertex3f(-1.0, -1.0, -0.5);
					glTexCoord2d(1.0, 0.0); glVertex3f(1.0, -1.0, -0.5);
					glTexCoord2d(1.0, 1.0); glVertex3f(1.0, 1.0, -0.5);
					glTexCoord2d(0.0, 1.0); glVertex3f(-1.0, 1.0, -0.5);
				glEnd();
			}
		glDisable(GL_BLEND);
//	}
	
	glFlush();
	[glLock unlock];
//	[renderLock unlock];
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
	gl[0] = point[0] - view -> center[0];
	gl[1] = point[1] - view -> center[1];
	gl[0] /= ((double) [self bounds].size.width * view -> pixelSize * view -> aspectRatio / 2.0);
	gl[1] /= ((double) [self bounds].size.height * view -> pixelSize / 2.0);
}

/* end coordinate conversions */

@end

#undef NSLog