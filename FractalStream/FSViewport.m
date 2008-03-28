#import "FSViewport.h"

@implementation FSKernelData
- (void) setLock: (NSLock*) newLock { lock = newLock; }
@end

@implementation FSViewport

- (void) awakeFromNib
{
	[[self window] makeFirstResponder: self];

	coordinateTracker = [self 
		addTrackingRect: [self bounds] 
		owner: self
		userData: NULL
		assumeInside: YES
	];
	[[self window] setInitialFirstResponder: self];
	
	centerX = centerY = 0.0;
	scale = 2.0;
	maxIterations = 100;
	dynamical = NO; invertDynamics = NO;
	configured = NO;
	kernel = NULL;
	colorScheme = 0;
	
	renderLock = [[NSLock alloc] init];
	modificationLock = [[NSLock alloc] init];
	textureReadyLock = [[NSLock alloc] init];
	[modificationLock lock];
	[NSThread detachNewThreadSelector: @selector(renderTexture:) toTarget: self withObject: self];
	displayLocked = NO;
}

- (void) relockModificationLock { [modificationLock lock]; }
- (void) updateViewport { nodeChanged = YES; [modificationLock unlock]; }

- (void*) theKernel { return (void*) kernel; }

- (void) loadTexture: (float*) texture x: (int) X y: (int) Y
{
		[[self openGLContext] makeCurrentContext];
		glEnable(GL_TEXTURE_2D);
		glBindTexture(GL_TEXTURE_2D, textureHandle);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_DECAL);
		glTexImage2D(GL_TEXTURE_2D, 0, 3, X, Y, 0, GL_RGB, GL_FLOAT, texture);
}

- (IBAction) nextColorScheme: (id) sender {
	++colorScheme; colorScheme = colorScheme % 6;
	[self reloadView: self];
}

- (IBAction) invertDynamics: (id) sender {
	invertDynamics = (invertDynamics == YES)? NO : YES;
	[self reloadView: self];
}

- (IBAction) startKernel: (id) sender {
		double data[2];
		data[0] = pa; data[1] = pb;
		kernel(-1, data, 0, 0, 0, 0.0);
}


- (void) renderTexture: (id) sender
{
	float* texture;
	double in[9];
	double *out;
	int i, j, k, n, m, l, mxcsr, colors;
	double x, y, xstep, ystep;
	double parX, parY, cenX, cenY, sc, width, height, maxRad;
	double dx2, dy2, nearTo;
	float r, g, b, shade;
	int prog, maxIt;
	BOOL firstLoop, useBlack;
	int size, pass;
	double multiplier;
	FSKernelData* threadData[2];
	NSLock* threadLock[2];
	
	width = height = 512.0;
	
	out = (double*) malloc(2 * width * 3 * sizeof(double));
	texture = (float*) malloc(2 * width * 2 * height * 3 * sizeof(float));
	if(texture == NULL) { NSLog(@"stillborn\n"); while(1) ; }
	
	threadData[0] = [[FSKernelData alloc] init];
	threadLock[0] = [[NSLock alloc] init];
	[threadData[0] setLock: threadLock[0]];
	threadData[1] = [[FSKernelData alloc] init];
	threadLock[1] = [[NSLock alloc] init];
	[threadData[1] setLock: threadLock[0]];
	
	firstLoop = YES;
	while(1) {
		if(firstLoop == YES) [textureReadyLock lock];
		[modificationLock lock];
		
		prog = ([theSession currentNode] -> program) | (((invertDynamics == YES) && ([theSession currentNode] -> program == 3))? 4 : 0);
		NSLog(@"prog = %i\n", prog);
		sc = [[theSession currentNode] scale];
		cenX = [[theSession currentNode] centerX];
		cenY = [[theSession currentNode] centerY]; 
		parX = paramX; parY = paramY;
		maxIt = maxIterations; maxRad = maxRadius;
		nodeChanged = NO;
		
/*
		mxcsr = _mm_getcsr();
		_mm_setcsr(mxcsr | 0x8040);
*/
		
		size = 512 / 4;
		multiplier = 4.0;
		
		in[5] = pa = [aParam doubleValue]; in[6] = pb = [bParam doubleValue]; in[7] = pc = [cParam doubleValue];
		colors = [maxColors intValue];
		if(colors < 0) { colors = 0; [maxColors setIntValue: colors]; }
		if(colors > 9) { colors = 9; [maxColors setIntValue: colors]; }
		useBlack = ([useBlackCheck state] == NSOnState)? YES : NO;
		
		nsteps = [intSteps intValue];
		if(nsteps < 1) { nsteps = 1; [intSteps setIntValue: nsteps]; }
		in[8] = (double) nsteps;
		
		for(pass = 0; pass < 3; pass++) {
			switch(pass) {
				case 0:
					size = 512 / 4; multiplier = 4.0; break;
				case 1:
					size = 512; multiplier = 1.0; break;
				case 2:
					size = 512 * 2; multiplier = 0.5; break;
			}
		xstep = multiplier * 2.0 * sc / (double) width;
		ystep = multiplier * -2.0 * sc / (double) height;
		y = cenY + sc;
		for(i = 0; i < size; i++) {
			x = cenX - sc;
			in[0] = x; in[1] = y; in[2] = xstep; in[3] = parX; in[4] = parY;
			kernel(prog, in, size, out, maxIt, maxRad);
			for(j = 0; j < size * 3; j += 3) {
					k = (int) out[j + 2];
					if(k == -1) {
						switch(colorScheme) {
							case 0:
							case 1:
							case 2:
								if(out[j] <= 0.0) { r = 1.0; g = 0.3; b = 0.3; }
								else { r = 0.3; g = 0.3; b = 1.0; }
								break;
							default:
								r = g = b = 1.0;
								break;
						}
					}
					else if(k >= maxIterations) { r = g = b = 0.0; }
					else {
						b = (k & 0xf) * 50.0 / 16.0; b += 50.0;
						b /= 100.0;
						if(k & 0x10) b = 1.5 - b;  
						b *= 0.65;  // was 0.8
						switch(colorScheme) {
							case 0:
								r = 1.0; g = (k & 0xf) / 15.0; b = 0.0;
								if(k & 0x10) g = 1.0 - g;
								break;
							case 1: /* "smart" coloring */
								if((out[j] * out[j] + out[j + 1] * out[j + 1]) > maxRadius * maxRadius) {
									r = g = b = 0.0;
									break;
								}
								//nearTo = 1.0 / (maxRadius * maxRadius);
								nearTo = 1.0 / maxRadius; /*** hack, "stops" uses maxRad^2 ***/
								m = -1;
								if(fixpoints > 0) for(n = 0; n < fixpoints; n++) {
									dx2 = fixpoint[0][n] - out[j];
									dy2 = fixpoint[1][n] - out[j + 1];
									dx2 *= dx2; dy2 *= dy2;
									if(dx2 + dy2 <= nearTo) { m = n; break; }
								}
								if(m == -1) { /* new fixpoint */
									if(fixpoints >= colors) n = -1;
									else {
										fixpoint[0][fixpoints] = out[j];
										fixpoint[1][fixpoints] = out[j + 1];
										NSLog(@"made a new fixpoint at %lf + i %lf\n", out[j], out[j+1]);
										n = fixpoints; ++fixpoints;
									}
								}
								if(n == -1) { r = g = b = (useBlack == YES)? 0.0 : 1.0; }
								else {
									switch(n) {
										case 0: r = 1.0; g = 0.0; b = 0.0; break;
										case 1: r = 0.0; g = 1.0; b = 0.0; break;
										case 2: r = 0.0; g = 0.0; b = 1.0; break;
										case 3: r = 1.0; g = 1.0; b = 0.0; break;
										case 4: r = 1.0; g = 0.0; b = 1.0; break;
										case 5: r = 0.0; g = 1.0; b = 1.0; break;
										
										case 6: r = 1.0; g = 0.5; b = 0.0; break;
										case 7: r = 0.0; g = 1.0; b = 0.5; break;
										case 8: r = 0.5; g = 0.0; b = 1.0; break;
									}
								}
								shade = (k & 7) / 7.0;
								if(k & 8) shade = 1.0 - shade;
								shade /= 2.0; shade += 0.5;
								r *= shade; g *= shade; b *= shade;
								break;
							case 2: r = g = b; break;
							case 3: r = g = b = 0.0; break;
							case 4:
								switch(k % 12) {
									case 0:
										r = 1.0; g = 0.0; b = 0.0;
										break;
									case 1:
										r = 0.7; g = 0.4; b = 0.0;
										break;
									case 2:
										r = 0.5; g = 0.5; b = 0.0;
										break;
									case 3:
										r = 0.4; g = 0.7; b = 0.0;
										break;
									case 4:
										r = 0.0; g = 1.0; b = 0.0;
										break;
									case 5:
										r = 0.0; g = 0.7; b = 0.4;
										break;
									case 6:
										r = 0.0; g = 0.5; b = 0.5;
										break;
									case 7:
										r = 0.0; g = 0.4; b = 0.7;
										break;
									case 8:
										r = 0.0; g = 0.0; b = 1.0;
										break;
									case 9:
										r = 0.4; g = 0.0; b = 0.7;
										break;
									case 10:
										r = 0.5; g = 0.0; b = 0.5;
										break;
									case 11:
										r = 0.7; g = 0.0; b = 0.4;
										break;

								}
								break;
							case 5:
								if(k & 0x1) {
									if(out[j + 1] >= 0.0) { r = g = 1.0; b = 0.0; }
									else { r = g = 0.0; b = 0.95; }
								}
								else {
									if(out[j + 1] >= 0.0) { r = g = 0.95; b = 0.0; }
									else { r = g = 0.0; b = 1.0; };
								}
								break;
						}
					}
					k = (i * size * 3) + j;
					texture[k + 0] = r; texture[k + 1] = g; texture[k + 2] = b;
			}
			y += ystep;
			if(nodeChanged == YES) break;
		}
		if(nodeChanged == NO) { 
			displayLocked = YES;
			[renderLock lock];
			[self loadTexture: texture x: size y: size];
	
			[renderLock unlock];
			displayLocked = NO;
		}
		if(firstLoop == YES) { firstLoop = NO; [textureReadyLock unlock]; }
		[self setNeedsDisplay: YES];
		// reaquire the modification lock */
		if(nodeChanged == YES) { NSLog(@"aborted\n"); pass = 10000; }
		else { [modificationLock unlock]; [modificationLock lock]; }
		}
		
		[modificationLock unlock];
		if(nodeChanged == NO) [sender relockModificationLock]; 

/*		_mm_setcsr(mxcsr);*/

	}

	free(texture); // never gets here, though
}


- (void) loadTexture {
	unsigned char *texture;
	int i, j;
	
	texture = (unsigned char*) malloc(640 * 640 * 3 * sizeof(unsigned char));
	for(i = 0; i < 640; i++) {
		for(j = 0; j < 640; j++) {
			texture[3 * ((640 * i) + j) + 0] = (i * 256) / 640;
			texture[3 * ((640 * i) + j) + 2] = (j * 256) / 640;
			texture[3 * ((640 * i) + j) + 1] = 0;
		}
	}
//	glGenTextures(1, &textureHandle);
	glBindTexture(GL_TEXTURE_2D, textureHandle);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
//	gluBuild2DMipmaps(GL_TEXTURE_2D, 3, 640, 640, GL_RGB, GL_UNSIGNED_BYTE, texture);
	free(texture);
}

- (id) initWithCoder: (NSCoder*) coder
{
	self = [super initWithCoder: coder];

	kernel = NULL;
	configured = NO;
	return self;
}

- (void) linkToKernel: (void*) newKernel;
{
//	kernel = newKernel;
	[self startKernel: self];
	
	/* send config data over to the test FSViewer */
	viewerData.center[0] = viewerData.center[1] = 0.0;
	viewerData.par[0] = viewerData.par[1] = 0.0;
	viewerData.pixelSize = 4.0 / 256.0;
	viewerData.detailLevel = 1.0;
	viewerData.kernel = kernel;
	viewerData.eventManager = nil;
	[theViewer setViewerData: &viewerData];
	/* end FSViewer test setup */
	
	configured = YES;
	fixpoints = 0;
	[[self window] setTitle: @"Parameter Plane"];
	[[self window] setAcceptsMouseMovedEvents: YES];
	glEnable(GL_TEXTURE_2D);
	glGenTextures(1, &textureHandle);
	[modificationLock unlock];
	[textureReadyLock lock]; // wait for the first texture to get rendered.
	[self setNeedsDisplay: YES];
}

- (double) currentScale { return scale; }
- (double) currentCenterX { return centerX; }
- (double) currentCenterY { return centerY; }

- (void) setScale: (double) newScale X: (double) newX Y: (double) newY
{
	scale = newScale; centerX = newX; centerY = newY;
}

/* pass mouse events off to the FSTools */
- (void) mouseEntered: (NSEvent*) theEvent
{
	[[self window] setAcceptsMouseMovedEvents: YES];
	[toolkit mouseEntered: theEvent];
}
- (void) mouseExited: (NSEvent*) theEvent
{
	[[self window] setAcceptsMouseMovedEvents: NO];
	[toolkit mouseExited: theEvent];
}
- (void) mouseMoved: (NSEvent*) theEvent { [toolkit mouseMoved: theEvent]; }

- (void) mouseDragged: (NSEvent*) theEvent { [toolkit mouseDragged: theEvent]; }
- (void) mouseUp: (NSEvent*) theEvent { [toolkit mouseUp: theEvent]; }
- (void) mouseDown: (NSEvent*) theEvent { [toolkit mouseDown: theEvent]; }
- (void) rightMouseDown: (NSEvent*) theEvent { [toolkit rightMouseDown: theEvent]; }
- (void) scrollWheel: (NSEvent*) theEvent { [toolkit scrollWheel: theEvent]; }
/* end of mouse events */

/* coordinate conversions */
- (void) convertLocation: (NSPoint) location toPoint: (FSPoint*) pt {
	pt -> x = (2.0 * (location.x - [self frame].origin.x) / [self bounds].size.width) - 1.0;
	pt -> y = (2.0 * (location.y - [self frame].origin.y) / [self bounds].size.height) - 1.0;
	pt -> x = (pt -> x) * [self currentScale] + [self currentCenterX];
	pt -> y = (pt -> y) * [self currentScale] + [self currentCenterY];
}

- (void) convertEvent: (NSEvent*) theEvent toPoint: (FSPoint*) pt {
	pt -> x = (2.0 * ([theEvent locationInWindow].x - [self frame].origin.x) / [self bounds].size.width) - 1.0;
	pt -> y = (2.0 * ([theEvent locationInWindow].y - [self frame].origin.y) / [self bounds].size.height) - 1.0;
	pt -> x = (pt -> x) * [self currentScale] + [self currentCenterX];
	pt -> y = (pt -> y) * [self currentScale] + [self currentCenterY];
}

- (void) convertPoint: (FSPoint) p toLocation:  (NSPoint*) location {
	p.x -= [self currentCenterX];		p.y -= [self currentCenterY];
	p.x /= [self currentScale];			p.y /= [self currentScale];
	p.x += 1.0;							p.y += 1.0;
	p.x *= [self bounds].size.width;	p.y *= [self bounds].size.height;
	p.x /= 2.0;							p.y /= 2.0;
	p.x += [self frame].origin.x;		p.y += [self frame].origin.y;
	location -> x = p.x;				location -> y = p.y;
}
/* end coordinate conversions */

- (void) lineFrom: (NSPoint) start to: (NSPoint) end
{
	double sx, sy, ex, ey;
	
	/* convert to internal coordinates */
	sx = (2.0 * (start.x - [self frame].origin.x) / [self bounds].size.width) - 1.0;
	sy = (2.0 * (start.y - [self frame].origin.y) / [self bounds].size.height) - 1.0;
	ex = (2.0 * (end.x - [self frame].origin.x)   / [self bounds].size.width) - 1.0;
	ey = (2.0 * (end.y - [self frame].origin.y)   / [self bounds].size.height) - 1.0;
	
	[renderLock lock];
	[[self openGLContext] makeCurrentContext];
	
	glViewport(0, 0, [self bounds].size.height, [self bounds].size.width);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(-1.0, 1.0, -1.0, 1.0, 0.0, 1.0);
	glMatrixMode(GL_MODELVIEW);
	
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);

	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glEnable(GL_TEXTURE_2D);

	if(displayLocked == NO) {
		glBindTexture(GL_TEXTURE_2D, textureHandle);
		glBegin(GL_QUADS);
			glColor3f(1.0, 1.0, 1.0);
			glTexCoord2d(0.0, 1.0); glVertex3f(-1.0, -1.0, -0.5);
			glTexCoord2d(1.0, 1.0); glVertex3f(1.0, -1.0, -0.5);
			glTexCoord2d(1.0, 0.0); glVertex3f(1.0, 1.0, -0.5);
			glTexCoord2d(0.0, 0.0); glVertex3f(-1.0, 1.0, -0.5);
		glEnd();
	}
	
	glDisable(GL_TEXTURE_2D);

	glBegin(GL_QUADS);
		glColor4f(0.2, 0.5, 1.0, 0.5);
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
	[renderLock unlock];
}

- (void) tracePathFrom: (NSPoint) start
{
	double in[9], out[3], x, y;
	int i, k;

	x = (2.0 * (start.x - [self frame].origin.x) / [self bounds].size.width) - 1.0;
	y = (2.0 * (start.y - [self frame].origin.y) / [self bounds].size.height) - 1.0;
	in[0] = centerX + scale * x;
	in[1] = centerY + scale * y;
	in[2] = 0.0;
	in[3] = paramX; in[4] = paramY;
	
	[renderLock lock];
	[[self openGLContext] makeCurrentContext];
	glViewport(0, 0, [self bounds].size.height, [self bounds].size.width);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(-1.0, 1.0, -1.0, 1.0, 0.0, 1.0);
	glMatrixMode(GL_MODELVIEW);
	
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);

	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glEnable(GL_TEXTURE_2D);

	if(displayLocked == NO) {
		glBindTexture(GL_TEXTURE_2D, textureHandle);
		glBegin(GL_QUADS);
			glColor3f(1.0, 1.0, 1.0);
			glTexCoord2d(0.0, 1.0); glVertex3f(-1.0, -1.0, -0.5);
			glTexCoord2d(1.0, 1.0); glVertex3f(1.0, -1.0, -0.5);
			glTexCoord2d(1.0, 0.0); glVertex3f(1.0, 1.0, -0.5);
			glTexCoord2d(0.0, 0.0); glVertex3f(-1.0, 1.0, -0.5);
		glEnd();
	}
	
	glDisable(GL_TEXTURE_2D);

		//k = (dynamical == NO) ? 0x1 : 0x3;
	k = [theSession currentNode] -> program;
	
	glColor4f(1.0, 1.0, 1.0, 1.0);
	in[5] = pa; in[6] = pb; in[7] = pc; in[8] = (double) nsteps;
	
	for(i = 0; i < 100; i++) {
		kernel(k, in, 1, out, 1, 100.0);
		if((out[2] >= maxIterations) || (out[2] == -1)) break;
		if((out[0] * out[0] + out[1] * out[1]) > (maxRadius * maxRadius)) break;
		glBegin(GL_LINES);
			x = (in[0] - centerX) / scale; y = (in[1] - centerY) / scale;
			glVertex3f(x, y, -1.0);
			x = (out[0] - centerX) / scale; y = (out[1] - centerY) / scale;
			glVertex3f(x, y, -1.0);
		glEnd();
		in[0] = out[0]; in[1] = out[1];
	}
	
	glFlush();
	[renderLock unlock];
}

- (void) drawRayFrom: (NSPoint) start
{
	double in[5], out[3], x, y, z[2][4], step, u, v, n[4];
	int i, j, k;

	x = (2.0 * (start.x - [self frame].origin.x) / [self bounds].size.width) - 1.0;
	y = (2.0 * (start.y - [self frame].origin.y) / [self bounds].size.height) - 1.0;
	in[0] = centerX + scale * x;
	in[1] = centerY + scale * y;
	in[2] = 0.0;
	in[3] = paramX; in[4] = paramY;
	step = 2.0 * scale / (double) [self bounds].size.width;
	
	[renderLock lock];
	[[self openGLContext] makeCurrentContext];
	glViewport(0, 0, [self bounds].size.height, [self bounds].size.width);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(-1.0, 1.0, -1.0, 1.0, 0.0, 1.0);
	glMatrixMode(GL_MODELVIEW);
	
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);

	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glEnable(GL_TEXTURE_2D);

	if(displayLocked == NO) {
		glBindTexture(GL_TEXTURE_2D, textureHandle);
		glBegin(GL_QUADS);
			glColor3f(1.0, 1.0, 1.0);
			glTexCoord2d(0.0, 1.0); glVertex3f(-1.0, -1.0, -0.5);
			glTexCoord2d(1.0, 1.0); glVertex3f(1.0, -1.0, -0.5);
			glTexCoord2d(1.0, 0.0); glVertex3f(1.0, 1.0, -0.5);
			glTexCoord2d(0.0, 0.0); glVertex3f(-1.0, 1.0, -0.5);
		glEnd();
	}
	
	glDisable(GL_TEXTURE_2D);

	k = [theSession currentNode] -> program;
	
	glColor4f(1.0, 1.0, 1.0, 0.95);
	in[0] = x - step; in[1] = y;
	for(i = 0; i < 500; i++) {
		kernel(k, in, 1, out, 100, 100.0);
		z[0][0] = out[0]; z[1][0] = out[1];
		in[0] += 2.0 * step;
		kernel(k, in, 1, out, 100, 100.0);
		z[0][1] = out[0]; z[1][1] = out[1];
		in[0] -= step; in[1] += step;
		kernel(k, in, 1, out, 100, 100.0);
		z[0][2] = out[0]; z[1][2] = out[1];
		in[1] -= 2.0 * step;
		kernel(k, in, 1, out, 100, 10000000.0);
		z[0][3] = out[0]; z[1][3] = out[1];
		for(j = 0; j < 4; j++) {
			n[j] = z[0][j] * z[0][j] + z[1][j] * z[1][j];
			n[j] = sqrt(n[j]);
		}
		if((n[0] >= n[1]) && (n[0] >= n[2]) && (n[0] >= n[3])) x += step / 2.0;
		else if((n[1] >= n[2]) && (n[1] >= n[3])) x -= step / 2.0;
		else if(n[2] >= n[3]) y -= step / 2.0;
		else y += step / 2.0;
		glBegin(GL_POINTS);
			glVertex3f(x, y, -1.0);
		glEnd();
		in[0] = x; in[1] = y;
	}
	
	glFlush();
	[renderLock unlock];
}


- (void) recenterOn: (NSPoint) newCenter
{
	float x, y;
	x = (2.0 * (newCenter.x - [self frame].origin.x) / [self bounds].size.width) - 1.0;
	y = (2.0 * (newCenter.y - [self frame].origin.y) / [self bounds].size.height) - 1.0;
	centerX += x * scale;
	centerY += y * scale;
	[theSession addChildNodeWithScale: scale X: centerX Y: centerY 
		flags: [theSession currentNode] -> program];//(dynamical == YES)? 0x3 : 0x1];
	nodeChanged = YES;
	[modificationLock unlock];
	[self setNeedsDisplay: YES];
}

- (void) scaleOutFrom: (NSPoint) newCenter by: (double) factor
{
	scale *= factor;
	[theSession addChildNodeWithScale: scale X: centerX Y: centerY 
		flags: [theSession currentNode] -> program];//(dynamical == YES)? 0x3 : 0x1];
	[self recenterOn: newCenter];
}

- (void) viewBoxFrom: (NSPoint) start to: (NSPoint) end {
	double sx, sy, ex, ey, t, cx, cy;
	double dimX, dimY;

	/* convert to internal view coordinates */
	sx = (2.0 * (start.x - [self frame].origin.x) / [self bounds].size.width) - 1.0;
	sy = (2.0 * (start.y - [self frame].origin.y) / [self bounds].size.height) - 1.0;
	ex = (2.0 * (end.x - [self frame].origin.x)   / [self bounds].size.width) - 1.0;
	ey = (2.0 * (end.y - [self frame].origin.y)   / [self bounds].size.height) - 1.0;

	sx = centerX + (sx * scale);
	sy = centerY + (sy * scale);
	ex = centerX + (ex * scale);
	ey = centerY + (ey * scale);

	if(ex < sx) { t = sx; sx = ex; ex = t; }
	if(ey < sy) { t = sy; sy = ey; ey = t; }
	
	if((ey - sy) > (ex - sx)) t = (ey - sy) / 2.0;
	else t = (ex - sx) / 2.0;

	if(scale / t > 50.0) [self recenterOn: start];
	else {
		centerX = (ex + sx) / 2.0;
		centerY = (ey + sy) / 2.0;
		scale = t;
		[theSession addChildNodeWithScale: scale X: centerX Y: centerY 
			flags: [theSession currentNode] -> program];//(dynamical == YES)? 0x3 : 0x1];
		nodeChanged = YES;
		[modificationLock unlock];
		[self setNeedsDisplay: YES];
	}
}

- (double) pX { return paramX; }
- (double) pY { return paramY; }

- (void) changeToDynamical: (NSPoint) click {
	double x, y;
	
	x = (2.0 * (click.x - [self frame].origin.x) / [self bounds].size.width) - 1.0;
	y = (2.0 * (click.y - [self frame].origin.y) / [self bounds].size.height) - 1.0;
	paramX = centerX + x * scale;
	paramY = centerY + y * scale;
	dynamical = YES;
	centerX = centerY = 0.0; scale = 2.0;
	[theSession addChildNodeWithScale: scale X: centerX Y: centerY flags: 0x3];
	nodeChanged = YES;
	[modificationLock unlock];
	[self setNeedsDisplay: YES];
}

- (void) previewDynamical: (NSPoint) click {
	double x, y;
	
	x = (2.0 * (click.x - [self frame].origin.x) / [self bounds].size.width) - 1.0;
	y = (2.0 * (click.y - [self frame].origin.y) / [self bounds].size.height) - 1.0;
	viewerData.par[0] = centerX + x * scale;
	viewerData.par[1] = centerY + y * scale;
	[theViewer setViewerData: &viewerData];
}
- (IBAction) reloadView: (id) sender {
	maxIterations = [iterBox intValue];
	maxRadius = [radBox doubleValue];
	nodeChanged = YES; [modificationLock unlock]; [self setNeedsDisplay: YES];
}

- (IBAction) resetColors: (id) sender { fixpoints = 0; [self reloadView: self]; }

- (IBAction) goHome: (id) sender {
	[theSession goToRoot: sender];
	[self reloadView: sender];
}

- (void) drawRect: (NSRect) rect
{
	int height, width;
	int i, j, n;
	double x, y, xstep, ystep; /* opengl window coordinates */
	double in[5], out[4096];
	double theta, shade;
	double X, Y, Xstep, Ystep; /* complex plane coordinates */
	double N;
			
	[renderLock lock];
	
	height = [self bounds].size.height;
	width = [self bounds].size.width;
	
	[owner iterations: &maxIterations];
	[owner radius: &maxRadius];
	
	centerX = [[theSession currentNode] centerX];
	centerY = [[theSession currentNode] centerY];
	scale = [[theSession currentNode] scale];
	
	glViewport(0, 0, width, height);
	
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(-1.0, 1.0, -1.0, 1.0, 0.0, 1.0);
	glMatrixMode(GL_MODELVIEW);
	
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);
	
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glDisable(GL_BLEND);
	
	glEnable(GL_TEXTURE_2D);

	if(displayLocked == NO) {
		glBindTexture(GL_TEXTURE_2D, textureHandle);
		glBegin(GL_QUADS);
			glTexCoord2d(0.0, 1.0); glVertex3f(-1.0, -1.0, -0.5);
			glTexCoord2d(1.0, 1.0); glVertex3f(1.0, -1.0, -0.5);
			glTexCoord2d(1.0, 0.0); glVertex3f(1.0, 1.0, -0.5);
			glTexCoord2d(0.0, 0.0); glVertex3f(-1.0, 1.0, -0.5);
		glEnd();
	}
	
	glDisable(GL_TEXTURE_2D);
	
	glFlush();
	
	[renderLock unlock];
}

@end
