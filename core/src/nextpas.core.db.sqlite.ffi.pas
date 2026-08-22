unit nextpas.core.db.sqlite.ffi;

{** @desc Raw SQLite C ABI declarations (sqlite3.h 3.46.1, system libsqlite3).
       Raw declarations only — no helpers, no wrappers. *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.sqlite.base;

const
  SQLITE3_LIB = 'sqlite3';

type
  sqlite3_destructor_type = procedure(APtr: Pointer); cdecl;

function sqlite3_open_v2(const AFileName: PAnsiChar;
  out ADb: TSqliteHandle; AFlags: Integer; const AVfs: PAnsiChar): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_close_v2(ADb: TSqliteHandle): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_errmsg(ADb: TSqliteHandle): PAnsiChar; cdecl; external SQLITE3_LIB;
function sqlite3_errcode(ADb: TSqliteHandle): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_get_autocommit(ADb: TSqliteHandle): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_extended_errcode(ADb: TSqliteHandle): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_extended_result_codes(ADb: TSqliteHandle; AOnOff: Integer): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_exec(ADb: TSqliteHandle; const ASql: PAnsiChar;
  ACallback: Pointer; AArg: Pointer; out AErrMsg: PAnsiChar): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_prepare_v2(ADb: TSqliteHandle; const ASql: PAnsiChar;
  ANBytes: Integer; out AStmt: TSqliteStmt; const ATail: PPAnsiChar): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_step(AStmt: TSqliteStmt): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_finalize(AStmt: TSqliteStmt): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_reset(AStmt: TSqliteStmt): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_bind_parameter_count(AStmt: TSqliteStmt): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_bind_text(AStmt: TSqliteStmt; AIndex: Integer; const AValue: PAnsiChar;
  ANBytes: Integer; ADestructor: sqlite3_destructor_type): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_bind_int64(AStmt: TSqliteStmt; AIndex: Integer; AValue: Int64): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_bind_double(AStmt: TSqliteStmt; AIndex: Integer; AValue: Double): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_bind_blob(AStmt: TSqliteStmt; AIndex: Integer; const AValue: Pointer;
  ANBytes: Integer; ADestructor: sqlite3_destructor_type): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_bind_null(AStmt: TSqliteStmt; AIndex: Integer): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_column_count(AStmt: TSqliteStmt): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_column_name(AStmt: TSqliteStmt; AIndex: Integer): PAnsiChar; cdecl; external SQLITE3_LIB;
function sqlite3_column_type(AStmt: TSqliteStmt; AIndex: Integer): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_column_int64(AStmt: TSqliteStmt; AIndex: Integer): Int64; cdecl; external SQLITE3_LIB;
function sqlite3_column_double(AStmt: TSqliteStmt; AIndex: Integer): Double; cdecl; external SQLITE3_LIB;
function sqlite3_column_text(AStmt: TSqliteStmt; AIndex: Integer): PAnsiChar; cdecl; external SQLITE3_LIB;
function sqlite3_column_blob(AStmt: TSqliteStmt; AIndex: Integer): Pointer; cdecl; external SQLITE3_LIB;
function sqlite3_column_bytes(AStmt: TSqliteStmt; AIndex: Integer): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_changes(ADb: TSqliteHandle): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_last_insert_rowid(ADb: TSqliteHandle): Int64; cdecl; external SQLITE3_LIB;
function sqlite3_libversion: PAnsiChar; cdecl; external SQLITE3_LIB;
function sqlite3_free(APtr: Pointer): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_busy_timeout(ADb: TSqliteHandle; AMs: Integer): Integer; cdecl; external SQLITE3_LIB;
function sqlite3_wal_checkpoint(ADb: TSqliteHandle; const ADbName: PAnsiChar): Integer; cdecl; external SQLITE3_LIB;

implementation

end.