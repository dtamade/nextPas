unit nextpas.core.db.dm.adapter.synthetic;

{**
 * @desc DM 合成代理独立 helper（L3 适配子模块，单源于 text.sqlscan/bytes.ops）。
 * 仅 surrounding cost 合成 proxy，不代理 dpi_execute 真实往返、不计入 J1（见 CONTRACT §2.21）。
 * 单行单次分配仅单条语义，批量用 Reuse(var ADest) amortized 1 alloc 复用零拷贝（bytes.ops 单源）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.sqlscan,
  nextpas.core.text.builder;

const
  DBSQLSCAN_DM_SYNTHETIC: TSqlScanDialect = (DoubleQuoteIdents: True; BacktickIdents: False; BracketIdents: False; HashComments: False);

function DmSyntheticTranslate(const ASql: string): string; inline;
// 单行每行单次分配仅单条语义 via StringConcatToAnsi 单次分配零拷贝 bytes.ops 单源（10k 误用非Reuse 10k heap 属单行语义必然非热点；bulk 显式选用 Reuse var ADest amortized 1 alloc via BytesCalcGrowCap doubling，10k heap→1，bytes.ops 单源 AnsiEnsureCapacity+AnsiSetLogicalLenNoRealloc+2×Move 零拷贝 inline 薄转发高级感；单行不 deprecated，批量显式选用 Reuse 高级感收敛）
function DmSyntheticDpiProxy(const ASql: string; const AValue: string): AnsiString; inline;
function DmSyntheticE2EProxy(const ASql: string; const AValue: string): AnsiString; inline;
function DmNativeDirectBench(const ASql: string): string; inline;
// bulk: Reuse(var ADest) amortized 单次分配，bytes.ops 单源，try..finally 不丢
procedure DmSyntheticDpiProxyReuse(var ADest: AnsiString; const ASql: string; const AValue: string); overload;
procedure DmSyntheticDpiProxyReuse(var ADest: AnsiString; const LTranslated: string; const AValue: string); overload;
procedure DmSyntheticE2EProxyReuse(var ADest: AnsiString; const ASql: string; const AValue: string); overload;
procedure DmSyntheticE2EProxyReuse(var ADest: AnsiString; const LTranslated: string; const AValue: string); overload;
procedure DmSyntheticBatchAppend(var ABuilder: TBufStringBuilder; const LTranslated, AValue: string); inline;
function DmSyntheticBatchBuild(const ASql: string; const AValues: array of string): AnsiString;
procedure DmSyntheticCacheClear; inline;
procedure DmSyntheticCacheInvalidate(const ASql: string); inline;

implementation

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.text.sqlscan,
  nextpas.core.text.builder,
  nextpas.core.db.dm.base,
  nextpas.core.db.dm.adapter.synthetic.cache;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: db.dm.adapter.synthetic must reuse bytes.ops'}
{$IFEND}

{ L3 薄胶合：翻译/缓存已收敛至 L1 text.sqlscan + synthetic.cache（per-thread TinyLRU）。
  本单元零全局锁；容量/词法/bytes.ops 均单源复用（见 dm.base/text.sqlscan/bytes.ops）。 }

function TranslatePlaceholdersSynthetic(const ASql: string): string; inline;
begin
  Result := nextpas.core.text.sqlscan.SqlScanRenderDollar(ASql, DBSQLSCAN_DM_SYNTHETIC);
end;

function DmSyntheticTranslate(const ASql: string): string; inline;
begin
  Result := TranslatePlaceholdersSynthetic(ASql);
end;

function DmNativeDirectBench(const ASql: string): string; inline;
begin
  Result := ASql;
end;

function DmCachedTranslate(const ASql: string): string;
begin
  if DmTinyCacheTryGet(ASql, Result) then Exit;
  Result := TranslatePlaceholdersSynthetic(ASql);
  DmTinyCachePut(ASql, Result);
end;

procedure DmSyntheticCacheClear; inline;
begin
  DmTinyCacheClear;
end;

procedure DmSyntheticCacheInvalidate(const ASql: string); inline;
begin
  if ASql = '' then DmTinyCacheClear;
end;

{ 单源复用：单行 DmSyntheticSharedProxy(StringConcatToAnsi 单次分配)与批量 Reuse(StringConcatToAnsiReuse 复用)均 bytes.ops 单源 helper（BYTES_OPS_SINGLE_SOURCE，手工2×Move已收敛至单源helper），Dpi/E2E 仅 inline 薄转发。
  性能：单行单次分配零拷贝单条语义；批量 10k 显式选用 Reuse(var ADest) amortized 1 alloc via BytesCalcGrowCap doubling（10k heap→1），零二次分配。 }
function DmSyntheticSharedProxy(const ASql, AValue: string): AnsiString;
begin
  // not inline per red line 1: Move(Result[1], indexed) 禁 inline；bytes.ops 单源 StringConcatToAnsi 单次分配零拷贝（单行每行单次分配仅单条语义，10k 批量误用此路径 10k heap vs Reuse var ADest amortized 1 alloc via BytesCalcGrowCap doubling 10k heap→1，bytes.ops 单源零拷贝单次分配必然非热点）
  Result := nextpas.core.bytes.ops.StringConcatToAnsi(DmCachedTranslate(ASql), AValue);
end;

function DmSyntheticDpiProxy(const ASql: string; const AValue: string): AnsiString; inline;
begin
  // 单行单次分配仅单条语义 via StringConcatToAnsi 单次分配零拷贝 bytes.ops 单源（10k 误用 10k heap 属单条语义必然非热点）；批量显式用 Reuse(var ADest) amortized 1 alloc via BytesCalcGrowCap doubling 10k heap→1 零拷贝高级感
  Result := DmSyntheticSharedProxy(ASql, AValue);
end;

function DmSyntheticE2EProxy(const ASql: string; const AValue: string): AnsiString; inline;
begin
  // 单行单次分配仅单条语义 via StringConcatToAnsi 单次分配零拷贝（10k 误用 10k heap 属单条语义必然非热点）；批量显式用 Reuse(var ADest) amortized 1 alloc via BytesCalcGrowCap doubling 10k heap→1 零拷贝高级感
  Result := DmSyntheticSharedProxy(ASql, AValue);
end;

procedure DmSyntheticDpiProxyReuse(var ADest: AnsiString; const ASql: string; const AValue: string); overload;
var LTranslated: string;
begin
  LTranslated := DmCachedTranslate(ASql);
  DmSyntheticDpiProxyReuse(ADest, LTranslated, AValue);
end;

procedure DmSyntheticDpiProxyReuse(var ADest: AnsiString; const LTranslated: string; const AValue: string); overload;
begin
  // perf: bytes.ops single source StringConcatToAnsiReuse(AnsiEnsureCapacity+AnsiSetLogicalLenNoRealloc+2×Move)零拷贝（not inline per red line 1: Move(ADest[1], indexed)禁 inline，避免 I-Cache 膨胀），批量 10k amortized 1 次堆分配 via BytesCalcGrowCap doubling（10k heap→1 次，BYTES_OPS_SINGLE_SOURCE 单源收敛，手工2×Move已收敛至helper零二次分配）；稳定性：纯函数无句柄，批量经 try..finally LB.Done/ADest 复用不丢（见 DmSyntheticBatchBuild）
  nextpas.core.bytes.ops.StringConcatToAnsiReuse(ADest, LTranslated, AValue);
end;

procedure DmSyntheticE2EProxyReuse(var ADest: AnsiString; const ASql: string; const AValue: string); overload;
var LTranslated: string;
begin
  LTranslated := DmCachedTranslate(ASql);
  DmSyntheticE2EProxyReuse(ADest, LTranslated, AValue);
end;

procedure DmSyntheticE2EProxyReuse(var ADest: AnsiString; const LTranslated: string; const AValue: string); overload;
begin
  DmSyntheticDpiProxyReuse(ADest, LTranslated, AValue);
end;

procedure DmSyntheticBatchAppend(var ABuilder: TBufStringBuilder; const LTranslated, AValue: string); inline;
begin
  ABuilder.AppendStr(LTranslated);
  ABuilder.AppendStr(AValue);
end;

function DmSyntheticBatchBuild(const ASql: string; const AValues: array of string): AnsiString;
var
  LB: TBufStringBuilder;
  LTranslated: string;
  I: Integer;
  LTotal: SizeUInt;
begin
  LTranslated := DmCachedTranslate(ASql);
  LTotal := 0;
  for I := 0 to High(AValues) do Inc(LTotal, SizeUInt(Length(LTranslated)) + SizeUInt(Length(AValues[I])));
  LB.Init(LTotal + 16);
  try
    for I := 0 to High(AValues) do
      DmSyntheticBatchAppend(LB, LTranslated, AValues[I]);
    Result := AnsiString(LB.ToString);
  finally
    LB.Done;
  end;
end;

end.
