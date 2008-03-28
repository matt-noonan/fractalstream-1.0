void kernel(int mode, double* in, int length, double* out, int maxiter, 
double maxnorm) {
	int i, j;
	double zx, zy, cx, cy;
	double tx, ty, lx, ly, wx, wy;
	double n, minnorm;

	maxnorm *= maxnorm;
	minnorm = 1.0 / maxnorm;
	if(mode == 1) {
		cx = in[0]; cy = in[1];
		for(i = 0; i < 3*length; i += 3) {
			zx = cx; zy = cy; lx = ly = 0.0;
			for(j = 0; j < maxiter; j++) {
				tx = cx + zx * zx - zy * zy;
				zy = cy + 2 * zx * zy;
				zx = tx;
				n = zx * zx + zy * zy;
				if((n > maxnorm) || (n < minnorm)) break;
				lx = zx; ly = zy;
			}
			out[i] = lx; out[i + 1] = ly;
			out[i + 2] = (double) j;
			if(n < minnorm) out[i + 2] = -1;
			cx += in[2];
		}
	}
	else if(mode == 3) {
		cx = in[3]; cy = in[4];
                wx = in[0]; wy = in[1];
                for(i = 0; i < 3*length; i += 3) {
                        zx = wx; zy = wy;
                        for(j = 0; j < maxiter; j++) {
                                tx = cx + zx * zx - zy * zy;
                                zy = cy + 2 * zx * zy;
                                zx = tx;
                                if((zx * zx + zy * zy) > maxnorm) break;
                        }
                out[i] = zx; out[i + 1] = zy;
                out[i + 2] = (double) j;
        	wx += in[2];	
		}
	}
}
