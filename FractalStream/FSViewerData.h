/*
 *  FSViewerData.h
 *  FractalStream
 *
 *  Created by Matt Noonan on 1/11/08.
 *  Copyright 2008 __MyCompanyName__. All rights reserved.
 *
 */

typedef struct {
	double center[2];
	double pixelSize;
	double aspectRatio;
	double detailLevel;
	double par[2];
	double data[3];
	int maxIters;
	double maxRadius;
	double minRadius;
	int program;
	void (*kernel)(int, double*, int, double*, int, double, double);
	id eventManager;
} FSViewerData;
