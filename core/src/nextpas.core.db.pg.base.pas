unit nextpas.core.db.pg.base;

{** @desc PostgreSQL L2 module: public constants and type aliases.
       Raw libpq ABI declarations live in nextpas.core.db.pg.ffi (resolved
       at runtime via nextpas.core.db.pg.loader, dlopen on libpq.so.5).
       The friendly surface (TPgConn / TPgQuery / EPgError) lives in
       nextpas.core.db.pg.conn and is re-exported by the nextpas.core.pg
       facade. EPgError lives here so the loader can raise it too. *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception;

const
  { ConnStatusType (PQstatus) }
  CONNECTION_OK  = 0;
  CONNECTION_BAD = 1;

  { ExecStatusType (PQresultStatus) }
  PGRES_EMPTY_QUERY    = 0;
  PGRES_COMMAND_OK     = 1;
  PGRES_TUPLES_OK      = 2;
  PGRES_COPY_OUT       = 3;
  PGRES_COPY_IN        = 4;
  PGRES_BAD_RESPONSE   = 5;
  PGRES_NONFATAL_ERROR = 6;
  PGRES_FATAL_ERROR    = 7;

  { PQresultErrorField field codes (single ASCII chars) }
  PG_DIAG_SEVERITY       = 83;  { 'S' }
  PG_DIAG_SQLSTATE       = 67;  { 'C' }
  PG_DIAG_MESSAGE_PRIMARY = 77; { 'M' }
  PG_DIAG_DETAIL         = 68;  { 'D' }
  PG_DIAG_HINT           = 72;  { 'H' }

  { Shared-library name. Linux carries only the versioned soname
    (libpq.so.5), no dev symlink — hence dlopen instead of a
    compile-time external link. }
  PG_LIBRARY_NAME = 'libpq.so.5';

type
  PGconn   = Pointer;   { PGconn*   }
  PGresult = Pointer;   { PGresult* }

  {** @desc PostgreSQL error, carries libpq diagnostics.
       MessagePrimary is in Message; SqlState/Severity/Detail are the
       standard PG error fields when the server provided them. *}
  EPgError = class(ENextPasError)
  private
    FSqlState: string;
    FSeverity: string;
    FDetail: string;
  public
    constructor Create(const AMessage: string); overload;
    constructor Create(const AMessage, ASqlState, ASeverity, ADetail: string); overload;
    property SqlState: string read FSqlState;
    property Severity: string read FSeverity;
    property Detail: string read FDetail;
  end;

implementation

constructor EPgError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
  FSqlState := '';
  FSeverity := '';
  FDetail := '';
end;

constructor EPgError.Create(const AMessage, ASqlState, ASeverity, ADetail: string);
begin
  inherited Create(AMessage);
  FSqlState := ASqlState;
  FSeverity := ASeverity;
  FDetail := ADetail;
end;

end.
