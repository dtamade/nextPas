unit nextpas.core.db.odbc.loader;

{** @desc ODBC driver-manager runtime loader. Probes
       ODBC_LIBRARY_CANDIDATES in order and binds every symbol from the
       first library that opens; fails fast with a readable EDbOdbcError
       naming all candidates tried when none loads. Load is idempotent.

       Unlike the mysql lane there is no library_init call: the ISO CLI
       initializes lazily inside SQLAllocHandle(SQL_HANDLE_ENV). There is
       also no flavor split — unixODBC and iODBC expose identical ABI for
       the bound surface, so a single binding table serves both.

       OdbcDiag collects SQLGetDiagRec records (rec 1..n until
       SQL_NO_DATA) into canonical TOdbcDiagRecs; OdbcRaise turns the
       first record into an EDbOdbcError so callers see state+native+text
       in one exception. Both are loader-level helpers (bound symbols
       required), used by tests here and by the A4 adapter. *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.odbc.base;

procedure OdbcEnsureLoaded;
function OdbcLoaded: Boolean;
function OdbcLibraryName: string;

{ 收集句柄上的全部诊断记录（RecNumber 从 1 起，直到 SQL_NO_DATA）。
  无诊断（如 SQL_INVALID_HANDLE 场景）返回空数组。 }
function OdbcDiag(AHandleType: SmallInt; AHandle: Pointer): TOdbcDiagRecs;

{ 首条诊断 → EDbOdbcError；无诊断时 SqlState 为空、消息给上下文。 }
procedure OdbcRaise(AHandleType: SmallInt; AHandle: Pointer;
  ARetCode: SmallInt; const AContext: string);

implementation

uses
  nextpas.core.platform.dl,
  nextpas.core.text.conv,
  nextpas.core.text.format,
  nextpas.core.exception,
  nextpas.core.db.odbc.ffi;

var
  GLib: TPlatformLibrary;
  GLoaded: Boolean;
  GLibName: string;
function DlErrorText: string;
var
  LBuf: array[0..511] of AnsiChar;
  LN: Int32;
begin
  LN := platform_dl_error(@LBuf[0], SizeOf(LBuf));
  if LN > 0 then
    Result := StrPas(PAnsiChar(@LBuf[0]))
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
    raise EDbOdbcError.CreateFmt('%s 符号 %s 缺失（%s）',
      [GLibName, AName, DlErrorText]);
end;

procedure BindAll;
begin
  sql_allocHandle     := TSqlAllocHandle(LoadSym('SQLAllocHandle'));
  sql_freeHandle      := TSqlFreeHandle(LoadSym('SQLFreeHandle'));
  sql_setEnvAttr      := TSqlSetEnvAttr(LoadSym('SQLSetEnvAttr'));
  sql_setConnectAttr  := TSqlSetConnectAttr(LoadSym('SQLSetConnectAttr'));
  sql_setStmtAttr     := TSqlSetStmtAttr(LoadSym('SQLSetStmtAttr'));
  sql_driverConnect   := TSqlDriverConnect(LoadSym('SQLDriverConnect'));
  sql_disconnect      := TSqlDisconnect(LoadSym('SQLDisconnect'));
  sql_endTran         := TSqlEndTran(LoadSym('SQLEndTran'));
  sql_execDirect      := TSqlExecDirect(LoadSym('SQLExecDirect'));
  sql_prepare         := TSqlPrepare(LoadSym('SQLPrepare'));
  sql_execute         := TSqlExecute(LoadSym('SQLExecute'));
  sql_closeCursor     := TSqlCloseCursor(LoadSym('SQLCloseCursor'));
  sql_numResultCols   := TSqlNumResultCols(LoadSym('SQLNumResultCols'));
  sql_describeCol     := TSqlDescribeCol(LoadSym('SQLDescribeCol'));
  sql_rowCount        := TSqlRowCount(LoadSym('SQLRowCount'));
  sql_fetch           := TSqlFetch(LoadSym('SQLFetch'));
  sql_getData         := TSqlGetData(LoadSym('SQLGetData'));
  sql_bindCol         := TSqlBindCol(LoadSym('SQLBindCol'));
  sql_numParams       := TSqlNumParams(LoadSym('SQLNumParams'));
  sql_bindParameter   := TSqlBindParameter(LoadSym('SQLBindParameter'));
  sql_getInfo         := TSqlGetInfo(LoadSym('SQLGetInfo'));
  sql_getDiagRec      := TSqlGetDiagRec(LoadSym('SQLGetDiagRec'));
end;

procedure OdbcEnsureLoaded;
var
  I: Integer;
  LLastErr: string;
  LAllNames: string;
begin
  if GLoaded then
    Exit;
  LLastErr := '';
  for I := Low(ODBC_LIBRARY_CANDIDATES) to High(ODBC_LIBRARY_CANDIDATES) do
  begin
    if platform_dl_open(PAnsiChar(AnsiString(ODBC_LIBRARY_CANDIDATES[I])),
        PLATFORM_DL_LAZY, GLib) = 0 then
    begin
      GLibName := ODBC_LIBRARY_CANDIDATES[I];
      try
        BindAll;
      except
        { 符号缺失即回滚加载态并上抛：管理器被裁剪属于环境问题，
          不静默换候选（ISO CLI 表面是标准集，缺符号=库不完整） }
        GLib.Close;
        GLib := PLATFORM_DL_NIL_LIBRARY;
        GLibName := '';
        raise;
      end;
      GLoaded := True;
      Exit;
    end;
    LLastErr := DlErrorText;
    GLib := PLATFORM_DL_NIL_LIBRARY;
  end;
  LAllNames := '';
  for I := Low(ODBC_LIBRARY_CANDIDATES) to High(ODBC_LIBRARY_CANDIDATES) do
  begin
    if LAllNames <> '' then
      LAllNames := LAllNames + ', ';
    LAllNames := LAllNames + ODBC_LIBRARY_CANDIDATES[I];
  end;
  raise EDbOdbcError.CreateFmt(
    'odbc: 驱动管理器加载失败（依次尝试 %s；请确认已安装 unixODBC）: %s',
    [LAllNames, LLastErr]);
end;

function OdbcLoaded: Boolean;
begin
  Result := GLoaded;
end;

function OdbcLibraryName: string;
begin
  Result := GLibName;
end;

function OdbcDiag(AHandleType: SmallInt;
  AHandle: Pointer): TOdbcDiagRecs;
const
  CStateLen = 6;    { 5 字符 + NUL }
  CMsgLen = 1024;
var
  LState: array[0..CStateLen] of AnsiChar;
  LMsg: array[0..CMsgLen - 1] of AnsiChar;
  LNative: Integer;
  LMsgLen: SmallInt;
  LRec: SmallInt;
begin
  { PAnsiChar → string 一律经 StrPas：本工具链上
    string(AnsiString(ptr)) 强转在返回托管记录数组的函数内会损坏
    临时管理（实证：数组指针坏 → 调用方访问 AV），属硬边界。 }
  Result := nil;
  SetLength(Result, 0);
  LRec := 1;
  while True do
  begin
    FillChar(LState, SizeOf(LState), 0);
    FillChar(LMsg, SizeOf(LMsg), 0);
    LNative := 0;
    LMsgLen := 0;
    case sql_getDiagRec(AHandleType, AHandle, LRec, @LState[0], LNative,
        @LMsg[0], CMsgLen, LMsgLen) of
      SQL_SUCCESS, SQL_SUCCESS_WITH_INFO:
        begin
          SetLength(Result, Length(Result) + 1);
          Result[High(Result)].SqlState := StrPas(PAnsiChar(@LState[0]));
          Result[High(Result)].NativeError := LNative;
          Result[High(Result)].Message := StrPas(PAnsiChar(@LMsg[0]));
          Inc(LRec);
        end;
      SQL_NO_DATA:
        Break;
    else
      { SQL_ERROR / SQL_INVALID_HANDLE：停止收集，保留已得记录 }
      Break;
    end;
  end;
end;

procedure OdbcRaise(AHandleType: SmallInt; AHandle: Pointer;
  ARetCode: SmallInt; const AContext: string);
var
  LDiag: TOdbcDiagRecs;
  LMsg: string;
begin
  LDiag := OdbcDiag(AHandleType, AHandle);
  if Length(LDiag) > 0 then
    LMsg := TextFormat('odbc: %s [%s/%d] %s',
      [AContext, LDiag[0].SqlState, LDiag[0].NativeError,
       LDiag[0].Message])
  else
    LMsg := TextFormat('odbc: %s [retcode %d, no diagnostics]',
      [AContext, ARetCode]);
  if Length(LDiag) > 0 then
    raise EDbOdbcError.Create(LMsg, ARetCode, LDiag[0].SqlState)
  else
    raise EDbOdbcError.Create(LMsg, ARetCode);
end;

end.
