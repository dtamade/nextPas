unit nextpas.core.numa;

{$I nextpas.core.settings.inc}

interface

type
  TNumaNode = record
    Id: Integer;
    CpuCount: Integer;
    Cpus: array of Integer;
  end;

  TNumaPlatform = class
  public
    function NodeCount: Integer; virtual; abstract;
    function GetNodeForCpu(ACpuId: Integer): Integer; virtual; abstract;
    function GetCurrentNode: Integer; virtual; abstract;
    function AllocOnNode(ASize: PtrUInt; ANode: Integer): Pointer; virtual; abstract;
    procedure FreeOnNode(APtr: Pointer; ASize: PtrUInt; ANode: Integer); virtual; abstract;
    function GetNodeInfo(ANode: Integer; out AInfo: TNumaNode): Boolean; virtual; abstract;
    procedure SetThreadAffinity(AThreadId: PtrUInt; ANode: Integer); virtual; abstract;
  end;

{** @desc 获取系统 NUMA 节点数
  @return NUMA 节点数，1 表示非 NUMA 系统 }
function NumaNodeCount: Integer;

{** @desc 获取指定 CPU 所在的 NUMA 节点
  @param ACpuId CPU ID (0-based)
  @return NUMA 节点 ID，-1 表示未知 }
function NumaGetNodeForCpu(ACpuId: Integer): Integer;

{** @desc 获取当前线程所在的 NUMA 节点
  @return NUMA 节点 ID }
function NumaGetCurrentNode: Integer;

{** @desc 在指定 NUMA 节点上分配内存
  @param ASize 分配大小
  @param ANode NUMA 节点 ID
  @return 分配的内存指针，失败返回 nil }
function NumaAllocOnNode(ASize: PtrUInt; ANode: Integer): Pointer;

{** @desc 释放 NUMA 节点上分配的内存
  @param APtr 内存指针
  @param ASize 分配大小
  @param ANode NUMA 节点 ID }
procedure NumaFreeOnNode(APtr: Pointer; ASize: PtrUInt; ANode: Integer);

{** @desc 获取指定 NUMA 节点的信息
  @param ANode NUMA 节点 ID
  @param AInfo 返回的节点信息
  @return True 表示成功 }
function NumaGetNodeInfo(ANode: Integer; out AInfo: TNumaNode): Boolean;

{** @desc 获取负载最低的 NUMA 节点
  @return NUMA 节点 ID }
function NumaGetOptimalNode: Integer;

{** @desc 设置线程的 NUMA 亲和性
  @param AThreadId 线程 ID (0 表示当前线程)
  @param ANode NUMA 节点 ID }
procedure NumaSetThreadAffinity(AThreadId: PtrUInt; ANode: Integer);

implementation

uses
  {$IFDEF LINUX}
  nextpas.core.numa.linux,
  {$ENDIF}
  {$IFDEF WINDOWS}
  nextpas.core.numa.windows,
  {$ENDIF}
  nextpas.core.errors,
  nextpas.core.mem;

var
  GPlatform: TNumaPlatform = nil;
  GInitialized: Boolean = False;

procedure InitializePlatform;
begin
  if GInitialized then Exit;
  GInitialized := True;
  {$IFDEF LINUX}
  GPlatform := TNumaPlatformLinux.Create;
  {$ENDIF}
  {$IFDEF WINDOWS}
  GPlatform := TNumaPlatformWindows.Create;
  {$ENDIF}
end;

function NumaNodeCount: Integer;
begin
  InitializePlatform;
  if GPlatform = nil then
    Exit(1);  // 非 NUMA 系统返回 1
  Result := GPlatform.NodeCount;
end;

function NumaGetNodeForCpu(ACpuId: Integer): Integer;
begin
  InitializePlatform;
  if GPlatform = nil then
    Exit(0);  // 非 NUMA 系统返回节点 0
  Result := GPlatform.GetNodeForCpu(ACpuId);
end;

function NumaGetCurrentNode: Integer;
begin
  InitializePlatform;
  if GPlatform = nil then
    Exit(0);
  Result := GPlatform.GetCurrentNode;
end;

function NumaAllocOnNode(ASize: PtrUInt; ANode: Integer): Pointer;
begin
  InitializePlatform;
  if GPlatform = nil then
    Exit(GetMem(ASize));  // 非 NUMA 系统使用普通分配
  Result := GPlatform.AllocOnNode(ASize, ANode);
end;

procedure NumaFreeOnNode(APtr: Pointer; ASize: PtrUInt; ANode: Integer);
begin
  InitializePlatform;
  if GPlatform = nil then
  begin
    FreeMem(APtr, ASize);
    Exit;
  end;
  GPlatform.FreeOnNode(APtr, ASize, ANode);
end;

function NumaGetNodeInfo(ANode: Integer; out AInfo: TNumaNode): Boolean;
begin
  InitializePlatform;
  if GPlatform = nil then
  begin
    AInfo.Id := 0;
    AInfo.CpuCount := 0;
    AInfo.Cpus := nil;
    Result := ANode = 0;
    Exit;
  end;
  Result := GPlatform.GetNodeInfo(ANode, AInfo);
end;

function NumaGetOptimalNode: Integer;
begin
  InitializePlatform;
  if GPlatform = nil then
    Exit(0);
  // 简单实现：返回当前线程所在节点
  // 更复杂的实现可以监控各节点负载
  Result := GPlatform.GetCurrentNode;
end;

procedure NumaSetThreadAffinity(AThreadId: PtrUInt; ANode: Integer);
begin
  InitializePlatform;
  if GPlatform = nil then
    Exit;  // 非 NUMA 系统忽略
  GPlatform.SetThreadAffinity(AThreadId, ANode);
end;

initialization

finalization
  if GPlatform <> nil then
  begin
    GPlatform.Free;
    GPlatform := nil;
  end;

end.
