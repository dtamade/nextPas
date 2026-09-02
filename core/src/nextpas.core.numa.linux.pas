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
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.files,
  nextpas.core.platform.files.base,
  nextpas.core.text.conv;

var
  GNodeCount: Integer = -1;
  GCpuToNode: array of Integer;

function ReadSmallFile(const APath: AnsiString): AnsiString;
var
  LHandle: TPlatformFileHandle;
  LBuf: array[0..511] of AnsiChar;
  LRead: PtrUInt;
begin
  Result := '';
  if platform_file_open(PAnsiChar(APath), fomReadOnly, fcmOpenExisting, LHandle) <> 0 then
    Exit;
  try
    FillChar(LBuf, SizeOf(LBuf), 0);
    if platform_file_read(LHandle, @LBuf[0], SizeOf(LBuf) - 1, LRead) = 0 then
    begin
      if LRead > 0 then
      begin
        // trim trailing newline
        while (LRead > 0) and (LBuf[LRead - 1] in [#10, #13]) do
          Dec(LRead);
        SetLength(Result, LRead);
        if LRead > 0 then
          Move(LBuf[0], Result[1], LRead);
      end;
    end;
  finally
    platform_file_close(LHandle);
  end;
end;

function CountNodesViaDir: Integer;
var
  LDir: TPlatformDirHandle;
  LEntry: TPlatformDirEntry;
  LName: AnsiString;
  LDummy: Integer;
begin
  Result := 0;
  if platform_dir_open('/sys/devices/system/node', LDir) <> 0 then
    Exit(0);
  try
    while platform_dir_read(LDir, LEntry) = 0 do
    begin
      if LEntry.NameLen < 4 then Continue;
      if (LEntry.Name[0] = 'n') and (LEntry.Name[1] = 'o') and (LEntry.Name[2] = 'd') and (LEntry.Name[3] = 'e') then
      begin
        SetLength(LName, LEntry.NameLen);
        Move(LEntry.Name[0], LName[1], LEntry.NameLen);
        if TryStrToInt(Copy(LName, 5, Length(LName) - 4), LDummy) then
          Inc(Result)
        else
          Inc(Result);
      end;
    end;
  finally
    platform_dir_close(LDir);
  end;
end;

function ParseCpuTopology: Boolean;
var
  LNodeId, LCpuId: Integer;
  LLine: AnsiString;
  LCounted: Integer;
begin
  Result := False;
  GNodeCount := 0;
  LCounted := CountNodesViaDir;
  if LCounted > 0 then
    GNodeCount := LCounted
  else
    GNodeCount := 1;
  if GNodeCount = 0 then
  begin
    GNodeCount := 1;
    Exit;
  end;
  SetLength(GCpuToNode, 256);
  for LCpuId := 0 to High(GCpuToNode) do
    GCpuToNode[LCpuId] := -1;
  for LNodeId := 0 to GNodeCount - 1 do
  begin
    LLine := ReadSmallFile('/sys/devices/system/node/node' + IntToStr(LNodeId) + '/cpulist');
    if LLine = '' then Continue;
    // simplified: single integer, else first number before '-' or ','
    LCpuId := StrToIntDef(Copy(LLine, 1, Pos('-', LLine) - 1), StrToIntDef(LLine, -1));
    if (LCpuId >= 0) and (LCpuId < Length(GCpuToNode)) then
      GCpuToNode[LCpuId] := LNodeId;
  end;
  Result := True;
end;

function TNumaPlatformLinux.NodeCount: Integer; inline;
begin
  if GNodeCount < 0 then
    ParseCpuTopology;
  Result := GNodeCount;
end;

function TNumaPlatformLinux.GetNodeForCpu(ACpuId: Integer): Integer; inline;
begin
  if GNodeCount < 0 then
    ParseCpuTopology;
  if (ACpuId < 0) or (ACpuId > High(GCpuToNode)) then
    Exit(-1);
  Result := GCpuToNode[ACpuId];
end;

function TNumaPlatformLinux.GetCurrentNode: Integer; inline;
begin
  Result := 0;
end;

function TNumaPlatformLinux.AllocOnNode(ASize: PtrUInt; ANode: Integer): Pointer; inline;
begin
  Result := mmap(nil, ASize, PLATFORM_POSIX_PROT_READ or PLATFORM_POSIX_PROT_WRITE,
    PLATFORM_POSIX_MAP_PRIVATE or PLATFORM_POSIX_MAP_ANONYMOUS, -1, 0);
  if PtrUInt(Result) = PLATFORM_POSIX_MAP_FAILED_PTR then
    Result := nil;
end;

procedure TNumaPlatformLinux.FreeOnNode(APtr: Pointer; ASize: PtrUInt; ANode: Integer); inline;
begin
  if APtr <> nil then
    munmap(APtr, ASize);
end;

function TNumaPlatformLinux.GetNodeInfo(ANode: Integer; out AInfo: TNumaNode): Boolean;
var
  LLine: AnsiString;
  LCpuId: Integer;
begin
  Result := False;
  if GNodeCount < 0 then
    ParseCpuTopology;
  if (ANode < 0) or (ANode >= GNodeCount) then
    Exit;
  AInfo.Id := ANode;
  AInfo.CpuCount := 0;
  AInfo.Cpus := nil;
  LLine := ReadSmallFile('/sys/devices/system/node/node' + IntToStr(ANode) + '/cpulist');
  if LLine = '' then Exit;
  LCpuId := StrToIntDef(LLine, -1);
  if LCpuId < 0 then Exit;
  AInfo.CpuCount := 1;
  SetLength(AInfo.Cpus, 1);
  AInfo.Cpus[0] := LCpuId;
  Result := True;
end;

procedure TNumaPlatformLinux.SetThreadAffinity(AThreadId: PtrUInt; ANode: Integer); inline;
begin
  if GNodeCount < 0 then
    ParseCpuTopology;
  if (ANode < 0) or (ANode >= GNodeCount) then
    Exit;
  // no-op: affinity via platform.thread affinity API if needed; keep minimal
end;

end.
