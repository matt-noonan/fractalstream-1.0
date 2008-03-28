#include <math.h>

#define PI 3.1415926535897932384626

void kernel(int mode, double* in, int length, double* out, int maxiter, 
double maxnorm) {
	int i, j, k, N;
	double x, y, oldx, oldy, near, h;
	double Cos[512];

	N = (int) in[8];
	maxnorm *= maxnorm; near = 1.0 / maxnorm;
	h = 2.0 * PI / (double) N;
	for(i = 0; i < N; i++) {
		Cos[i] = in[7] * cos(2.0 * PI * (double) i / (double) N);
	}

	for(i = 0; i < 3*length; i += 3) {
		x = in[0] + (double)i * in[2] / 3.0; y = in[1];
		for(j = 0; j < maxiter; j++) {
			for(k = 0; k < N; k++) {
				x += h * y;
				y += h * (-in[5] * y - in[6] * sin(x) + 
Cos[k]);
			}
			if(j && (((x - oldx)*(x - oldx) + 
(y-oldy)*(y-oldy)) < near)) break;
			oldx = x; oldy = y;
		}
		out[i] = x; out[i + 1] = y;
		out[i + 2] = (double) j;
	}
}
