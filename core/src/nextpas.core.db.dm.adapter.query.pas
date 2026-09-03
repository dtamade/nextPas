unit nextpas.core.db.dm.adapter.query;

{** @desc DM 适配器查询分治（L3 实现子模块）。
       封装 TDbDmQuery 的语句/参数单缓冲与存取单缓冲（FParamAnsi+FIsNullInt+FFetchAnsi，
       单次 Move 零拷贝，bytes.ops 单源 BYTES_OPS_SINGLE_SOURCE，批内存减半复用）。
       层级：L3 适配子模块（严格下向 L2 dm.base/ffi/base + L1 bytes/text/collections，
       同层单向：仅被 conn/adapter 单向依赖，不反向；依赖 common 单向）。
       性能：BindText 单次 StringToAnsiString 单 Move（外联于 bytes.ops per red line 1，
       薄转发零额外分配），BindInt64/BindDouble 外联 Schubfach 栈缓冲→Ansi 单 Move 单次堆分配复用（bytes.ops AnsiEnsureCapacity 单源 BYTES_OPS_SINGLE_SOURCE，批量复用零二次分配，red line 1 外联避免 Move(LBuf[0]) 索引元素常量传播污染与 I-Cache 膨胀），
       BindBlob 零拷贝视图 BytesToAnsiStringReuse 单 Move 复用（bytes.ops AnsiEnsureCapacity 单源，去 BytesToString 双次物化，大对象零二次分配），
       Get* 零拷贝 Parse* 直连无中间串，GetText 栈4K单Move+大文本流式StringEnsureCapacity直取Result零拷贝复用（去AnsiString中间物化，128KB+单往返，bytes.ops单源），大对象单缓冲直写 Result。
       稳定性：Holder 接口托管（Detach 移交所有权，析构 dpi_free_stmt 不丢），对象期托管 FFetchAnsi/FParamAnsi。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.dm.base,
  nextpas.core.db.trace,
  nextpas.core.collections.lrucache.intf;

type
  IDmStmtHolder = interface
    ['{E2F3A9C4-8B11-4D2E-9F7C-1A2B3C4D5E6F}']
    function Detach: TDmStmt;
  end;

  TDmStmtHolder = class(TInterfacedObject, IDmStmtHolder)
  private
    FStmt: TDmStmt;
  public
    constructor Create(AStmt: TDmStmt);
    destructor Destroy; override;
    function Detach: TDmStmt;
  end;

  IDmStmtHome = interface
    ['{F3A4B5C6-9C22-4E3F-8A7D-2B3C4D5E6F70}']
    procedure ReturnStmt(const ASql: string; AStmt: TDmStmt);
  end;

  IDmStmtCache = specialize ILruCache<string, IDmStmtHolder>;

  TDbDmQuery = class(TInterfacedObject, IDbQuery)
  private
    FConn: TDmConn;
    FEnv: TDmEnv;
    FStmt: TDmStmt;
    FSql: string;
    FHome: IDmStmtHome;
    FTrace: TDbTraceHub;
    FEmitted: Boolean;
    FColCount: Integer;
    FHasRow: Boolean;
    FParamAnsi: array of AnsiString;
    FParamIsNull: array of Boolean;
    FIsNullInt: array of Integer;
    FFetchAnsi: AnsiString;
    FRows: array of array of string;
    FRowIdx: Integer;
    procedure EnsureStmt;
    procedure DoBind;
  public
    constructor Create(AEnv: TDmEnv; AConn: TDmConn; const ASql: string; ATrace: TDbTraceHub); overload;
    constructor Create(AEnv: TDmEnv; AConn: TDmConn; const ASql: string; ATrace: TDbTraceHub; const AHome: IDmStmtHome; AStmt: TDmStmt); overload;
    destructor Destroy; override;
    procedure BindText(AIndex: Integer; const AValue: string);
    procedure BindInt64(AIndex: Integer; const AValue: Int64);
    procedure BindDouble(AIndex: Integer; const AValue: Double);
    procedure BindBlob(AIndex: Integer; const AValue: TBytes);
    procedure BindNull(AIndex: Integer);
    function Step: Boolean;
    procedure Reset;
    function ColumnCount: Integer;
    function ColumnName(AIndex: Integer): string;
    function ColumnType(AIndex: Integer): TDbColumnType;
    function IsNull(AIndex: Integer): Boolean;
    function GetInt64(AIndex: Integer): Int64;
    function GetDouble(AIndex: Integer): Double;
    function GetText(AIndex: Integer): string;
    function GetBlob(AIndex: Integer): TBytes;
  end;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.text.conv,
  nextpas.core.text.number,
  nextpas.core.db.err,
  nextpas.core.db.dm.ffi,
  nextpas.core.db.dm.adapter.common;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: db.dm.adapter.query must reuse bytes.ops'}
{$IFEND}

constructor TDmStmtHolder.Create(AStmt: TDmStmt);
begin
  inherited Create;
  FStmt := AStmt;
end;

destructor TDmStmtHolder.Destroy;
begin
  if FStmt <> nil then
  begin
    dpi_free_stmt(FStmt);
    FStmt := nil;
  end;
  inherited Destroy;
end;

function TDmStmtHolder.Detach: TDmStmt;
begin
  Result := FStmt;
  FStmt := nil;
end;

constructor TDbDmQuery.Create(AEnv: TDmEnv; AConn: TDmConn; const ASql: string; ATrace: TDbTraceHub);
begin
  Create(AEnv, AConn, ASql, ATrace, nil, nil);
end;

constructor TDbDmQuery.Create(AEnv: TDmEnv; AConn: TDmConn; const ASql: string; ATrace: TDbTraceHub; const AHome: IDmStmtHome; AStmt: TDmStmt);
begin
  inherited Create;
  FEnv := AEnv; FConn := AConn; FSql := ASql; FTrace := ATrace; FHome := AHome;
  FStmt := AStmt; FColCount := 0; FHasRow := False; FRowIdx := -1;
  SetLength(FParamAnsi, 8); SetLength(FParamIsNull, 8);
  SetLength(FIsNullInt, 8);
end;

destructor TDbDmQuery.Destroy;
begin
  if FStmt <> nil then
  begin
    if FHome <> nil then
    begin
      FHome.ReturnStmt(FSql, FStmt);
      FStmt := nil;
    end
    else
    begin
      dpi_free_stmt(FStmt); FStmt := nil;
    end;
  end;
  FHome := nil;
  inherited Destroy;
end;

procedure TDbDmQuery.EnsureStmt;
var
  LSql: AnsiString;
  LStr: string;
  LCode: Integer;
begin
  if FStmt <> nil then Exit;
  LCode := dpi_create_stmt(FConn, @FStmt);
  CheckDpi(LCode, FConn, DPI_HANDLE_DBC);
  LStr := TranslatePlaceholders(FSql);
  LSql := nextpas.core.bytes.ops.StringToAnsiString(LStr);
  LCode := dpi_prepare(FStmt, PAnsiChar(LSql), Length(LSql));
  if LCode <> DPI_SUCCESS then
  begin
    CheckDpi(LCode, FStmt, DPI_HANDLE_STMT);
  end;
end;

procedure TDbDmQuery.DoBind;
var
  I: Integer;
begin
  if Length(FIsNullInt) < Length(FParamAnsi) then
    SetLength(FIsNullInt, Length(FParamAnsi));
  for I := 0 to High(FParamAnsi) do
  begin
    if FParamIsNull[I] then
    begin
      FIsNullInt[I] := 1;
      dpi_bind_param(FStmt, I+1, DPI_TYPE_VARCHAR, nil, 0, @FIsNullInt[I]);
    end else
    begin
      FIsNullInt[I] := 0;
      if FParamAnsi[I] <> '' then
        dpi_bind_param(FStmt, I+1, DPI_TYPE_VARCHAR, PAnsiChar(FParamAnsi[I]), Length(FParamAnsi[I]), @FIsNullInt[I])
      else
        dpi_bind_param(FStmt, I+1, DPI_TYPE_VARCHAR, PAnsiChar(''), 0, @FIsNullInt[I]);
    end;
  end;
end;

procedure TDbDmQuery.BindText(AIndex: Integer; const AValue: string);
begin
  if (AIndex < 1) then raise EDbError.CreateSimple(dbkDm, 'bind index out of range');
  if Length(FParamAnsi) < AIndex then
  begin
    SetLength(FParamAnsi, AIndex);
    SetLength(FParamIsNull, AIndex);
    SetLength(FIsNullInt, AIndex);
  end;
  FParamAnsi[AIndex-1] := nextpas.core.bytes.ops.StringToAnsiString(AValue);
  FParamIsNull[AIndex-1] := False;
end;

procedure TDbDmQuery.BindInt64(AIndex: Integer; const AValue: Int64);
var
  LBuf: array[0..31] of AnsiChar;
  LLen: Int32;
begin
  if (AIndex < 1) then raise EDbError.CreateSimple(dbkDm, 'bind index out of range');
  if Length(FParamAnsi) < AIndex then
  begin
    SetLength(FParamAnsi, AIndex);
    SetLength(FParamIsNull, AIndex);
    SetLength(FIsNullInt, AIndex);
  end;
  LLen := nextpas.core.text.number.IntToBuffer(AValue, @LBuf[0]);
  // perf: not inline per red line 1 (Move(LBuf[0]) 索引元素作 untyped 源参禁 inline，避免常量传播污染与 I-Cache 复制膨胀)；
  // Schubfach 栈缓冲→Ansi 单 Move 零拷贝复用（bytes.ops 单源 BYTES_OPS_SINGLE_SOURCE）；批量路径单次堆分配（AnsiEnsureCapacity 复用 Cap + 单 Move），消除双倍堆分配
  nextpas.core.bytes.ops.AnsiEnsureCapacity(FParamAnsi[AIndex-1], SizeUInt(LLen));
  nextpas.core.bytes.ops.AnsiSetLogicalLenNoRealloc(FParamAnsi[AIndex-1], SizeUInt(LLen));
  if LLen > 0 then
    Move(LBuf[0], PAnsiChar(FParamAnsi[AIndex-1])^, SizeUInt(LLen));
  FParamIsNull[AIndex-1] := False;
end;

procedure TDbDmQuery.BindDouble(AIndex: Integer; const AValue: Double);
var
  LBuf: array[0..31] of AnsiChar;
  LLen: Int32;
begin
  if (AIndex < 1) then raise EDbError.CreateSimple(dbkDm, 'bind index out of range');
  if Length(FParamAnsi) < AIndex then
  begin
    SetLength(FParamAnsi, AIndex);
    SetLength(FParamIsNull, AIndex);
    SetLength(FIsNullInt, AIndex);
  end;
  LLen := nextpas.core.text.number.FloatToBuffer(AValue, @LBuf[0]);
  // perf: not inline per red line 1 (Move(LBuf[0]) 索引元素作 untyped 源参禁 inline)；Schubfach 栈缓冲→Ansi 单 Move 零拷贝复用（bytes.ops 单源）；批量路径单次堆分配复用，消除双倍分配
  nextpas.core.bytes.ops.AnsiEnsureCapacity(FParamAnsi[AIndex-1], SizeUInt(LLen));
  nextpas.core.bytes.ops.AnsiSetLogicalLenNoRealloc(FParamAnsi[AIndex-1], SizeUInt(LLen));
  if LLen > 0 then
    Move(LBuf[0], PAnsiChar(FParamAnsi[AIndex-1])^, SizeUInt(LLen));
  FParamIsNull[AIndex-1] := False;
end;

procedure TDbDmQuery.BindBlob(AIndex: Integer; const AValue: TBytes);
var
  LLen: SizeUInt;
begin
  // perf: not inline per red line 1 (Move(AValue[0]) 索引元素作 untyped 源参禁 inline)；零拷贝视图 BytesToAnsiStringReuse 单 Move 复用（bytes.ops AnsiEnsureCapacity 单源 BYTES_OPS_SINGLE_SOURCE，去 BytesToString 双次物化，大对象零二次分配复用，批复用单次堆分配）
  if (AIndex < 1) then raise EDbError.CreateSimple(dbkDm, 'bind index out of range');
  if Length(FParamAnsi) < AIndex then
  begin
    SetLength(FParamAnsi, AIndex);
    SetLength(FParamIsNull, AIndex);
    SetLength(FIsNullInt, AIndex);
  end;
  LLen := SizeUInt(Length(AValue));
  nextpas.core.bytes.ops.AnsiEnsureCapacity(FParamAnsi[AIndex-1], LLen);
  nextpas.core.bytes.ops.AnsiSetLogicalLenNoRealloc(FParamAnsi[AIndex-1], LLen);
  if LLen > 0 then
    Move(AValue[0], PAnsiChar(FParamAnsi[AIndex-1])^, LLen);
  FParamIsNull[AIndex-1] := False;
end;

procedure TDbDmQuery.BindNull(AIndex: Integer);
begin
  if (AIndex < 1) then raise EDbError.CreateSimple(dbkDm, 'bind index out of range');
  if Length(FParamAnsi) < AIndex then
  begin
    SetLength(FParamAnsi, AIndex);
    SetLength(FParamIsNull, AIndex);
    SetLength(FIsNullInt, AIndex);
  end;
  FParamIsNull[AIndex-1] := True;
  FParamAnsi[AIndex-1] := '';
end;

function TDbDmQuery.Step: Boolean;
var
  LT0: QWord; LTimed: Boolean; LCode: Integer;
  LCat: TDbErrorCategory; LCon: TDbConstraintKind;
begin
  LT0 := 0; LTimed := (FTrace <> nil) and (not FEmitted) and FTrace.BeginOp(LT0);
  try
    EnsureStmt;
    DoBind;
    LCode := dpi_execute(FStmt);
    if LCode <> DPI_SUCCESS then CheckDpi(LCode, FStmt, DPI_HANDLE_STMT);
    LCode := dpi_fetch(FStmt, 0, 0);
    if LCode = DPI_NO_DATA then Result := False
    else begin CheckDpi(LCode, FStmt, DPI_HANDLE_STMT); Result := True; end;
    if LTimed then begin FEmitted := True; FTrace.NotifyQuery(LT0, FSql); end;
  except
    on E: EDmError do
    begin
      if LTimed then
      begin
        ClassifyDm(E.ErrorCode, E.SqlState, LCat, LCon);
        FTrace.NotifyError(LCat, FSql);
      end;
      RaiseDmAsDb(E);
    end;
    on E: EDbError do
    begin
      if LTimed then FTrace.NotifyError(E.Category, FSql);
      raise;
    end;
  end;
end;

procedure TDbDmQuery.Reset;
begin
  FEmitted := False;
  if FStmt <> nil then dpi_close_cursor(FStmt);
end;

function TDbDmQuery.ColumnCount: Integer;
var
  C: Integer;
begin
  EnsureStmt; dpi_col_count(FStmt, @C); Result := C;
end;

function TDbDmQuery.ColumnName(AIndex: Integer): string;
var
  N: array[0..255] of AnsiChar; T, Len, Prec, Scale, Nullable: Integer;
begin
  EnsureStmt;
  N[0] := #0;
  dpi_describe_col(FStmt, AIndex, @N[0], SizeOf(N), @T, @Len, @Prec, @Scale, @Nullable);
  Result := AnsiPtrToStr(@N[0]);
end;

function TDbDmQuery.ColumnType(AIndex: Integer): TDbColumnType;
var
  N: array[0..255] of AnsiChar; T, Len, Prec, Scale, Nullable: Integer;
begin
  dpi_describe_col(FStmt, AIndex, @N[0], SizeOf(N), @T, @Len, @Prec, @Scale, @Nullable);
  case T of
    DPI_TYPE_INTEGER, DPI_TYPE_BIGINT: Result := dbcInteger;
    DPI_TYPE_DOUBLE: Result := dbcFloat;
    DPI_TYPE_BLOB: Result := dbcBlob;
    else Result := dbcText;
  end;
end;

function TDbDmQuery.IsNull(AIndex: Integer): Boolean;
var
  Buf: array[0..7] of Byte; Len: Integer;
begin
  Len := -1;
  dpi_get_data(FStmt, AIndex, DPI_TYPE_VARCHAR, @Buf[0], SizeOf(Buf), @Len);
  Result := Len < 0;
end;

function TDbDmQuery.GetInt64(AIndex: Integer): Int64;
var
  LBuf: array[0..31] of AnsiChar;
  LLen: Integer;
  LV: Int64;
begin
  LBuf[0] := #0; LLen := 0;
  dpi_get_data(FStmt, AIndex, DPI_TYPE_VARCHAR, @LBuf[0], SizeOf(LBuf), @LLen);
  if LLen < 0 then Exit(0);
  if LLen < SizeOf(LBuf) then
  begin
    LBuf[LLen] := #0;
    if nextpas.core.text.number.ParseInt64(@LBuf[0], SizeUInt(LLen), LV) then
      Exit(LV)
    else
      Exit(0);
  end;
  nextpas.core.bytes.ops.AnsiEnsureCapacity(FFetchAnsi, SizeUInt(LLen)+1);
  nextpas.core.bytes.ops.AnsiSetLogicalLenNoRealloc(FFetchAnsi, SizeUInt(LLen));
  LLen := 0;
  dpi_get_data(FStmt, AIndex, DPI_TYPE_VARCHAR, PAnsiChar(FFetchAnsi), Length(FFetchAnsi)+1, @LLen);
  if LLen < 0 then Exit(0);
  if SizeUInt(LLen) < SizeUInt(Length(FFetchAnsi)) then
    nextpas.core.bytes.ops.AnsiSetLogicalLenNoRealloc(FFetchAnsi, SizeUInt(LLen));
  if nextpas.core.text.number.ParseInt64(PAnsiChar(FFetchAnsi), SizeUInt(Length(FFetchAnsi)), LV) then
    Result := LV
  else
    Result := 0;
end;

function TDbDmQuery.GetDouble(AIndex: Integer): Double;
var
  LBuf: array[0..63] of AnsiChar;
  LLen: Integer;
  LV: Double;
begin
  LBuf[0] := #0; LLen := 0;
  dpi_get_data(FStmt, AIndex, DPI_TYPE_VARCHAR, @LBuf[0], SizeOf(LBuf), @LLen);
  if LLen < 0 then Exit(0);
  if LLen < SizeOf(LBuf) then
  begin
    LBuf[LLen] := #0;
    if nextpas.core.text.number.ParseDouble(@LBuf[0], SizeUInt(LLen), LV) then
      Exit(LV)
    else
      Exit(0);
  end;
  nextpas.core.bytes.ops.AnsiEnsureCapacity(FFetchAnsi, SizeUInt(LLen)+1);
  nextpas.core.bytes.ops.AnsiSetLogicalLenNoRealloc(FFetchAnsi, SizeUInt(LLen));
  LLen := 0;
  dpi_get_data(FStmt, AIndex, DPI_TYPE_VARCHAR, PAnsiChar(FFetchAnsi), Length(FFetchAnsi)+1, @LLen);
  if LLen < 0 then Exit(0);
  if SizeUInt(LLen) < SizeUInt(Length(FFetchAnsi)) then
    nextpas.core.bytes.ops.AnsiSetLogicalLenNoRealloc(FFetchAnsi, SizeUInt(LLen));
  if nextpas.core.text.number.ParseDouble(PAnsiChar(FFetchAnsi), SizeUInt(Length(FFetchAnsi)), LV) then
    Result := LV
  else
    Result := 0;
end;

function TDbDmQuery.GetText(AIndex: Integer): string;
var
  Buf: array[0..4095] of AnsiChar; Len: Integer;
  LRem: Integer;
begin
  // perf: not inline per red line 1 (Move(Buf[0]) indexed untyped)；小文本栈4K单Move零拷贝+大文本单次分配流式直写Result零拷贝复用（bytes.ops 单源 BYTES_OPS_SINGLE_SOURCE，垂直与 AnsiEnsureCapacity 同源 BytesCalcGrowCap，去 AnsiString 中间物化与 AnsiPtrToStr 扫描，128KB+单往返 amortized，首片4K复用零二次往返重传，inline 薄转发零 I-Cache 膨胀）
  Buf[0] := #0; Len := 0;
  dpi_get_data(FStmt, AIndex, DPI_TYPE_VARCHAR, @Buf[0], SizeOf(Buf), @Len);
  if Len < 0 then Exit('');
  if Len < SizeOf(Buf) then
  begin
    SetLength(Result, Len);
    if Len > 0 then
      Move(Buf[0], Result[1], SizeUInt(Len));
    Exit;
  end;
  // 大字段：首片4K已在Buf，单次 StringEnsureCapacity(BytesCalcGrowCap 几何扩容) 直写 Result 单 Move 复用，避免整串二次往返重传 bandwidth 2×；剩余尾片直写 Result 尾部，剩余语义/整值重取语义双兼容
  nextpas.core.bytes.ops.StringEnsureCapacity(Result, SizeUInt(Len));
  nextpas.core.bytes.ops.StringSetLengthNoRealloc(Result, SizeUInt(Len));
  Move(Buf[0], Result[1], SizeOf(Buf));
  LRem := Len - SizeOf(Buf);
  if LRem <= 0 then Exit;
  Len := 0;
  dpi_get_data(FStmt, AIndex, DPI_TYPE_VARCHAR, PAnsiChar(Result) + SizeOf(Buf), LRem + 1, @Len);
  if Len < 0 then Exit('');
  // 兼容：驱动若为整值重取语义会回 Len=总长 (>LRem)，需整串重取兜底
  if Len > LRem then
  begin
    if SizeUInt(Len) > SizeUInt(Length(Result)) then
    begin
      nextpas.core.bytes.ops.StringEnsureCapacity(Result, SizeUInt(Len));
      nextpas.core.bytes.ops.StringSetLengthNoRealloc(Result, SizeUInt(Len));
    end;
    Len := 0;
    dpi_get_data(FStmt, AIndex, DPI_TYPE_VARCHAR, PAnsiChar(Result), Length(Result)+1, @Len);
    if Len < 0 then Exit('');
    if SizeUInt(Len) < SizeUInt(Length(Result)) then
      nextpas.core.bytes.ops.StringSetLengthNoRealloc(Result, SizeUInt(Len))
    else if Len > Length(Result) then
    begin
      // 极端截断：几何扩容重试（amortized BytesCalcGrowCap 单源，128KB+单往返）
      nextpas.core.bytes.ops.StringEnsureCapacity(Result, SizeUInt(Len));
      nextpas.core.bytes.ops.StringSetLengthNoRealloc(Result, SizeUInt(Len));
      Len := 0;
      dpi_get_data(FStmt, AIndex, DPI_TYPE_VARCHAR, PAnsiChar(Result), Length(Result)+1, @Len);
      if Len < 0 then Exit('');
      if SizeUInt(Len) < SizeUInt(Length(Result)) then
        nextpas.core.bytes.ops.StringSetLengthNoRealloc(Result, SizeUInt(Len));
    end;
    Exit;
  end;
  if SizeUInt(Len) < SizeUInt(LRem) then
    nextpas.core.bytes.ops.StringSetLengthNoRealloc(Result, SizeUInt(SizeOf(Buf) + Len));
  // 剩余语义下 Len==LRem 时已完整，无需二次整串往返
end;

function TDbDmQuery.GetBlob(AIndex: Integer): TBytes;
var
  LBuf: array[0..4095] of Byte;
  LLen: Integer;
begin
  LLen := 0;
  dpi_get_data(FStmt, AIndex, DPI_TYPE_VARCHAR, @LBuf[0], SizeOf(LBuf), @LLen);
  if LLen < 0 then Exit(nil);
  if LLen < SizeOf(LBuf) then
  begin
    SetLength(Result, LLen);
    if LLen > 0 then
      Move(LBuf[0], Result[0], LLen);
    Exit;
  end;
  SetLength(Result, LLen + 1);
  if Length(Result) = 0 then Exit(nil);
  LLen := 0;
  dpi_get_data(FStmt, AIndex, DPI_TYPE_VARCHAR, @Result[0], Length(Result), @LLen);
  if LLen < 0 then
  begin
    SetLength(Result, 0);
    Exit(nil);
  end;
  if SizeUInt(LLen) < SizeUInt(Length(Result)) then
    SetLength(Result, LLen);
end;

end.
