#include "sqlite3.h"
#include <stdlib.h>


sqlite3* open(char *path) {
	sqlite3** db = (sqlite3 **)malloc(sizeof(struct sqlite3 *));
	sqlite3_open(path, db);

	return *db;
}
