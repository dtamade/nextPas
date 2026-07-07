{
# nextpas.core.mem.registry

## 摘要

Allocator registry — 分配器注册表，按名称查找/切换分配器。

特性:
- 全局单例，线程安全
- 预注册常用分配器（default, guard, stats 等）
- 支持配置驱动的分配器选择
- 名称查找 O(1)（哈希表）

适用场景: 配置驱动的分配器选择、运行时切换分配策略。

Author:    fafafaStudio
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.registry;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.mutex;

type
  {** TAllocatorRegistry
   *
   *  分配器注册表 — 全局单例，按名称查找/切换分配器。
   *
   *  使用模式:
   *    TAllocatorRegistry.Instance.Register('default', DefaultAllocator);
   *    TAllocatorRegistry.Instance.Register('guard', LGuardAlloc);
   *
   *    var LAlloc: IAllocator;
   *    if TAllocatorRegistry.Instance.TryGet('guard', LAlloc) then
   *      LPtr := LAlloc.GetMem(1024);
   *}
  TAllocatorRegistry = class
  private
    FLock: TMemMutex;
    { 哈希表: name → IAllocator }
    FNames: array of string;
    FAllocators: array of IAllocator;
    FMask: SizeUInt;
    FCount: SizeUInt;
    procedure Grow;
    function FindIndex(const AName: string): SizeUInt;
    class var FInstance: TAllocatorRegistry;
  public
    constructor Create;
    destructor Destroy; override;

    {** 获取全局单例 }
    class function Instance: TAllocatorRegistry;
    {** 释放全局单例（程序退出时调用） }
    class procedure ReleaseInstance;

    {** 注册分配器 }
    procedure Register(const AName: string; AAllocator: IAllocator);
    {** 获取分配器（不存在则异常） }
    function Get(const AName: string): IAllocator;
    {** 尝试获取分配器（不存在返回 False） }
    function TryGet(const AName: string; out AAllocator: IAllocator): Boolean;
    {** 注销分配器 }
    procedure Unregister(const AName: string);
    {** 是否存在 }
    function Contains(const AName: string): Boolean;
    {** 注册数量 }
    function Count: SizeUInt;
  end;

implementation

uses
  nextpas.core.mem.error;

const
  REGISTRY_MIN_CAP = 16;

{ 简单哈希函数 }
function SimpleHash(const S: string): UInt32;
var
  LI: Integer;
begin
  Result := 2166136261;
  for LI := 1 to Length(S) do
    Result := (Result xor Ord(S[LI])) * 16777619;
end;

{ TAllocatorRegistry }

constructor TAllocatorRegistry.Create;
var
  LI: SizeUInt;
begin
  inherited Create;
  FLock.Init;
  SetLength(FNames, REGISTRY_MIN_CAP);
  SetLength(FAllocators, REGISTRY_MIN_CAP);
  FMask := REGISTRY_MIN_CAP - 1;
  FCount := 0;
  for LI := 0 to FMask do
    FNames[LI] := '';
end;

destructor TAllocatorRegistry.Destroy;
begin
  FLock.Done;
  SetLength(FNames, 0);
  SetLength(FAllocators, 0);
  inherited Destroy;
end;

class function TAllocatorRegistry.Instance: TAllocatorRegistry;
begin
  if FInstance = nil then
    FInstance := TAllocatorRegistry.Create;
  Result := FInstance;
end;

class procedure TAllocatorRegistry.ReleaseInstance;
begin
  if FInstance <> nil then
  begin
    FInstance.Free;
    FInstance := nil;
  end;
end;

function TAllocatorRegistry.FindIndex(const AName: string): SizeUInt;
var
  LHash: UInt32;
  LPos: SizeUInt;
begin
  LHash := SimpleHash(AName);
  LPos := LHash and FMask;
  while True do
  begin
    if FNames[LPos] = '' then
      Exit(LPos); { 空槽位，未找到 }
    if FNames[LPos] = AName then
      Exit(LPos); { 找到 }
    LPos := (LPos + 1) and FMask;
  end;
end;

procedure TAllocatorRegistry.Grow;
var
  LOldNames: array of string;
  LOldAllocs: array of IAllocator;
  LOldCap: SizeUInt;
  LI: SizeUInt;
  LPos: SizeUInt;
begin
  LOldCap := FMask + 1;
  LOldNames := FNames;
  LOldAllocs := FAllocators;

  SetLength(FNames, LOldCap shl 1);
  SetLength(FAllocators, LOldCap shl 1);
  FMask := (LOldCap shl 1) - 1;
  FCount := 0;

  for LI := 0 to FMask do
    FNames[LI] := '';

  for LI := 0 to LOldCap - 1 do
  begin
    if LOldNames[LI] <> '' then
    begin
      LPos := FindIndex(LOldNames[LI]);
      FNames[LPos] := LOldNames[LI];
      FAllocators[LPos] := LOldAllocs[LI];
      Inc(FCount);
    end;
  end;
end;

procedure TAllocatorRegistry.Register(const AName: string; AAllocator: IAllocator);
var
  LPos: SizeUInt;
begin
  if AName = '' then
    raise EAllocError.Create(aeInvalidLayout, 'TAllocatorRegistry.Register: name cannot be empty');
  if AAllocator = nil then
    raise EAllocError.Create(aeInvalidLayout, 'TAllocatorRegistry.Register: allocator cannot be nil');

  FLock.Acquire;
  try
    { 检查是否需要扩容 }
    if (FCount + 1) > ((FMask + 1) shr 1) then
      Grow;
    LPos := FindIndex(AName);
    if FNames[LPos] = '' then
    begin
      { 新注册 }
      FNames[LPos] := AName;
      FAllocators[LPos] := AAllocator;
      Inc(FCount);
    end
    else
    begin
      { 覆盖已有 }
      FAllocators[LPos] := AAllocator;
    end;
  finally
    FLock.Release;
  end;
end;

function TAllocatorRegistry.Get(const AName: string): IAllocator;
begin
  if not TryGet(AName, Result) then
    raise EAllocError.Create(aeInvalidLayout,
      'TAllocatorRegistry.Get: allocator "' + AName + '" not found');
end;

function TAllocatorRegistry.TryGet(const AName: string; out AAllocator: IAllocator): Boolean;
var
  LPos: SizeUInt;
begin
  AAllocator := nil;
  Result := False;
  FLock.Acquire;
  try
    LPos := FindIndex(AName);
    if FNames[LPos] <> '' then
    begin
      AAllocator := FAllocators[LPos];
      Result := True;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TAllocatorRegistry.Unregister(const AName: string);
var
  LPos: SizeUInt;
begin
  FLock.Acquire;
  try
    LPos := FindIndex(AName);
    if FNames[LPos] <> '' then
    begin
      FNames[LPos] := '';
      FAllocators[LPos] := nil;
      if FCount > 0 then
        Dec(FCount);
    end;
  finally
    FLock.Release;
  end;
end;

function TAllocatorRegistry.Contains(const AName: string): Boolean;
var
  LDummy: IAllocator;
begin
  Result := TryGet(AName, LDummy);
end;

function TAllocatorRegistry.Count: SizeUInt;
begin
  FLock.Acquire;
  try
    Result := FCount;
  finally
    FLock.Release;
  end;
end;

end.
