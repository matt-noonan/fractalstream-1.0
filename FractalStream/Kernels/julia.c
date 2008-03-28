#include "cplx.h"

void kernel(int mode, double* in, int length, double* out, int maxiter, 
double maxnorm) {
	int i, j;
	complex z, w, c, t;

	maxnorm *= maxnorm;
	c.x = -0.123; c.y = 0.745;
	mode = 1;
	if(mode == 1) {
		w.x = in[0]; w.y = in[1];
		for(i = 0; i < 3*length; i += 3) {
			Cmov(&w, &z);
			for(j = 0; j < maxiter; j++) {
				Cmul(&z, &z, &t);
				Cadd(&t, &c, &z);
				if(Cnorm2(&z) > maxnorm) break;
			}
			out[i] = z.x; out[i + 1] = z.y;
			out[i + 2] = (double) j;
			w.x += in[2];
		}
	}
}
