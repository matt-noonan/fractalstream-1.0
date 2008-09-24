//
//  FSViewer.m
//  FractalStream
//
//  Created by Matt Noonan on 11/24/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "FSViewer.h"

// smooth coloring still experimental 
//#define SMOOTH_COLORING

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
	configured = NO;
	readyToRender = NO;
	readyToDisplay = NO;
	threadCount = 0;
/*
*/
	renderLock = [[NSLock alloc] init];
	Debug(@"this is viewer %@\n", self);
	Debug(@"renderLock: %@\n", renderLock);

	for(i = 0; i < 4; i++) {
		subtextureSize[i] = 0;
		subtexture[i] = NULL;
		subtextureLock[i] = [[NSLock alloc] init];
		Debug(@"subtextureLock[%i]: %@\n", i, subtextureLock[i]);
		changed[i] = YES;
	}
	
	for(i = 0; i < 64; i++) {
		acCache[i].allocated_entries = 16;
		acCache[i].used_entries = 0; 
		acCache[i].color = malloc(8 * 8 * 3 * sizeof(float) * 16);
		acCache[i].x = malloc(sizeof(double) * 16);
		acCache[i].y = malloc(sizeof(double) * 16);
	}


	return self;
}

- (void) awakeFromNib {
	int i, j;
	
	

	renderingFinishedObject = nil;
	[renderLock lock]; // lock the rendering engine.  unlocking will then cause the engine to render a new frame.
	currentBatch = 0;
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
	[[self window] setTitle: @"FractalStream Test, January 2008"];
	
	
	glConfigured = NO;
	glLock = [[NSLock alloc] init];
	finishedLock = [[NSLock alloc] init];
	syncLock = [[NSLock alloc] init];
	acLock = [[NSLock alloc] init];
	
	Debug(@"glLock: %@    :-)\n", glLock);
	Debug(@"finishedLock: %@\n", finishedLock);
	Debug(@"syncLock: %@\n", syncLock);
	
	[progress setDisplayedWhenStopped: NO];

	[NSThread detachNewThreadSelector: @selector(renderEngine:) toTarget: self withObject: self];
	for(i = 0; i < nTasks; i++) {
		[NSThread detachNewThreadSelector: @selector(renderQuarter:) toTarget: self withObject: self];
	}
	
	displayLocked = NO;	
	awake = YES;
}

- (BOOL) isAwake { return awake; }

- (void) setViewerData: (FSViewerData*) newData {
	Debug(@"somebody set the viewer data\n");
	nodeChanged = YES;
	[finishedLock lock];
	[finishedLock unlock];
	
	/* If everything in the new view is the same except for zoom level / center, we can reuse the old texture as an approximation */
	if(configured == YES) if(
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
		Debug(@"readyToDisplay says %@\n", (readyToDisplay == YES)? @"yes" : @"no");
	}

	if(readyToRender == NO) { 
		Debug(@"not ready to render\n");
		return;
	}
	Debug(@"render: dropping\n");
	[finishedLock lock];
	[finishedLock unlock];

	[progress startAnimation: self];
	[renderLock unlock];
}

- setRenderCompletedMessage: (SEL) message forObject: (id) obj { renderingFinished = message; renderingFinishedObject = obj; }

- setDefaultsTo: (double*) def count: (int) n {
	int i;
	Debug(@"setDefaultsTo got count %i\n", n);
	defaults = n;
	if(n) for(i = 0; i < n; i++) { setting[i + 6] = def[i]; Debug(@"viewer set default %i to %f\n", i, def[i]); }
}

- (IBAction) renderEngine: (id) sender {
	int i, j, k;
	int height, width, xMax, yMax, blockSize, size;
	double detailLevel;
	int loop;
	struct timeval startTime, endTime;
	int mxcsr;
	BOOL flushDenormals;
	NSAutoreleasePool* pool;
	
	readyToRender = YES;
	for(i = 0; i < nTasks; i++) [subtextureLock[i] lock];
	while(1) {
		Debug(@"engine: waiting\n");
		[renderLock lock]; // try to aquire the render lock.  can only do this if the browser releases this lock to request a new frame
		pool = [[NSAutoreleasePool alloc] init];
#ifdef __WIN32__
#else
		gettimeofday(&startTime, NULL);
#endif

		flushDenormals = ([denormalButton state] == NSOnState)? YES : NO;

		nodeChanged = NO;
		detailLevel = view -> detailLevel / 4.0;
		
		for(loop = 0; loop < 3; loop++) { if(nodeChanged == YES) break; view -> detailLevel = detailLevel; detailLevel *= 2.0; 
		[finishedLock lock];
		Debug(@"**** loop %i ****\n", loop);
		Debug(@"engine: holding lock, configured = %@\n", (configured == YES)? @"yes" : @"no");

		autocolorAdded = NO;
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
			Debug(@"allocating %i bytes for texture at %x\n", size, texture);
			if(texture == NULL) {
				Debug(@"failed!\n");
			}
		}

		[syncLock lock];
		activeSubtasks = 0;
		for(i = 0; i < nTasks; i++) { // start the four subtasks which do the actual rendering
			Debug(@"rendering thread unlocking subtexture %i\n", i);
			[subtextureLock[i] unlock];
		}
		[syncLock unlock];
		/* rendering happens here */

/******* THIS NEXT THING IS REALLY PRETTY STUPID *******/

		Debug(@"waiting for subthreads\n");
		while(activeSubtasks != TasksStartedMask) ; // make sure everybody has grabbed their lock before going on
		Debug(@"subthreads all active\n");
		for(i = 0; i < nTasks; i++) { // reaquire the four subtask locks
			Debug(@"rendering thread waiting on subtexture lock %i\n", i);
			[subtextureLock[i] lock];
		}
		Debug(@"rendering thread got all subtexture locks\n");
		/* rendering subtasks are finished, reassemble the results. */
		if(nodeChanged == YES) {
			// scrap our work and start over
			Debug(@"node changed, scrap it!\n");
			rendering = NO;
			readyToDisplay = NO;
			[finishedLock unlock];
			Debug(@"waiting for activeSubtasks to get to 0 (nodeChanged)\n");
			while(activeSubtasks != TasksEndedMask) ;
			break;
		}
		[glLock lock];
			finalX = xMax; finalY = yMax;
			Debug(@"rendering engine creating OpenGL texture of size (%f, %f)\n", finalX, finalY);
			[[self openGLContext] makeCurrentContext];
			glEnable(GL_TEXTURE_RECTANGLE_EXT);
			glBindTexture(GL_TEXTURE_RECTANGLE_EXT, textureHandle);
			glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
//			glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_DECAL);
			glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, 3, xMax, yMax, 0, GL_RGB, GL_FLOAT, texture);
		[glLock unlock];
		Debug(@"texture created.\n");
		rendering = NO;
		readyToDisplay = YES;
		[self setNeedsDisplay: YES];
		Debug(@"engine: dropping\n");
		[finishedLock unlock];
		Debug(@"waiting for activeSubtasks to get to 0\n");
		while(activeSubtasks != TasksEndedMask) ;
		if(autocolorAdded) [colorPicker change: self];
		}
		Debug(@"got there\n");
#ifdef __WIN32__
		memcpy(&startTime, &endTime, sizeof(struct timeval));
#else
		gettimeofday(&endTime, NULL);
#endif
		[timerField setStringValue: [NSString stringWithFormat: @"%f seconds",
			(double)(endTime.tv_sec - startTime.tv_sec) + (double)(endTime.tv_usec - startTime.tv_usec) / 1000000.0]
		];
		[progress stopAnimation: self];
		if(renderingFinishedObject != nil) [renderingFinishedObject performSelector: renderingFinished];
		[pool release];
	}
}

- (IBAction) renderQuarter: (id) sender
{
	int size;
	int thisThread;
	int x, y, height, width, xMax, yMax, k, phase, flag, i, j;
	float c;
	double step, X, Y, oX, oY;
	float r, g, b;
	double in[512], *out;
	int startLine, endLine;
	BOOL firstLoop;
	float colorArray[64*8*8*3];
	NSAutoreleasePool* pool;
	
	[syncLock lock];
	thisThread = threadCount++;
	firstLoop = YES;
	Debug(@"thread %i is ready, going to grab the lock\n", thisThread);
	[syncLock unlock];
	
	while(1) { [subtextureLock[thisThread] lock];  // wait for permission to start
		if(view == NULL) {
			Debug(@"thread %i is not ready, view == NULL\n", thisThread);
			[subtextureLock[thisThread] unlock]; continue;
		}
		if(view -> kernel == NULL) { 
			Debug(@"thread %i is not ready, view -> kernel == NULL\n", thisThread);
			[subtextureLock[thisThread] unlock]; continue;
		}
		[syncLock lock];
		Debug(@"thread %i is active, activeSubtasks = %i, texture = %x\n", thisThread, activeSubtasks + 1, texture);
		activeSubtasks |= (1 << thisThread);
		Debug(@"thread %i, now activeSubtasks = %i\n", thisThread, activeSubtasks);
		[syncLock unlock];
		pool = [[NSAutoreleasePool alloc] init];
		
		/* WHY IS THIS IN THE SUBTHREAD????? */
		[colorPicker colorArrayValue: colorArray];
		[acLock lock];
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
		[acLock unlock];
		/*************************************/
		
		for(i = 0; i < 512; i++) in[i] = setting[i];
	
		
		height = [self bounds].size.height;
		width = [self bounds].size.width;
		xMax = (int)(width * view -> detailLevel + 0.5);
		yMax = (int)(height * view -> detailLevel + 0.5);
	
		startLine = (yMax / nTasks) * thisThread;
		endLine = (thisThread + 1) * (yMax / nTasks);
	
		X = view -> center[0] - ((double) width * view -> pixelSize * view -> aspectRatio / 2.0);
		Y = view -> center[1] + ((double) height * view -> pixelSize / 2.0);
		Y -= (float) thisThread * view -> pixelSize * (float) yMax / ((double) nTasks * view -> detailLevel);
		step = view -> pixelSize / view -> detailLevel;
	
		out = (double*) malloc(3 * xMax * sizeof(double));
		size = xMax * yMax * 3 * sizeof(float) / nTasks;
		if(size > subtextureSize[thisThread]) {  /* decide if this is really the behavior you want... */
//			free(subtexture[thisThread]);
//			subtexture[thisThread] = (float*) malloc(size);
			subtextureSize[thisThread] = size;
//			if(subtexture[thisThread] == NULL) { Debug(@"****** subtexture malloc failed!!! *******\n"); while(1); }		
		}
	
		for(y = startLine; y < endLine; y++) {
			double nearR, farR;
			int prog;
			in[0] = X; in[1] = Y;
			in[2] = step * view->aspectRatio;
			in[3] = view -> par[0]; in[4] = view -> par[1];
			in[5] = view -> pixelSize; 
			farR = view -> maxRadius;
			nearR = view -> minRadius; 
			nearR *= nearR; farR *= farR;
			prog = view->program;
			(view -> kernel)(view -> program, in, xMax, out, view -> maxIters, view -> maxRadius, view -> minRadius);
			[acLock lock];
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
					BOOL useGrey;
					phase = 0;
					if((oX > 0.0) && (oY > 0.0)) phase = 0;
					if((oX < 0.0) && (oY > 0.0)) phase = 2;
					if((oX < 0.0) && (oY < 0.0)) phase = 4;
					if((oX > 0.0) && (oY < 0.0)) phase = 6;
					if(((phase & 2)) && ((oY * oY) < (oX * oX))) phase += 1;
					else if(((phase & 2) == 0) && ((oX * oX) < (oY * oY))) phase += 1; 

#ifndef SMOOTH_COLORING
					if(acCache[flag].active == NO) {
						r = colorArray[(8*8*3)*flag + (phase*8*3) + (((k >> 1) & 0x7) * 3) + 0];
						g = colorArray[(8*8*3)*flag + (phase*8*3) + (((k >> 1) & 0x7) * 3) + 1];
						b = colorArray[(8*8*3)*flag + (phase*8*3) + (((k >> 1) & 0x7) * 3) + 2];
						if(k & 1) {
							r += colorArray[(8*8*3)*flag + (phase*8*3) + ((((k+1) >> 1) & 0x7) * 3) + 0];
							g += colorArray[(8*8*3)*flag + (phase*8*3) + ((((k+1) >> 1) & 0x7) * 3) + 1];
							b += colorArray[(8*8*3)*flag + (phase*8*3) + ((((k+1) >> 1) & 0x7) * 3) + 2];
							r /= 2.0; g /= 2.0; b /= 2.0;
						}
					}
					else {
						/* this color scheme uses autocoloring.  MAKE THIS THREAD-SAFE!!!! */
						i = 0;
						useGrey = NO;
						if(acCache[flag].used_entries > 0) for(i = 0; i < acCache[flag].used_entries; i++) {
							if(((oX - acCache[flag].x[i])*(oX - acCache[flag].x[i]) + (oY - acCache[flag].y[i])*(oY - acCache[flag].y[i])) < nearR) break;
							if((acCache[flag].x[i] == FSViewer_Infinity) && ((oX*oX + oY*oY) > farR)) break;
						}
						if(i == acCache[flag].used_entries) {
							int acCount;
							/* hit a new fixpoint */

							if(acCache[flag].locked || (prog == 1)) useGrey = YES;
							// hack, should just be else
							else if(acCache[flag].used_entries < 16) {
							
							autocolorAdded = YES;
							Debug(@"------> autocolorAdded = %@\n", (autocolorAdded)? @"yes" : @"no");
							if((oX*oX + oY*oY) < farR) [colorPicker
								addFixpointWithX: oX
								Y: oY 
								name: [NSString stringWithFormat: @"%f + %fi", oX, oY]
								toAutocolor: flag
							];
							else [colorPicker
								addFixpointWithX: FSViewer_Infinity
								Y: FSViewer_Infinity
								name: [NSString stringWithFormat: @"Infinity", oX, oY]
								toAutocolor: flag
							];
							acCount = [colorPicker numberOfFixpointsForAutocolor: flag];

							
							acCache[flag].used_entries = acCount;
							if(acCount > acCache[flag].allocated_entries) {
								acCache[flag].allocated_entries = acCount + 16;
								realloc(acCache[flag].color, 8 * 8 * 3 * sizeof(float) * acCache[flag].allocated_entries);
								realloc(acCache[flag].x, sizeof(double) * acCache[flag].allocated_entries);
								realloc(acCache[flag].y, sizeof(double) * acCache[flag].allocated_entries);
							}
							[colorPicker cacheAutocolor: flag to: acCache[flag].color X: acCache[flag].x Y: acCache[flag].y];
							} /* hack */
						}
						if(useGrey == NO) {
							r = acCache[flag].color[(8*8*3)*i + (phase*8*3) + (((k >> 1) & 0x7) * 3) + 0];
							g = acCache[flag].color[(8*8*3)*i + (phase*8*3) + (((k >> 1) & 0x7) * 3) + 1];
							b = acCache[flag].color[(8*8*3)*i + (phase*8*3) + (((k >> 1) & 0x7) * 3) + 2];
							if(k & 1) {
								r += acCache[flag].color[(8*8*3)*i + (phase*8*3) + ((((k+1) >> 1) & 0x7) * 3) + 0];
								g += acCache[flag].color[(8*8*3)*i + (phase*8*3) + ((((k+1) >> 1) & 0x7) * 3) + 1];
								b += acCache[flag].color[(8*8*3)*i + (phase*8*3) + ((((k+1) >> 1) & 0x7) * 3) + 2];
								r /= 2.0; g /= 2.0; b /= 2.0;
							}
						}
						else {
							/* autocoloring, did not land on a known fixpoint.  Try to compute a color value anyway. */
							double total, dist;
							float R, G, B;
							int i;
							total = 0.0;
							for(i = 0; i < acCache[flag].used_entries; i++) {
								if(acCache[flag].x[i] == FSViewer_Infinity) continue;
								dist = (oX-acCache[flag].x[i])*(oX-acCache[flag].x[i]) + (oY-acCache[flag].y[i])*(oY-acCache[flag].y[i]);
								if(dist == 0.0) continue;
								total += 1.0 / dist;
							}
							if(total == 0.0) { r = g = b = 0.2; }
							else {
								R = G = B = 0.0;
								for(i = 0; i < acCache[flag].used_entries; i++) {
									if(acCache[flag].x[i] == FSViewer_Infinity) continue;
									dist = (oX-acCache[flag].x[i])*(oX-acCache[flag].x[i]) + (oY-acCache[flag].y[i])*(oY-acCache[flag].y[i]);
									if(dist == 0.0) continue;
									r = acCache[flag].color[(8*8*3)*i + (phase*8*3) + (((k >> 1) & 0x7) * 3) + 0];
									g = acCache[flag].color[(8*8*3)*i + (phase*8*3) + (((k >> 1) & 0x7) * 3) + 1];
									b = acCache[flag].color[(8*8*3)*i + (phase*8*3) + (((k >> 1) & 0x7) * 3) + 2];
									if(k & 1) {
										r += acCache[flag].color[(8*8*3)*i + (phase*8*3) + ((((k+1) >> 1) & 0x7) * 3) + 0];
										g += acCache[flag].color[(8*8*3)*i + (phase*8*3) + ((((k+1) >> 1) & 0x7) * 3) + 1];
										b += acCache[flag].color[(8*8*3)*i + (phase*8*3) + ((((k+1) >> 1) & 0x7) * 3) + 2];
										r /= 2.0; g /= 2.0; b /= 2.0;
									}
									dist = 1.0 / dist;
									R += r * (dist / total);
									G += g * (dist / total);
									B += b * (dist / total);
								}
								r = R; g = G; b = B;
							}
						}
					}
					c = (k & 0xf) / 15.0; 
					if(k & 0x10) c = 1.0 - c;
#else
					{ 
						double lograd, dphase, fr, fp, pi;
						pi = 3.1415926535897932385;
						lograd = (log(2.0 * log((double) (view -> maxRadius))) - log(log(oX*oX + oY*oY) / 2.0)) / log(3.0);
						dphase = 8.0 * (atan2(oY, oX) + pi) / (2.0 * pi);
						phase = (int) floor(dphase);
						fr = 1.0 - (lograd - floor(lograd));
						fp = 1.0 - (dphase - floor(dphase));
						r = g = b = 0.0;
						r += colorArray[(8*8*3)*flag + ((phase&7)*8*3) + ((k & 0x7) * 3) + 0] * fr * fp;
						g += colorArray[(8*8*3)*flag + ((phase&7)*8*3) + ((k & 0x7) * 3) + 1] * fr * fp;
						b += colorArray[(8*8*3)*flag + ((phase&7)*8*3) + ((k & 0x7) * 3) + 2] * fr * fp;
						r += colorArray[(8*8*3)*flag + ((phase&7)*8*3) + (((k+1) & 0x7) * 3) + 0] * (1.0 - fr) * fp;
						g += colorArray[(8*8*3)*flag + ((phase&7)*8*3) + (((k+1) & 0x7) * 3) + 1] * (1.0 - fr) * fp;
						b += colorArray[(8*8*3)*flag + ((phase&7)*8*3) + (((k+1) & 0x7) * 3) + 2] * (1.0 - fr) * fp;
						r += colorArray[(8*8*3)*flag + ((phase&7)*8*3) + ((k & 0x7) * 3) + 0] * fr * (1.0 - fp);
						g += colorArray[(8*8*3)*flag + ((phase&7)*8*3) + ((k & 0x7) * 3) + 1] * fr * (1.0 - fp);
						b += colorArray[(8*8*3)*flag + ((phase&7)*8*3) + ((k & 0x7) * 3) + 2] * fr * (1.0 - fp);
						r += colorArray[(8*8*3)*flag + ((phase&7)*8*3) + (((k+1) & 0x7) * 3) + 0] * (1.0 - fr) * (1.0 - fp);
						g += colorArray[(8*8*3)*flag + ((phase&7)*8*3) + (((k+1) & 0x7) * 3) + 1] * (1.0 - fr) * (1.0 - fp);
						b += colorArray[(8*8*3)*flag + ((phase&7)*8*3) + (((k+1) & 0x7) * 3) + 2] * (1.0 - fr) * (1.0 - fp);
					}
#endif
				}
				if(nodeChanged == YES) break;
				if((3 * x) + (y * 3 * xMax) + 2 < textureSize) {
					texture[(3 * x) + (y * 3 * xMax) + 0] = r;
					texture[(3 * x) + (y * 3 * xMax) + 1] = g;
					texture[(3 * x) + (y * 3 * xMax) + 2] = b;
				}
				else {
					Debug(@"thread %i tried to overrun the texture: textureSize is %i, tried %i\n", thisThread, textureSize, (3 * x) + (y * 3 * xMax));
				}
			}
			[acLock unlock];
			Y -= step;
			if(nodeChanged == YES) break;
		}

/*
		Debug(@"%i is aquiring glLock...\n", thisThread);
		[glLock lock];
		Debug(@"%i got it!\n", thisThread);
		[[self openGLContext] makeCurrentContext];
		Debug(@"A\n");
		glEnable(GL_TEXTURE_2D);
		Debug(@"B\n");
		glBindTexture(GL_TEXTURE_2D, subtextureHandle[thisThread]);
		Debug(@"C\n");
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		Debug(@"D\n");
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		Debug(@"E\n");
//		glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_DECAL);
		Debug(@"F\n");
//		glTexImage2D(GL_TEXTURE_2D, 0, 3, xMax, yMax, 0, GL_RGB, GL_FLOAT, subtexture[thisThread]);
	gluBuild2DMipmaps(GL_TEXTURE_2D, 3, xMax, yMax, GL_RGB, GL_FLOAT, subtexture[thisThread]);
		Debug(@"G\n");
		[glLock unlock];
		Debug(@"H\n");
*/	
	
		free(out);
		firstLoop = NO;

	if(nodeChanged) Debug(@"thread %i: quitting becaue node changed\n", thisThread);
	[subtextureLock[thisThread] unlock];
	Debug(@"thread %i: waiting for finishedLock\n", thisThread);
	[finishedLock lock]; 
	Debug(@"thread %i: holding the finishedLock, dropping it\n", thisThread);
	[finishedLock unlock];
	Debug(@"thread %i: dropped the finishedLock\n", thisThread);
	[syncLock lock];
	activeSubtasks |= (1 << (nTasks + thisThread));
	[syncLock unlock];
	[pool release];
	 }
}

- (void) viewDidEndLiveResize {
	[super viewDidEndLiveResize];
	Debug(@"viewDidEndLiveResize\n");
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

- (void) changeBatch: (int) batch to: (int) newBatch {
	NSEnumerator* objEnum;
	FSViewerObject* theObj;
	
	objEnum = [displayList objectEnumerator];
	while(theObj = [objEnum nextObject]) if([theObj batch] == batch) [theObj itemPtr] -> batch = newBatch;
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
/*
	NSImage* snap;
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
	if(view -> detailLevel == 2.0) for(j = 0; j < yMax; j+=2) {
		for(i = 0; i < xMax; i+=2) {
			r = texture[k+0]; g = texture[k+1];	b = texture[k+2];
			k += 3;
			r += texture[k+0]; g += texture[k+1]; b += texture[k+2];
			k += 3 * xMax;
			r += texture[k+0]; g += texture[k+1]; b += texture[k+2];
			k -= 3;
			r += texture[k+0]; g += texture[k+1]; b += texture[k+2];
			k -= 3 * xMax;
			c = [NSColor colorWithDeviceRed: r/4.0 green: g/4.0 blue: b/4.0 alpha: 1.0];
			[bitmap setColor: c atX: i/2 y: j/2];
			k += 6;
		}
		k += 3 * xMax;
	}
	else if(view -> detailLevel == 1.0) for(j = 0; j < yMax; j++) {
		for(i = 0; i < xMax; i++) {
			r = texture[k+0]; g = texture[k+1];	b = texture[k+2];
			c = [NSColor colorWithDeviceRed: r green: g blue: b alpha: 1.0];
			[bitmap setColor: c atX: i y: j];
			k += 3;
		}
	}
	else for(j = 0; j < yMax; j++) {
		for(i = 0; i < xMax; i++) {
			r = texture[k+0]; g = texture[k+1];	b = texture[k+2];
			c = [NSColor colorWithDeviceRed: r green: g blue: b alpha: 1.0];
			[bitmap setColor: c atX: 2*i y: 2*j];
			[bitmap setColor: c atX: 2*i+1 y: 2*j];
			[bitmap setColor: c atX: 2*i+1 y: 2*j+1];
			[bitmap setColor: c atX: 2*i y: 2*j+1];
			k += 3;			
		}
	}
	
	snap = [[[NSImage alloc] initWithData: [bitmap TIFFRepresentation]] autorelease];
	return snap;
*/
	unsigned char* planes[1];
	NSSize size;
	NSBitmapImageRep* bitmap;
	NSImage* image;
	NSMutableData* buffer;
	
	size = [self bounds].size;
	buffer = [NSMutableData dataWithLength:size.width*size.height*3];
	glReadBuffer(GL_BACK);
	glReadPixels(0, 0, size.width, size.height, GL_RGB, GL_UNSIGNED_BYTE, [buffer mutableBytes]);
	planes[0] = [buffer mutableBytes];
	bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: planes
		pixelsWide: size.width pixelsHigh: size.height bitsPerSample: 8
		samplesPerPixel: 3 hasAlpha: NO isPlanar: NO
		colorSpaceName: NSDeviceRGBColorSpace bytesPerRow: (size.width * 3)
		bitsPerPixel: 24
	];
	image = [[NSImage alloc] initWithSize: size];
	[image setFlipped:YES];
	[image lockFocus];
	[bitmap drawInRect: NSMakeRect(0, 0, size.width, size.height)];
	[image unlockFocus];
	return [image autorelease];
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

- (void) runAt: (double*) p into: (double*) result probe: (int) pr steps: (int) ns {
	double in[16];
	in[0] = p[0]; in[1] = p[1];
	in[2] = view -> aspectRatio;
	in[3] = view -> par[0]; in[4] = view -> par[1];
	in[5] = view -> pixelSize; 
	int length; int it;
	if(pr == 0) { length = 1; it = 1; }
	else { length = -pr; it = view -> maxIters; }
	it = ns;
	if(it > view -> maxIters) it = view -> maxIters;
	(view -> kernel)(view -> program, in, length, result, it, view -> maxRadius, view -> minRadius);
}

- (void) runAt: (double*) p into: (double*) result probe: (int) pr {
	double in[16];
	in[0] = p[0]; in[1] = p[1];
	in[2] = view -> aspectRatio;
	in[3] = view -> par[0]; in[4] = view -> par[1];
	in[5] = view -> pixelSize; 
	int length; int it;
	if(pr == 0) { length = 1; it = 1; }
	else { length = -pr; it = view -> maxIters; }
	(view -> kernel)(view -> program, in, length, result, it, view -> maxRadius, view -> minRadius);
}

- (void) draw: (int) nTraces tracesFrom: (NSPoint*) traceList steps: (int) nSteps {
	double p[2];
	double in[512], out[3], x, y;
	double sx, sy, ex, ey, lx, ly;
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
	for(i = 0; i < 512; i++) in[i] = setting[i];
	
	for(j = 0; j < nTraces; j++) {
		[self convertLocation: traceList[j] toPoint: p];
		in[0] = p[0];
		in[1] = p[1];
		in[2] = 0.0;
		in[3] = view -> par[0]; in[4] = view -> par[1];
		in[5] = view -> pixelSize;
	for(i = 0; i < nSteps; i++) {
		(view -> kernel)(k, in, 1, out, 1, view -> maxRadius, view -> minRadius);
		if(out[2] == -1) break;
		if((out[0] * out[0] + out[1] * out[1]) > (view -> maxRadius * view -> maxRadius)) break;
		p[0] = in[0]; p[1] = in[1];
		P = [self locationOfPoint: p];
//		P = [[self window] convertPoint: P fromView: self];
		sx = (2.0 * P.x  / [self bounds].size.width) - 1.0;
		sy = (2.0 * P.y / [self bounds].size.height) - 1.0;
		if((i > 0) && ([linesButton state] != NSOffState)) {
			glBegin(GL_LINES);
				glColor4f(wheel[j][0], wheel[j][1], wheel[j][2], 1.0);
				glVertex3f(lx, ly, -1.0);
				glColor4f(wheel[j][0], wheel[j][1], wheel[j][2], 1.0);
				glVertex3f(sx, sy, -1.0);
			glEnd();
		}
		lx = sx;  ly = sy;
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
				Debug(@"-drawObjects in FSViewer did not recognize object type %i\n", item -> type);
				break;
		}
	}
	glDisable(GL_BLEND);
}

- (void) setUsesFakeZoom: (BOOL) z { useFakeZoom = z; }

- zoomFrom: (double*) start to: (double*) end scalingFrom: (double) startSize to: (double) endSize {
	double p[2], q[2], t[2];
	int height, width;
	int i, j, k, s;
	float x, y, dx, dy, tw, th, zoom;

	if(useFakeZoom == NO) return;
	
	[self convertPoint: start toGL: p];
	[self convertPoint: end toGL: q];
	t[0] = q[0] - p[0]; t[1] = q[1] - p[1];
	zoom = startSize / endSize;
	t[0] *= -zoom;
	t[1] *= -zoom;
	
	
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
	
	glColor4f(0.0, 0.0, 0.0, 1.0);
	glBegin(GL_QUADS);
		glVertex3f(-1.0, -1.0, -0.5);
		glVertex3f(1.0, -1.0, -0.5);
		glVertex3f(1.0, 1.0, -0.5);
		glVertex3f(-1.0, 1.0, -0.5);
	glEnd();

	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glDisable(GL_BLEND);

	glEnable(GL_TEXTURE_RECTANGLE_EXT);
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, textureHandle);
		glColor4f(1.0, 1.0, 1.0, 1.0);
		glBegin(GL_QUADS);
			glTexCoord2d(0.0, 0.0); glVertex3f(-zoom + t[0], zoom + t[1], -0.5);
			glTexCoord2d(finalX, 0.0); glVertex3f(zoom + t[0], zoom + t[1], -0.5);
			glTexCoord2d(finalX, finalY); glVertex3f(zoom + t[0], -zoom + t[1], -0.5);
			glTexCoord2d(0.0, finalY); glVertex3f(-zoom + t[0], -zoom + t[1], -0.5);
		glEnd();	
	glDisable(GL_TEXTURE_RECTANGLE_EXT);

	
	glFlush();
	[glLock unlock];
}


- (void) drawTexture {
	glEnable(GL_TEXTURE_RECTANGLE_EXT);
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, textureHandle);
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
	Debug(@"eventManager is %@.  I am %@.\n", view -> eventManager, self);
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
