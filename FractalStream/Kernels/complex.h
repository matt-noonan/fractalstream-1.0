
#define Real double

#define zx realPart
#define zy imagPart

class complex {
	
	public:
	
		Real realPart,imagPart;
		
		complex(void) { zx=zy=0.0; }
		complex(Real x) { zx = x; zy = 0.0; }
		complex(Real x, Real y) { zx = x; zy = y; }
		
		inline friend complex operator -(const complex& z) {
			complex r;
			r.zx = -z.zx;
			r.zy = -z.zy;
			return r;
		}
		
		inline complex bar(void) {
			complex r;
			r.zx = zx;
			r.zy = -zy;
			return r;
		}
		
		inline Real norm2(void) { return zx * zx + zy * zy; }
		
		inline friend complex operator +(const complex& z, const complex& w) {
			complex r;
			r.zx = z.zx + w.zx; r.zy = z.zy + w.zy;
			return r;
		}
		
		inline friend complex operator +(const complex& z, const Real& w) {
			complex r;
			r.zx = z.zx + w; r.zy = z.zy;
			return r;
		}
		
		inline friend complex operator -(const complex& z, const complex& w) {
			return z + (-w);
		}
		
		inline friend complex operator *(const complex& z, const complex& w) {
			complex r;
			r.zx = z.zx * w.zx - z.zy * w.zy;
			r.zy = z.zx * w.zy + z.zy * w.zx;
			return r;
		}
		
		inline friend complex operator *(const complex& z, const Real& c) {
			complex r;
			r.zx = z.zx * c; r.zy = z.zy * c;
			return r;
		}
		
		inline friend complex operator *(const Real& c, const complex& z) {
			complex r;
			r.zx = z.zx * c; r.zy = z.zy * c;
			return r;
		}

		inline friend complex operator /(const complex& z, const Real& c) {
			complex r;
			r.zx = z.zx / c; r.zy = z.zy / c;
			return r;
		}
		
		inline friend complex operator /(const complex& z, const complex& w) {
			return z * w.bar() / w.norm2();
		}
		
		inline complex operator =(const Real& c) {
			zx = c; zy = 0.0;
			return *this;
		}
		
		Real Re(void) { return zx; } Real Im(void) { return zy; }
};

const complex _i_(0.0,1.0);

complex inline PairToComplex(Real x, Real y) { 
	complex r; 
	r.realPart = x; r.imagPart = y; 
	return r;
}

#undef zx
#undef zy
