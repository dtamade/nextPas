unit nextpas.core.db.pg.conn;

{** @desc PostgreSQL L2 implementation: friendly facade over libpq
       (loaded via nextpas.core.db.pg.loader).
       - TPgConn: open/close, Exec (multi-statement DDL/DML), prepared
         parameterized queries, Changes, server/lib versions.
       - TPgQuery: prepared statement lifecycle (bind 1-based, step,
         columns 0-based), mirroring TSqliteQuery's shape.
       - EPgError: carries SQLSTATE / severity / detail.
       Text is UTF-8. One connection = one serialized writer; libpq is
       not thread-safe per connection, keep each TPgConn on one thread
       (the owning application's db layer serializes writers). *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.db.pg.base,
  nextpas.core.db.pg.ffi,
  nextpas.core.db.pg.loader;

type
  TPgConn = class;

  {** @desc A parameterized, executed query (all rows buffered).
       Parameter count is derived from the SQL ($N placeholders, with
       string literals and comments skipped) and passed explicitly to
       PQexecParams — libpq reports no parameter count from PQprepare on
       unnamed statements, so type inference is handed to the server.
       Bind parameters 1-based; columns 0-based. Step advances the row
       cursor; Get* reads the current row (NULL -> 0 / ''). *}
  TPgQuery = class
  private
    FConn: TPgConn;
    FSql: string;
    FRes: PGresult;
    FRow: Integer;        { -1 = not executed }
    FRows: Integer;
    FCols: Integer;
    FParamCount: Integer;
    FParamStorage: array of string;    { keeps bound value memory alive }
    FParamValues: array of PAnsiChar;  { pointer array handed to libpq }
    { 已绑定 Blob 的参数索引（1-based）；ExecuteOnce 对这些 $N 追加
      ::bytea cast（文本协议下二进制经 hex 字面量传入）。 }
    FCastIdx: array of Integer;
    FExecuted: Boolean;
    procedure ExecuteOnce;
    procedure AddCastIndex(const AIndex: Integer);
  public
    constructor Create(const AConn: TPgConn; const ASql: string);
    destructor Destroy; override;

    procedure BindText(const AIndex: Integer; const AValue: string);
    procedure BindInt64(const AIndex: Integer; const AValue: Int64);
    procedure BindDouble(const AIndex: Integer; const AValue: Double);
    { 二进制参数：hex 文本（\x…）+ ::bytea cast，服务端按 bytea 解析。 }
    procedure BindBlob(const AIndex: Integer; const AValue: TBytes);
    procedure BindNull(const AIndex: Integer);

    function Step: Boolean;
    procedure Reset;
    function ColumnCount: Integer;
    function ColumnName(const AIndex: Integer): string;
    { 结果列的 PostgreSQL 类型 OID（PQftype；未执行时返回 0）。 }
    function ColumnFieldOid(const AIndex: Integer): Cardinal;
    function IsNull(const AIndex: Integer): Boolean;
    function GetInt64(const AIndex: Integer): Int64;
    function GetDouble(const AIndex: Integer): Double;
    function GetText(const AIndex: Integer): string;
    { bytea 列读取（hex 输出解码）；非 \x 前缀 fail-closed 抛错。 }
    function GetBlob(const AIndex: Integer): TBytes;
  end;

  {** @desc PostgreSQL connection. Open with PgOpen (or Create) — the
       first open triggers libpq.so.5 loading. Exec runs multi-statement
       SQL; transactions are caller-managed via Exec('BEGIN'/'COMMIT'/
       'ROLLBACK') exactly like the sqlite module. No connection pool:
       that stays in the consuming application's db layer. *}
  TPgConn = class
  private
    FConn: PGconn;
    FLastCmdTuples: Int64;
    procedure CheckResultStatus(const ARes: PGresult);
  public
    constructor Create(const AConnInfo: string);
    destructor Destroy; override;

    procedure Exec(const ASql: string);
    function Query(const ASql: string): TPgQuery;
    function Changes: Int64;
    function Version: string;
    function ServerVersion: Integer;
    function ErrorMessage: string;
  end;

{ Open a PostgreSQL connection. AConnInfo uses libpq key=value syntax,
  e.g. 'host=/var/run/postgresql dbname=myapp user=app'. Raises EPgError
  on load or connect failure. }
function PgOpen(const AConnInfo: string): TPgConn;

implementation

{ ===== helpers ===== }

function ErrField(const ARes: PGresult; const AFieldCode: Integer): string;
var
  LP: PAnsiChar;
begin
  LP := pq_resultErrorField(ARes, AFieldCode);
  if LP = nil then
    Result := ''
  else
    Result := string(AnsiString(LP));
end;

procedure RaiseResultError(const ARes: PGresult);
var
  LMsg: string;
begin
  LMsg := string(AnsiString(pq_resultErrorMessage(ARes)));
  if LMsg = '' then
    LMsg := 'PostgreSQL 执行失败';
  raise EPgError.Create(LMsg, ErrField(ARes, PG_DIAG_SQLSTATE),
    ErrField(ARes, PG_DIAG_SEVERITY), ErrField(ARes, PG_DIAG_DETAIL));
end;

{** @desc Maximum $N parameter index referenced by ASql, skipping single-
       quoted string literals ('' escapes), double-quoted identifiers,
       line comments (--) and block comments (/* */). 0 = no parameters.
       Dollar-quoted bodies ($$ ... $$) are not used by this module's
       repository SQL; a '$$' in a literal would count, which is
       acceptable for controlled SQL. *}
function MaxParamIndex(const ASql: string): Integer;
var
  I: Integer;
  C: Char;
  InStr, InDq, InLineC, InBlockC: Boolean;
  N: Integer;
begin
  Result := 0;
  InStr := False;
  InDq := False;
  InLineC := False;
  InBlockC := False;
  I := 1;
  while I <= Length(ASql) do
  begin
    C := ASql[I];
    if InLineC then
    begin
      if C = #10 then
        InLineC := False;
    end
    else if InBlockC then
    begin
      if (C = '*') and (I < Length(ASql)) and (ASql[I + 1] = '/') then
      begin
        InBlockC := False;
        Inc(I);
      end;
    end
    else if InStr then
    begin
      if C = '''' then
      begin
        if (I < Length(ASql)) and (ASql[I + 1] = '''') then
          Inc(I)
        else
          InStr := False;
      end;
    end
    else if InDq then
    begin
      if C = '"' then
      begin
        if (I < Length(ASql)) and (ASql[I + 1] = '"') then
          Inc(I)
        else
          InDq := False;
      end;
    end
    else
    begin
      case C of
        '''': InStr := True;
        '"': InDq := True;
        '-':
          if (I < Length(ASql)) and (ASql[I + 1] = '-') then
            InLineC := True;
        '/':
          if (I < Length(ASql)) and (ASql[I + 1] = '*') then
          begin
            InBlockC := True;
            Inc(I);
          end;
        '$':
          begin
            Inc(I);
            N := 0;
            while (I <= Length(ASql)) and (ASql[I] in ['0'..'9']) do
            begin
              N := N * 10 + (Ord(ASql[I]) - Ord('0'));
              Inc(I);
            end;
            if N > Result then
              Result := N;
            Continue;
          end;
      end;
    end;
    Inc(I);
  end;
end;

{ ===== bytea hex helpers ===== }

function HexDigit(const ANibble: Byte): AnsiChar;
begin
  if ANibble < 10 then
    Result := AnsiChar(Ord('0') + ANibble)
  else
    Result := AnsiChar(Ord('a') + ANibble - 10);
end;

function HexValue(const AC: AnsiChar): Integer;
begin
  case AC of
    '0'..'9': Result := Ord(AC) - Ord('0');
    'a'..'f': Result := Ord(AC) - Ord('a') + 10;
    'A'..'F': Result := Ord(AC) - Ord('A') + 10;
  else
    Result := -1;
  end;
end;

{ TBytes -> '\x…' bytea hex 字面量（空数组 = '\x'）。 }
function BytesToPgHexText(const AValue: TBytes): string;
var
  LText: AnsiString;
  I: Integer;
  P: Integer;
begin
  SetLength(LText, 2 + Length(AValue) * 2);
  LText[1] := '\';
  LText[2] := 'x';
  P := 3;
  for I := 0 to High(AValue) do
  begin
    LText[P] := HexDigit(AValue[I] shr 4);
    LText[P + 1] := HexDigit(AValue[I] and $F);
    Inc(P, 2);
  end;
  Result := string(LText);
end;

{ bytea hex 文本（不含 \x 前缀）-> TBytes；非法字符抛 EPgError。 }
function PgHexToBytes(const AHex: string): TBytes;
var
  I: Integer;
  HI, LO: Integer;
begin
  if Length(AHex) mod 2 <> 0 then
    raise EPgError.Create('bytea hex 长度不是偶数');
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
  begin
    HI := HexValue(AnsiString(AHex)[I * 2 + 1]);
    LO := HexValue(AnsiString(AHex)[I * 2 + 2]);
    if (HI < 0) or (LO < 0) then
      raise EPgError.CreateFmt('bytea hex 含非法字符（偏移 %d）', [I * 2]);
    Result[I] := Byte(HI shl 4 or LO);
  end;
end;

{** @desc 对 ASql 中列出的 $N 参数追加 ::bytea cast。扫描状态机与
       MaxParamIndex 完全一致（跳过字面量/注释），保证索引对齐；
       dollar-quote 体不识别——与 MaxParamIndex 同一受控边界。 *}
function AppendByteaCasts(const ASql: string;
  const AIndexes: array of Integer): string;
var
  LB: string;
  I: Integer;
  C: Char;
  InStr, InDq, InLineC, InBlockC: Boolean;
  N, K: Integer;
  Matched: Boolean;
begin
  LB := '';
  InStr := False;
  InDq := False;
  InLineC := False;
  InBlockC := False;
  I := 1;
  while I <= Length(ASql) do
  begin
    C := ASql[I];
    if InLineC then
    begin
      LB := LB + C;
      if C = #10 then
        InLineC := False;
    end
    else if InBlockC then
    begin
      LB := LB + C;
      if (C = '*') and (I < Length(ASql)) and (ASql[I + 1] = '/') then
      begin
        LB := LB + '/';
        InBlockC := False;
        Inc(I);
      end;
    end
    else if InStr then
    begin
      LB := LB + C;
      if C = '''' then
      begin
        if (I < Length(ASql)) and (ASql[I + 1] = '''') then
        begin
          LB := LB + '''';
          Inc(I);
        end
        else
          InStr := False;
      end;
    end
    else if InDq then
    begin
      LB := LB + C;
      if C = '"' then
      begin
        if (I < Length(ASql)) and (ASql[I + 1] = '"') then
        begin
          LB := LB + '"';
          Inc(I);
        end
        else
          InDq := False;
      end;
    end
    else
    begin
      case C of
        '''' :
          begin
            InStr := True;
            LB := LB + C;
          end;
        '"' :
          begin
            InDq := True;
            LB := LB + C;
          end;
        '-' :
          begin
            if (I < Length(ASql)) and (ASql[I + 1] = '-') then
              InLineC := True;
            LB := LB + C;
          end;
        '/' :
          begin
            if (I < Length(ASql)) and (ASql[I + 1] = '*') then
            begin
              InBlockC := True;
              Inc(I);   { '*' 由 InBlockC 分支下一轮带出 }
              Continue;
            end;
            LB := LB + C;
          end;
        '$' :
          begin
            LB := LB + C;
            Inc(I);
            N := 0;
            while (I <= Length(ASql)) and (ASql[I] in ['0'..'9']) do
            begin
              LB := LB + ASql[I];
              N := N * 10 + (Ord(ASql[I]) - Ord('0'));
              Inc(I);
            end;
            Matched := False;
            for K := 0 to High(AIndexes) do
              if AIndexes[K] = N then
              begin
                Matched := True;
                Break;
              end;
            if Matched and (N > 0) then
              LB := LB + '::bytea';
            Continue;
          end;
      else
        LB := LB + C;
      end;
    end;
    Inc(I);
  end;
  Result := LB;
end;

{ ===== TPgConn ===== }

constructor TPgConn.Create(const AConnInfo: string);
begin
  inherited Create;
  PgEnsureLoaded;
  FConn := pq_connectdb(PAnsiChar(AnsiString(AConnInfo)));
  if FConn = nil then
    raise EPgError.Create('PQconnectdb 返回空连接（内存不足）');
  if pq_status(FConn) <> CONNECTION_OK then
  begin
    try
      raise EPgError.Create(string(AnsiString(pq_errorMessage(FConn))));
    finally
      pq_finish(FConn);
      FConn := nil;
    end;
  end;
end;

destructor TPgConn.Destroy;
begin
  if FConn <> nil then
    pq_finish(FConn);
  inherited;
end;

procedure TPgConn.CheckResultStatus(const ARes: PGresult);
var
  LStatus: Integer;
begin
  if ARes = nil then
    raise EPgError.Create('PostgreSQL 返回空结果');
  LStatus := pq_resultStatus(ARes);
  if not (LStatus in [PGRES_EMPTY_QUERY, PGRES_COMMAND_OK, PGRES_TUPLES_OK]) then
    RaiseResultError(ARes);
  FLastCmdTuples := StrToInt64Def(string(AnsiString(pq_cmdTuples(ARes))), 0);
end;

procedure TPgConn.Exec(const ASql: string);
var
  LRes: PGresult;
begin
  LRes := pq_exec(FConn, PAnsiChar(AnsiString(ASql)));
  try
    CheckResultStatus(LRes);
  finally
    pq_clear(LRes);
  end;
end;

function TPgConn.Query(const ASql: string): TPgQuery;
begin
  Result := TPgQuery.Create(Self, ASql);
end;

function TPgConn.Changes: Int64;
begin
  Result := FLastCmdTuples;
end;

function TPgConn.Version: string;
begin
  Result := IntToStr(pq_libVersion());
end;

function TPgConn.ServerVersion: Integer;
begin
  Result := pq_serverVersion(FConn);
end;

function TPgConn.ErrorMessage: string;
begin
  Result := string(AnsiString(pq_errorMessage(FConn)));
end;

function PgOpen(const AConnInfo: string): TPgConn;
begin
  Result := TPgConn.Create(AConnInfo);
end;

{ ===== TPgQuery ===== }

constructor TPgQuery.Create(const AConn: TPgConn; const ASql: string);
begin
  inherited Create;
  PgEnsureLoaded;
  FConn := AConn;
  FSql := ASql;
  FParamCount := MaxParamIndex(ASql);
  SetLength(FParamStorage, FParamCount);
  SetLength(FParamValues, FParamCount);
  FRow := -1;
end;

destructor TPgQuery.Destroy;
begin
  if FRes <> nil then
    pq_clear(FRes);
  inherited;
end;

procedure TPgQuery.BindText(const AIndex: Integer; const AValue: string);
begin
  if (AIndex < 1) or (AIndex > FParamCount) then
    raise EPgError.CreateFmt('绑定参数 %d 越界（共 %d 个占位符）', [AIndex, FParamCount]);
  FParamStorage[AIndex - 1] := AValue;
  FParamValues[AIndex - 1] := PAnsiChar(AnsiString(FParamStorage[AIndex - 1]));
end;

procedure TPgQuery.BindInt64(const AIndex: Integer; const AValue: Int64);
begin
  BindText(AIndex, IntToStr(AValue));
end;

procedure TPgQuery.BindDouble(const AIndex: Integer; const AValue: Double);
begin
  BindText(AIndex, FloatToStr(AValue));
end;

procedure TPgQuery.AddCastIndex(const AIndex: Integer);
var
  I: Integer;
begin
  for I := 0 to High(FCastIdx) do
    if FCastIdx[I] = AIndex then
      Exit;
  SetLength(FCastIdx, Length(FCastIdx) + 1);
  FCastIdx[High(FCastIdx)] := AIndex;
end;

procedure TPgQuery.BindBlob(const AIndex: Integer; const AValue: TBytes);
begin
  if (AIndex < 1) or (AIndex > FParamCount) then
    raise EPgError.CreateFmt('绑定参数 %d 越界（共 %d 个占位符）', [AIndex, FParamCount]);
  FParamStorage[AIndex - 1] := BytesToPgHexText(AValue);
  FParamValues[AIndex - 1] := PAnsiChar(AnsiString(FParamStorage[AIndex - 1]));
  AddCastIndex(AIndex);
end;

procedure TPgQuery.BindNull(const AIndex: Integer);
begin
  if (AIndex < 1) or (AIndex > FParamCount) then
    raise EPgError.CreateFmt('绑定参数 %d 越界（共 %d 个占位符）', [AIndex, FParamCount]);
  FParamStorage[AIndex - 1] := '';
  FParamValues[AIndex - 1] := nil;   { nil pointer = SQL NULL in text format }
end;

procedure TPgQuery.ExecuteOnce;
var
  LRes: PGresult;
  LCmd: string;
begin
  if Length(FCastIdx) > 0 then
    LCmd := AppendByteaCasts(FSql, FCastIdx)
  else
    LCmd := FSql;
  if FParamCount = 0 then
    LRes := pq_execParams(FConn.FConn, PAnsiChar(AnsiString(LCmd)), 0, nil, nil, nil, nil, 0)
  else
    LRes := pq_execParams(FConn.FConn, PAnsiChar(AnsiString(LCmd)), FParamCount, nil,
      PPAnsiChar(@FParamValues[0]), nil, nil, 0);
  try
    FConn.CheckResultStatus(LRes);
    FRows := pq_ntuples(LRes);
    FCols := pq_nfields(LRes);
    FRes := LRes;
  except
    pq_clear(LRes);
    raise;
  end;
  FRow := -1;
  FExecuted := True;
end;

function TPgQuery.Step: Boolean;
begin
  if not FExecuted then
    ExecuteOnce;
  if FRows = 0 then
    Exit(False);
  Inc(FRow);
  Result := FRow < FRows;
end;

procedure TPgQuery.Reset;
begin
  if FRes <> nil then
  begin
    pq_clear(FRes);
    FRes := nil;
  end;
  FRow := -1;
  FRows := 0;
  FCols := 0;
  FExecuted := False;
end;

function TPgQuery.ColumnCount: Integer;
begin
  if FRes = nil then
    Exit(0);
  Result := pq_nfields(FRes);
end;

function TPgQuery.ColumnName(const AIndex: Integer): string;
begin
  if FRes = nil then
    Exit('');
  Result := string(AnsiString(pq_fname(FRes, AIndex)));
end;

function TPgQuery.ColumnFieldOid(const AIndex: Integer): Cardinal;
begin
  if FRes = nil then
    Exit(0);
  Result := pq_ftype(FRes, AIndex);
end;

function TPgQuery.IsNull(const AIndex: Integer): Boolean;
begin
  if (FRes = nil) or (FRow < 0) or (FRow >= FRows) then
    Exit(True);
  Result := pq_getisnull(FRes, FRow, AIndex) <> 0;
end;

function TPgQuery.GetText(const AIndex: Integer): string;
var
  LP: PAnsiChar;
  LL: Integer;
begin
  if IsNull(AIndex) then
    Exit('');
  LP := pq_getvalue(FRes, FRow, AIndex);
  LL := pq_getlength(FRes, FRow, AIndex);
  SetString(Result, LP, LL);
end;

function TPgQuery.GetInt64(const AIndex: Integer): Int64;
var
  LS: string;
begin
  if IsNull(AIndex) then
    Exit(0);
  LS := GetText(AIndex);
  if not TryStrToInt64(LS, Result) then
    raise EPgError.CreateFmt('列 %d 不是合法的 int64 值: "%s"', [AIndex, LS]);
end;

function TPgQuery.GetDouble(const AIndex: Integer): Double;
var
  LS: string;
begin
  if IsNull(AIndex) then
    Exit(0);
  LS := GetText(AIndex);
  if not TryStrToFloat(LS, Result) then
    raise EPgError.CreateFmt('列 %d 不是合法的 double 值: "%s"', [AIndex, LS]);
end;

function TPgQuery.GetBlob(const AIndex: Integer): TBytes;
var
  LS: string;
begin
  if IsNull(AIndex) then
    Exit(nil);
  LS := GetText(AIndex);
  if (Length(LS) >= 2) and (LS[1] = '\') and (LS[2] = 'x') then
    Result := PgHexToBytes(Copy(LS, 3, Length(LS) - 2))
  else
    raise EPgError.CreateFmt('列 %d 不是 bytea hex 输出，无法按 Blob 读取', [AIndex]);
end;

end.