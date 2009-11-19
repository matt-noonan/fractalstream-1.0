//
//  FSColorizer.m
//  FractalStream
//
//  Created by Matt Noonan on 1/15/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "FSColorizer.h"


@implementation FSColorizer

- (id) init {
	FSGradient* gradient;
	FSColor* color;
	self = [super init];
	colorArray = nil;
	return self;
}

- (void) dealloc {
	//free(acCache);
	[super dealloc];
}

- (void) setColorWidget: (FSColorWidget*) picker autocolorCache: (FSViewer_Autocolor_Cache*) acc {
	acCache = acc;
	colorPicker = picker;
}

- (void) setColorArray: (NSArray*) colors { colorArray = colors; }

- (void) setCurrentBatch: (int) cb {
	synchronizeTo(colorArray) { currentBatch = cb; }
}


- (void) colorUnit: (FSRenderUnit*) unit {
	unsigned char* texture;
	double oX, oY;
	int k;
	int x, y, flag, sd, i, j;
	float r, g, b, or, og, ob;
	double loglog, golgol;
	int phase;
	int xMax, yMax;
//	float* colorArray;
	int* smoothness;
//	id gradient;
	FSColor* col;
	int index, offset;
	NSColor* c;
	FSGradient* gradient;
	FSColorCache* cache;
	double nearR, farR;
	int prog;
	
	if((unit->batch) != currentBatch) return;
	
	texture = (unsigned char*) (unit -> result);   /**** have to mix down to 8-bit integer with NSBitmapImageRep?? ***/
	xMax = unit -> dimension[0];
	yMax = unit -> dimension[1];
	colorArray = [colorPicker colorArray];
	//	smoothness = [colorPicker smoothnessPtr];
	farR = (unit -> viewerData) -> maxRadius;
	nearR = (unit -> viewerData) -> minRadius;
	nearR *= nearR; farR *= farR;
	prog = (unit -> viewerData) -> program;

	cache = [colorPicker getColorCache];

	
	if(cache -> needsLock && (unit -> parametric == NO)) {		// grab a lock, color cache could change while we work.
		colorArray = [colorPicker colorArray];
		synchronizeTo(colorArray) {
			cache = [colorPicker getColorCache];
			[cache -> lock lock];
			[cache -> lock unlockWithCondition: 0];	// mutex lock for autocolor code means the condition lock is irrelevant
			for(y = 0; y < yMax; y++) {
				for(x = 0; x < xMax; x++) {
					oX = (unit -> result)[(3*xMax*y) + (3*x) + 0];
					oY = (unit -> result)[(3*xMax*y) + (3*x) + 1];
					k = (int) ((unit -> result)[(3*xMax*y) + (3*x) + 2]);
					flag = k & 0xff;  flag &= 0x0f;
					k >>= 8;
					
					if(k == -1) { r = g = b = 1.0; }
					else if((flag >= 64) || (flag >= cache -> totalColors)) { r = g = b = 0.7; }
					else if(k == (unit -> viewerData) -> maxIters) { 
						r = g = b = 0.0;
					}
					else {
						index = cache -> colorIndex[flag];
						sd = cache -> subdivisions[flag];
						if(sd <= 0) sd = 1;
						if(cache -> usesAutocolor[flag] && (cache -> locked[flag] || unit -> parametric)) {
							// Autocolor by blending
							double weight, d, w[512];
							weight = 0.0;
							for(i = 0; i < cache -> subcolors[flag]; i++) {
								d = ((oX - cache->X[cache->locationIndex[flag]+i])*(oX - cache->X[cache->locationIndex[flag]+i]) + (oY - cache->Y[cache->locationIndex[flag]+i])*(oY - cache->Y[cache->locationIndex[flag]+i]));
								if(d < 0.000001) d = 0.000001;
								w[i] = 1.0 / d;
								weight += 1.0 / d;
							}
							// make blended gradient
							if(0) {
							}
							else {
								r = g = b = 0.0;
								offset = 3*(k % sd);
								for(i = 0; i < cache -> subcolors[flag]; i++) {
									r += cache->color[index + (1+i)*3*sd + offset + 0] * w[i] / weight;
									g += cache->color[index + (1+i)*3*sd + offset + 1] * w[i] / weight;
									b += cache->color[index + (1+i)*3*sd + offset + 2] * w[i] / weight;
								}
							}
						}
						else if(cache -> usesAutocolor[flag]) {
							// Autocolor and allow new fixed points
							double d, D;
							D = (unit->viewerData)->minRadius; D = D*D;
							for(i = 0; i < cache -> subcolors[flag]; i++) {
								d = ((oX - cache->X[cache->locationIndex[flag]+i])*(oX - cache->X[cache->locationIndex[flag]+i]) + (oY - cache->Y[cache->locationIndex[flag]+i])*(oY - cache->Y[cache->locationIndex[flag]+i]));
								if(d < D) break;
							}
							if(i == cache -> subcolors[flag]) {
								// make a new autocolor
								if(oX*oX + oY*oY < (unit->viewerData)->maxRadius*(unit->viewerData)->maxRadius) {
									[[[colorPicker colorArray] objectAtIndex: flag] createNewSubcolorForX: oX Y: oY];
									[colorPicker makeColorCache];
									cache = [colorPicker getColorCache];
									for(i = 0; i < cache -> subcolors[flag]; i++) {
										d = ((oX - cache->X[cache->locationIndex[flag]+i])*(oX - cache->X[cache->locationIndex[flag]+i]) + (oY - cache->Y[cache->locationIndex[flag]+i])*(oY - cache->Y[cache->locationIndex[flag]+i]));
										if(d < D) break;
									}
									if(i == cache -> subcolors[flag]) {
										// failed to make a new color, must have run out.  Use the base gradient.
										i = -1;
									}
								}
								else { 
									[[[colorPicker colorArray] objectAtIndex: flag] setHasInfinity: YES];
									i = -1;
								}
							}
							index = cache -> colorIndex[flag];
							sd = cache -> subdivisions[flag];
							if(sd <= 0) sd = 1;
							if(0) {
							}
							else {
								offset = 3*(k % sd);
								r = cache->color[index + (1+i)*3*sd + offset + 0];
								g = cache->color[index + (1+i)*3*sd + offset + 1];
								b = cache->color[index + (1+i)*3*sd + offset + 2];
							}							
						}
						else {
							if(cache -> smoothing[flag] > 0  && (oX*oX + oY*oY > 2.0)) {
								loglog = (double)k + 
								(log(2.0 * log((double) ((unit -> viewerData)->maxRadius)))
								 - log(log(oX*oX + oY*oY) / 2.0)) / log((double) cache -> smoothing[flag]);
								k = (int) loglog;
								loglog = loglog - floor(loglog);
								offset = 3*((k+1) % sd);
								r = loglog*cache->color[index + offset + 0]; g = loglog*cache->color[index + offset + 1]; b = loglog*cache->color[index + offset +  2];
								loglog = 1.0 - loglog;
								offset = 3*(k % sd);
								r += loglog*cache->color[index + offset + 0]; g += loglog*cache->color[index + offset +  1]; b += loglog*cache->color[index + offset +  2];
							}
							else {
								offset = 3*(k % sd);
								r = cache -> color[index + offset + 0];
								g = cache -> color[index + offset + 1];
								b = cache -> color[index + offset + 2];
							}
						}
					}
					if(r > 1.0) r = 1.0; if(g > 1.0) g = 1.0; if(b > 1.0) b = 1.0;
					if(r < 0.0) r = 0.0; if(g < 0.0) g = 0.0; if(b < 0.0) b = 0.0;
#ifndef WINDOWS
					((unsigned char*) unit -> result)[(4 * x) + (y * 4 * xMax) + 0] = (unsigned char)(255.0 * r + 0.5);
					((unsigned char*) unit -> result)[(4 * x) + (y * 4 * xMax) + 1] = (unsigned char)(255.0 * g + 0.5);
					((unsigned char*) unit -> result)[(4 * x) + (y * 4 * xMax) + 2] = (unsigned char)(255.0 * b + 0.5);
#else
					((unsigned char*) unit -> result)[(3 * x) + (y * 3 * xMax) + 0] = (unsigned char)(255.0 * r + 0.5);
					((unsigned char*) unit -> result)[(3 * x) + (y * 3 * xMax) + 1] = (unsigned char)(255.0 * g + 0.5);
					((unsigned char*) unit -> result)[(3 * x) + (y * 3 * xMax) + 2] = (unsigned char)(255.0 * b + 0.5);
#endif					
				}
			}			
		}
	}
	else {
		cache = [colorPicker getColorCache];
		[cache -> lock lock];
		[cache -> lock unlockWithCondition: [cache -> lock condition] + 1];
		for(y = 0; y < yMax; y++) {
			for(x = 0; x < xMax; x++) {
				oX = (unit -> result)[(3*xMax*y) + (3*x) + 0];
				oY = (unit -> result)[(3*xMax*y) + (3*x) + 1];
				k = (int) ((unit -> result)[(3*xMax*y) + (3*x) + 2]);
				flag = k & 0xff;  flag &= 0x0f;
				k >>= 8;
				
				if(k == -1) { r = g = b = 1.0; }
				else if((flag >= 64) || (flag >= cache -> totalColors)) { r = g = b = 0.7; }
				else if(k == (unit -> viewerData) -> maxIters) { 
					r = g = b = 0.0;
				}
				else {
					index = cache -> colorIndex[flag];
					sd = cache -> subdivisions[flag];
					if(sd <= 0) sd = 1;
					if(cache -> usesAutocolor[flag]) {
						double weight, d, w[512];
						weight = 0.0;
						for(i = 0; i < cache -> subcolors[flag]; i++) {
							d = ((oX - cache->X[cache->locationIndex[flag]+i])*(oX - cache->X[cache->locationIndex[flag]+i]) + (oY - cache->Y[cache->locationIndex[flag]+i])*(oY - cache->Y[cache->locationIndex[flag]+i]));
							if(d < 0.000001) d = 0.000001;
							w[i] = 1.0 / d;
							weight += 1.0 / d;
						}
						// make blended gradient
						if(0) {
						}
						else {
							r = g = b = 0.0;
							offset = 3*(k % sd);
							for(i = 0; i < cache -> subcolors[flag]; i++) {
								r += cache->color[index + (1+i)*3*sd + offset + 0] * w[i] / weight;
								g += cache->color[index + (1+i)*3*sd + offset + 1] * w[i] / weight;
								b += cache->color[index + (1+i)*3*sd + offset + 2] * w[i] / weight;
							}
						}
					}
					else {
						if(cache -> smoothing[flag] > 0 && (oX*oX + oY*oY > 2.0)) {
							loglog = (double)k + 
							(log(2.0 * log((double) ((unit -> viewerData)->maxRadius)))
							 - log(log(oX*oX + oY*oY) / 2.0)) / log((double) cache -> smoothing[flag]);
							k = (int) loglog;
							loglog = loglog - floor(loglog);
							offset = 3*((k+1) % sd);
							r = loglog*cache->color[index + offset + 0]; g = loglog*cache->color[index + offset + 1]; b = loglog*cache->color[index + offset +  2];
							loglog = 1.0 - loglog;
							offset = 3*(k % sd);
							r += loglog*cache->color[index + offset + 0]; g += loglog*cache->color[index + offset +  1]; b += loglog*cache->color[index + offset +  2];
						}
						else {
							offset = 3*(k % sd);
							r = cache -> color[index + offset + 0];
							g = cache -> color[index + offset + 1];
							b = cache -> color[index + offset + 2];
						}
					}
				}
				if(r > 1.0) r = 1.0; if(g > 1.0) g = 1.0; if(b > 1.0) b = 1.0;
				if(r < 0.0) r = 0.0; if(g < 0.0) g = 0.0; if(b < 0.0) b = 0.0;
#ifndef WINDOWS
				((unsigned char*) unit -> result)[(4 * x) + (y * 4 * xMax) + 0] = (unsigned char)(255.0 * r + 0.5);
				((unsigned char*) unit -> result)[(4 * x) + (y * 4 * xMax) + 1] = (unsigned char)(255.0 * g + 0.5);
				((unsigned char*) unit -> result)[(4 * x) + (y * 4 * xMax) + 2] = (unsigned char)(255.0 * b + 0.5);
#else
				((unsigned char*) unit -> result)[(3 * x) + (y * 3 * xMax) + 0] = (unsigned char)(255.0 * r + 0.5);
				((unsigned char*) unit -> result)[(3 * x) + (y * 3 * xMax) + 1] = (unsigned char)(255.0 * g + 0.5);
				((unsigned char*) unit -> result)[(3 * x) + (y * 3 * xMax) + 2] = (unsigned char)(255.0 * b + 0.5);
#endif					
			}
		}
		[cache -> lock lock];
		[cache -> lock unlockWithCondition: [cache -> lock condition] - 1];
	}
}




	
/*
	synchronizeTo(colorPicker) {
		for(y = 0; y < yMax; y++) {
			for(x = 0; x < xMax; x++) {
				oX = (unit -> result)[(3*xMax*y) + (3*x) + 0];
				oY = (unit -> result)[(3*xMax*y) + (3*x) + 1];
				k = (int) ((unit -> result)[(3*xMax*y) + (3*x) + 2]);
				flag = k & 0xff;  flag &= 0x0f;
				k >>= 8;
				
				if(k == -1) { r = g = b = 1.0; }
				else if(flag >= 64) { r = g = b = 0.7; }
				else if(k == (unit -> viewerData) -> maxIters) { 
					r = g = b = 0.0;
				}
				else {
					BOOL useGrey;
					if(smoothness[flag]) {
						if(smoothness[flag] > 0)
							loglog = (double)k + 
								(log(2.0 * log((double) ((unit -> viewerData)->maxRadius)))
								- log(log(oX*oX + oY*oY) / 2.0)) / log((double) smoothness[flag]);
						else
							loglog = (double)k + 
								(log(2.0 * log((double) ((unit -> viewerData)->minRadius)))
								- log(log(1.0/(oX*oX + oY*oY)) / 2.0)) / log((double) -smoothness[flag]); // crappy
						k = (int) loglog;
						loglog = loglog - floor(loglog);
						golgol = 1.0 - loglog;
					}
					phase = 0;
					if((oX > 0.0) && (oY > 0.0)) phase = 0;
					if((oX < 0.0) && (oY > 0.0)) phase = 2;
					if((oX < 0.0) && (oY < 0.0)) phase = 4;
					if((oX > 0.0) && (oY < 0.0)) phase = 6;
					if(((phase & 2)) && ((oY * oY) < (oX * oX))) phase += 1;
					else if(((phase & 2) == 0) && ((oX * oX) < (oY * oY))) phase += 1; 

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
						if(smoothness[flag]) {
							++k; or = r; og = g; ob = b;
							r = colorArray[(8*8*3)*flag + (phase*8*3) + (((k >> 1) & 0x7) * 3) + 0];
							g = colorArray[(8*8*3)*flag + (phase*8*3) + (((k >> 1) & 0x7) * 3) + 1];
							b = colorArray[(8*8*3)*flag + (phase*8*3) + (((k >> 1) & 0x7) * 3) + 2];
							if(k & 1) {
								r += colorArray[(8*8*3)*flag + (phase*8*3) + ((((k+1) >> 1) & 0x7) * 3) + 0];
								g += colorArray[(8*8*3)*flag + (phase*8*3) + ((((k+1) >> 1) & 0x7) * 3) + 1];
								b += colorArray[(8*8*3)*flag + (phase*8*3) + ((((k+1) >> 1) & 0x7) * 3) + 2];
								r /= 2.0; g /= 2.0; b /= 2.0;
							}
							--k;
							r = golgol*or + loglog*r;
							g = golgol*og + loglog*g;
							b = golgol*ob + loglog*b;
						}
					}
					else {
						int i;
						i = 0;
						useGrey = NO;
						if(acCache[flag].used_entries > 0) for(i = 0; i < acCache[flag].used_entries; i++) {
							if(((oX - acCache[flag].x[i])*(oX - acCache[flag].x[i]) + (oY - acCache[flag].y[i])*(oY - acCache[flag].y[i])) < nearR) break;
							if((acCache[flag].x[i] == FSViewer_Infinity) && ((oX*oX + oY*oY) > farR)) break;
						}
						if(i == acCache[flag].used_entries) {
							{ // used to synch to colorPicker
								int acCount;

								if(acCache[flag].locked || (prog == 1)) useGrey = YES;
								else if(acCache[flag].used_entries < 16) {
								
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
							}
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
							if(smoothness[flag]) {
								++k; or = r; og = g; ob = b;
								r = acCache[flag].color[(8*8*3)*i + (phase*8*3) + (((k >> 1) & 0x7) * 3) + 0];
								g = acCache[flag].color[(8*8*3)*i + (phase*8*3) + (((k >> 1) & 0x7) * 3) + 1];
								b = acCache[flag].color[(8*8*3)*i + (phase*8*3) + (((k >> 1) & 0x7) * 3) + 2];
								if(k & 1) {
									r += acCache[flag].color[(8*8*3)*i + (phase*8*3) + ((((k+1) >> 1) & 0x7) * 3) + 0];
									g += acCache[flag].color[(8*8*3)*i + (phase*8*3) + ((((k+1) >> 1) & 0x7) * 3) + 1];
									b += acCache[flag].color[(8*8*3)*i + (phase*8*3) + ((((k+1) >> 1) & 0x7) * 3) + 2];
									r /= 2.0; g /= 2.0; b /= 2.0;
								}
								--k;
								r = golgol*or + loglog*r;
								g = golgol*og + loglog*g;
								b = golgol*ob + loglog*b;
							}
						}
						else {
							double total, dist;
							float R, G, B;
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
									if(smoothness[flag]) {
										++k; or = r; og = g; ob = b;
										r = acCache[flag].color[(8*8*3)*i + (phase*8*3) + (((k >> 1) & 0x7) * 3) + 0];
										g = acCache[flag].color[(8*8*3)*i + (phase*8*3) + (((k >> 1) & 0x7) * 3) + 1];
										b = acCache[flag].color[(8*8*3)*i + (phase*8*3) + (((k >> 1) & 0x7) * 3) + 2];
										if(k & 1) {
											r += acCache[flag].color[(8*8*3)*i + (phase*8*3) + ((((k+1) >> 1) & 0x7) * 3) + 0];
											g += acCache[flag].color[(8*8*3)*i + (phase*8*3) + ((((k+1) >> 1) & 0x7) * 3) + 1];
											b += acCache[flag].color[(8*8*3)*i + (phase*8*3) + ((((k+1) >> 1) & 0x7) * 3) + 2];
											r /= 2.0; g /= 2.0; b /= 2.0;
										}
										--k;
										r = golgol*or + loglog*r;
										g = golgol*og + loglog*g;
										b = golgol*ob + loglog*b;
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
				}
				if(r > 1.0) r = 1.0; if(g > 1.0) g = 1.0; if(b > 1.0) b = 1.0;
				if(r < 0.0) r = 0.0; if(g < 0.0) g = 0.0; if(b < 0.0) b = 0.0;
				texture[(4 * x) + (y * 4 * xMax) + 0] = (unsigned char)(255.0 * r + 0.5);
				texture[(4 * x) + (y * 4 * xMax) + 1] = (unsigned char)(255.0 * g + 0.5);
				texture[(4 * x) + (y * 4 * xMax) + 2] = (unsigned char)(255.0 * b + 0.5);
				texture[(4 * x) + (y * 4 * xMax) + 3] = 0;
			}
		}
	}*/


@end

