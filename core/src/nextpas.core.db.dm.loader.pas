unit nextpas.core.db.dm.loader;

{** @desc DM DPI 运行时加载器：按候选 soname 顺序 dlopen，绑定全部必选符号。
       模式复刻 db.mysql.loader / db.pg.loader：构建主机仅需头文件，运行时
       才需真实库，CI 无库亦可离线全绿（负连接走管理器链路）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.dm.base,
  nextpas.core.db.dm.ffi;

function DmEnsureLoaded: Boolean;
function DmIsLoaded: Boolean;
function DmLibraryName: string;

implementation

uses
  nextpas.core.platform.dl,
  nextpas.core.text.conv,
  nextpas.core.errors;

var
  GLib: TPlatformLibrary;
  GLibName: string = '';
  GLoaded: Boolean = False;

function DmIsLoaded: Boolean;
begin
  Result := GLoaded;
end;

function DmLibraryName: string;
begin
  Result := GLibName;
end;

function LoadSym(const AName: string): Pointer;
var
  LRC: Int32;
  P: Pointer;
begin
  P := nil;
  LRC := GLib.Sym(PAnsiChar(AnsiString(AName)), P);
  if (LRC <> 0) or (P = nil) then
    raise EDmError.CreateFmt('DM DPI 符号 %s 缺失', [AName]);
  Result := P;
end;

function TrySym(const AName: string): Pointer;
var
  P: Pointer;
begin
  P := nil;
  if GLib.Sym(PAnsiChar(AnsiString(AName)), P) = 0 then
    Result := P
  else
    Result := nil;
end;

function DlErrorText: string;
var
  LBuf: array[0..511] of AnsiChar;
begin
  if platform_dl_error(@LBuf[0], SizeOf(LBuf)) > 0 then
    Result := AnsiPtrToStr(@LBuf[0])
  else
    Result := 'unknown dl error';
end;

procedure BindAll;
var
  P: Pointer;
begin
  P := LoadSym('dpi_create_env'); dpi_create_env := TDpiCreateEnv(P);
  P := LoadSym('dpi_free_env'); dpi_free_env := TDpiFreeEnv(P);
  P := LoadSym('dpi_create_conn'); dpi_create_conn := TDpiCreateConn(P);
  P := LoadSym('dpi_free_conn'); dpi_free_conn := TDpiFreeConn(P);
  P := LoadSym('dpi_connect'); dpi_connect := TDpiConnect(P);
  P := LoadSym('dpi_disconnect'); dpi_disconnect := TDpiDisconnect(P);
  P := LoadSym('dpi_commit'); dpi_commit := TDpiCommit(P);
  P := LoadSym('dpi_rollback'); dpi_rollback := TDpiRollback(P);
  P := LoadSym('dpi_create_stmt'); dpi_create_stmt := TDpiCreateStmt(P);
  P := LoadSym('dpi_free_stmt'); dpi_free_stmt := TDpiFreeStmt(P);
  P := LoadSym('dpi_prepare'); dpi_prepare := TDpiPrepare(P);
  P := LoadSym('dpi_execute'); dpi_execute := TDpiExecute(P);
  P := LoadSym('dpi_fetch'); dpi_fetch := TDpiFetch(P);
  P := LoadSym('dpi_close_cursor'); dpi_close_cursor := TDpiCloseCursor(P);
  P := LoadSym('dpi_bind_param'); dpi_bind_param := TDpiBindParam(P);
  P := LoadSym('dpi_bind_col'); dpi_bind_col := TDpiBindCol(P);
  P := LoadSym('dpi_get_data'); dpi_get_data := TDpiGetData(P);
  P := LoadSym('dpi_row_count'); dpi_row_count := TDpiRowCount(P);
  P := LoadSym('dpi_col_count'); dpi_col_count := TDpiColCount(P);
  P := LoadSym('dpi_describe_col'); dpi_describe_col := TDpiDescribeCol(P);
  P := LoadSym('dpi_get_error'); dpi_get_error := TDpiGetError(P);
  P := TrySym('dpi_cancel'); dpi_cancel := TDpiCancel(P);
  P := TrySym('dpi_version'); dpi_version := TDpiVersion(P);
end;

function DmEnsureLoaded: Boolean;
var
  I: Integer;
  LName: string;
begin
  if GLoaded then
    Exit(True);
  for I := Low(DM_LIBRARY_CANDIDATES) to High(DM_LIBRARY_CANDIDATES) do
  begin
    LName := DM_LIBRARY_CANDIDATES[I];
    if platform_dl_open(PAnsiChar(AnsiString(LName)), PLATFORM_DL_LAZY, GLib) <> 0 then
      Continue;
    try
      BindAll;
      GLibName := LName;
      GLoaded := True;
      Exit(True);
    except
      platform_dl_close(GLib);
      Continue;
    end;
  end;
  Result := False;
end;

finalization
  if GLoaded then
    platform_dl_close(GLib);

end.
