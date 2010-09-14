
/* FSViewer represents an NSView which can display images of dynamical systems */


#import "FSViewer.h"


@implementation FSViewer

- (void) awakeFromNib {
	scale = 1.0;
	panX = panY = 0;
	savedBackground = nil;
//	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"CGEnableBuiltin"]; 
	[[NSNotificationCenter defaultCenter]
		addObserver: self
		selector: @selector(dynamicsImageUpdatedHandler:)
		name: @"Dynamics image updated"
		object: dynamics
	];
	[[NSNotificationCenter defaultCenter]
	 addObserver: self
	 selector: @selector(sceneChangedHandler:)
	 name: @"Scene changed"
	 object: interaction
	 ];
	
#ifndef WINDOWS
	[self setAcceptsTouchEvents: YES];
	followingTouches = NO;
	panningTouches = NO;
#endif	
	
}

- (void) panByX: (double) x Y: (double) y {
	panX += x; panY += y; [self setNeedsDisplay: YES];
}
- (void) scaleBy: (double) factor fromX: (double) x Y: (double) y { 
	NSPoint p;
	if(factor < 0.0) return;
	p = [self convertPoint: NSMakePoint(x,y) fromView: nil];
	scale *= factor;
	panX += (factor - 1.0) * (panX - p.x);
	panY += (factor - 1.0) * (panY - p.y);
	[self setNeedsDisplay: YES];
}
- (void) resetPanAndScale { [self resetPanAndScaleNoDisplayUpdate]; [self setNeedsDisplay: YES]; }
- (void) resetPanAndScaleNoDisplayUpdate { scale = 1.0; panX = 0.0; panY = 0.0;  }

- (double) panX { return panX; }
- (double) panY { return panY; }
- (double) scale { return scale; }

- (void) dynamicsImageUpdatedHandler: (NSNotification*) note {
	[self setNeedsDisplay: YES]; // does this always run on the right thread?
}
- (void) sceneChangedHandler: (NSNotification*) note {
	if(savedBackground) [savedBackground release];
	savedBackground = [[dynamics image] retain];
	savedPanX = panX; savedPanY = panY; savedScale = scale;
	[self resetPanAndScaleNoDisplayUpdate];	
	[self drawScene: [[note object] scene]];
}

- (void) mouseEntered: (NSEvent*) theEvent {
	if(interaction != nil) {
		[[self window] setAcceptsMouseMovedEvents: YES];
		[interaction mouseEntered: theEvent];
	}
}
- (void) mouseExited: (NSEvent*) theEvent {
	if(interaction != nil) {
		[[self window] setAcceptsMouseMovedEvents: NO];
		[interaction mouseExited: theEvent];
	}
}
- (void) mouseMoved: (NSEvent*) theEvent { if(interaction != nil) [interaction mouseMoved: theEvent]; }
- (void) mouseDragged: (NSEvent*) theEvent { if(interaction != nil) [interaction mouseDragged: theEvent]; }
- (void) rightMouseDragged: (NSEvent*) theEvent { if(interaction != nil) [interaction rightMouseDragged: theEvent]; }
- (void) mouseUp: (NSEvent*) theEvent { if(interaction != nil) [interaction mouseUp: theEvent]; }
- (void) rightMouseUp: (NSEvent*) theEvent { if(interaction != nil) [interaction rightMouseUp: theEvent]; }
- (void) mouseDown: (NSEvent*) theEvent { if(interaction != nil) [interaction mouseDown: theEvent]; }
- (void) rightMouseDown: (NSEvent*) theEvent { if(interaction != nil) [interaction rightMouseDown: theEvent]; }
- (void) scrollWheel: (NSEvent*) theEvent { if(interaction != nil) [interaction scrollWheel: theEvent]; }

#ifndef WINDOWS
- (void) magnifyWithEvent: (NSEvent *) theEvent {
	followingTouches = YES;
	if(panningTouches == NO)
		[self scaleBy: 1.0 + [theEvent magnification]*2.0 fromX: [theEvent locationInWindow].x Y: [theEvent locationInWindow].y];
}

- (void) touchesBeganWithEvent: (NSEvent*) event {
}

- (void) touchesMovedWithEvent: (NSEvent*) event {
 double dx, dy;
	if([event type] == NSEventTypeGesture) {
		if(([event subtype] & NSTouchPhaseMoved) && ([event subtype] & NSTouchPhaseStationary)) {
			NSArray* touches = [[event touchesMatchingPhase: NSTouchPhaseTouching inView: self] allObjects];
			if(touches.count == 2) {
				if(followingTouches == NO) {
					followingTouches = YES;
					panningTouches = YES;
					initialTouchLocation[0] = 0.5 * (((NSTouch*)[touches objectAtIndex: 0]).normalizedPosition.x + ((NSTouch*)[touches objectAtIndex: 1]).normalizedPosition.x);
					initialTouchLocation[1] = 0.5 * (((NSTouch*)[touches objectAtIndex: 0]).normalizedPosition.y + ((NSTouch*)[touches objectAtIndex: 1]).normalizedPosition.y);
				}
				else if(panningTouches == YES) {
					dx = 0.5 * (((NSTouch*)[touches objectAtIndex: 0]).normalizedPosition.x + ((NSTouch*)[touches objectAtIndex: 1]).normalizedPosition.x) - initialTouchLocation[0];
					dy = 0.5 * (((NSTouch*)[touches objectAtIndex: 0]).normalizedPosition.y + ((NSTouch*)[touches objectAtIndex: 1]).normalizedPosition.y) - initialTouchLocation[1];
					initialTouchLocation[0] = 0.5 * (((NSTouch*)[touches objectAtIndex: 0]).normalizedPosition.x + ((NSTouch*)[touches objectAtIndex: 1]).normalizedPosition.x);
					initialTouchLocation[1] = 0.5 * (((NSTouch*)[touches objectAtIndex: 0]).normalizedPosition.y + ((NSTouch*)[touches objectAtIndex: 1]).normalizedPosition.y);
					[self panByX: -dx*1000.0 Y: -dy*1000.0];
				}
			}
		}
	}
}

- (void) touchesEndedWithEvent: (NSEvent*) event {
	if(followingTouches) {
		NSLog(@"end of touch\n");
		[interaction sendSceneNotification];
		followingTouches = NO;
		panningTouches = NO;
	}
}

- (void) touchesCancelledWithEvent: (NSEvent*) event {
}

- (void) swipeWithEvent: (NSEvent*) event {
}
#endif


- (void) drawScene: (FSScene*) scene  {
	[self performSelectorOnMainThread: @selector(drawSceneOnMainThread:) withObject: scene waitUntilDone: YES];
}

- (void) drawSceneOnMainThread: (FSScene*) scene {
	FSKernelData data;
	double aspect_ratio;
	
	data.z[0] = [scene center][0] - [self bounds].size.width * [scene pixelSize][0] / 2.0; 
	data.z[1] = [scene center][1] - [self bounds].size.height * [scene pixelSize][1] / 2.0; 
	data.dim[0] = [self bounds].size.width; data.dim[1] = [self bounds].size.height;
	aspect_ratio = (double) data.dim[1] / (double) data.dim[0];
	data.dz[0] = [scene pixelSize][0]; data.dz[1] = [scene pixelSize][1];
//	if([scene isConformal]) data.dz[1] = data.dz[0] * aspect_ratio;
	data.kernel = [scene kernel];
	NSLog(@"drawing scene, parameters are %@\n", [scene parameters]);
	data.parameters = [scene parameters];
	data.plane = [scene plane];
	data.bitmap = [dynamics getBitmapWithWidth: data.dim[0] height: data.dim[1]];
	data.batch = [dynamics getBatchIdentifier];
	data.manager = data.owner = dynamics;
	[workManager processData: data];
}

- (void) drawRect: (NSRect) rect {
	NSImage* background;
	
	background = [dynamics image];

	[[NSColor grayColor] set];
	NSRectFill([self bounds]);
	if(savedBackground) {
		[savedBackground 
						 drawInRect: NSMakeRect(panX+scale*savedPanX,panY+scale*savedPanY,scale*savedScale*[savedBackground size].width, scale*savedScale*[savedBackground size].height)
						   fromRect: NSZeroRect
						  operation: NSCompositeCopy
						   fraction: 1.0
		 ];
	}
	if(background) {
		[background 
		 drawInRect: NSMakeRect(panX,panY,scale*[background size].width, scale*[background size].height)
			fromRect: NSZeroRect
			operation: NSCompositeSourceOver
			fraction: 1.0
		 ];

	}
}

- (FSComplexNumber*) coordinateOfWindowLocation: (NSPoint) p forScene: (FSScene*) scene {
	double z[2];
	z[0] =  [scene center][0] + (p.x - panX - [self bounds].size.width / 2.0) * [scene pixelSize][0]/scale;
	z[1] = -[scene center][1] + (p.y - panY - [self bounds].size.height / 2.0) * [scene pixelSize][1]/scale;
	return [[[FSComplexNumber alloc] initWithReal: z[0] imag: z[1]] autorelease];
}

@end
