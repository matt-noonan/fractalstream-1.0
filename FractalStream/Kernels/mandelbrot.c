#include "cplx.h"

void kernel(int mode, double* in, int length, double* out, int maxiter, 
double maxnorm) {
	int i, j;
	complex z, c, t, l, w;

	maxnorm *= maxnorm;
	if(mode == 1) {
		c.x = in[0]; c.y = in[1];
		for(i = 0; i < 3*length; i += 3) {
			Cmov(&c, &z); 
			for(j = 0; j < maxiter; j++) {
				Cmul(&z, &z, &t);
				Cadd(&c, &t, &z);
				if(Cnorm2(&z) > maxnorm) break;
			}
			out[i] = z.x; out[i + 1] = z.y;
			out[i + 2] = (double) j;
			c.x += in[2];
		}
	}
	else if(mode == 3) {
		c.x = in[3]; c.y = in[4];
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
