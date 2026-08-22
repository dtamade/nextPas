unit nextpas.core.db.pg.ffi;

{** @desc Raw libpq C ABI as cdecl procedure types.
       Unlike nextpas.core.sqlite.ffi (compile-time `external`), libpq
       is loaded at runtime: the build host only ships libpq.so.5 (no
       unversioned dev symlink), so `external 'pq'` would not link.
       nextpas.core.db.pg.loader binds these vars to dlsym addresses via
       nextpas.core.platform.dl. Raw declarations only — no helpers. *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.pg.base;

type
  TPQconnectdb    = function(const AConnInfo: PAnsiChar): PGconn; cdecl;
  TPQfinish       = procedure(AConn: PGconn); cdecl;
  TPQstatus       = function(AConn: PGconn): Integer; cdecl;
  TPQerrorMessage = function(AConn: PGconn): PAnsiChar; cdecl;
  TPQexec         = function(AConn: PGconn; const AQuery: PAnsiChar): PGresult; cdecl;
  TPQexecParams   = function(AConn: PGconn; const ACommand: PAnsiChar;
    ANParams: Integer; const AParamTypes: PInteger;
    const AParamValues: PPAnsiChar; const AParamLengths: PInteger;
    const AParamFormats: PInteger; AResultFormat: Integer): PGresult; cdecl;
  TPQresultStatus = function(ARes: PGresult): Integer; cdecl;
  TPQresultErrorMessage = function(ARes: PGresult): PAnsiChar; cdecl;
  TPQresultErrorField   = function(ARes: PGresult; AFieldCode: Integer): PAnsiChar; cdecl;
  TPQntuples      = function(ARes: PGresult): Integer; cdecl;
  TPQnfields      = function(ARes: PGresult): Integer; cdecl;
  TPQfname        = function(ARes: PGresult; AColumnNumber: Integer): PAnsiChar; cdecl;
  TPQftype        = function(ARes: PGresult; AColumnNumber: Integer): Cardinal; cdecl;
  TPQgetisnull    = function(ARes: PGresult; ARowNumber: Integer;
    AColumnNumber: Integer): Integer; cdecl;
  TPQgetvalue     = function(ARes: PGresult; ARowNumber: Integer;
    AColumnNumber: Integer): PAnsiChar; cdecl;
  TPQgetlength    = function(ARes: PGresult; ARowNumber: Integer;
    AColumnNumber: Integer): Integer; cdecl;
  TPQcmdTuples    = function(ARes: PGresult): PAnsiChar; cdecl;
  TPQclear        = procedure(ARes: PGresult); cdecl;
  TPQlibVersion   = function: Integer; cdecl;
  TPQserverVersion = function(AConn: PGconn): Integer; cdecl;

var
  { Bound by nextpas.core.db.pg.loader; callers must PgEnsureLoaded first
    (TPgConn.Create does it). Never call while nil. }
  pq_connectdb:    TPQconnectdb;
  pq_finish:       TPQfinish;
  pq_status:       TPQstatus;
  pq_errorMessage: TPQerrorMessage;
  pq_exec:         TPQexec;
  pq_execParams:   TPQexecParams;
  pq_resultStatus: TPQresultStatus;
  pq_resultErrorMessage: TPQresultErrorMessage;
  pq_resultErrorField:   TPQresultErrorField;
  pq_ntuples:      TPQntuples;
  pq_nfields:      TPQnfields;
  pq_fname:        TPQfname;
  pq_ftype:        TPQftype;
  pq_getisnull:    TPQgetisnull;
  pq_getvalue:     TPQgetvalue;
  pq_getlength:    TPQgetlength;
  pq_cmdTuples:    TPQcmdTuples;
  pq_clear:        TPQclear;
  pq_libVersion:   TPQlibVersion;
  pq_serverVersion: TPQserverVersion;

implementation

end.