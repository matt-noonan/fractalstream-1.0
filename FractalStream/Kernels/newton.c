void kernel(int mode, double* in, int length, double* out, int maxiter, 
double maxnorm) {
	int i, j;
	double zx, zy, wx, wy, tx, ty, norm2, lx, ly;

	length *= 3;
	for(i = 0; i < length; i += 3) {
		zx = in[0] + in[2] * (double) i / 3.0; 
		zy = in[1];
		lx = zx; ly = zy;
		for(j = 0; j < maxiter; j++) {
			wx = zx * zx - zy * zy;
			wy = 2.0 * zx * zy;
			norm2 = wx * wx + wy * wy;
			tx = -wx / (3.0 * norm2);
			ty = wy / (3.0 * norm2);
			zx *= 2.0 / 3.0;
			zy *= 2.0 / 3.0;
			zx += tx;
			zy += ty;
			if(((lx - zx) * (lx - zx) + (ly - zy) * (ly - zy)) 
< 0.001) break;
			lx = zx;
			ly = zy;
		}
		out[i] = zx; out[i + 1] = zy; out[i + 2] = (double) j;
	}
}

