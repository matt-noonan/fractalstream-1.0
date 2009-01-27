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
		NSArray *names, *real, *imag, *probes;
		id tools;
		BOOL disableEditor;
}

+ (BOOL) usesMiniLoads;
+ (void) useMiniLoads: (BOOL) ml;
- (NSString*) type;
- (FSSession*) session;
- (NSArray*) editor;
- (NSArray*) minidata;
- (FSColorWidget*) colorizer;
- (NSArray*) variableNames;
- (NSArray*) variableReal;
- (NSArray*) variableImag;
- (NSArray*) probeNames;
- (BOOL) allowEditor;
- (BOOL) hasTools;
- (NSFileWrapper*) customTools;
- (void) setType: (NSString*) newType session: (FSSession*) sess colorizer: (FSColorWidget*) col editor: (FSEController*) edit browser: (FSBrowser*) browser;

- (void) encodeWithCoder: (NSCoder*) coder;
- (id) initWithCoder: (NSCoder*) coder;

@end
