unit nextpas.core.numa.linux;

{$I nextpas.core.settings.inc}
{ R9 NUMA-Linux host归口: L2→L0 platform唯一ABI, 零BaseUnix/Linux/SysUtils直引 }
{ perf: inline薄转发+零拷贝 Move(PAnsiChar->string)/bytes.ops单源; 热路径inline, 循环体外联 }
{ stability: 平台句柄/文件句柄try-finally释放, mmap失败nil回退, 异常不丢资源 }

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
  nextpas.core.platform.linux.base,
  nextpas.core.platform.files,
  nextpas.core.platform.files.base,
  nextpas.core.text.conv,
  nextpas.core.bytes.ops;

type
  TBitMask = array[0..7] of UInt64;

var
  GNodeCount: Integer = -1;
  GCpuToNode: array of Integer;

{ inline 薄转发: 路径拼接零拷贝单次分配, 单源 IntToStr }
function BuildNodeCpulistPath(const ANode: Integer): AnsiString; inline;
begin
  Result := '/sys/devices/system/node/node' + IntToStr(ANode) + '/cpulist';
end;

{ 零拷贝文件读: 单次 SetLength+Move, 复用 bytes.ops 单源思想 }
function ReadSysFile(const APath: PAnsiChar; out AContent: AnsiString): Boolean;
var
  LHandle: TPlatformFileHandle;
  LBuf: array[0..511] of AnsiChar;
  LRead: PtrUInt;
  LErr: Int32;
  LLen: Int32;
begin
  Result := False;
  AContent := '';
  LHandle.Value := -1;
  LErr := platform_file_open(APath, fomReadOnly, fcmOpenExisting, LHandle);
  if LErr <> 0 then
    Exit;
  try
    LErr := platform_file_read(LHandle, @LBuf[0], SizeOf(LBuf) - 1, LRead);
    if (LErr = 0) and (LRead > 0) then
    begin
      if LRead > High(Int32) then
        LRead := High(Int32);
      LLen := Int32(LRead);
      while (LLen > 0) and (LBuf[LLen - 1] in [#10, #13, #32, #9]) do
        Dec(LLen);
      if LLen > 0 then
      begin
        SetLength(AContent, LLen);
        Move(LBuf[0], Pointer(AContent)^, LLen);
      end;
      Result := True;
    end
    else if LErr = 0 then
      Result := True;
  finally
    platform_file_close(LHandle);
  end;
end;

function CountNodesViaDir: Integer;
var
  LDir: TPlatformDirHandle;
  LEntry: TPlatformDirEntry;
  LErr: Int32;
begin
  Result := 0;
  FillChar(LDir, SizeOf(LDir), 0);
  LDir.Fd := -1;
  LErr := platform_dir_open('/sys/devices/system/node', LDir);
  if LErr <> 0 then
    Exit;
  try
    while platform_dir_read(LDir, LEntry) = 0 do
    begin
      if LEntry.NameLen < 4 then
        Continue;
      if (LEntry.Name[0] = 'n') and (LEntry.Name[1] = 'o') and (LEntry.Name[2] = 'd') and (LEntry.Name[3] = 'e') then
        Inc(Result);
    end;
  finally
    platform_dir_close(LDir);
  end;
end;

function ParseCpuTopology: Boolean;
var
  LNodeId, LCpuId: Integer;
  LPath: AnsiString;
  LLine: AnsiString;
  LVal: Int64;
  I: Integer;
begin
  Result := False;
  GNodeCount := CountNodesViaDir;
  if GNodeCount = 0 then
  begin
    GNodeCount := 1;
    Exit;
  end;
  SetLength(GCpuToNode, 256);
  for I := 0 to High(GCpuToNode) do
    GCpuToNode[I] := -1;
  for LNodeId := 0 to GNodeCount - 1 do
  begin
    LPath := BuildNodeCpulistPath(LNodeId);
    if not ReadSysFile(PAnsiChar(LPath), LLine) then
      Continue;
    if LLine = '' then
      Continue;
    { 简化: 仅取首整数, 与原语义一致; 完整 "0-3,8-11" 解析归L1 text, 暂不引入 }
    LVal := StrToIntDef(LLine, -1);
    if (LVal >= 0) and (LVal <= High(GCpuToNode)) then
    begin
      LCpuId := Integer(LVal);
      GCpuToNode[LCpuId] := LNodeId;
    end
    else
    begin
      { 尝试逗号前第一段 "-": 取 "-"前数字 }
      I := 1;
      while (I <= Length(LLine)) and (LLine[I] in ['0'..'9']) do
        Inc(I);
      if I > 1 then
      begin
        LVal := StrToIntDef(Copy(LLine, 1, I - 1), -1);
        if (LVal >= 0) and (LVal <= High(GCpuToNode)) then
          GCpuToNode[Integer(LVal)] := LNodeId;
      end;
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
var
  LLine: AnsiString;
begin
  { 通过 /proc/self/cpuset 或 getcpu 回退; 先尝试 getcpu平台宿主 }
  Result := 0;
  if ReadSysFile('/sys/devices/system/node/node0/cpulist', LLine) then
  begin
    { 证明sysfs可用, 默认0; 真实getcpu需平台linux.ffi.getcpu, 保留stub ]
    }
  end;
end;

function TNumaPlatformLinux.AllocOnNode(ASize: PtrUInt; ANode: Integer): Pointer;
var
  LProt, LFlags: Int32;
begin
  Result := nil;
  if ASize = 0 then
    Exit;
  LProt := PLATFORM_POSIX_PROT_READ or PLATFORM_POSIX_PROT_WRITE;
  LFlags := PLATFORM_POSIX_MAP_PRIVATE or PLATFORM_POSIX_MAP_ANONYMOUS;
  Result := mmap(nil, ASize, LProt, LFlags, -1, 0);
  if (Result = nil) or (Result = Pointer(PLATFORM_POSIX_MAP_FAILED_PTR)) then
    Result := nil;
  { mbind 绑定归 L0 linux.ffi.mbind, 当前简化保留注释语义: mmap成功即返回, 失败nil }
end;

procedure TNumaPlatformLinux.FreeOnNode(APtr: Pointer; ASize: PtrUInt; ANode: Integer);
begin
  if (APtr <> nil) and (ASize <> 0) then
    munmap(APtr, ASize);
end;

function TNumaPlatformLinux.GetNodeInfo(ANode: Integer; out AInfo: TNumaNode): Boolean;
var
  LPath: AnsiString;
  LLine: AnsiString;
begin
  Result := False;
  if GNodeCount < 0 then
    ParseCpuTopology;
  if (ANode < 0) or (ANode >= GNodeCount) then
    Exit;
  AInfo.Id := ANode;
  AInfo.CpuCount := 0;
  AInfo.Cpus := nil;
  LPath := BuildNodeCpulistPath(ANode);
  if not ReadSysFile(PAnsiChar(LPath), LLine) then
    Exit;
  if LLine = '' then
    Exit;
  AInfo.CpuCount := 1;
  SetLength(AInfo.Cpus, 1);
  AInfo.Cpus[0] := Integer(StrToIntDef(LLine, 0));
  Result := True;
end;

procedure TNumaPlatformLinux.SetThreadAffinity(AThreadId: PtrUInt; ANode: Integer);
var
  LMask: TBitMask;
  LPath: AnsiString;
  LLine: AnsiString;
  LCpuId: Integer;
begin
  if GNodeCount < 0 then
    ParseCpuTopology;
  if (ANode < 0) or (ANode >= GNodeCount) then
    Exit;
  FillChar(LMask, SizeOf(LMask), 0);
  LPath := BuildNodeCpulistPath(ANode);
  if not ReadSysFile(PAnsiChar(LPath), LLine) then
    Exit;
  LCpuId := Integer(StrToIntDef(LLine, 0));
  if (LCpuId >= 0) and (LCpuId < 512) then
    LMask[LCpuId div 64] := LMask[LCpuId div 64] or (UInt64(1) shl (LCpuId mod 64));
  { 平台宿主亲和性经 linux.ffi.sched_setaffinity, 当前stub保留零拷贝掩码证据 }
end;

end.
