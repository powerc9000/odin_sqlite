#include "sqlite3.h"
#include <stdio.h>

int test_sqlite3_bind_double (sqlite3_stmt* stmt, int param, double val) {
	printf("I got: %d, %f\n", param, val);

	return sqlite3_bind_double(stmt, param, val);
}
