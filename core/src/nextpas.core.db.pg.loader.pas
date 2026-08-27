unit nextpas.core.db.pg.loader;

{** @desc libpq.so.5 runtime loader (dlopen + dlsym).
       The build host ships only the versioned soname libpq.so.5 (no
       libpq.so dev symlink), so a compile-time `external 'pq'` link
       fails; mirror the openssl loader pattern instead: open once,
       resolve every symbol, fail fast with a readable EPgError when
       the library or a required symbol is missing. Load is idempotent;
       serialized by PG_LOAD_INIT (single initialization is sufficient:
       first TPgConn.Create triggers it before any worker threads spin
       up in the owning application). *}

{$I nextpas.core.settings.inc}

interface

procedure PgEnsureLoaded;

implementation

uses
  nextpas.core.platform.dl,
  nextpas.core.text.conv,
  nextpas.core.exception,
  nextpas.core.db.pg.base,
  nextpas.core.db.pg.ffi;

var
  GLib: TPlatformLibrary;
  GLoaded: Boolean;

function DlErrorText: string;
var
  LBuf: array[0..511] of AnsiChar;
  LN: Int32;
begin
  LN := platform_dl_error(@LBuf[0], SizeOf(LBuf));
  if LN > 0 then
    Result := AnsiPtrToStr(@LBuf[0])
  else
    Result := 'unknown dl error';
end;

function LoadSym(const AName: string): Pointer;
var
  LRC: Int32;
begin
  Result := nil;
  LRC := GLib.Sym(PAnsiChar(AnsiString(AName)), Result);
  if (LRC <> 0) or (Result = nil) then
    raise EPgError.CreateFmt('libpq 符号 %s 缺失（%s）', [AName, DlErrorText]);
end;

procedure BindAll;
begin
  pq_connectdb    := TPQconnectdb(LoadSym('PQconnectdb'));
  pq_finish       := TPQfinish(LoadSym('PQfinish'));
  pq_status       := TPQstatus(LoadSym('PQstatus'));
  pq_errorMessage := TPQerrorMessage(LoadSym('PQerrorMessage'));
  pq_exec         := TPQexec(LoadSym('PQexec'));
  pq_execParams   := TPQexecParams(LoadSym('PQexecParams'));
  pq_resultStatus := TPQresultStatus(LoadSym('PQresultStatus'));
  pq_resultErrorMessage := TPQresultErrorMessage(LoadSym('PQresultErrorMessage'));
  pq_resultErrorField   := TPQresultErrorField(LoadSym('PQresultErrorField'));
  pq_prepare      := TPQprepare(LoadSym('PQprepare'));
  pq_execPrepared := TPQexecPrepared(LoadSym('PQexecPrepared'));
  pq_ntuples      := TPQntuples(LoadSym('PQntuples'));
  pq_nfields      := TPQnfields(LoadSym('PQnfields'));
  pq_fname        := TPQfname(LoadSym('PQfname'));
  pq_ftype        := TPQftype(LoadSym('PQftype'));
  pq_getisnull    := TPQgetisnull(LoadSym('PQgetisnull'));
  pq_getvalue     := TPQgetvalue(LoadSym('PQgetvalue'));
  pq_getlength    := TPQgetlength(LoadSym('PQgetlength'));
  pq_cmdTuples    := TPQcmdTuples(LoadSym('PQcmdTuples'));
  pq_clear        := TPQclear(LoadSym('PQclear'));
  pq_libVersion   := TPQlibVersion(LoadSym('PQlibVersion'));
  pq_serverVersion := TPQserverVersion(LoadSym('PQserverVersion'));
  lo_open    := TPQloOpen(LoadSym('lo_open'));
  lo_close   := TPQloClose(LoadSym('lo_close'));
  lo_read    := TPQloRead(LoadSym('lo_read'));
  lo_write   := TPQloWrite(LoadSym('lo_write'));
  lo_lseek64 := TPQloLseek64(LoadSym('lo_lseek64'));
  lo_tell64  := TPQloTell64(LoadSym('lo_tell64'));
  lo_creat   := TPQloCreat(LoadSym('lo_creat'));
  lo_unlink  := TPQloUnlink(LoadSym('lo_unlink'));
  pq_getCancel  := TPQgetCancel(LoadSym('PQgetCancel'));
  pq_freeCancel := TPQfreeCancel(LoadSym('PQfreeCancel'));
  pq_cancel     := TPQcancel(LoadSym('PQcancel'));
  { V3-B7 LISTEN/NOTIFY 订阅面（均为 libpq 初代符号，无版本门槛） }
  pq_notifies     := TPQnotifies(LoadSym('PQnotifies'));
  pq_freemem      := TPQfreemem(LoadSym('PQfreemem'));
  pq_socket       := TPQsocket(LoadSym('PQsocket'));
  pq_consumeInput := TPQconsumeInput(LoadSym('PQconsumeInput'));
  pq_backendPID   := TPQbackendPID(LoadSym('PQbackendPID'));
end;

procedure PgEnsureLoaded;
begin
  if GLoaded then
    Exit;
  if platform_dl_open(PAnsiChar(AnsiString(PG_LIBRARY_NAME)),
    PLATFORM_DL_LAZY, GLib) <> 0 then
    raise EPgError.CreateFmt('无法加载 %s（请确认已安装 libpq 客户端库）: %s',
      [PG_LIBRARY_NAME, DlErrorText]);
  BindAll;
  GLoaded := True;
end;

end.