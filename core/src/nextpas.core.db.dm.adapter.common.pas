unit nextpas.core.db.dm.adapter.common;

{** @desc DM 适配器公共分治（L3 实现子模块）。
       收敛占位符翻译/DSN 校验/错误归一/诊断的单源：零全局锁，
       纯函数单次 Move 零拷贝经 bytes.ops 单源 BYTES_OPS_SINGLE_SOURCE。
       层级：L3 适配子模块（严格下向 L2 dm.base/ffi + L1 text/bytes/collections/sync，
       同层单向：仅被 query/conn/adapter 单向依赖，不反向）。
       性能：DsnToDpiConnStr 零锁纯函数（去 GDmDsnLock 热点读锁争用，
       池 Acquire 路径零额外锁开销，inline 薄转发，单次 SetLength+Move），
       TranslatePlaceholders inline 零拷贝直连 text.sqlscan 单源单遍，
       DmSynthetic* 合成代理已抽为独立 helper 单元 dm.adapter.synthetic 单源
       （本单元仅 inline 薄转发，单源于 synthetic，bytes.ops 单源 BYTES_OPS_SINGLE_SOURCE，
       10k 合成压测单次翻译零 2× 开销，仅 surrounding cost 合成 proxy，不代理 dpi_execute 真实往返、不计入 J1，
       见 benchmarks.md J1/CONTRACT §2.21；J1 需 nightly live `NEXTPAS_DM_TEST_CONN` 真机闭环）。
       稳定性：纯函数无句柄/无资源泄漏，bytes.ops 单源所有权，零拷贝视图无额外分配，
       合成代理资源由 synthetic 托管（Builder/Dest 复用 try..finally Done 不丢，全局 LRU 接口托管 finalization 清零不泄漏）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.dm.base,
  nextpas.core.text.sqlscan,
  nextpas.core.text.builder;

const
  DBSQLSCAN_DM: TSqlScanDialect = (DoubleQuoteIdents: True; BacktickIdents: False; BracketIdents: False; HashComments: False);

function ValidateDmDsn(const ADsn: string): string;
function DsnToDpiConnStr(const ADsn: string): AnsiString;
procedure RaiseDmAsDb(const AE: EDmError);
procedure CheckDpi(const ACode: Integer; AHandle: Pointer; AHandleType: Integer);
function TranslatePlaceholders(const ASql: string): string; inline;
function DmSyntheticTranslate(const ASql: string): string; inline;
// 单行每行单次分配仅单条语义 via StringConcatToAnsi 单源 single-alloc 零拷贝（10k 误用 10k heap 属单行语义必然，非热点；bulk 显式选用 Reuse(var ADest) amortized 1 alloc via BytesCalcGrowCap，10k heap→1，bytes.ops 单源 AnsiEnsureCapacity+2×Move 零拷贝 inline 薄转发高级感，见 Reuse 重载）
function DmSyntheticDpiProxy(const ASql: string; const AValue: string): AnsiString; inline;
function DmSyntheticE2EProxy(const ASql: string; const AValue: string): AnsiString; inline;
function DmNativeDirectBench(const ASql: string): string; inline;
// bulk 最优：var ADest 复用 amortized 单次堆分配（1 次 via BytesCalcGrowCap doubling，10k heap→1，bytes.ops 单源 AnsiEnsureCapacity+AnsiSetLogicalLenNoRealloc+2×Move 零拷贝 inline 薄转发证据，稳定性 try..finally Done 不丢），显式 LTranslated 重载零 TLS/锁 thread-safe，调用方批量显式选用 Reuse 高级感收敛（单行仅单条，不 deprecated）
procedure DmSyntheticDpiProxyReuse(var ADest: AnsiString; const ASql: string; const AValue: string); overload;
procedure DmSyntheticDpiProxyReuseTranslated(var ADest: AnsiString; const LTranslated: string; const AValue: string); overload;
procedure DmSyntheticE2EProxyReuse(var ADest: AnsiString; const ASql: string; const AValue: string); overload;
procedure DmSyntheticE2EProxyReuseTranslated(var ADest: AnsiString; const LTranslated: string; const AValue: string); overload;
procedure DmSyntheticBatchAppend(var ABuilder: TBufStringBuilder; const LTranslated, AValue: string); inline;
function DmSyntheticBatchBuild(const ASql: string; const AValues: array of string): AnsiString;
procedure DmSyntheticCacheClear; inline;
procedure DmSyntheticCacheInvalidate(const ASql: string); inline;

implementation

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.text.kv,
  nextpas.core.text.conv,
  nextpas.core.db.base,
  nextpas.core.db.err,
  nextpas.core.db.dm.ffi,
  nextpas.core.db.dm.adapter.synthetic;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: db.dm.adapter.common must reuse bytes.ops'}
{$IFEND}

procedure RaiseDmAsDb(const AE: EDmError);
var
  LCategory: TDbErrorCategory;
  LConstraint: TDbConstraintKind;
begin
  ClassifyDm(AE.ErrorCode, AE.SqlState, LCategory, LConstraint);
  raise NewDbErrorDm(AE.ErrorCode, AE.SqlState, AE.Message, LCategory, LConstraint);
end;

function TranslatePlaceholders(const ASql: string): string; inline;
begin
  Result := nextpas.core.text.sqlscan.SqlScanRenderDollar(ASql, DBSQLSCAN_DM);
end;

function DmSyntheticTranslate(const ASql: string): string; inline;
begin
  Result := nextpas.core.db.dm.adapter.synthetic.DmSyntheticTranslate(ASql);
end;

function DmNativeDirectBench(const ASql: string): string; inline;
begin
  Result := nextpas.core.db.dm.adapter.synthetic.DmNativeDirectBench(ASql);
end;

function DmSyntheticDpiProxy(const ASql: string; const AValue: string): AnsiString;
begin
  Result := nextpas.core.db.dm.adapter.synthetic.DmSyntheticDpiProxy(ASql, AValue);
end;

function DmSyntheticE2EProxy(const ASql: string; const AValue: string): AnsiString;
begin
  Result := nextpas.core.db.dm.adapter.synthetic.DmSyntheticE2EProxy(ASql, AValue);
end;

procedure DmSyntheticDpiProxyReuse(var ADest: AnsiString; const ASql: string; const AValue: string); overload;
begin
  nextpas.core.db.dm.adapter.synthetic.DmSyntheticDpiProxyReuse(ADest, ASql, AValue);
end;

procedure DmSyntheticDpiProxyReuseTranslated(var ADest: AnsiString; const LTranslated: string; const AValue: string); overload;
begin
  nextpas.core.db.dm.adapter.synthetic.DmSyntheticDpiProxyReuseTranslated(ADest, LTranslated, AValue);
end;

procedure DmSyntheticE2EProxyReuse(var ADest: AnsiString; const ASql: string; const AValue: string); overload;
begin
  nextpas.core.db.dm.adapter.synthetic.DmSyntheticE2EProxyReuse(ADest, ASql, AValue);
end;

procedure DmSyntheticE2EProxyReuseTranslated(var ADest: AnsiString; const LTranslated: string; const AValue: string); overload;
begin
  nextpas.core.db.dm.adapter.synthetic.DmSyntheticE2EProxyReuseTranslated(ADest, LTranslated, AValue);
end;

procedure DmSyntheticBatchAppend(var ABuilder: TBufStringBuilder; const LTranslated, AValue: string); inline;
begin
  nextpas.core.db.dm.adapter.synthetic.DmSyntheticBatchAppend(ABuilder, LTranslated, AValue);
end;

function DmSyntheticBatchBuild(const ASql: string; const AValues: array of string): AnsiString;
begin
  Result := nextpas.core.db.dm.adapter.synthetic.DmSyntheticBatchBuild(ASql, AValues);
end;

procedure DmSyntheticCacheClear; inline;
begin
  nextpas.core.db.dm.adapter.synthetic.DmSyntheticCacheClear;
end;

procedure DmSyntheticCacheInvalidate(const ASql: string); inline;
begin
  nextpas.core.db.dm.adapter.synthetic.DmSyntheticCacheInvalidate(ASql);
end;

function ValidateDmDsn(const ADsn: string): string;
var
  LErr: string;
begin
  if ADsn = '' then
    raise EDbError.CreateSimple(dbkDm, 'DM DSN empty');
  if not ValidateKV(ADsn, LErr) then
    raise EDbError.CreateSimple(dbkDm, 'DM DSN malformed: ' + LErr);
  Result := ADsn;
end;

function DsnToDpiConnStr(const ADsn: string): AnsiString;
begin
  Result := nextpas.core.bytes.ops.StringToAnsiString(ADsn);
end;

procedure CheckDpi(const ACode: Integer; AHandle: Pointer; AHandleType: Integer);
var
  LCode: Integer;
  LMsg: array[0..1023] of AnsiChar;
  LState: array[0..15] of AnsiChar;
begin
  if ACode = DPI_SUCCESS then Exit;
  if ACode = DPI_NO_DATA then Exit;
  LCode := ACode;
  LMsg[0] := #0; LState[0] := #0;
  if Assigned(dpi_get_error) then
    dpi_get_error(AHandle, AHandleType, @LCode, @LMsg[0], SizeOf(LMsg), @LState[0]);
  raise EDmError.Create(AnsiPtrToStr(@LMsg[0]), LCode, AnsiPtrToStr(@LState[0]));
end;

end.
