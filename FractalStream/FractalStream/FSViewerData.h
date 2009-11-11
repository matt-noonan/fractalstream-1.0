/*
 *  FSViewerData.h
 *  FractalStream
 *
 *  Created by Matt Noonan on 1/11/08.
 *  Copyright 2008 __MyCompanyName__. All rights reserved.
 *
 */

#define FSViewer_Infinity   1.23456789e10000

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

typedef struct {
	int type;
		#define FSVO_Point	0
		#define FSVO_Dot	1
		#define FSVO_Line	2
		#define FSVO_Circle	3
		#define FSVO_Box	4
		#define FSVO_Arrow	5
	double point[2][2];
	float color[2][4];
	int batch;
	BOOL visible;
} FSViewerItem;

typedef struct {
	float* color;
	double* x;
	double* y;
	BOOL active;
	BOOL locked;
	int allocated_entries;
	int used_entries;
} FSViewer_Autocolor_Cache;