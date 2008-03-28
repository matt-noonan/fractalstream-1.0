//
//  FSViewManager.h
//  FractalStream
//
//  Created by Matt Noonan on 4/14/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FSSession.h"
#import "FSViewport.h"

@interface FSViewManager : NSObject {

	IBOutlet FSSession* session;
	IBOutlet FSViewport* viewport;
	
}

- (IBAction) updateViewport: (id) sender;

@end
