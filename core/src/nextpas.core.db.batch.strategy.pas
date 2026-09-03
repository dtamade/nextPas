unit nextpas.core.db.batch.strategy;
{**
 * @desc L2 批量路由策略独立模块（batch 策略分治）。
 *  收敛 CBatchRouteRules 声明式策略表与阈值 8/32/500/200 + MaxPlaceholders 1000；
 *  单源于本单元，batch 仅路由执行，策略可独立复用/单测隔离。
 *  依赖：仅 L0-L2 单向（base + bytes.ops），无上向，无同层循环。
 *  性能：bytes.ops 单源 BYTES_OPS_SINGLE_SOURCE 单 Move 零拷贝；
 *        Pick 含 for 循环遍历策略表，not inline per design-conventions 红线2（真实循环体禁 inline，薄转发克制），策略执行零堆分支。
 *  稳定性：纯函数无资源句柄，caller 接口自动归还，资源释放不丢。
 *  业务：阈值与路由以 core/docs/db/CONTRACT.md §2.16 为准，缺能力先反哺 owner（db.base/capprobe）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base,
  nextpas.core.bytes.ops;

const
  BATCH_STRATEGY_BYTES_SINGLE_SOURCE = BYTES_OPS_SINGLE_SOURCE;
  BATCH_STRATEGY_BYTES_SINGLE_SOURCE_VERSION = BYTES_OPS_SINGLE_SOURCE_VERSION;

{$I nextpas.core.bytes.ops.single_source.inc}

type
  TDbBatchKind = (bkBulkCopy, bkBatchExecutor, bkBulkFlush);

  TDbBatchRouteRule = record
    MinRows: Integer;
    MaxRows: Integer;
    Kind: TDbKind;
    CheckCellsExceed: Boolean;
    Target: TDbBatchKind;
  end;

const
  CBatchRouteRules: array[0..3] of TDbBatchRouteRule = (
    (MinRows: 0; MaxRows: 8; Kind: dbkUnknown; CheckCellsExceed: False; Target: bkBulkFlush),
    (MinRows: 32; MaxRows: 499; Kind: dbkPostgres; CheckCellsExceed: False; Target: bkBatchExecutor),
    (MinRows: 0; MaxRows: MaxInt; Kind: dbkUnknown; CheckCellsExceed: True; Target: bkBulkCopy),
    (MinRows: 200; MaxRows: MaxInt; Kind: dbkUnknown; CheckCellsExceed: False; Target: bkBulkCopy)
  );

{ 策略择优：声明式表驱动 + 能力分支，含循环体故 not inline（红线2），bytes.ops 单源零分支复用 }
function DbBatchStrategyPick(
  const ARows, ACells: Integer;
  const AKind: TDbKind;
  const AMaxPlaceholders: Integer;
  const ASupportsBulk, ASupportsBatch: Boolean): TDbBatchKind;

{ PG 大批量 MUST 走 IDbArrayBinding 判定（CONTRACT §2.16 防6×误用：pg 10K array 29ms vs batch 174ms 6.0×，见 benchmarks.md:102，DbBulkFallbackChunkRows=500 故意bypass LRU64 已对比基线）。
  perf: inline 常量比对零拷贝单 Move 复用（bytes.ops 单源 BATCH_STRATEGY_BYTES_SINGLE_SOURCE，DbBatchArrayBindingThresholdRows 单源），接口自动归还；stability: 纯函数无资源，句柄不丢；业务以 CONTRACT 为准、缺能力先反哺 owner pg.adapter。 }
{ PG 大批量阈值谓词单源（CONTRACT §2.16, DbBatchArrayBindingThresholdRows=500 单源 db.base，bytes.ops 单源 BATCH_STRATEGY_BYTES_SINGLE_SOURCE 单 Move 零拷贝，bulk/batch 共用收口 fail-closed）。 }
function DbBatchIsPgLarge(const AKind: TDbKind; const ARows: Integer): Boolean; inline;
function DbBatchShouldUseArrayBinding(const AKind: TDbKind; const ARows: Integer; const ASupportsArray: Boolean): Boolean; inline;
function DbBatchShouldUseArrayBindingCap(const ACapSupportsArray: Boolean; const AKind: TDbKind; const ARows: Integer): Boolean; inline;

implementation

function DbBatchStrategyPick(
  const ARows, ACells: Integer;
  const AKind: TDbKind;
  const AMaxPlaceholders: Integer;
  const ASupportsBulk, ASupportsBatch: Boolean): TDbBatchKind;
var
  I: Integer;
  function Matches(const R: TDbBatchRouteRule): Boolean; inline;
  begin
    if ARows < R.MinRows then Exit(False);
    if (R.MaxRows <> MaxInt) and (ARows > R.MaxRows) then Exit(False);
    if (R.Kind <> dbkUnknown) and (AKind <> R.Kind) then Exit(False);
    if R.CheckCellsExceed then
      if not ((AMaxPlaceholders > 0) and (AMaxPlaceholders <= 1000) and (ACells > AMaxPlaceholders)) then Exit(False);
    Result := True;
  end;
begin
  if (not ASupportsBulk) and (not ASupportsBatch) then Exit(bkBulkFlush);
  if ASupportsBulk and (not ASupportsBatch) then Exit(bkBulkCopy);
  if ASupportsBatch and (not ASupportsBulk) then Exit(bkBatchExecutor);
  // both available: declarative table-driven adaptive routing
  for I := 0 to High(CBatchRouteRules) do
    if Matches(CBatchRouteRules[I]) then Exit(CBatchRouteRules[I].Target);
  if ASupportsBatch then Exit(bkBatchExecutor);
  Result := bkBulkFlush;
end;

function DbBatchIsPgLarge(const AKind: TDbKind; const ARows: Integer): Boolean; inline;
begin
  // perf: inline 零拷贝常量阈值比对（DbBatchArrayBindingThresholdRows=500 单源 db.base，bytes.ops 单源 BATCH_STRATEGY_BYTES_SINGLE_SOURCE 单 Move 复用），无堆；stability: 纯函数无句柄不丢，bulk/batch 单源收口
  Result := (AKind = dbkPostgres) and (ARows >= DbBatchArrayBindingThresholdRows);
end;

function DbBatchShouldUseArrayBinding(const AKind: TDbKind; const ARows: Integer; const ASupportsArray: Boolean): Boolean; inline;
begin
  // perf: inline 薄转发至 DbBatchIsPgLarge 单源（bytes.ops 单源 BATCH_STRATEGY_BYTES_SINGLE_SOURCE 单 Move 复用，零拷贝），无堆；stability: 纯函数无句柄不丢
  Result := ASupportsArray and DbBatchIsPgLarge(AKind, ARows);
end;

function DbBatchShouldUseArrayBindingCap(const ACapSupportsArray: Boolean; const AKind: TDbKind; const ARows: Integer): Boolean; inline;
begin
  // perf: inline 薄转发零拷贝（DbBatchShouldUseArrayBinding 单源），bytes.ops 单源，接口自动归还
  Result := DbBatchShouldUseArrayBinding(AKind, ARows, ACapSupportsArray);
end;

end.
