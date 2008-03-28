#include "cplx.h"
#include <math.h>

void kernel(int mode, double* in, int length, double* out, int maxiter, 
double maxnorm) {
	int i, j;
	double x, y, a, t, lambda, x0, y0, temp;;

	maxnorm *= maxnorm;
	if(mode == 1) {
	}
	else if(mode == 3) {
		a = in[5]; t = in[6];
                x0 = in[0]; y0 = in[1];
		lambda = 2.0 * sqrt(a) * cos(2 * 3.1415926535897932 * t);
                for(i = 0; i < 3*length; i += 3) {
                        x = x0; y = y0;
                        for(j = 0; j < maxiter; j++) {
				temp = lambda*x + x*x - a*y;
				y = x; x = temp;
                                if((x*x + y*y) > maxnorm) break;
                        }
                out[i] = x; out[i + 1] = y;
                out[i + 2] = (double) j;
        	x0 += in[2];	
		}
	}
}

