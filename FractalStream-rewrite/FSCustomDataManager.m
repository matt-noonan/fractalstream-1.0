
#import "FSCustomDataManager.h"


@implementation FSCustomDataManager

- (id) init {
	self = [super init];
	dataDictionary = [[NSMutableDictionary alloc] init];
	queryDictionary = [[NSMutableDictionary alloc] init];
	return self;
}

- (void) addDataNamed: (NSString*) name usingObject: (id) ob {
	NSLog(@"adding data source named %@\n", name);
	[dataDictionary setObject: ob forKey: name];
	[[NSNotificationCenter defaultCenter] postNotificationName: @"FSCustomDataAdded" object: self];
}

- (void) addQueryNamed: (NSString*) name usingObject: (id) ob {
	[queryDictionary setObject: ob forKey: name];
}

- (void*) getFunctionPointerForQuery: (NSString*) name {
	id ob;
	ob = [queryDictionary objectForKey: name];
	if([ob respondsToSelector: @selector(queryNamed:)]) return [ob queryNamed: name];
	return NULL;
}

- (void*) getFunctionPointerForMerge: (NSString*) name {
	id ob;
	ob = [dataDictionary objectForKey: name];
	if([ob respondsToSelector: @selector(queryNamed:)]) return [ob queryNamed: name];
	return NULL;
}

- (void*) getFunctionPointerForData: (NSString*) name {
	// returns a pointer to a function of type int(double* in, double* out)
	id ob;
//	NSLog(@"dataManager (%@): somebody is requesting a data source named \"%@\"\n", self, name);
	ob = [dataDictionary objectForKey: name];
//	NSLog(@"ob is %@\n", ob);
	if([ob respondsToSelector: @selector(dataNamed:)]) {
//		NSLog(@"responds to selector\n");
		return [ob dataNamed: name];
	}
//	NSLog(@"!!!! does not respond to selector ????\n");
	return NULL;	
}

- (void*) getFunctionPointerForEval: (NSString*) name {
	id ob;
	ob = [dataDictionary objectForKey: name];
	if([ob respondsToSelector: @selector(evalNamed:)]) {
		return [ob evalNamed: name];
	}
	return NULL;	
}

- (NSDictionary*) dataDictionary {
	return [NSDictionary dictionaryWithDictionary: dataDictionary];
}

- (NSDictionary*) queryDictionary {
	return [NSDictionary dictionaryWithDictionary: queryDictionary];
}

@end
