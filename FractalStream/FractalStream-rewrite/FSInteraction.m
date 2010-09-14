
/* Responsible for handing events in the viewer and routing to tools */

#import "FSInteraction.h"
#import "FSKernelData.h"

@implementation FSInteraction

- (id) init {
	self = [super init];

	manager = [[FSWorkerManager alloc] init];
	kernel = [[FSKernel alloc] init];
	scene = [[FSScene alloc] init];
	[scene setKernel: kernel centerX: 0.0 Y: 0.0 scale: 1/128.0];
	return self;
}

- (void) dealloc {
	[manager release];
	[super dealloc];
}

- (void) mouseDragged: (NSEvent*) theEvent { 
	ignoreNextMouseUp = NO;
	[viewer panByX: [theEvent deltaX] Y: -[theEvent deltaY]];
	[viewer setNeedsDisplay: YES];
}
- (void) rightMouseDragged: (NSEvent*) theEvent {
	double dlambda;
	dlambda = 0.01 * [theEvent deltaY];
	if(dlambda < -0.999) dlambda = -0.999;
	if(dlambda > 0.999) dlambda = 0.999;
	[viewer 
		scaleBy: 1.0 + dlambda
		fromX: lastRightMouseDown.x
		Y: lastRightMouseDown.y
	];
	[viewer setNeedsDisplay: YES];
}

- (void) scrollWheel: (NSEvent*) theEvent {

}

- (void) mouseDown: (NSEvent*) theEvent {
	lastMouseDown = [theEvent locationInWindow];
	if([theEvent clickCount] == 2) {
		ignoreNextMouseUp = YES;
		FSComplexNumber* Z = [viewer coordinateOfWindowLocation: [theEvent locationInWindow] forScene: scene];
		NSLog(@"double click at z = %f + %f i\n", [Z realPart], [Z imagPart]);
	}
}
- (void) rightMouseDown: (NSEvent*) theEvent {
	lastRightMouseDown = [theEvent locationInWindow];
}

- (void) mouseUp: (NSEvent*) theEvent {
	if(ignoreNextMouseUp) {
		ignoreNextMouseUp = NO;
		return;
	}
	[self sendSceneNotification];
}

- (void) rightMouseUp: (NSEvent*) theEvent {
	[self sendSceneNotification];
}

- (void) sendSceneNotification {
	double panX, panY, scale, dx, dy;
	double z[2];
	panX = [viewer panX]; panY = [viewer panY]; scale = [viewer scale];
	dx = [viewer bounds].size.width / 2.0 - (panX + [viewer bounds].size.width * scale / 2.0);
	dy = [viewer bounds].size.height / 2.0 - (panY + [viewer bounds].size.height * scale / 2.0);
	z[0] = [scene center][0] + dx * [scene pixelSize][0] / scale;
	z[1] = [scene center][1] - dy * [scene pixelSize][1] / scale;
	[scene setKernel: [scene kernel] centerX: z[0] Y: z[1] scale: [scene pixelSize][0]/scale];
	[[NSNotificationCenter defaultCenter] 
		postNotificationName: @"Scene changed"
		object: self
	];
}

- (FSScene*) scene { return scene; }


- (IBAction) runDynamics: (id) sender {
	FSKernelData data;
	
	data.batch = [dynamics getBatchIdentifier];
	data.z[0] = -2.0;
	data.z[1] = 2.0;
	
	
	data.dim[0] = (int)[viewer bounds].size.width;
	data.dim[1] = (int)[viewer bounds].size.height;
	data.bitmap = [dynamics getBitmapWithWidth: data.dim[0] height: data.dim[1]];
	
	data.dz[0] = 4.0 / (double) data.dim[0];
	data.dz[1] = - 4.0 / (double) data.dim[1];


	data.manager = data.owner = dynamics;
	[manager processData: data];
}

@end
