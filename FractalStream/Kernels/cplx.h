typedef struct {
	double x, y;
} complex;

inline void Cmov(complex* z, complex* w) {
	w -> x = z -> x;
	w -> y = z -> y;
}

inline void Cadd(complex* z1, complex* z2, complex* w) {
	w -> x = z1 -> x + z2 -> x;
	w -> y = z1 -> y + z2 -> y;
}

inline void Csub(complex* z1, complex* z2, complex* w) {
	w -> x = z1 -> x - z2 -> x;
	w -> y = z1 -> y - z2 -> y;
}

inline double Cnorm2(complex* z) { return z -> x * z -> x + z -> y * z -> 
y; }

inline void Cmul(complex* z1, complex* z2, complex* w) {
	w -> x = z1 -> x * z2 -> x - z1 -> y * z2 -> y;
	w -> y = z1 -> x * z2 -> y + z2 -> x * z1 -> y;
}

inline void Cinv(complex* z, complex* w) {
	double n;
	n = Cnorm2(z);
	w -> x = z -> x / n;
	w -> y = -(z -> y) / n; 
}

inline void Cdiv(complex* z1, complex* z2, complex* w) {
	complex t;
	Cinv(z2, &t);
	Cmul(z1, &t, w);
}

