/*
 Manages named data sources provided by external tools and acts as glue to make these
 data sources (C arrays) available to FSKernels.
 */

#import <Cocoa/Cocoa.h>


@interface FSCustomDataManager : NSObject {
	NSMutableDictionary* dataDictionary;
	NSMutableDictionary* queryDictionary;
}

- (void) addDataNamed: (NSString*) name usingObject: (id) ob;
- (void) addQueryNamed: (NSString*) name usingObject: (id) ob;
- (void*) getFunctionPointerForQuery: (NSString*) name;
- (void*) getFunctionPointerForData: (NSString*) name;
- (NSDictionary*) dataDictionary;
- (NSDictionary*) queryDictionary;

@end
