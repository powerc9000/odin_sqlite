all: sqlite

sqlite:
	gcc  -c sqlite3.c -o sqlite3.o
	ar rcs sqlite3.a sqlite3.o
