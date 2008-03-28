//
//  FSSave.h
//  FractalStream
//
//  Created by Matt Noonan on 2/10/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FSColorWidget.h"
#import "FSSession.h"
#import "FSEController.h"
#import "FSBrowser.h"

@interface FSSave : NSObject <NSCoding> {
		NSString* type;
		FSSession* session;
		NSArray* editor;
		FSColorWidget* colorizer;
		FSBrowser* browser;
		NSArray *names, *real, *imag;
}

- (NSString*) type;
- (FSSession*) session;
- (NSArray*) editor;
- (FSColorWidget*) colorizer;
- (NSArray*) variableNames;
- (NSArray*) variableReal;
- (NSArray*) variableImag;
- (void) setType: (NSString*) newType session: (FSSession*) sess colorizer: (FSColorWidget*) col editor: (FSEController*) edit browser: (FSBrowser*) browser;

- (void) encodeWithCoder: (NSCoder*) coder;
- (id) initWithCoder: (NSCoder*) coder;

@end
