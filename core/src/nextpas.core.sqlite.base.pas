unit nextpas.core.sqlite.base;

{** @desc SQLite L2 module: public constants and type aliases.
       Raw ABI declarations live in nextpas.core.sqlite.ffi.
       The friendly surface (TSqliteDb / TSqliteQuery / ESqliteError)
       lives in nextpas.core.sqlite.conn and is re-exported by the
       nextpas.core.sqlite facade. *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

const
  { Result codes (sqlite3.h) }
  SQLITE_OK          = 0;
  SQLITE_ROW         = 100;
  SQLITE_DONE        = 101;

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