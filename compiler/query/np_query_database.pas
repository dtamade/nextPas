{**
 * np_query_database.pas
 *
 * 查询系统框架 — 对标 rustc Salsa
 *
 * 核心概念：
 *   - Query Key：查询的输入标识（文件路径、符号名等）
 *   - Query Value：查询的输出（解析结果、类型信息等）
 *   - 缓存：Key → Value 映射，命中直接返回
 *   - 失效传播：输入变化 → 依赖该输入的查询全部失效
 *
 * 使用方式：
 *   Database.Get(Key, @ComputeFunc)
 *   - 缓存命中 → 直接返回
 *   - 缓存未命中 → 调用 ComputeFunc，缓存结果，返回
 *
 * 线程安全：查询数据库本身是单线程的（阶段 2.3 并行编译将使用
 *   每线程独立数据库 + 不可变共享数据）。
 *
 * 对标：Rust Salsa 框架的 jar/database 模式
 *}

unit np_query_database;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  {**
   * TQueryKey — 查询键
   *
   * 用字符串编码查询标识：
   *   'parse:path/to/file.pas'     — 解析结果
   *   'type:MyUnit.TMyType'        — 类型定义
   *   'symbol:MyUnit.MyProc'       — 符号信息
   *   'hir:MyUnit.MyProc'          — HIR 表示
   *}
  TQueryKey = string;

  {**
   * TQueryValue — 查询值（泛型擦除）
   *
   * 实际类型由查询函数管理，数据库只负责缓存生命周期。
   * 使用 TObject 作为基类型，具体查询返回 TObject 子类。
   *}
  TQueryValue = TObject;

  {**
   * TQueryFunc — 查询计算函数签名
   *
   * 接收 Key，返回 Value。由调用方提供具体计算逻辑。
   *}
  TQueryFunc = function(const AKey: TQueryKey): TQueryValue of object;

  {**
   * TQueryEntry — 缓存条目
   *}
  PQueryEntry = ^TQueryEntry;
  TQueryEntry = record
    Key: TQueryKey;
    Value: TQueryValue;
    Dirty: Boolean;
  end;

  {**
   * TQueryDatabase — 查询数据库
   *
   * 简单的 Key→Value 缓存，支持：
   *   - Get：缓存命中/未命中 → 自动计算
   *   - Invalidate：标记指定 Key 为脏
   *   - InvalidatePrefix：标记所有匹配前缀的 Key 为脏
   *   - Clear：清空所有缓存
   *   - Stats：缓存命中率统计
   *}
  TQueryDatabase = class
  private
    FEntries: array of TQueryEntry;
    FHits: LongInt;
    FMisses: LongInt;
    function FindEntry(const AKey: TQueryKey): LongInt;
  public
    constructor Create;
    destructor Destroy; override;

    { 获取查询结果：命中返回缓存，未命中调用 ACompute 计算并缓存 }
    function Get(const AKey: TQueryKey; ACompute: TQueryFunc): TQueryValue;

    { 直接存储值（用于 ACompute=nil 时外部已计算好的结果） }
    procedure Store(const AKey: TQueryKey; AValue: TQueryValue);

    { 使指定 Key 的缓存失效 }
    procedure Invalidate(const AKey: TQueryKey);

    { 使所有匹配前缀的缓存失效（用于文件级失效传播） }
    procedure InvalidatePrefix(const APrefix: string);

    { 清空所有缓存 }
    procedure Clear;

    { 缓存命中率 }
    function HitRate: Double;

    { 统计信息 }
    function EntryCount: LongInt;
    function HitCount: LongInt;
    function MissCount: LongInt;
  end;

implementation

constructor TQueryDatabase.Create;
begin
  inherited Create;
  SetLength(FEntries, 0);
  FHits := 0;
  FMisses := 0;
end;

destructor TQueryDatabase.Destroy;
begin
  { Values are owned by the caller (TCompilationSession), not freed here }
  SetLength(FEntries, 0);
  inherited Destroy;
end;

function TQueryDatabase.FindEntry(const AKey: TQueryKey): LongInt;
var
  I: LongInt;
begin
  for I := 0 to Length(FEntries) - 1 do
    if FEntries[I].Key = AKey then
      Exit(I);
  Result := -1;
end;

function TQueryDatabase.Get(
  const AKey: TQueryKey;
  ACompute: TQueryFunc
): TQueryValue;
var
  Idx: LongInt;
begin
  Idx := FindEntry(AKey);
  if Idx >= 0 then
  begin
    if not FEntries[Idx].Dirty then
    begin
      Inc(FHits);
      Result := FEntries[Idx].Value;
      Exit;
    end;
    { Dirty entry: treat as miss, will recompute below }
  end;

  if not Assigned(ACompute) then
  begin
    Result := nil;
    Exit;
  end;

  Inc(FMisses);
  Result := ACompute(AKey);
  if Result <> nil then
  begin
    Idx := Length(FEntries);
    SetLength(FEntries, Idx + 1);
    FEntries[Idx].Key := AKey;
    FEntries[Idx].Value := Result;
    FEntries[Idx].Dirty := False;
  end;
end;

procedure TQueryDatabase.Store(const AKey: TQueryKey; AValue: TQueryValue);
var
  Idx: LongInt;
begin
  if AValue = nil then
    Exit;
  Idx := FindEntry(AKey);
  if Idx >= 0 then
  begin
    { Update existing entry — caller retains ownership, old value is NOT freed }
    FEntries[Idx].Value := AValue;
    FEntries[Idx].Dirty := False;
    Exit;
  end;
  Idx := Length(FEntries);
  SetLength(FEntries, Idx + 1);
  FEntries[Idx].Key := AKey;
  FEntries[Idx].Value := AValue;
  FEntries[Idx].Dirty := False;
end;

procedure TQueryDatabase.Invalidate(const AKey: TQueryKey);
var
  Idx: LongInt;
begin
  Idx := FindEntry(AKey);
  if Idx >= 0 then
  begin
    { Caller retains ownership — just mark dirty }
    FEntries[Idx].Dirty := True;
  end;
end;

procedure TQueryDatabase.InvalidatePrefix(const APrefix: string);
var
  I: LongInt;
  PrefixLen: SizeInt;
begin
  PrefixLen := Length(APrefix);
  for I := 0 to Length(FEntries) - 1 do
    if (Length(FEntries[I].Key) >= PrefixLen)
      and (Copy(FEntries[I].Key, 1, PrefixLen) = APrefix) then
    begin
      { Caller retains ownership — just mark dirty }
      FEntries[I].Dirty := True;
    end;
end;

procedure TQueryDatabase.Clear;
var
  I: LongInt;
begin
  { Values owned by caller, just clear the array }
  SetLength(FEntries, 0);
  FHits := 0;
  FMisses := 0;
end;

function TQueryDatabase.HitRate: Double;
var
  Total: LongInt;
begin
  Total := FHits + FMisses;
  if Total = 0 then
    Exit(0.0);
  Result := FHits / Total;
end;

function TQueryDatabase.EntryCount: LongInt;
begin
  Result := Length(FEntries);
end;

function TQueryDatabase.HitCount: LongInt;
begin
  Result := FHits;
end;

function TQueryDatabase.MissCount: LongInt;
begin
  Result := FMisses;
end;

end.
