package sqlite_wrapper;

import "core:c";
import "core:strings";
import "core:mem";
import "core:fmt";

when ODIN_OS == "darwin" {
	foreign import "./sqlite3.a";
} 
when ODIN_OS == "windows" {
	foreign import "./sqlite3.lib";
}

Handle :: rawptr;
Statement :: rawptr;
BackupHandle :: rawptr;
SqliteStatus :: distinct int;
SQLITE_DONE : SqliteStatus : 101;
SqliteColumnType :: enum {
	INTEGER  = 1,
	FLOAT    = 2,
	TEXT = 3,
	BLOB     = 4,
	NULL     = 5

}

SQLITE_OPEN_READWRITE : c.int : 0x00000002;
SQLITE_OPEN_CREATE : c.int : 0x00000004;



foreign sqlite3 {
	sqlite3_open :: proc(cstring, ^Handle) -> c.int ---;
	sqlite3_open_v2 :: proc(cstring, ^Handle, c.int, cstring) -> c.int ---;
	sqlite3_close :: proc(Handle) ---;
	sqlite3_finalize :: proc(Statement) ---;
	sqlite3_prepare_v2 :: proc(Handle, cstring, c.int, ^Statement, ^^u8) -> c.int ---;
	sqlite3_step :: proc(Statement) -> SqliteStatus ---;
	sqlite3_column_type :: proc(Statement, c.int) -> SqliteColumnType ---;
	sqlite3_column_count :: proc(Statement) -> c.int ---;
	sqlite3_column_name :: proc(Statement, c.int) -> cstring ---;
	sqlite3_column_text :: proc(Statement, c.int) -> cstring ---;
	sqlite3_column_int :: proc(Statement, c.int) -> i64 ---;
	sqlite3_errmsg :: proc(Handle) -> cstring ---;
	sqlite3_exec :: proc(Handle, cstring, rawptr, rawptr, rawptr) -> int ---;
	sqlite3_backup_init :: proc(Handle, cstring, Handle, cstring) -> BackupHandle ---;
	sqlite3_backup_step :: proc(BackupHandle, c.int) -> c.int ---;
	sqlite3_backup_finish :: proc(BackupHandle) -> c.int ---;
	sqlite3_bind_double :: proc(Statement, c.int, c.double) -> c.int ---;
	sqlite3_bind_int :: proc(Statement, c.int, c.int) -> c.int ---;
	sqlite3_bind_int64 :: proc(Statement, c.int, i64) -> c.int ---;
	sqlite3_bind_null :: proc(Statement, c.int) -> c.int ---;
	sqlite3_bind_text :: proc(Statement, c.int, cstring, c.int, rawptr) -> c.int ---;

}


RowValue :: union {
	i64,
	string
}


Row :: map[string]RowValue;
RowValues :: [dynamic]Row;

QueryResult :: struct {
	rows: RowValues
}

backup_db :: proc(fromDb: Handle, toDb: Handle) -> bool {
	if fromDb == nil || toDb == nil {
		return false;
	}

	backupHandle := sqlite3_backup_init(toDb, "main", fromDb, "main");
	err := sqlite3_backup_step(backupHandle, -1);
	e2 := sqlite3_backup_finish(backupHandle);
	fmt.println(err, e2);

	return true;

}

open :: proc(path: string, create:= true) -> (Handle, bool) {

	db : Handle;
	cstr := strings.clone_to_cstring(path, context.temp_allocator);
	flags := SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE;
	if !create {
		flags = SQLITE_OPEN_READWRITE;
	}
	success := sqlite3_open_v2(cstr, &db, flags, nil);
	return db, success == 0;
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

exec :: proc(db: Handle, query: string) -> bool {
	cstr := strings.clone_to_cstring(query, context.temp_allocator);
	err := sqlite3_exec(db, cstr, nil, nil, nil);



	return err == 0;
}

query :: proc(db: Handle, query: string, values: ..any) -> (queryResult: QueryResult, success: bool, errStr: string)  {
	result := make([dynamic]map[string]RowValue);
	success = true;
	errStr = "";
	statement, ok, errMessage := prepare(db, query);


	if !ok {
		errStr = errMessage;
		success = false;
		return;
	}

	if len(values) > 0 {
		for value, index in values {
			switch v in value {
				case string: {
					cstr := strings.clone_to_cstring(v, context.temp_allocator);
					sqlite3_bind_text(statement, i32(index + 1), cstr, -1, nil);
				}
				case i32, u32, i8, u8, i16, u16: {
					res : i32;
					switch v in value {
						case i32: {
							res = i32(v);
						}
						case u32: {
							res = i32(v);
						}
						case i8: {
							res = i32(v);
						}
						case i16: {
							res = i32(v);
						}
						case u16: {
							res = i32(v);
						}
					}
					sqlite3_bind_int(statement, i32(index + 1), res);
				}
				case int, i64, uint, u64: {
					res : i64;
					switch v in value {
						case int: {
							res = i64(v);
						}
						case i64: {
							res = v;
						}
						case uint: {
							res = i64(v);
						}
						case u64: {
							res = i64(v);
						}
					}
					sqlite3_bind_int64(statement, i32(index + 1), res);
				}
				case f32, f64: {
					res : f64;
					switch v in value {
						case f32: {
							res = f64(v);
						}
						case f64: {
							res = v;
						}
					}
					sqlite3_bind_double(statement, i32(index + 1), res);
				}
				case: {
					success = false;
					errStr = "Can't handle that type of argument";
					return;
				}
			}
		}
	}

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
	}, success, errStr;
}

prepare :: proc(db: Handle, query: string) -> (Statement, bool, string) {
	cstr := strings.clone_to_cstring(query, context.temp_allocator);
	statement: Statement;
	errStr := "";
	res := sqlite3_prepare_v2(db, cstr, -1, &statement, nil);
	if res != 0 {
		errStr = cstring_to_string(sqlite3_errmsg(db));
	}
	return statement, res == 0, errStr;
}
