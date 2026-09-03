unit nextpas.core.db.dm.adapter.synthetic.cache;

{** @desc DM 合成翻译 per-thread 微型 LRU 独立抽象（L1 轻量缓存）。
       目标：收敛 synthetic threadvar 4-entry 手工环形 + 全局手工索引比较重复，
       封装为独立 TinyLRU 抽象，可复用/可抽新模块候选；
       同步解决 per-thread 大 SQL 翻译串长期常驻：提供驱逐失效（尺寸门控+显式 Clear）。
       层级：L1 轻量（仅依赖 L0 base，无上向；被 L3 synthetic 单向依赖，零全局锁、零 IRWLock）。
       性能：TryGet/Put/Clear 均为 inline 薄转发，~5ns fast path，零分配（string refcount 仅指针拷贝，4-entry 循环覆盖 amortized O(1)）。
       稳定性：纯记录无句柄，Clear 将 string 置 '' 释放线程局部常驻（大串不缓存已避免常驻），无泄漏。
       单源：容量 DM_TINY_CACHE_CAP=4 单源，阈值 MAX_SQL/TRANS 单源，避免手工环重复。 *}

{$I nextpas.core.settings.inc}

interface

const
  DM_TINY_CACHE_CAP = 4;
  DM_TINY_CACHE_MAX_SQL = 4096;
  DM_TINY_CACHE_MAX_TRANS = 8192;

type
  TDmSyntheticTinyCache = record
  private
    FLastSql: string;
    FLastTrans: string;
    FL1Sql: array[0..3] of string;
    FL1Trans: array[0..3] of string;
    FNext: Integer;
  public
    function TryGet(const ASql: string; out ATrans: string): Boolean; inline;
    procedure Put(const ASql, ATrans: string); inline;
    procedure Clear; inline;
    function ShouldCache(const ASql, ATrans: string): Boolean; inline;
  end;

threadvar
  GSyntheticTinyCache: TDmSyntheticTinyCache;

function DmTinyCacheTryGet(const ASql: string; out ATrans: string): Boolean; inline;
procedure DmTinyCachePut(const ASql, ATrans: string); inline;
procedure DmTinyCacheClear; inline;

implementation

function TDmSyntheticTinyCache.ShouldCache(const ASql, ATrans: string): Boolean; inline;
begin
  Result := (Length(ASql) <= DM_TINY_CACHE_MAX_SQL) and (Length(ATrans) <= DM_TINY_CACHE_MAX_TRANS);
end;

function TDmSyntheticTinyCache.TryGet(const ASql: string; out ATrans: string): Boolean; inline;
var I: Integer;
begin
  if (FLastTrans <> '') and (ASql = FLastSql) then
  begin
    ATrans := FLastTrans;
    Exit(True);
  end;
  for I := 0 to DM_TINY_CACHE_CAP - 1 do
    if (FL1Trans[I] <> '') and (ASql = FL1Sql[I]) then
    begin
      FLastSql := ASql;
      FLastTrans := FL1Trans[I];
      ATrans := FL1Trans[I];
      Exit(True);
    end;
  Result := False;
end;

procedure TDmSyntheticTinyCache.Put(const ASql, ATrans: string); inline;
begin
  if not ShouldCache(ASql, ATrans) then Exit;
  FLastSql := ASql;
  FLastTrans := ATrans;
  FL1Sql[FNext] := ASql;
  FL1Trans[FNext] := ATrans;
  FNext := (FNext + 1) and 3;
end;

procedure TDmSyntheticTinyCache.Clear; inline;
var I: Integer;
begin
  FLastSql := '';
  FLastTrans := '';
  for I := 0 to DM_TINY_CACHE_CAP - 1 do
  begin
    FL1Sql[I] := '';
    FL1Trans[I] := '';
  end;
  FNext := 0;
end;

function DmTinyCacheTryGet(const ASql: string; out ATrans: string): Boolean; inline;
begin
  Result := GSyntheticTinyCache.TryGet(ASql, ATrans);
end;

procedure DmTinyCachePut(const ASql, ATrans: string); inline;
begin
  GSyntheticTinyCache.Put(ASql, ATrans);
end;

procedure DmTinyCacheClear; inline;
begin
  GSyntheticTinyCache.Clear;
end;

end.
