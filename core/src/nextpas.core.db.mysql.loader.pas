unit nextpas.core.db.mysql.loader;

{** @desc MySQL/MariaDB client library runtime loader.
       Probes MYSQL_LIBRARY_CANDIDATES in order and binds every symbol
       from the first library that opens; fails fast with a readable
       EMySqlError naming all candidates tried when none loads. Load is
       idempotent; mysql_library_init(0,nil,nil) is called exactly once
       right after a successful open (the C API requires it before any
       mysql_init in multithreaded processes). Single initialization is
       sufficient: first conn-layer entry triggers it before worker
       threads spin up in the owning application.

       Flavor detection probes MariaDB-only symbols (mariadb_connection,
       mariadb_version — verified against real libmariadb.so.3 exports;
       Connector/C notably does NOT export mysql_library_init nor
       mysql_real_escape_string_quote, hence the fallback bindings).
       The result drives the MYSQL_BIND marshaling layout and the
       escape-function choice in the conn layer (V3-A2). *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.mysql.base;

procedure MySqlEnsureLoaded;
function MySqlLoaded: Boolean;
function MySqlLibraryName: string;
function MySqlClientVersion: QWord;
function MySqlFlavor: TMysqlFlavor;

implementation

uses
  nextpas.core.platform.dl,
  nextpas.core.exception,
  nextpas.core.db.mysql.ffi;

var
  GLib: TPlatformLibrary;
  GLoaded: Boolean;
  GInitDone: Boolean;
  GLibName: string;
  GFlavor: TMysqlFlavor;

function DlErrorText: string;
var
  LBuf: array[0..511] of AnsiChar;
  LN: Int32;
begin
  LN := platform_dl_error(@LBuf[0], SizeOf(LBuf));
  if LN > 0 then
    Result := string(AnsiString(@LBuf[0]))
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
    raise EMySqlError.CreateFmt('%s 符号 %s 缺失（%s）',
      [GLibName, AName, DlErrorText]);
end;

function TrySym(const AName: string): Pointer;
var
  LRC: Int32;
begin
  Result := nil;
  LRC := GLib.Sym(PAnsiChar(AnsiString(AName)), Result);
  if LRC <> 0 then
    Result := nil;
end;

function LoadSymWithFallback(const APrimary, AFallback: string): Pointer;
begin
  { 方言分叉点：Oracle 导出真符号；MariaDB Connector/C 头文件把
    library_init/end 定义为 server_init/end 的宏别名，只导出后者。
    两家 ABI 一致，仅符号名不同。 }
  Result := TrySym(APrimary);
  if Result = nil then
    Result := LoadSym(AFallback);
end;

function HasSym(const AName: string): Boolean;
var
  LAddr: Pointer;
begin
  Result := False;
  if GLib.Sym(PAnsiChar(AnsiString(AName)), LAddr) = 0 then
    Result := LAddr <> nil;
end;

procedure BindAll;
var
  LAddr: Pointer;
begin
  my_library_init  := TMysqlLibraryInit(
    LoadSymWithFallback('mysql_library_init', 'mysql_server_init'));
  my_library_end   := TMysqlLibraryEnd(
    LoadSymWithFallback('mysql_library_end', 'mysql_server_end'));
  my_getClientVersion := TMysqlGetClientVersion(LoadSym('mysql_get_client_version'));
  my_getServerVersion := TMysqlGetServerVersion(LoadSym('mysql_get_server_version'));
  my_init          := TMysqlInit(LoadSym('mysql_init'));
  my_options       := TMysqlOptions(LoadSym('mysql_options'));
  my_realConnect   := TMysqlRealConnect(LoadSym('mysql_real_connect'));
  my_close         := TMysqlClose(LoadSym('mysql_close'));
  my_ping          := TMysqlPing(LoadSym('mysql_ping'));
  my_selectDb      := TMysqlSelectDb(LoadSym('mysql_select_db'));
  my_setCharacterSet := TMysqlSetCharacterSet(LoadSym('mysql_set_character_set'));
  my_autocommit    := TMysqlAutocommit(LoadSym('mysql_autocommit'));
  my_commit        := TMysqlCommit(LoadSym('mysql_commit'));
  my_rollback      := TMysqlRollback(LoadSym('mysql_rollback'));
  my_errno         := TMysqlErrno(LoadSym('mysql_errno'));
  my_error         := TMysqlError_(LoadSym('mysql_error'));
  my_sqlstate      := TMysqlSqlstate(LoadSym('mysql_sqlstate'));
  my_realQuery     := TMysqlRealQuery(LoadSym('mysql_real_query'));
  my_fieldCount    := TMysqlFieldCount(LoadSym('mysql_field_count'));
  my_storeResult   := TMysqlStoreResult(LoadSym('mysql_store_result'));
  my_useResult     := TMysqlUseResult(LoadSym('mysql_use_result'));
  my_freeResult    := TMysqlFreeResult(LoadSym('mysql_free_result'));
  my_numRows       := TMysqlNumRows(LoadSym('mysql_num_rows'));
  my_numFields     := TMysqlNumFields(LoadSym('mysql_num_fields'));
  my_fetchRow      := TMysqlFetchRow(LoadSym('mysql_fetch_row'));
  my_fetchLengths  := TMysqlFetchLengths(LoadSym('mysql_fetch_lengths'));
  my_fetchField    := TMysqlFetchField(LoadSym('mysql_fetch_field'));
  my_fetchFieldDirect := TMysqlFetchFieldDirect(LoadSym('mysql_fetch_field_direct'));
  my_nextResult    := TMysqlNextResult(LoadSym('mysql_next_result'));
  my_moreResults   := TMysqlMoreResults(LoadSym('mysql_more_results'));
  my_affectedRows  := TMysqlAffectedRows(LoadSym('mysql_affected_rows'));
  my_insertId      := TMysqlInsertId(LoadSym('mysql_insert_id'));
  my_warningCount  := TMysqlWarningCount(LoadSym('mysql_warning_count'));
  my_realEscapeStringQuote := nil;
  LAddr := TrySym('mysql_real_escape_string_quote');
  if LAddr <> nil then
    my_realEscapeStringQuote := TMysqlRealEscapeStringQuote(LAddr);
  my_realEscapeString := TMysqlRealEscapeString(LoadSym('mysql_real_escape_string'));
  my_stmtInit      := TMysqlStmtInit(LoadSym('mysql_stmt_init'));
  my_stmtPrepare   := TMysqlStmtPrepare(LoadSym('mysql_stmt_prepare'));
  my_stmtParamCount := TMysqlStmtParamCount(LoadSym('mysql_stmt_param_count'));
  my_stmtFieldCount := TMysqlStmtFieldCount(LoadSym('mysql_stmt_field_count'));
  my_stmtExecute   := TMysqlStmtExecute(LoadSym('mysql_stmt_execute'));
  my_stmtFetch     := TMysqlStmtFetch(LoadSym('mysql_stmt_fetch'));
  my_stmtFetchColumn := TMysqlStmtFetchColumn(LoadSym('mysql_stmt_fetch_column'));
  my_stmtStoreResult := TMysqlStmtStoreResult(LoadSym('mysql_stmt_store_result'));
  my_stmtFreeResult := TMysqlStmtFreeResult(LoadSym('mysql_stmt_free_result'));
  my_stmtClose     := TMysqlStmtClose(LoadSym('mysql_stmt_close'));
  my_stmtReset     := TMysqlStmtReset(LoadSym('mysql_stmt_reset'));
  my_stmtResultMetadata := TMysqlStmtResultMetadata(LoadSym('mysql_stmt_result_metadata'));
  my_stmtAffectedRows := TMysqlStmtAffectedRows(LoadSym('mysql_stmt_affected_rows'));
  my_stmtInsertId  := TMysqlStmtInsertId(LoadSym('mysql_stmt_insert_id'));
  my_stmtNumRows   := TMysqlStmtNumRows(LoadSym('mysql_stmt_num_rows'));
  my_stmtErrno     := TMysqlStmtErrno(LoadSym('mysql_stmt_errno'));
  my_stmtError     := TMysqlStmtError(LoadSym('mysql_stmt_error'));
  my_stmtSqlstate  := TMysqlStmtSqlstate(LoadSym('mysql_stmt_sqlstate'));
  my_stmtSendLongData := TMysqlStmtSendLongData(LoadSym('mysql_stmt_send_long_data'));
  my_stmtNextResult := TMysqlStmtNextResult(LoadSym('mysql_stmt_next_result'));
  my_stmtBindParam := TMysqlStmtBindParam(LoadSym('mysql_stmt_bind_param'));
  my_stmtBindResult := TMysqlStmtBindResult(LoadSym('mysql_stmt_bind_result'));
end;

procedure MySqlEnsureLoaded;
var
  I: Integer;
  LLastErr: string;
  LAllNames: string;
begin
  if GLoaded then
    Exit;
  LLastErr := '';
  LAllNames := '';
  for I := Low(MYSQL_LIBRARY_CANDIDATES) to High(MYSQL_LIBRARY_CANDIDATES) do
  begin
    if platform_dl_open(PAnsiChar(AnsiString(MYSQL_LIBRARY_CANDIDATES[I])),
      PLATFORM_DL_LAZY, GLib) = 0 then
    begin
      GLibName := MYSQL_LIBRARY_CANDIDATES[I];
      Break;
    end;
    LLastErr := DlErrorText;
    GLib := PLATFORM_DL_NIL_LIBRARY;
  end;
  if GLibName = '' then
  begin
    for I := Low(MYSQL_LIBRARY_CANDIDATES) to High(MYSQL_LIBRARY_CANDIDATES) do
    begin
      if LAllNames <> '' then
        LAllNames := LAllNames + ', ';
      LAllNames := LAllNames + MYSQL_LIBRARY_CANDIDATES[I];
    end;
    raise EMySqlError.CreateFmt(
      '无法加载 MySQL 客户端库（依次尝试 %s；请确认已安装 libmysqlclient 或 libmariadb）: %s',
      [LAllNames, LLastErr]);
  end;
  try
    { flavor 探测：mariadb_connection / mariadb_version 仅存在于
      MariaDB Connector/C（本机 libmariadb.so.3 实证导出前者）。 }
    if HasSym('mariadb_connection') or HasSym('mariadb_version') then
      GFlavor := mfMariadb
    else
      GFlavor := mfMysql;
    BindAll;
    { 进程级一次性库初始化；失败即回滚加载态，避免半初始化句柄外泄 }
    if my_library_init(0, nil, nil) <> 0 then
      raise EMySqlError.Create(GLibName + ' mysql_library_init 失败');
    GInitDone := True;
  except
    GLib.Close;
    GLib := PLATFORM_DL_NIL_LIBRARY;
    GLibName := '';
    GFlavor := mfUnknown;
    raise;
  end;
  GLoaded := True;
end;

function MySqlLoaded: Boolean;
begin
  Result := GLoaded;
end;

function MySqlLibraryName: string;
begin
  Result := GLibName;
end;

function MySqlClientVersion: QWord;
begin
  if GLoaded then
    Result := my_getClientVersion()
  else
    Result := 0;
end;

function MySqlFlavor: TMysqlFlavor;
begin
  Result := GFlavor;
end;

finalization
  { 进程退出：库不 dlclose（句柄可能仍被长生命周期对象引用），
    仅对称调用 mysql_library_end（若我们初始化过）。 }
  if GInitDone and Assigned(my_library_end) then
    my_library_end();

end.
