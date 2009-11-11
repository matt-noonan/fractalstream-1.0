//
//  FSStartup.h
//  FractalStream
//
//  Created by Matthew Noonan on 2/3/09.
//  Copyright 2009 Cornell University. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FSStartup : NSObject {
	IBOutlet NSMenuItem* slsave;
	IBOutlet NSMenuItem* embedtool;
}

- (IBAction) openLibrary: (id) sender;

@end
