package sqlite_wrapper;

import "core:c";
import "core:strings";
import "core:mem";
import "core:fmt";

foreign import "./sqlite3.a";

Handle :: rawptr;
Statement :: rawptr;
SqliteStatus :: distinct int;
SQLITE_DONE : SqliteStatus : 101;
SqliteColumnType :: enum {
	INTEGER  = 1,
	FLOAT    = 2,
	TEXT = 3,
	BLOB     = 4,
	NULL     = 5

}

foreign sqlite3 {
	sqlite3_open :: proc(cstring, ^Handle) ---;
	sqlite3_close :: proc(Handle) ---;
	sqlite3_finalize :: proc(Statement) ---;
	sqlite3_prepare_v2 :: proc(Handle, cstring, c.int, ^Statement, ^^u8) -> c.int ---;
	sqlite3_step :: proc(Statement) -> SqliteStatus ---;
	sqlite3_column_type :: proc(Statement, c.int) -> SqliteColumnType ---;
	sqlite3_column_count :: proc(Statement) -> c.int ---;
	sqlite3_column_name :: proc(Statement, c.int) -> cstring ---;
	sqlite3_column_text :: proc(Statement, c.int) -> cstring ---;
	sqlite3_column_int :: proc(Statement, c.int) -> i64 ---;
}


RowValue :: union {
	i64,
	string
}

QueryResult :: struct {
	rows: [dynamic]map[string]RowValue
}

open :: proc(path: string) -> Handle {

	db : Handle;
	cstr := strings.clone_to_cstring(path, context.temp_allocator);
	sqlite3_open(cstr, &db);

	return db;
}
close :: proc(db: Handle) {
	sqlite3_close(db);
}

cstring_to_string :: proc(str: cstring) -> string {
	length := len(str);
			dest: rawptr = mem.alloc(length);
			mem.copy(dest, cast(rawptr)str, length);
			return strings.string_from_ptr(transmute(^u8)dest, length);
}

query :: proc(db: Handle, query: string) -> QueryResult {
	result := make([dynamic]map[string]RowValue);
	statement := prepare(db, query);
	defer sqlite3_finalize(statement);
	for sqlite3_step(statement) != SQLITE_DONE {
		totalCols := sqlite3_column_count(statement);
		row := make(map[string]RowValue);
		for colIndex in 0..<totalCols {
			name := cstring_to_string(sqlite3_column_name(statement, colIndex));

			#partial switch(sqlite3_column_type(statement, colIndex)) {
				case .TEXT: {
					row[name] = cstring_to_string(sqlite3_column_text(statement, colIndex));
				}
				case .INTEGER: {
					row[name] = sqlite3_column_int(statement, colIndex);
				}
			}
		}
		append(&result, row);
	}

	return {
		rows=result
	};
}

prepare :: proc(db: Handle, query: string) -> Statement {
	cstr := strings.clone_to_cstring(query, context.temp_allocator);
	statement: Statement;
	sqlite3_prepare_v2(db, cstr, -1, &statement, nil);
	return statement;
}