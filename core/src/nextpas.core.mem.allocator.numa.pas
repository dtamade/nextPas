{
# nextpas.core.mem.allocator.numa

## 摘要

NUMA 感知分配器 — 根据当前 CPU 将分配路由到对应 NUMA 节点。

特性:
- 从 sysfs 读取 NUMA 拓扑（节点数、CPU 到节点映射）
- 每个 NUMA 节点独立的 IAllocator
- 基于当前 CPU 自动路由（getcpu 系统调用）
- 降级策略：非 NUMA 系统使用单一 fallback 分配器

适用场景: 多 NUMA 节点服务器，减少跨节点内存访问。

Author:    fafafaStudio
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.allocator.numa;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base;

const
  {** 最大支持的 NUMA 节点数 }
  MAX_NUMA_NODES = 16;
  {** 最大支持的 CPU 数 }
  MAX_NUMA_CPUS = 256;

type
  {** NUMA 拓扑信息 }
  TNumaTopology = record
    NodeCount: Integer;                              { 节点数 (1 = UMA) }
    CpuToNode: array[0..MAX_NUMA_CPUS - 1] of Int32; { CPU → 节点映射 }
    NodeCpuCount: array[0..MAX_NUMA_NODES - 1] of Int32; { 每节点 CPU 数 }
  end;

  {** TNumaAllocator
   *
   *  NUMA 感知分配器。根据当前 CPU 将分配路由到对应 NUMA 节点的分配器。
   *  非 NUMA 系统自动降级为单一 fallback 分配器。
   *}
  TNumaAllocator = class(TAllocator)
  private
    FTopology: TNumaTopology;
    FNodeAllocators: array[0..MAX_NUMA_NODES - 1] of IAllocator;
    FFallback: IAllocator;
    function GetCurrentNode: Integer;
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    function DoAllocMem(ASize: SizeUInt): Pointer; override;
    function DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(APtr: Pointer); override;
  public
    {** 创建 NUMA 分配器。
     *  ADefault: 默认分配器（用于节点无专属分配器时的 fallback）。
     *  拓扑自动检测。 }
    constructor Create(ADefault: IAllocator);
    destructor Destroy; override;

    {** 为指定 NUMA 节点设置分配器 }
    procedure SetNodeAllocator(ANode: Integer; AAlloc: IAllocator);
    {** 获取指定节点的分配器 }
    function GetNodeAllocator(ANode: Integer): IAllocator;
    {** 检测到的 NUMA 拓扑 }
    property Topology: TNumaTopology read FTopology;
    {** 是否为 NUMA 系统 (NodeCount > 1) }
    function IsNuma: Boolean;

    function Traits: TAllocatorTraits; override;
  end;

{** 读取系统 NUMA 拓扑 (从 sysfs) }
function DetectNumaTopology: TNumaTopology;

implementation

uses
  nextpas.core.mem.error;

{ getcpu 系统调用 — 返回当前 CPU 和 node }
function getcpu(var cpu, node: Cardinal): Int32; cdecl;
  external 'c' name 'getcpu';

{ --- NUMA 拓扑检测 --- }

{ 从 sysfs 读取一个整数文件 }
function ReadSysfsInt(const APath: string; ADefault: Integer): Integer;
var
  F: Text;
  LVal: Integer;
begin
  Result := ADefault;
  Assign(F, APath);
  {$I-}
  Reset(F);
  if IOResult <> 0 then Exit;
  Read(F, LVal);
  if IOResult = 0 then
    Result := LVal;
  Close(F);
  {$I+}
end;

{ 解析 CPU 列表字符串 (如 "0-3,8-11") 填充 CPU 集合 }
procedure ParseCpuList(const AList: string; var ASet: array of Boolean;
  ANode: Integer; var ATopo: TNumaTopology);
var
  LPos, LLen: Integer;
  LStart, LEnd, LCpu: Integer;
begin
  LLen := Length(AList);
  LPos := 1;
  while LPos <= LLen do
  begin
    { Parse start of range }
    LStart := 0;
    while (LPos <= LLen) and (AList[LPos] >= '0') and (AList[LPos] <= '9') do
    begin
      LStart := LStart * 10 + (Ord(AList[LPos]) - Ord('0'));
      Inc(LPos);
    end;
    LEnd := LStart;
    { Check for range separator }
    if (LPos <= LLen) and (AList[LPos] = '-') then
    begin
      Inc(LPos);
      LEnd := 0;
      while (LPos <= LLen) and (AList[LPos] >= '0') and (AList[LPos] <= '9') do
      begin
        LEnd := LEnd * 10 + (Ord(AList[LPos]) - Ord('0'));
        Inc(LPos);
      end;
    end;
    { Fill range }
    for LCpu := LStart to LEnd do
    begin
      if LCpu < MAX_NUMA_CPUS then
      begin
        ASet[LCpu] := True;
        ATopo.CpuToNode[LCpu] := ANode;
      end;
    end;
    { Skip comma }
    if (LPos <= LLen) and (AList[LPos] = ',') then
      Inc(LPos);
  end;
end;

function DetectNumaTopology: TNumaTopology;
var
  LNode, LCpu: Integer;
  LPath: string;
  F: Text;
  LBuf: string;
  LUsed: array[0..MAX_NUMA_CPUS - 1] of Boolean;
begin
  FillChar(Result, SizeOf(Result), 0);
  for LCpu := 0 to MAX_NUMA_CPUS - 1 do
    Result.CpuToNode[LCpu] := 0;
  FillChar(LUsed, SizeOf(LUsed), False);

  { Count nodes by checking /sys/devices/system/node/nodeN/ }
  LNode := 0;
  while LNode < MAX_NUMA_NODES do
  begin
    Str(LNode, LPath);
    LPath := '/sys/devices/system/node/node' + LPath + '/cpulist';
    Assign(F, LPath);
    {$I-}
    Reset(F);
    if IOResult <> 0 then
    begin
      Inc(LNode);
      Continue;
    end;
    ReadLn(F, LBuf);
    Close(F);
    {$I+}
    { Parse cpulist and fill CpuToNode mapping }
    ParseCpuList(LBuf, LUsed, LNode, Result);
    Inc(LNode);
  end;
  Result.NodeCount := LNode;
  if Result.NodeCount < 1 then
    Result.NodeCount := 1;

  { Count CPUs per node }
  for LCpu := 0 to MAX_NUMA_CPUS - 1 do
  begin
    if LUsed[LCpu] then
    begin
      LNode := Result.CpuToNode[LCpu];
      if (LNode >= 0) and (LNode < MAX_NUMA_NODES) then
        Inc(Result.NodeCpuCount[LNode]);
    end;
  end;
end;

{ --- TNumaAllocator --- }

constructor TNumaAllocator.Create(ADefault: IAllocator);
begin
  inherited Create;
  if ADefault = nil then
    raise EArgumentNil.Create('TNumaAllocator.Create: ADefault cannot be nil');
  FFallback := ADefault;
  FTopology := DetectNumaTopology;
  FillChar(FNodeAllocators, SizeOf(FNodeAllocators), 0);
end;

destructor TNumaAllocator.Destroy;
var
  LI: Integer;
begin
  for LI := 0 to MAX_NUMA_NODES - 1 do
    FNodeAllocators[LI] := nil;
  FFallback := nil;
  inherited Destroy;
end;

procedure TNumaAllocator.SetNodeAllocator(ANode: Integer; AAlloc: IAllocator);
begin
  if (ANode < 0) or (ANode >= MAX_NUMA_NODES) then
    raise EAllocError.Create(aeInvalidLayout,
      'TNumaAllocator.SetNodeAllocator: invalid node index');
  FNodeAllocators[ANode] := AAlloc;
end;

function TNumaAllocator.GetNodeAllocator(ANode: Integer): IAllocator;
begin
  if (ANode >= 0) and (ANode < MAX_NUMA_NODES) and
     (FNodeAllocators[ANode] <> nil) then
    Result := FNodeAllocators[ANode]
  else
    Result := FFallback;
end;

function TNumaAllocator.GetCurrentNode: Integer;
var
  LCpu, LNode: Cardinal;
begin
  LCpu := 0;
  LNode := 0;
  if getcpu(LCpu, LNode) = 0 then
    Result := Integer(LNode)
  else
    Result := 0;
end;

function TNumaAllocator.DoGetMem(ASize: SizeUInt): Pointer;
begin
  Result := GetNodeAllocator(GetCurrentNode).GetMem(ASize);
end;

function TNumaAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := GetNodeAllocator(GetCurrentNode).AllocMem(ASize);
end;

function TNumaAllocator.DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  Result := GetNodeAllocator(GetCurrentNode).ReallocMem(APtr, ASize);
end;

procedure TNumaAllocator.DoFreeMem(APtr: Pointer);
begin
  { Free goes through fallback — the memory is still valid regardless of node }
  FFallback.FreeMem(APtr);
end;

function TNumaAllocator.IsNuma: Boolean;
begin
  Result := FTopology.NodeCount > 1;
end;

function TNumaAllocator.Traits: TAllocatorTraits;
begin
  Result := FFallback.Traits;
end;

end.
