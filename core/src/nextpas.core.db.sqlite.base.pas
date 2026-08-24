unit nextpas.core.db.sqlite.base;

{** @desc SQLite L2 module: public constants and type aliases.
       Raw ABI declarations live in nextpas.core.db.sqlite.ffi.
       The friendly surface (TSqliteDb / TSqliteQuery / ESqliteError)
       lives in nextpas.core.db.sqlite.conn and is re-exported by the
       nextpas.core.db.sqlite facade. *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

const
  { Result codes (sqlite3.h) }
  SQLITE_OK          = 0;
  SQLITE_ROW         = 100;
  SQLITE_DONE        = 101;

  { Primary constraint violation code + extended subcodes (sqlite3.h).
    sqlite3_step/sqlite3_exec return SQLITE_CONSTRAINT (19); the precise
    kind (UNIQUE/PK/FK/CHECK/...) is only visible via the extended code,
    obtainable through sqlite3_extended_errcode. Constants per sqlite3.h. }
  SQLITE_CONSTRAINT              = 19;
  SQLITE_CONSTRAINT_CHECK        = 275;
  SQLITE_CONSTRAINT_COMMITHOOK   = 531;
  SQLITE_CONSTRAINT_FOREIGNKEY   = 787;
  SQLITE_CONSTRAINT_FUNCTION     = 1043;
  SQLITE_CONSTRAINT_NOTNULL      = 1299;
  SQLITE_CONSTRAINT_PRIMARYKEY   = 1555;
  SQLITE_CONSTRAINT_TRIGGER      = 1811;
  SQLITE_CONSTRAINT_UNIQUE       = 2067;
  SQLITE_CONSTRAINT_VTAB         = 2323;
  SQLITE_CONSTRAINT_ROWID        = 2579;
  SQLITE_CONSTRAINT_PINNED       = 2835;
  SQLITE_CONSTRAINT_DATATYPE     = 3091;

  { sqlite3_open_v2 flags }
  SQLITE_OPEN_READONLY  = $00000001;
  SQLITE_OPEN_READWRITE = $00000002;
  SQLITE_OPEN_CREATE    = $00000004;
  SQLITE_OPEN_URI       = $00000040;
  SQLITE_OPEN_MEMORY    = $00000080;
  SQLITE_OPEN_NOMUTEX   = $00008000;
  SQLITE_OPEN_FULLMUTEX = $00010000;

  { Column data types (sqlite3_column_type) }
  SQLITE_INTEGER = 1;
  SQLITE_FLOAT   = 2;
  SQLITE_TEXT    = 3;
  SQLITE_BLOB    = 4;
  SQLITE_NULL    = 5;

  { Destructor-style values for text/blob binds }
  SQLITE_STATIC    = 0;
  SQLITE_TRANSIENT = -1;

type
  TSqliteHandle = Pointer;   // sqlite3*
  TSqliteStmt   = Pointer;   // sqlite3_stmt*
  TSqliteBlob   = Pointer;   // sqlite3_blob*（INC-8 增量 blob I/O 句柄）

  { Bindable parameter value }
  TSqliteValue = record
    Kind: Integer;  // SQLITE_INTEGER..SQLITE_NULL
    AsInt64: Int64;
    AsDouble: Double;
    AsText: string;
    AsBlob: TBytes;
  end;

implementation

end.