#include <stdio.h>

int main(void) {
	double x[128];
	int j[3], y;
	y = 1;
	x[24] = 1.00000000000000000000e+01;
	for(j[1] = (int) x[24]; j[1]; j[1]--) { printf("%i\n", y); ++y; }
}
