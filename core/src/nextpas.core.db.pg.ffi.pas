unit nextpas.core.db.pg.ffi;

{** @desc Raw libpq C ABI as cdecl procedure types.
       Unlike nextpas.core.db.sqlite.ffi (compile-time `external`), libpq
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
  { V3-C1 语句缓存：服务端 prepared statement 两件套。
    PQprepare(conn, stmtName, query, nParams, paramTypes)；paramTypes
    传 nil = 服务端推断（与 PQexecParams 现状同口径）。
    PQexecPrepared 的 paramValues 编组与 PQexecParams 完全一致。 }
  TPQprepare        = function(AConn: PGconn; const AStmtName: PAnsiChar;
    const AQuery: PAnsiChar; ANParams: Integer;
    const AParamTypes: PInteger): PGresult; cdecl;
  TPQexecPrepared   = function(AConn: PGconn; const AStmtName: PAnsiChar;
    ANParams: Integer; const AParamValues: PPAnsiChar;
    const AParamLengths: PInteger; const AParamFormats: PInteger;
    AResultFormat: Integer): PGresult; cdecl;
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

  { INC-8 大对象 fastpath（lo_* 系；lseek/tell 用 64 位变体支持 >2GB） }
  TPQloOpen    = function(AConn: PGconn; AOid: TOid; AMode: Integer): Integer; cdecl;
  TPQloClose   = function(AConn: PGconn; AFd: Integer): Integer; cdecl;
  TPQloRead    = function(AConn: PGconn; AFd: Integer; ABuf: PAnsiChar;
    ALen: SizeInt): SizeInt; cdecl;
  TPQloWrite   = function(AConn: PGconn; AFd: Integer;
    const ABuf: PAnsiChar; ALen: SizeInt): SizeInt; cdecl;
  TPQloLseek64 = function(AConn: PGconn; AFd: Integer; AOffset: Int64;
    AWhence: Integer): Int64; cdecl;
  TPQloTell64  = function(AConn: PGconn; AFd: Integer): Int64; cdecl;
  TPQloCreat   = function(AConn: PGconn; AMode: Integer): TOid; cdecl;
  TPQloUnlink  = function(AConn: PGconn; AOid: TOid): Integer; cdecl;

  { V3-B6 异步取消三件套。PGcancel 句柄线程安全：PQgetCancel 在建连
    线程取一次，PQcancel 可从任意线程调用（libpq 文档明示），向服务
    端另发取消请求使在途语句以 57014（query_canceled）收场。 }
  TPQgetCancel  = function(AConn: PGconn): PGcancel; cdecl;
  TPQfreeCancel = procedure(ACancel: PGcancel); cdecl;
  TPQcancel     = function(ACancel: PGcancel; AErrBuf: PAnsiChar;
    AErrBufSize: Integer): Integer; cdecl;

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
  pq_prepare:      TPQprepare;
  pq_execPrepared: TPQexecPrepared;
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
  lo_open:    TPQloOpen;
  lo_close:   TPQloClose;
  lo_read:    TPQloRead;
  lo_write:   TPQloWrite;
  lo_lseek64: TPQloLseek64;
  lo_tell64:  TPQloTell64;
  lo_creat:   TPQloCreat;
  lo_unlink:  TPQloUnlink;
  pq_getCancel:  TPQgetCancel;
  pq_freeCancel: TPQfreeCancel;
  pq_cancel:     TPQcancel;

implementation

end.