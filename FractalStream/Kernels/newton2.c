#include "cplx.h"

void kernel(int mode, double* in, int length, double* out, int maxiter, 
double maxnorm) {
	int i, j;
	complex z, c, t, l, w, cplus1, t2, t3, z2, num, den;
	double close;

	maxnorm *= maxnorm;
	close = 1.0 / maxnorm;
	if(mode == 1) {
		w.x = in[0]; w.y = in[1]; 
		Cmul(&w, &w, &c);
		c.x -= 0.25; cplus1.y = c.y;
		cplus1.x = c.x + 1.0;
		for(i = 0; i < 3*length; i += 3) {
			z.x = z.y = 0.0; 
			for(j = 0; j < maxiter; j++) {
				Cmul(&z, &z, &z2);
				Cmul(&z, &z2, &t2);
				Cmul(&z, &cplus1, &t);
				Csub(&c, &t, &t3);
				Cadd(&t2, &t3, &num);
				z2.x *= 3.0; z2.y *= 3.0;
				Csub(&z2, &cplus1, &den);
				if(Cnorm2(&den) < close) break;
				Cdiv(&num, &den, &t);
				Csub(&z, &t, &z);
				Csub(&z, &l, &t); 
				if((Cnorm2(&t) < close) || (Cnorm2(&t) > 
maxnorm)) break;
				Cmov(&z, &l);
			}
			if((w.x - 0.5 - z.x) * (w.x - 0.5 - z.x) + (w.y - 
z.y) * (w.y - z.y) <= close) 
				Csub(&w, &z, &z);
			else if((-w.x - 0.5 - z.x) * (-w.x - 0.5 - z.x) + 
(w.y + z.y) * (w.y + z.y) <= close)
				Cadd(&z, &w, &z);	
			out[i] = z.x; out[i + 1] = z.y;
			out[i + 2] = (double) j;
			if(Cnorm2(&den) < close) out[i + 2] = -1.0;
			w.x += in[2];
			Cmul(&w, &w, &c);
			c.x -= 0.25; cplus1.x = c.x + 1.0; cplus1.y = c.y;
		}
	}
	else if(mode == 3) {
		w.x = in[3]; w.y = in[4]; 
		Cmul(&w, &w, &c);
		c.x -= 0.25; cplus1.y = c.y;
		cplus1.x = c.x + 1.0;
		w.x = in[0]; w.y = in[1];
		for(i = 0; i < 3*length; i += 3) {
			Cmov(&w, &z);
			for(j = 0; j < maxiter; j++) {
				Cmul(&z, &z, &z2);
				Cmul(&z, &z2, &t2);
				Cmul(&z, &cplus1, &t);
				Csub(&c, &t, &t3);
				Cadd(&t2, &t3, &num);
				z2.x *= 3.0; z2.y *= 3.0;
				Csub(&z2, &cplus1, &den);
				Cdiv(&num, &den, &t);
				Csub(&z, &t, &z);
				Csub(&z, &l, &t); 
				if(Cnorm2(&t) < close) break;
				Cmov(&z, &l);
			}
			out[i] = z.x; out[i + 1] = z.y;
			out[i + 2] = (double) j;
			w.x += in[2];
		}
	}
}
