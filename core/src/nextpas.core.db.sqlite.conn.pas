unit nextpas.core.db.sqlite.conn;

{** @desc SQLite L2 implementation: safe facade over nextpas.core.db.sqlite.ffi.
       - TSqliteDb: open/close, Exec (DDL/DML), prepared queries,
         last_insert_rowid / changes, busy timeout, WAL checkpoint.
       - TSqliteQuery: prepared statement lifecycle (step, bind, columns).
       - ESqliteError: carries the native SQLite result code and the
         extended result code (precise constraint kind for SQLITE_CONSTRAINT,
         e.g. SQLITE_CONSTRAINT_UNIQUE vs FOREIGNKEY — see sqlite.base).
       Text is UTF-8 (SQLite native). Connections opened with FULLMUTEX
       are safe for cross-thread use; write serialization stays at
       the caller (proxy888 db layer serializes writers). *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.text.view,
  nextpas.core.db.sqlite.base,
  nextpas.core.db.sqlite.ffi;

type
  ESqliteError = class(ENextPasError)
  private
    FErrorCode: Integer;
    FExtendedErrorCode: Integer;
  public
    { 双参构造保留（extended := AErrorCode 兜底），三参构造带精确 extended code }
    constructor Create(const AErrorCode: Integer; const AMessage: string); overload;
    constructor Create(const AErrorCode: Integer; const AExtendedErrorCode: Integer;
      const AMessage: string); overload;
    property ErrorCode: Integer read FErrorCode;
    property ExtendedErrorCode: Integer read FExtendedErrorCode;
  end;

  TSqliteQuery = class
  private type
    TDeclCacheEntry = record
      DeclType: Integer;
      DeclTypeReady: Boolean;
      DeclName: string;
      DeclNameReady: Boolean;
      IsBool: Boolean;
      IsBoolReady: Boolean;
    end;
  private
    FStmt: TSqliteStmt;
    FDb: TSqliteHandle;
    // per-column decltype cache: single record array, single SetLength sync, zero alloc after first row
    FDeclCache: array of TDeclCacheEntry;
    procedure EnsureDeclCache; inline;
    function ComputeDeclType(const ADecl: PAnsiChar; const ALen: SizeUInt): Integer;
    function ComputeDeclName(const ADecl: PAnsiChar; const ALen: SizeUInt): string;
    procedure ComputeDeclAffinity(const ADecl: PAnsiChar; const ALen: SizeUInt; out AIsBool: Boolean; out ADeclType: Integer);
    procedure EnsureDeclAffinity(const AIndex: Integer);
    procedure EnsureAllDeclAffinity;
  public
    constructor Create(const ADb: TSqliteHandle; const ASql: string);
    destructor Destroy; override;

    procedure BindText(const AIndex: Integer; const AValue: string);
    procedure BindInt64(const AIndex: Integer; const AValue: Int64);
    procedure BindDouble(const AIndex: Integer; const AValue: Double);
    procedure BindBlob(const AIndex: Integer; const AValue: TBytes);
    procedure BindNull(const AIndex: Integer);
    function Step: Boolean;
    procedure Reset;
    { 清除全部绑定（语句复用前的干净状态保障） }
    procedure ClearBindings;
    function TryReset: Boolean; inline;
    function TryClearBindings: Boolean; inline;
    function ColumnCount: Integer;
    function ColumnName(const AIndex: Integer): string;
    function ColumnType(const AIndex: Integer): Integer;
    { 声明亲和类型（静态）；-1 = 无声明（表达式/聚合） }
    function ColumnDeclaredType(const AIndex: Integer): Integer;
    { 原始声明类型文本（大写化；空串 = 无声明）。供 adapter 做亲和
      规则之外的子串判定（如 INC-6 的 BOOLEAN）。 }
    function ColumnDeclaredTypeName(const AIndex: Integer): string;
    { 零拷贝视图：原始声明文本视图（无拷贝、无大写化），热路径零分配；需子串判定时配合 ScanFindSubstringCI / SpanEqualIgnoreCase 大小写不敏感判定 }
    function ColumnDeclaredTypeNameView(const AIndex: Integer): TStringView; inline;
    { 通用零拷贝包含判定：声明文本是否含子串（大小写不敏感，SIMD，零分配），热路径零扫描零分配（per-column cache 下沉至 IsBool/DeclType，通用面按需扫描） }
    function ColumnDeclaredContainsCI(const AIndex: Integer; const ANeedle: PAnsiChar; const ANeedleLen: SizeUInt): Boolean; inline;
    { 声明是否含 BOOL（INC-6）：零拷贝 SIMD 判定，结果每列静态缓存，热路径零扫描零分配 }
    function ColumnDeclaredIsBool(const AIndex: Integer): Boolean;
    { 单次物化双亲和：零拷贝单遍获取 IsBool/DeclType，首行整行缓存 50k 点查零重复分支（single-fetch single-scan，复用 per-column 缓存，inline 薄转发） }
    procedure GetDeclAffinity(const AIndex: Integer; out AIsBool: Boolean; out ADeclType: Integer); inline;
    { 批量预取：宽表首行 N 列一次性 FFI+亲和物化，单次 ColumnCount 同步+单次 SetLength+紧凑循环，摊还首行可观 FFI 成本，缓存后零扫描零分配 }
    procedure PrefetchDeclAffinity; inline;
    function GetInt64(const AIndex: Integer): Int64;
    function GetDouble(const AIndex: Integer): Double;
    function GetText(const AIndex: Integer): string;
    function GetBlob(const AIndex: Integer): TBytes;
  end;

  TSqliteDb = class
  private
    FDb: TSqliteHandle;
    FPath: string;
    procedure CheckOk(const ARC: Integer);
  public
    constructor Create(const APath: string); overload;
    constructor Create(const APath: string; const AFlags: Integer); overload;
    destructor Destroy; override;

    procedure Exec(const ASql: string);
    function Query(const ASql: string): TSqliteQuery;
    function Changes: Integer;
    function LastInsertRowId: Int64;
    procedure BusyTimeout(const AMs: Integer);
    procedure Checkpoint;
    function Version: string;
    property Path: string read FPath;
    { 原生 sqlite3* 句柄——供 sqlite.ffi 直接调用（如事务助手判断 autocommit）。 }
    property Handle: TSqliteHandle read FDb;
  end;

{ Open or create a SQLite database file (''memory'' for in-memory). }
function SqliteOpen(const APath: string): TSqliteDb;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.text.ansi,
  nextpas.core.text.scan;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: sqlite.conn must reuse bytes.ops'}
{$IFEND}

{ ===== helpers ===== }

procedure RaiseError(const ACode: Integer; const ADb: TSqliteHandle);
begin
  raise ESqliteError.Create(ACode, sqlite3_extended_errcode(ADb),
    AnsiPtrToStr(sqlite3_errmsg(ADb)));
end;

{ ===== ESqliteError ===== }

constructor ESqliteError.Create(const AErrorCode: Integer; const AMessage: string);
begin
  Create(AErrorCode, AErrorCode, AMessage);
end;

constructor ESqliteError.Create(const AErrorCode: Integer;
  const AExtendedErrorCode: Integer; const AMessage: string);
begin
  inherited Create(AMessage);
  FErrorCode := AErrorCode;
  FExtendedErrorCode := AExtendedErrorCode;
end;

{ ===== TSqliteDb ===== }

constructor TSqliteDb.Create(const APath: string);
begin
  Create(APath, SQLITE_OPEN_READWRITE or SQLITE_OPEN_CREATE or
    SQLITE_OPEN_FULLMUTEX);
end;

constructor TSqliteDb.Create(const APath: string; const AFlags: Integer);
var
  LRC: Integer;
  LErr: string;
  LExt: Integer;
  LHold: AnsiString;
begin
  inherited Create;
  FPath := APath;
  FDb := nil;
  LRC := sqlite3_open_v2(HoldAnsi(APath, LHold), FDb, AFlags, nil);
  if LRC <> SQLITE_OK then
  begin
    LErr := AnsiPtrToStr(sqlite3_errmsg(FDb));
    LExt := sqlite3_extended_errcode(FDb);
    if FDb <> nil then
    begin
      sqlite3_close_v2(FDb);
      FDb := nil;
    end;
    raise ESqliteError.Create(LRC, LExt, LErr);
  end;
end;

destructor TSqliteDb.Destroy;
begin
  if FDb <> nil then
    sqlite3_close_v2(FDb);
  inherited;
end;

procedure TSqliteDb.CheckOk(const ARC: Integer);
begin
  if ARC <> SQLITE_OK then
    RaiseError(ARC, FDb);
end;

procedure TSqliteDb.Exec(const ASql: string);
var
  LErr: PAnsiChar;
  LRC: Integer;
  LHold: AnsiString;
begin
  LErr := nil;
  LRC := sqlite3_exec(FDb, HoldAnsi(ASql, LHold), nil, nil, LErr);
  if LRC <> SQLITE_OK then
  begin
    if LErr <> nil then
    begin
      try
        raise ESqliteError.Create(LRC, sqlite3_extended_errcode(FDb),
          AnsiPtrToStr(LErr));
      finally
        sqlite3_free(LErr);
      end;
    end
    else
      RaiseError(LRC, FDb);
  end;
end;

function TSqliteDb.Query(const ASql: string): TSqliteQuery;
begin
  Result := TSqliteQuery.Create(FDb, ASql);
end;

function TSqliteDb.Changes: Integer;
begin
  Result := sqlite3_changes(FDb);
end;

function TSqliteDb.LastInsertRowId: Int64;
begin
  Result := sqlite3_last_insert_rowid(FDb);
end;

procedure TSqliteDb.BusyTimeout(const AMs: Integer);
begin
  CheckOk(sqlite3_busy_timeout(FDb, AMs));
end;

procedure TSqliteDb.Checkpoint;
begin
  CheckOk(sqlite3_wal_checkpoint(FDb, nil));
end;

function TSqliteDb.Version: string;
begin
  Result := AnsiPtrToStr(sqlite3_libversion);
end;

function SqliteOpen(const APath: string): TSqliteDb;
begin
  Result := TSqliteDb.Create(APath);
end;

{ ===== TSqliteQuery ===== }

constructor TSqliteQuery.Create(const ADb: TSqliteHandle; const ASql: string);
var
  LRC: Integer;
  LTail: PAnsiChar;
  LHold: AnsiString;
begin
  inherited Create;
  FDb := ADb;
  LRC := sqlite3_prepare_v2(FDb, HoldAnsi(ASql, LHold), -1, FStmt, @LTail);
  if LRC <> SQLITE_OK then
    RaiseError(LRC, FDb);
end;

destructor TSqliteQuery.Destroy;
begin
  if FStmt <> nil then
    sqlite3_finalize(FStmt);
  inherited;
end;

procedure TSqliteQuery.BindText(const AIndex: Integer; const AValue: string);
var
  LHold: AnsiString;
begin
  // perf: single-source via text.ansi HoldAnsi (single AnsiString alloc + zero-copy PAnsiChar bridge, SQLITE_TRANSIENT copy), gated BYTES_OPS_SINGLE_SOURCE
  if sqlite3_bind_text(FStmt, AIndex, HoldAnsi(AValue, LHold), -1,
    sqlite3_destructor_type(SQLITE_TRANSIENT)) <> SQLITE_OK then
    RaiseError(sqlite3_errcode(FDb), FDb);
end;

procedure TSqliteQuery.BindInt64(const AIndex: Integer; const AValue: Int64);
begin
  if sqlite3_bind_int64(FStmt, AIndex, AValue) <> SQLITE_OK then
    RaiseError(sqlite3_errcode(FDb), FDb);
end;

procedure TSqliteQuery.BindDouble(const AIndex: Integer; const AValue: Double);
begin
  if sqlite3_bind_double(FStmt, AIndex, AValue) <> SQLITE_OK then
    RaiseError(sqlite3_errcode(FDb), FDb);
end;

procedure TSqliteQuery.BindBlob(const AIndex: Integer; const AValue: TBytes);
var
  LP: Pointer;
  LL: Integer;
begin
  LP := nil;
  LL := Length(AValue);
  if LL > 0 then
    LP := @AValue[0];
  if sqlite3_bind_blob(FStmt, AIndex, LP, LL,
    sqlite3_destructor_type(SQLITE_TRANSIENT)) <> SQLITE_OK then
    RaiseError(sqlite3_errcode(FDb), FDb);
end;

procedure TSqliteQuery.BindNull(const AIndex: Integer);
begin
  if sqlite3_bind_null(FStmt, AIndex) <> SQLITE_OK then
    RaiseError(sqlite3_errcode(FDb), FDb);
end;

function TSqliteQuery.Step: Boolean;
var
  LRC: Integer;
begin
  Result := False;
  LRC := sqlite3_step(FStmt);
  case LRC of
    SQLITE_ROW: Result := True;
    SQLITE_DONE: Result := False;
  else
    RaiseError(LRC, FDb);
  end;
end;

procedure TSqliteQuery.Reset;
begin
  if sqlite3_reset(FStmt) <> SQLITE_OK then
    RaiseError(sqlite3_errcode(FDb), FDb);
end;

procedure TSqliteQuery.ClearBindings;
begin
  if sqlite3_clear_bindings(FStmt) <> SQLITE_OK then
    RaiseError(sqlite3_errcode(FDb), FDb);
end;

function TSqliteQuery.TryReset: Boolean; inline;
begin
  // perf: inline return-code check, zero exception frame on hot cache return path (owner反哺 L2 单源, bytes.ops single source)
  Result := sqlite3_reset(FStmt) = SQLITE_OK;
end;

function TSqliteQuery.TryClearBindings: Boolean; inline;
begin
  // perf: inline return-code check, zero exception frame, paired with TryReset for Reset+ClearBindings hot path
  Result := sqlite3_clear_bindings(FStmt) = SQLITE_OK;
end;

function TSqliteQuery.ColumnCount: Integer;
begin
  Result := sqlite3_column_count(FStmt);
end;

function TSqliteQuery.ColumnName(const AIndex: Integer): string;
begin
  Result := AnsiPtrToStr(sqlite3_column_name(FStmt, AIndex));
end;

procedure TSqliteQuery.EnsureDeclCache; inline;
var
  LCnt: Integer;
begin
  // perf: inline, single SetLength sync, zero extra alloc after first row; single source FDeclCache eliminates 5 parallel drift
  LCnt := sqlite3_column_count(FStmt);
  if Length(FDeclCache) <> LCnt then
    SetLength(FDeclCache, LCnt);
end;

function TSqliteQuery.ComputeDeclType(const ADecl: PAnsiChar; const ALen: SizeUInt): Integer;
var
  I: SizeUInt;
  LHasText, LHasBlob, LHasReal: Boolean;
  B0, B1, B2, B3: Byte;
begin
  // not inline per red line 2: single-pass state machine must not be inline (I-Cache bloat); perf: single O(N) scan vs O(4N) SIMD substring scans, zero-copy PAnsiChar view, inline ToLower, zero alloc, per-column cached via FDeclCache, hot path zero scan/zero alloc after first row; priority INT > TEXT(CHAR/CLOB/TEXT) > BLOB > REAL(REAL/FLOA/DOUB) per sqlite datatype3.html, NUMERIC fallback BLOB
  if ALen = 0 then
    Exit(SQLITE_BLOB);
  // perf: view-level zero-alloc full coverage for hot exact decls TEXT/INTEGER/REAL/BLOB via SpanEqualIgnoreCase (bytes.ops single source, inline zero-copy SIMD equality, literal refcount -1 fast path), zero scan/zero alloc after first row via FDeclCache; complex decls fallback single-pass state machine
  if ALen = 4 then
  begin
    if SpanEqualIgnoreCase(TByteSpan.Create(PByte(ADecl), 4), TByteSpan.Create(PByte(PAnsiChar('TEXT')), 4)) then Exit(SQLITE_TEXT);
    if SpanEqualIgnoreCase(TByteSpan.Create(PByte(ADecl), 4), TByteSpan.Create(PByte(PAnsiChar('BLOB')), 4)) then Exit(SQLITE_BLOB);
    if SpanEqualIgnoreCase(TByteSpan.Create(PByte(ADecl), 4), TByteSpan.Create(PByte(PAnsiChar('REAL')), 4)) then Exit(SQLITE_FLOAT);
  end
  else if ALen = 7 then
  begin
    if SpanEqualIgnoreCase(TByteSpan.Create(PByte(ADecl), 7), TByteSpan.Create(PByte(PAnsiChar('INTEGER')), 7)) then Exit(SQLITE_INTEGER);
  end;
  // single-pass state machine: one linear scan, case-insensitive, priority INT > TEXT > BLOB > REAL; INT highest -> immediate exit on first INT window, other affinities flagged and decided after scan to respect priority (avoids 4× ScanFindSubstringCI passes, first row N columns O(N) vs O(4N))
  LHasText := False;
  LHasBlob := False;
  LHasReal := False;
  for I := 0 to ALen - 1 do
  begin
    // INT window (3) — immediate exit, highest affinity
    if I + 2 < ALen then
    begin
      B0 := Byte(ADecl[I]); if (B0 >= 65) and (B0 <= 90) then Inc(B0, 32);
      B1 := Byte(ADecl[I + 1]); if (B1 >= 65) and (B1 <= 90) then Inc(B1, 32);
      B2 := Byte(ADecl[I + 2]); if (B2 >= 65) and (B2 <= 90) then Inc(B2, 32);
      if (B0 = 105) and (B1 = 110) and (B2 = 116) then // 'i','n','t'
        Exit(SQLITE_INTEGER);
    end;
    if I + 3 < ALen then
    begin
      B0 := Byte(ADecl[I]); if (B0 >= 65) and (B0 <= 90) then Inc(B0, 32);
      B1 := Byte(ADecl[I + 1]); if (B1 >= 65) and (B1 <= 90) then Inc(B1, 32);
      B2 := Byte(ADecl[I + 2]); if (B2 >= 65) and (B2 <= 90) then Inc(B2, 32);
      B3 := Byte(ADecl[I + 3]); if (B3 >= 65) and (B3 <= 90) then Inc(B3, 32);
      if not LHasText then
        if ((B0 = 99) and (B1 = 104) and (B2 = 97) and (B3 = 114)) or // CHAR
           ((B0 = 99) and (B1 = 108) and (B2 = 111) and (B3 = 98)) or // CLOB
           ((B0 = 116) and (B1 = 101) and (B2 = 120) and (B3 = 116)) then // TEXT
          LHasText := True;
      if not LHasBlob then
        if (B0 = 98) and (B1 = 108) and (B2 = 111) and (B3 = 98) then // BLOB
          LHasBlob := True;
      if not LHasReal then
        if ((B0 = 114) and (B1 = 101) and (B2 = 97) and (B3 = 108)) or // REAL
           ((B0 = 102) and (B1 = 108) and (B2 = 111) and (B3 = 97)) or // FLOA
           ((B0 = 100) and (B1 = 111) and (B2 = 117) and (B3 = 98)) then // DOUB
          LHasReal := True;
    end;
  end;
  if LHasText then Exit(SQLITE_TEXT);
  if LHasBlob then Exit(SQLITE_BLOB);
  if LHasReal then Exit(SQLITE_FLOAT);
  Result := SQLITE_BLOB;
end;

function TSqliteQuery.ComputeDeclName(const ADecl: PAnsiChar; const ALen: SizeUInt): string;
begin
  // not inline per red lines 1+2: Move(Result[1], indexed untyped) + SIMD ToUpperAscii must not be inline (constant-propagation + I-Cache bloat); perf: single source via bytes.ops AnsiToUpperStr (single alloc Move + SIMD in-place ToUpperAscii, zero extra alloc), gated BYTES_OPS_SINGLE_SOURCE
  // perf: intern common decl literals zero alloc: SpanEqualIgnoreCase (bytes.ops single source, inline zero-copy) returns literal constant (refcount -1) without heap for exact frequent decls (TEXT/BLOB/REAL/INTEGER/BOOLEAN); complex decls fallback single alloc AnsiToUpperStr
  if ALen = 4 then
  begin
    if SpanEqualIgnoreCase(TByteSpan.Create(PByte(ADecl), 4), TByteSpan.Create(PByte(PAnsiChar('TEXT')), 4)) then Exit('TEXT');
    if SpanEqualIgnoreCase(TByteSpan.Create(PByte(ADecl), 4), TByteSpan.Create(PByte(PAnsiChar('BLOB')), 4)) then Exit('BLOB');
    if SpanEqualIgnoreCase(TByteSpan.Create(PByte(ADecl), 4), TByteSpan.Create(PByte(PAnsiChar('REAL')), 4)) then Exit('REAL');
  end
  else if ALen = 7 then
  begin
    if SpanEqualIgnoreCase(TByteSpan.Create(PByte(ADecl), 7), TByteSpan.Create(PByte(PAnsiChar('BOOLEAN')), 7)) then Exit('BOOLEAN');
    if SpanEqualIgnoreCase(TByteSpan.Create(PByte(ADecl), 7), TByteSpan.Create(PByte(PAnsiChar('INTEGER')), 7)) then Exit('INTEGER');
  end;
  Result := AnsiToUpperStr(ADecl, ALen);
end;

procedure TSqliteQuery.ComputeDeclAffinity(const ADecl: PAnsiChar; const ALen: SizeUInt; out AIsBool: Boolean; out ADeclType: Integer);
var
  I, J: SizeUInt;
  LHasText, LHasBlob, LHasReal: Boolean;
  B0, B1, B2, B3: Byte;
begin
  // not inline per red line 2: single-pass unified affinity must not be inline (I-Cache bloat); perf: zero-copy single O(N) pass computes both IsBool (BOOL) and DeclType (INT/TEXT/BLOB/REAL) with shared ToLower and NUL-view, per-column cached via FDeclCache, 50k hot path single-fetch single-scan vs double-scan; priority INT > TEXT > BLOB > REAL per sqlite datatype3.html, NUMERIC fallback BLOB; bytes.ops single source via SpanEqualIgnoreCase (inline SIMD equality literal refcount -1 fast path)
  if ALen = 0 then
  begin
    AIsBool := False;
    ADeclType := SQLITE_BLOB;
    Exit;
  end;
  if ALen = 4 then
  begin
    if SpanEqualIgnoreCase(TByteSpan.Create(PByte(ADecl), 4), TByteSpan.Create(PByte(PAnsiChar('TEXT')), 4)) then begin AIsBool := False; ADeclType := SQLITE_TEXT; Exit; end;
    if SpanEqualIgnoreCase(TByteSpan.Create(PByte(ADecl), 4), TByteSpan.Create(PByte(PAnsiChar('BLOB')), 4)) then begin AIsBool := False; ADeclType := SQLITE_BLOB; Exit; end;
    if SpanEqualIgnoreCase(TByteSpan.Create(PByte(ADecl), 4), TByteSpan.Create(PByte(PAnsiChar('REAL')), 4)) then begin AIsBool := False; ADeclType := SQLITE_FLOAT; Exit; end;
    if SpanEqualIgnoreCase(TByteSpan.Create(PByte(ADecl), 4), TByteSpan.Create(PByte(PAnsiChar('BOOL')), 4)) then begin AIsBool := True; ADeclType := SQLITE_BLOB; Exit; end;
  end
  else if ALen = 7 then
  begin
    if SpanEqualIgnoreCase(TByteSpan.Create(PByte(ADecl), 7), TByteSpan.Create(PByte(PAnsiChar('INTEGER')), 7)) then begin AIsBool := False; ADeclType := SQLITE_INTEGER; Exit; end;
    if SpanEqualIgnoreCase(TByteSpan.Create(PByte(ADecl), 7), TByteSpan.Create(PByte(PAnsiChar('BOOLEAN')), 7)) then begin AIsBool := True; ADeclType := SQLITE_BLOB; Exit; end;
  end;
  // single-pass state machine: shared scan for INT/TEXT/BLOB/REAL + BOOL; flags then priority (INT highest), zero extra pass for BOOL
  AIsBool := False;
  LHasText := False;
  LHasBlob := False;
  LHasReal := False;
  // perf: local bool flags keep single loop O(N) vs O(2N) double ScanFindSubstringCI + ComputeDeclType, zero alloc
  for I := 0 to ALen - 1 do
  begin
    if I + 3 < ALen then
    begin
      B0 := Byte(ADecl[I]); if (B0 >= 65) and (B0 <= 90) then Inc(B0, 32);
      B1 := Byte(ADecl[I + 1]); if (B1 >= 65) and (B1 <= 90) then Inc(B1, 32);
      B2 := Byte(ADecl[I + 2]); if (B2 >= 65) and (B2 <= 90) then Inc(B2, 32);
      B3 := Byte(ADecl[I + 3]); if (B3 >= 65) and (B3 <= 90) then Inc(B3, 32);
      if not AIsBool then
        if (B0 = 98) and (B1 = 111) and (B2 = 111) and (B3 = 108) then // 'b','o','o','l'
          AIsBool := True;
      if not LHasText then
        if ((B0 = 99) and (B1 = 104) and (B2 = 97) and (B3 = 114)) or // CHAR
           ((B0 = 99) and (B1 = 108) and (B2 = 111) and (B3 = 98)) or // CLOB
           ((B0 = 116) and (B1 = 101) and (B2 = 120) and (B3 = 116)) then // TEXT
          LHasText := True;
      if not LHasBlob then
        if (B0 = 98) and (B1 = 108) and (B2 = 111) and (B3 = 98) then // BLOB
          LHasBlob := True;
      if not LHasReal then
        if ((B0 = 114) and (B1 = 101) and (B2 = 97) and (B3 = 108)) or // REAL
           ((B0 = 102) and (B1 = 108) and (B2 = 111) and (B3 = 97)) or // FLOA
           ((B0 = 100) and (B1 = 111) and (B2 = 117) and (B3 = 98)) then // DOUB
          LHasReal := True;
    end;
    if I + 2 < ALen then
    begin
      // INT window (3) — check after 4-window to keep BOOL/Text/Blob/Real shared ToLower work, but INT highest priority flagged
      B0 := Byte(ADecl[I]); if (B0 >= 65) and (B0 <= 90) then Inc(B0, 32);
      B1 := Byte(ADecl[I + 1]); if (B1 >= 65) and (B1 <= 90) then Inc(B1, 32);
      B2 := Byte(ADecl[I + 2]); if (B2 >= 65) and (B2 <= 90) then Inc(B2, 32);
      if (B0 = 105) and (B1 = 110) and (B2 = 116) then // 'i','n','t'
      begin
        ADeclType := SQLITE_INTEGER;
        // INT affinity wins regardless of later TEXT/BLOB/REAL; IsBool already flagged if BOOL seen before/at this window, still need to finish BOOL scan for remainder? If IsBool already true we can exit, else continue scanning only for BOOL
        if AIsBool then Exit;
        // continue scanning remaining for BOOL only to avoid second full pass
        for J := I + 3 to ALen - 1 do
        begin
          if J + 3 >= ALen then Break;
          B0 := Byte(ADecl[J]); if (B0 >= 65) and (B0 <= 90) then Inc(B0, 32);
          B1 := Byte(ADecl[J + 1]); if (B1 >= 65) and (B1 <= 90) then Inc(B1, 32);
          B2 := Byte(ADecl[J + 2]); if (B2 >= 65) and (B2 <= 90) then Inc(B2, 32);
          B3 := Byte(ADecl[J + 3]); if (B3 >= 65) and (B3 <= 90) then Inc(B3, 32);
          if (B0 = 98) and (B1 = 111) and (B2 = 111) and (B3 = 108) then begin AIsBool := True; Exit; end;
        end;
        Exit;
      end;
    end;
  end;
  if LHasText then ADeclType := SQLITE_TEXT
  else if LHasBlob then ADeclType := SQLITE_BLOB
  else if LHasReal then ADeclType := SQLITE_FLOAT
  else ADeclType := SQLITE_BLOB;
end;

procedure TSqliteQuery.EnsureDeclAffinity(const AIndex: Integer);
var
  LDecl: PAnsiChar;
  LLen: SizeUInt;
  LIsBool: Boolean;
  LDeclType: Integer;
begin
  // not inline per red line 2: NUL-scan + single-pass affinity must not be inline; perf: single sqlite3_column_decltype fetch + single NUL len + single ComputeDeclAffinity pass for both IsBool/DeclType, per-column cached dual-ready, zero duplicate ColumnDeclaredIsBool/DeclType branches, bytes.ops single source
  EnsureDeclCache;
  if (AIndex < 0) or (AIndex >= Length(FDeclCache)) then Exit;
  if FDeclCache[AIndex].IsBoolReady and FDeclCache[AIndex].DeclTypeReady then Exit;
  // wide-table fast path: first miss triggers batch prefetch to摊还首行可观 FFI 成本 (N列单次循环 vs N次分散调用，减少 ColumnCount/SetLength 分支与调用开销)
  if (Length(FDeclCache) > 4) then
  begin
    EnsureAllDeclAffinity;
    Exit;
  end;
  LDecl := sqlite3_column_decltype(FStmt, AIndex);
  if LDecl = nil then
  begin
    // nil = no decl (expression): cache sentinel -1 + false to avoid repeated FFI
    if not FDeclCache[AIndex].IsBoolReady then
    begin
      FDeclCache[AIndex].IsBool := False;
      FDeclCache[AIndex].IsBoolReady := True;
    end;
    if not FDeclCache[AIndex].DeclTypeReady then
    begin
      FDeclCache[AIndex].DeclType := -1;
      FDeclCache[AIndex].DeclTypeReady := True;
    end;
    Exit;
  end;
  // perf: StrLen via RTL optimized repne scasb/SSE zero alloc single NUL scan, replaces manual while loop byte-per-byte, bytes.ops single source gate preserved
  LLen := SizeUInt(StrLen(LDecl));
  if LLen = 0 then
  begin
    LIsBool := False;
    LDeclType := SQLITE_BLOB;
  end
  else
    ComputeDeclAffinity(LDecl, LLen, LIsBool, LDeclType);
  FDeclCache[AIndex].IsBool := LIsBool;
  FDeclCache[AIndex].IsBoolReady := True;
  FDeclCache[AIndex].DeclType := LDeclType;
  FDeclCache[AIndex].DeclTypeReady := True;
end;

procedure TSqliteQuery.EnsureAllDeclAffinity;
var
  LCnt, I: Integer;
  LDecl: PAnsiChar;
  LLen: SizeUInt;
  LIsBool: Boolean;
  LDeclType: Integer;
begin
  // not inline per red line 2: batch N-column FFI+NUL+single-pass must not be inline (I-Cache bloat); perf: single EnsureDeclCache/SetLength sync + single ColumnCount + tight loop N×(FFI+StrLen+ComputeDeclAffinity), wide-table首行批量预取摊还可观 FFI 成本, 缓存后热路径零扫描零分配零分支, L0-L3 bytes.ops single source
  EnsureDeclCache;
  LCnt := Length(FDeclCache);
  if LCnt = 0 then Exit;
  // fast sentinel: if first and last dual-ready, probe any hole; common batch后全 ready 则零扫描直接返回
  if FDeclCache[0].IsBoolReady and FDeclCache[0].DeclTypeReady and
     FDeclCache[LCnt - 1].IsBoolReady and FDeclCache[LCnt - 1].DeclTypeReady then
  begin
    for I := 0 to LCnt - 1 do
      if not (FDeclCache[I].IsBoolReady and FDeclCache[I].DeclTypeReady) then Break
      else if I = LCnt - 1 then Exit;
  end;
  for I := 0 to LCnt - 1 do
  begin
    if FDeclCache[I].IsBoolReady and FDeclCache[I].DeclTypeReady then Continue;
    LDecl := sqlite3_column_decltype(FStmt, I);
    if LDecl = nil then
    begin
      FDeclCache[I].IsBool := False;
      FDeclCache[I].IsBoolReady := True;
      FDeclCache[I].DeclType := -1;
      FDeclCache[I].DeclTypeReady := True;
      Continue;
    end;
    LLen := SizeUInt(StrLen(LDecl));
    if LLen = 0 then
    begin
      LIsBool := False;
      LDeclType := SQLITE_BLOB;
    end
    else
      ComputeDeclAffinity(LDecl, LLen, LIsBool, LDeclType);
    FDeclCache[I].IsBool := LIsBool;
    FDeclCache[I].IsBoolReady := True;
    FDeclCache[I].DeclType := LDeclType;
    FDeclCache[I].DeclTypeReady := True;
  end;
end;

function TSqliteQuery.ColumnType(const AIndex: Integer): Integer;
begin
  Result := sqlite3_column_type(FStmt, AIndex);
end;

{ 声明亲和类型（静态，空结果集亦可读，对齐 pg 静态 OID 行为）。
  返回 -1 = 无声明（表达式/聚合），由调用方回落到行值类型。
  亲和子串规则依 sqlite3 文档（datatype3.html）。 }
function TSqliteQuery.ColumnDeclaredType(const AIndex: Integer): Integer;
begin
  // perf: single-pass EnsureDeclAffinity eliminates duplicate ColumnDeclaredIsBool/DeclType branches, zero second fetch/scan, per-column dual-ready cache, 50k point query first-row zero duplicate
  EnsureDeclAffinity(AIndex);
  if (AIndex >= 0) and (AIndex < Length(FDeclCache)) and FDeclCache[AIndex].DeclTypeReady then
    Exit(FDeclCache[AIndex].DeclType);
  Result := -1;
end;

function TSqliteQuery.ColumnDeclaredTypeName(const AIndex: Integer): string;
var
  LDecl: PAnsiChar;
  LLen: SizeUInt;
begin
  LDecl := sqlite3_column_decltype(FStmt, AIndex);
  if LDecl = nil then
    Exit('');
  EnsureDeclCache;
  if (AIndex >= 0) and (AIndex < Length(FDeclCache)) and FDeclCache[AIndex].DeclNameReady then
    Exit(FDeclCache[AIndex].DeclName);
  LLen := SizeUInt(StrLen(LDecl));
  Result := ComputeDeclName(LDecl, LLen);
  if (AIndex >= 0) and (AIndex < Length(FDeclCache)) then
  begin
    FDeclCache[AIndex].DeclName := Result;
    FDeclCache[AIndex].DeclNameReady := True;
  end;
end;

function TSqliteQuery.ColumnDeclaredTypeNameView(const AIndex: Integer): TStringView; inline;
var
  LDecl: PAnsiChar;
  LLen: SizeUInt;
begin
  // perf: inline zero-copy view via text.view (single source, no alloc), bytes.ops single source, hot path zero scan/zero alloc, caller does CI compare without uppercasing
  LDecl := sqlite3_column_decltype(FStmt, AIndex);
  if LDecl = nil then
    Exit(TStringView.Create(nil, 0));
  LLen := SizeUInt(StrLen(LDecl));
  Result := TStringView.Create(LDecl, LLen);
end;

function TSqliteQuery.ColumnDeclaredContainsCI(const AIndex: Integer; const ANeedle: PAnsiChar; const ANeedleLen: SizeUInt): Boolean; inline;
var
  LDecl: PAnsiChar;
  LLen: SizeUInt;
begin
  // perf: inline zero-copy SIMD ScanFindSubstringCI (bytes.ops single source via text.scan), zero alloc, no uppercasing; generic BOOL/containment without per-column string cache, fast BOOL cache path零扫描判定
  if (ANeedleLen = 4) then
  begin
    // fast BOOL path: reuse per-column IsBool cache zero scan zero SIMD
    if ((ANeedle[0]='B') or (ANeedle[0]='b')) and ((ANeedle[1]='O') or (ANeedle[1]='o')) and ((ANeedle[2]='O') or (ANeedle[2]='o')) and ((ANeedle[3]='L') or (ANeedle[3]='l')) then
      Exit(ColumnDeclaredIsBool(AIndex));
  end;
  LDecl := sqlite3_column_decltype(FStmt, AIndex);
  if (LDecl = nil) or (ANeedle = nil) or (ANeedleLen = 0) then
    Exit(False);
  LLen := SizeUInt(StrLen(LDecl));
  if LLen = 0 then
    Exit(False);
  Result := ScanFindSubstringCI(LDecl, LLen, ANeedle, ANeedleLen) >= 0;
end;

function TSqliteQuery.ColumnDeclaredIsBool(const AIndex: Integer): Boolean;
begin
  // not inline per red line 2: body must not be inline (I-Cache bloat); perf: delegates to single-pass EnsureDeclAffinity, zero duplicate fetch/scan, per-column cached
  EnsureDeclAffinity(AIndex);
  if (AIndex >= 0) and (AIndex < Length(FDeclCache)) and FDeclCache[AIndex].IsBoolReady then
    Exit(FDeclCache[AIndex].IsBool);
  Result := False;
end;

procedure TSqliteQuery.PrefetchDeclAffinity; inline;
begin
  // perf: inline thin batch forwarder, zero alloc, single ColumnCount + tight loop批量预取, wide-table首行摊还 FFI, bytes.ops single source
  EnsureAllDeclAffinity;
end;

procedure TSqliteQuery.GetDeclAffinity(const AIndex: Integer; out AIsBool: Boolean; out ADeclType: Integer); inline;
begin
  // perf: inline thin forwarder to single-pass EnsureDeclAffinity (wide-table auto-batch), zero extra call after first row (cached), single-fetch single-scan, bytes.ops single source, 50k点查首行单次物化零重复分支
  EnsureDeclAffinity(AIndex);
  if (AIndex >= 0) and (AIndex < Length(FDeclCache)) and FDeclCache[AIndex].IsBoolReady and FDeclCache[AIndex].DeclTypeReady then
  begin
    AIsBool := FDeclCache[AIndex].IsBool;
    ADeclType := FDeclCache[AIndex].DeclType;
  end
  else if (AIndex >= 0) and (AIndex < Length(FDeclCache)) then
  begin
    // partial ready fallback (should not happen after EnsureDeclAffinity, but guard)
    if FDeclCache[AIndex].IsBoolReady then AIsBool := FDeclCache[AIndex].IsBool else AIsBool := False;
    if FDeclCache[AIndex].DeclTypeReady then ADeclType := FDeclCache[AIndex].DeclType else ADeclType := -1;
  end
  else
  begin
    AIsBool := False;
    ADeclType := -1;
  end;
end;

function TSqliteQuery.GetInt64(const AIndex: Integer): Int64;
begin
  Result := sqlite3_column_int64(FStmt, AIndex);
end;

function TSqliteQuery.GetDouble(const AIndex: Integer): Double;
begin
  Result := sqlite3_column_double(FStmt, AIndex);
end;

function TSqliteQuery.GetText(const AIndex: Integer): string;
var
  LP: PAnsiChar;
  LL: Integer;
begin
  // perf: zero-copy single alloc Move, pattern identical to bytes.ops BytesToString single Move (SetLength + Move(Result[1], LL)), gated BYTES_OPS_SINGLE_SOURCE
  LP := sqlite3_column_text(FStmt, AIndex);
  LL := sqlite3_column_bytes(FStmt, AIndex);
  SetString(Result, LP, LL);
end;

function TSqliteQuery.GetBlob(const AIndex: Integer): TBytes;
var
  LP: Pointer;
  LL: Integer;
  LSpan: TByteSpan;
begin
  LP := sqlite3_column_blob(FStmt, AIndex);
  LL := sqlite3_column_bytes(FStmt, AIndex);
  if LL <= 0 then
    Exit(nil);
  // perf: zero-copy via bytes.ops SpanClone single Move single alloc, single source BYTES_OPS_SINGLE_SOURCE
  LSpan := TByteSpan.Create(PByte(LP), SizeUInt(LL));
  Result := SpanClone(LSpan);
end;

end.