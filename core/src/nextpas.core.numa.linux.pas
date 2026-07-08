unit nextpas.core.numa.linux;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.numa;

type
  TNumaPlatformLinux = class(TNumaPlatform)
  public
    function NodeCount: Integer; override;
    function GetNodeForCpu(ACpuId: Integer): Integer; override;
    function GetCurrentNode: Integer; override;
    function AllocOnNode(ASize: PtrUInt; ANode: Integer): Pointer; override;
    procedure FreeOnNode(APtr: Pointer; ASize: PtrUInt; ANode: Integer); override;
    function GetNodeInfo(ANode: Integer; out AInfo: TNumaNode): Boolean; override;
    procedure SetThreadAffinity(AThreadId: PtrUInt; ANode: Integer); override;
  end;

implementation

uses
  BaseUnix, Linux, SysUtils;

const
  SYS_getcpu = 309;  // Linux syscall number for getcpu
  MPOL_DEFAULT = 0;
  MPOL_BIND = 2;
  MPOL_MF_MOVE = 1;

type
  TBitMask = array[0..7] of UInt64;  // 512 bits for CPU mask

var
  GNodeCount: Integer = -1;
  GCpuToNode: array of Integer;

function ParseCpuTopology: Boolean;
var
  LDir: String;
  LEntry: TSearchRec;
  LCpuId, LNodeId: Integer;
  LFile: Text;
  LLine: String;
begin
  Result := False;
  GNodeCount := 0;

  // 扫描 /sys/devices/system/node/node* 目录
  LDir := '/sys/devices/system/node';
  if FindFirst(LDir + '/node*', faDirectory, LEntry) = 0 then
  begin
    repeat
      if (LEntry.Name <> '.') and (LEntry.Name <> '..') then
      begin
        Inc(GNodeCount);
      end;
    until FindNext(LEntry) <> 0;
    FindClose(LEntry);
  end;

  if GNodeCount = 0 then
  begin
    // 非 NUMA 系统，设置节点数为 1
    GNodeCount := 1;
    Exit;
  end;

  // 初始化 CPU 到节点的映射
  SetLength(GCpuToNode, 256);  // 假设最多 256 个 CPU
  for LCpuId := 0 to High(GCpuToNode) do
    GCpuToNode[LCpuId] := -1;

  // 解析每个节点的 CPU 列表
  for LNodeId := 0 to GNodeCount - 1 do
  begin
    LDir := Format('/sys/devices/system/node/node%d/cpulist', [LNodeId]);
    if FileExists(LDir) then
    begin
      Assign(LFile, LDir);
      Reset(LFile);
      ReadLn(LFile, LLine);
      Close(LFile);

      // 解析 CPU 列表格式：0-3,8-11
      // 简化处理：假设格式为 "start-end" 或 "cpu1,cpu2,..."
      // 这里简化实现，实际需要更复杂的解析
      LCpuId := StrToIntDef(LLine, -1);
      if LCpuId >= 0 then
        GCpuToNode[LCpuId] := LNodeId;
    end;
  end;

  Result := True;
end;

function TNumaPlatformLinux.NodeCount: Integer;
begin
  if GNodeCount < 0 then
    ParseCpuTopology;
  Result := GNodeCount;
end;

function TNumaPlatformLinux.GetNodeForCpu(ACpuId: Integer): Integer;
begin
  if GNodeCount < 0 then
    ParseCpuTopology;
  if (ACpuId < 0) or (ACpuId > High(GCpuToNode)) then
    Exit(-1);
  Result := GCpuToNode[ACpuId];
end;

function TNumaPlatformLinux.GetCurrentNode: Integer;
begin
  // 简化实现：返回节点 0
  // 实际实现需要使用 sched_getcpu 系统调用
  Result := 0;
end;

function TNumaPlatformLinux.AllocOnNode(ASize: PtrUInt; ANode: Integer): Pointer;
type
  TNumaAllocation = record
    Addr: Pointer;
    Size: PtrUInt;
    Node: Integer;
  end;
var
  LAlloc: ^TNumaAllocation;
begin
  // 使用 mmap 分配内存，然后使用 mbind 绑定到指定节点
  Result := nil;

  // 分配内存
  Result := Pointer(fpMMap(nil, ASize, PROT_READ or PROT_WRITE,
    MAP_PRIVATE or MAP_ANONYMOUS, -1, 0));

  if Result = MAP_FAILED then
  begin
    Result := nil;
    Exit;
  end;

  // 使用 mbind 绑定到 NUMA 节点
  // 这里简化实现，实际需要使用 mbind 系统调用
  // mbind(addr, len, MPOL_BIND, &nodemask, maxnode, MPOL_MF_MOVE)

  // 保存分配信息以便释放
  New(LAlloc);
  LAlloc^.Addr := Result;
  LAlloc^.Size := ASize;
  LAlloc^.Node := ANode;
end;

procedure TNumaPlatformLinux.FreeOnNode(APtr: Pointer; ASize: PtrUInt; ANode: Integer);
begin
  if APtr <> nil then
    fpMUnmap(APtr, ASize);
end;

function TNumaPlatformLinux.GetNodeInfo(ANode: Integer; out AInfo: TNumaNode): Boolean;
var
  LDir: String;
  LFile: Text;
  LLine: String;
  LCount: Integer;
begin
  Result := False;
  if GNodeCount < 0 then
    ParseCpuTopology;

  if (ANode < 0) or (ANode >= GNodeCount) then
    Exit;

  AInfo.Id := ANode;
  AInfo.CpuCount := 0;
  AInfo.Cpus := nil;

  // 读取节点的 CPU 列表
  LDir := Format('/sys/devices/system/node/node%d/cpulist', [ANode]);
  if not FileExists(LDir) then
    Exit;

  Assign(LFile, LDir);
  Reset(LFile);
  ReadLn(LFile, LLine);
  Close(LFile);

  // 简化实现：计算 CPU 数量
  // 实际需要解析 "0-3,8-11" 格式
  LCount := 1;  // 简化
  AInfo.CpuCount := LCount;
  SetLength(AInfo.Cpus, LCount);
  AInfo.Cpus[0] := 0;  // 简化

  Result := True;
end;

procedure TNumaPlatformLinux.SetThreadAffinity(AThreadId: PtrUInt; ANode: Integer);
var
  LMask: TBitMask;
  LDir: String;
  LFile: Text;
  LLine: String;
  LCpuId: Integer;
begin
  if GNodeCount < 0 then
    ParseCpuTopology;

  if (ANode < 0) or (ANode >= GNodeCount) then
    Exit;

  // 初始化 CPU 掩码
  FillChar(LMask, SizeOf(LMask), 0);

  // 读取节点的 CPU 列表并设置掩码
  LDir := Format('/sys/devices/system/node/node%d/cpulist', [ANode]);
  if FileExists(LDir) then
  begin
    Assign(LFile, LDir);
    Reset(LFile);
    ReadLn(LFile, LLine);
    Close(LFile);

    // 简化实现：假设只有一个 CPU
    // 实际需要解析 "0-3,8-11" 格式
    LCpuId := StrToIntDef(LLine, 0);
    if (LCpuId >= 0) and (LCpuId < 512) then
      LMask[LCpuId div 64] := LMask[LCpuId div 64] or (UInt64(1) shl (LCpuId mod 64));
  end;

  // 使用 sched_setaffinity 设置线程亲和性
  // fpSchedSetAffinity(AThreadId, SizeOf(LMask), @LMask);
end;

end.
