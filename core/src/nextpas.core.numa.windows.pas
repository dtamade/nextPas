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
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;

var
  GNodeCount: Integer = -1;
  GCpuToNode: array of Integer;
  GNodeMasks: array of UInt64;

procedure ParseNumaTopology;
var
  LHighestNode: DWORD;
  LNode: DWORD;
  LCpu: Byte;
  LMask: UInt64;
  I: Integer;
  LNodeByte: Byte;
begin
  GNodeCount := 0;
  if not GetNumaHighestNodeNumber(LHighestNode) then
  begin
    GNodeCount := 1;
    Exit;
  end;
  GNodeCount := Integer(LHighestNode) + 1;
  SetLength(GCpuToNode, 256);
  for I := 0 to High(GCpuToNode) do
    GCpuToNode[I] := -1;
  SetLength(GNodeMasks, GNodeCount);
  for I := 0 to GNodeCount - 1 do
    GNodeMasks[I] := 0;
  for LCpu := 0 to 255 do
  begin
    if GetNumaProcessorNode(LCpu, LNodeByte) then
    begin
      if LNodeByte < GNodeCount then
      begin
        GCpuToNode[LCpu] := LNodeByte;
        GNodeMasks[LNodeByte] := GNodeMasks[LNodeByte] or (UInt64(1) shl LCpu);
      end;
    end;
  end;
  for LNode := 0 to DWORD(GNodeCount - 1) do
  begin
    if GetNumaNodeProcessorMask(LNode, LMask) then
      GNodeMasks[LNode] := LMask;
  end;
end;

function TNumaPlatformWindows.NodeCount: Integer; inline;
begin
  if GNodeCount < 0 then
    ParseNumaTopology;
  Result := GNodeCount;
end;

function TNumaPlatformWindows.GetNodeForCpu(ACpuId: Integer): Integer; inline;
begin
  if GNodeCount < 0 then
    ParseNumaTopology;
  if (ACpuId < 0) or (ACpuId > High(GCpuToNode)) then
    Exit(-1);
  Result := GCpuToNode[ACpuId];
end;

function TNumaPlatformWindows.GetCurrentNode: Integer; inline;
var
  LCpu: DWORD;
  LNode: Byte;
begin
  LCpu := GetCurrentProcessorNumber;
  if GetNumaProcessorNode(Byte(LCpu), LNode) then
    Result := LNode
  else
    Result := 0;
end;

function TNumaPlatformWindows.AllocOnNode(ASize: PtrUInt; ANode: Integer): Pointer; inline;
begin
  Result := VirtualAllocExNuma(
    GetCurrentProcess,
    nil,
    ASize,
    MEM_COMMIT or MEM_RESERVE,
    PAGE_READWRITE,
    DWORD(ANode)
  );
  if Result = nil then
    Result := VirtualAlloc(nil, ASize, MEM_COMMIT or MEM_RESERVE, PAGE_READWRITE);
end;

procedure TNumaPlatformWindows.FreeOnNode(APtr: Pointer; ASize: PtrUInt; ANode: Integer); inline;
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
  if ANode <= High(GNodeMasks) then
  begin
    LMask := GNodeMasks[ANode];
    LCount := 0;
    for I := 0 to 63 do
      if (LMask and (UInt64(1) shl I)) <> 0 then
        Inc(LCount);
    AInfo.CpuCount := LCount;
    SetLength(AInfo.Cpus, LCount);
    LCount := 0;
    for I := 0 to 63 do
      if (LMask and (UInt64(1) shl I)) <> 0 then
      begin
        AInfo.Cpus[LCount] := I;
        Inc(LCount);
      end;
    Result := True;
  end;
end;

procedure TNumaPlatformWindows.SetThreadAffinity(AThreadId: PtrUInt; ANode: Integer); inline;
var
  LMask: UInt64;
begin
  if GNodeCount < 0 then
    ParseNumaTopology;
  if (ANode < 0) or (ANode >= GNodeCount) then
    Exit;
  if ANode <= High(GNodeMasks) then
  begin
    LMask := GNodeMasks[ANode];
    if LMask <> 0 then
    begin
      if AThreadId = 0 then
        SetThreadAffinityMask(GetCurrentThread, LMask)
      else
        SetThreadAffinityMask(HANDLE(AThreadId), LMask);
    end;
  end;
end;

end.
