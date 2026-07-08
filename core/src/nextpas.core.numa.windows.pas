unit nextpas.core.numa.windows;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.numa;

type
  TNumaPlatformWindows = class(TNumaPlatform)
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
  Windows, SysUtils;

const
  // Windows NUMA API 常量
  INVALID_NODE_NUMBER = $FFFFFFFF;

// Windows API 声明
function GetNumaHighestNodeNumber(var HighestNodeNumber: LongWord): LongBool; stdcall; external 'kernel32.dll' name 'GetNumaHighestNodeNumber';
function GetNumaProcessorNode(Processor: Byte; var NodeNumber: Byte): LongBool; stdcall; external 'kernel32.dll' name 'GetNumaProcessorNode';
function GetNumaNodeProcessorMask(Node: LongWord; var ProcessorMask: UInt64): LongBool; stdcall; external 'kernel32.dll' name 'GetNumaNodeProcessorMask';
function VirtualAllocExNuma(hProcess: THandle; lpAddress: Pointer; dwSize: PtrUInt; flAllocationType: DWORD; flProtect: DWORD; nndPreferred: LongWord): Pointer; stdcall; external 'kernel32.dll' name 'VirtualAllocExNuma';
function VirtualFreeEx(hProcess: THandle; lpAddress: Pointer; dwSize: PtrUInt; dwFreeType: DWORD): LongBool; stdcall; external 'kernel32.dll' name 'VirtualFreeEx';
function SetThreadAffinityMask(hThread: THandle; dwThreadAffinityMask: UInt64): UInt64; stdcall; external 'kernel32.dll' name 'SetThreadAffinityMask';
function GetCurrentThread: THandle; stdcall; external 'kernel32.dll' name 'GetCurrentThread';
function GetCurrentProcessorNumber: LongWord; stdcall; external 'kernel32.dll' name 'GetCurrentProcessorNumber';

var
  GNodeCount: Integer = -1;
  GCpuToNode: array of Integer;
  GNodeMasks: array of UInt64;

procedure ParseNumaTopology;
var
  LHighestNode: LongWord;
  LNode, LCpu: Byte;
  LMask: UInt64;
  I: Integer;
begin
  GNodeCount := 0;

  // 获取最高节点号
  if not GetNumaHighestNodeNumber(LHighestNode) then
  begin
    // 非 NUMA 系统
    GNodeCount := 1;
    Exit;
  end;

  // 节点数 = 最高节点号 + 1
  GNodeCount := LHighestNode + 1;

  // 初始化 CPU 到节点的映射
  SetLength(GCpuToNode, 256);  // 假设最多 256 个 CPU
  for I := 0 to High(GCpuToNode) do
    GCpuToNode[I] := -1;

  // 初始化节点掩码
  SetLength(GNodeMasks, GNodeCount);
  for I := 0 to GNodeCount - 1 do
    GNodeMasks[I] := 0;

  // 解析每个 CPU 的节点归属
  for LCpu := 0 to 255 do
  begin
    if GetNumaProcessorNode(LCpu, LNode) then
    begin
      if LNode < GNodeCount then
      begin
        GCpuToNode[LCpu] := LNode;
        GNodeMasks[LNode] := GNodeMasks[LNode] or (UInt64(1) shl LCpu);
      end;
    end;
  end;

  // 获取每个节点的处理器掩码
  for LNode := 0 to GNodeCount - 1 do
  begin
    if GetNumaNodeProcessorMask(LNode, LMask) then
      GNodeMasks[LNode] := LMask;
  end;
end;

function TNumaPlatformWindows.NodeCount: Integer;
begin
  if GNodeCount < 0 then
    ParseNumaTopology;
  Result := GNodeCount;
end;

function TNumaPlatformWindows.GetNodeForCpu(ACpuId: Integer): Integer;
begin
  if GNodeCount < 0 then
    ParseNumaTopology;
  if (ACpuId < 0) or (ACpuId > High(GCpuToNode)) then
    Exit(-1);
  Result := GCpuToNode[ACpuId];
end;

function TNumaPlatformWindows.GetCurrentNode: Integer;
var
  LCpu: LongWord;
  LNode: Byte;
begin
  LCpu := GetCurrentProcessorNumber;
  if GetNumaProcessorNode(Byte(LCpu), LNode) then
    Result := LNode
  else
    Result := 0;
end;

function TNumaPlatformWindows.AllocOnNode(ASize: PtrUInt; ANode: Integer): Pointer;
begin
  // 使用 VirtualAllocExNuma 在指定节点分配内存
  Result := VirtualAllocExNuma(
    GetCurrentProcess,
    nil,
    ASize,
    MEM_COMMIT or MEM_RESERVE,
    PAGE_READWRITE,
    ANode
  );

  if Result = nil then
  begin
    // 回退到普通分配
    Result := VirtualAlloc(nil, ASize, MEM_COMMIT or MEM_RESERVE, PAGE_READWRITE);
  end;
end;

procedure TNumaPlatformWindows.FreeOnNode(APtr: Pointer; ASize: PtrUInt; ANode: Integer);
begin
  if APtr <> nil then
    VirtualFreeEx(GetCurrentProcess, APtr, 0, MEM_RELEASE);
end;

function TNumaPlatformWindows.GetNodeInfo(ANode: Integer; out AInfo: TNumaNode): Boolean;
var
  LMask: UInt64;
  I: Integer;
  LCount: Integer;
begin
  Result := False;
  if GNodeCount < 0 then
    ParseNumaTopology;

  if (ANode < 0) or (ANode >= GNodeCount) then
    Exit;

  AInfo.Id := ANode;
  AInfo.CpuCount := 0;
  AInfo.Cpus := nil;

  // 获取节点的处理器掩码
  if ANode <= High(GNodeMasks) then
  begin
    LMask := GNodeMasks[ANode];

    // 计算 CPU 数量
    LCount := 0;
    for I := 0 to 63 do
    begin
      if (LMask and (UInt64(1) shl I)) <> 0 then
        Inc(LCount);
    end;

    AInfo.CpuCount := LCount;
    SetLength(AInfo.Cpus, LCount);

    // 填充 CPU 列表
    LCount := 0;
    for I := 0 to 63 do
    begin
      if (LMask and (UInt64(1) shl I)) <> 0 then
      begin
        AInfo.Cpus[LCount] := I;
        Inc(LCount);
      end;
    end;

    Result := True;
  end;
end;

procedure TNumaPlatformWindows.SetThreadAffinity(AThreadId: PtrUInt; ANode: Integer);
var
  LMask: UInt64;
begin
  if GNodeCount < 0 then
    ParseNumaTopology;

  if (ANode < 0) or (ANode >= GNodeCount) then
    Exit;

  // 获取节点的处理器掩码
  if ANode <= High(GNodeMasks) then
  begin
    LMask := GNodeMasks[ANode];
    if LMask <> 0 then
    begin
      if AThreadId = 0 then
        SetThreadAffinityMask(GetCurrentThread, LMask)
      else
        SetThreadAffinityMask(THandle(AThreadId), LMask);
    end;
  end;
end;

end.
