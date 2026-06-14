unit nextpas.core.mem.memory_map;

{$I nextpas.core.settings.inc}

interface

uses nextpas.core.platform.mmap;

type
  TMemoryMapAccess = (
    mmaRead,
    mmaWrite,
    mmaReadWrite,
    mmaCopyOnWrite
  );

  TMemoryMapFlags = set of (
    mmfShared,
    mmfPrivate,
    mmfAnonymous,
    mmfFixed,
    mmfLocked
  );

  TMemoryMap = class
  private
    FFileName: string;
    FPlatformMap: TPlatformMappedFile;
    FBaseAddress: Pointer;
    FSize: UInt64;
    FAccess: TMemoryMapAccess;
    FFlags: TMemoryMapFlags;
    FIsOpen: Boolean;
    FIsAnonymous: Boolean;

    function PlatformAccess: TPlatformMapAccess;
    function PlatformFlags: TPlatformMapFlags;
    procedure AttachPlatformMap(const AMap: TPlatformMappedFile; const AFileName: string;
      AAccess: TMemoryMapAccess; AFlags: TMemoryMapFlags; AAnonymous: Boolean);
  public
    constructor Create;
    destructor Destroy; override;

    function OpenFile(const aFileName: string; aAccess: TMemoryMapAccess = mmaReadWrite;
      aFlags: TMemoryMapFlags = [mmfShared]; aSize: UInt64 = 0; aOffset: UInt64 = 0): Boolean;
    function CreateAnonymous(aSize: UInt64; aAccess: TMemoryMapAccess = mmaReadWrite;
      aFlags: TMemoryMapFlags = [mmfPrivate]): Boolean;
    procedure Close;

    function Flush(aOffset: UInt64 = 0; aSize: UInt64 = 0): Boolean;
    function FlushRange(aOffset: UInt64; aSize: UInt64): Boolean; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function Resize(aNewSize: UInt64): Boolean;
    function Lock(aOffset: UInt64 = 0; aSize: UInt64 = 0): Boolean;
    function Unlock(aOffset: UInt64 = 0; aSize: UInt64 = 0): Boolean;

    function WriteLPBytes(aOffset: UInt64; const aBuf: RawByteString): Boolean;
    function ReadLPBytes(aOffset: UInt64; out aBuf: RawByteString): Boolean;
    function WriteLPUTF8(aOffset: UInt64; const S: UnicodeString): Boolean;
    function ReadLPUTF8(aOffset: UInt64; out S: UTF8String): Boolean;

    property FileName: string read FFileName;
    property BaseAddress: Pointer read FBaseAddress;
    property Size: UInt64 read FSize;
    property Access: TMemoryMapAccess read FAccess;
    property Flags: TMemoryMapFlags read FFlags;
    property IsOpen: Boolean read FIsOpen;
    property IsAnonymous: Boolean read FIsAnonymous;

    function IsValid: Boolean; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function GetPointer(aOffset: UInt64 = 0): Pointer; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
  end;

  TSharedMemory = class
  private
    FName: string;
    FSize: UInt64;
    FMemoryMap: TMemoryMap;
    FIsCreator: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    function CreateShared(const aName: string; aSize: UInt64;
      aAccess: TMemoryMapAccess = mmaReadWrite): Boolean;
    function OpenShared(const aName: string; aAccess: TMemoryMapAccess = mmaReadWrite): Boolean;
    procedure Close;

    function IsValid: Boolean; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function GetPointer(aOffset: UInt64 = 0): Pointer; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function GetBaseAddress: Pointer; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    function WriteLPBytes(aOffset: UInt64; const aBuf: RawByteString): Boolean; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function ReadLPBytes(aOffset: UInt64; out aBuf: RawByteString): Boolean; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function WriteLPUTF8(aOffset: UInt64; const S: UnicodeString): Boolean;
    function ReadLPUTF8(aOffset: UInt64; out S: UTF8String): Boolean;

    function Flush(aOffset: UInt64 = 0; aSize: UInt64 = 0): Boolean; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function FlushRange(aOffset: UInt64; aSize: UInt64): Boolean; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    property Name: string read FName;
    property Size: UInt64 read FSize;
    property BaseAddress: Pointer read GetBaseAddress;
    property IsCreator: Boolean read FIsCreator;
  end;

implementation


{ TMemoryMap }

constructor TMemoryMap.Create;
begin
  inherited Create;
  FFileName := '';
  FBaseAddress := nil;
  FSize := 0;
  FAccess := mmaReadWrite;
  FFlags := [mmfShared];
  FIsOpen := False;
  FIsAnonymous := False;
end;

destructor TMemoryMap.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TMemoryMap.PlatformAccess: TPlatformMapAccess;
begin
  case FAccess of
    mmaRead: Result := pmaRead;
    mmaWrite: Result := pmaWrite;
    mmaReadWrite: Result := pmaReadWrite;
    mmaCopyOnWrite: Result := pmaCopyOnWrite;
  end;
end;

function TMemoryMap.PlatformFlags: TPlatformMapFlags;
begin
  Result := [];
  if mmfShared in FFlags then
    Include(Result, pmfShared);
  if mmfPrivate in FFlags then
    Include(Result, pmfPrivate);
  if mmfAnonymous in FFlags then
    Include(Result, pmfAnonymous);
  if mmfFixed in FFlags then
    Include(Result, pmfFixed);
  if mmfLocked in FFlags then
    Include(Result, pmfLocked);
end;

procedure TMemoryMap.AttachPlatformMap(const AMap: TPlatformMappedFile;
  const AFileName: string; AAccess: TMemoryMapAccess; AFlags: TMemoryMapFlags;
  AAnonymous: Boolean);
begin
  FPlatformMap := AMap;
  FFileName := AFileName;
  FAccess := AAccess;
  FFlags := AFlags;
  FBaseAddress := AMap.Addr;
  FSize := AMap.Size;
  FIsOpen := AMap.IsOpen;
  FIsAnonymous := AAnonymous;
end;

function TMemoryMap.OpenFile(const aFileName: string; aAccess: TMemoryMapAccess;
  aFlags: TMemoryMapFlags; aSize: UInt64; aOffset: UInt64): Boolean;
var
  LMap: TPlatformMappedFile;
  LFileName: string;
begin
  Result := False;
  Close;

  LFileName := aFileName;
  FAccess := aAccess;
  FFlags := aFlags;
  if platform_mmap_open_file(PAnsiChar(LFileName), PlatformAccess, PlatformFlags,
    aSize, aOffset, LMap) <> 0 then Exit;

  AttachPlatformMap(LMap, aFileName, aAccess, aFlags, False);
  Result := True;
end;

function TMemoryMap.CreateAnonymous(aSize: UInt64; aAccess: TMemoryMapAccess;
  aFlags: TMemoryMapFlags): Boolean;
var
  LMap: TPlatformMappedFile;
begin
  Result := False;
  Close;

  FAccess := aAccess;
  FFlags := aFlags + [mmfAnonymous];
  if platform_mmap_create_anonymous(aSize, PlatformAccess, PlatformFlags, LMap) <> 0 then
    Exit;

  AttachPlatformMap(LMap, '', aAccess, aFlags + [mmfAnonymous], True);
  Result := True;
end;

procedure TMemoryMap.Close;
begin
  if FIsOpen then
    platform_mmap_close(FPlatformMap);

  FFileName := '';
  FBaseAddress := nil;
  FSize := 0;
  FIsOpen := False;
  FIsAnonymous := False;
end;

function TMemoryMap.Flush(aOffset: UInt64; aSize: UInt64): Boolean;
var
  LFlushSize: UInt64;
begin
  Result := False;
  if not IsValid then Exit;
  if aOffset > FSize then Exit;

  if aSize = 0 then
    LFlushSize := FSize - aOffset
  else
    LFlushSize := aSize;
  if LFlushSize > FSize - aOffset then Exit;

  Result := platform_mmap_flush(FPlatformMap, aOffset, LFlushSize) = 0;
end;

function TMemoryMap.FlushRange(aOffset: UInt64; aSize: UInt64): Boolean;
var
  LPageSize: UInt64;
  LAlignedOffset: UInt64;
  LAlignedSize: UInt64;
  LDelta: UInt64;
begin
  Result := False;
  if aSize = 0 then Exit;
  if not IsValid then Exit;
  if aOffset >= FSize then Exit;

  LPageSize := platform_mmap_page_size;
  if (LPageSize <> 0) and ((LPageSize and (LPageSize - 1)) = 0) then
  begin
    LAlignedOffset := aOffset and not (LPageSize - 1);
    LDelta := aOffset - LAlignedOffset;
    LAlignedSize := aSize + LDelta;
    LAlignedSize := (LAlignedSize + LPageSize - 1) and not (LPageSize - 1);
  end
  else
  begin
    LAlignedOffset := aOffset;
    LAlignedSize := aSize;
  end;

  if LAlignedOffset + LAlignedSize > FSize then
    LAlignedSize := FSize - LAlignedOffset;

  Result := Flush(LAlignedOffset, LAlignedSize);
end;

function TMemoryMap.Resize(aNewSize: UInt64): Boolean;
var
  LOldFileName: string;
  LOldAccess: TMemoryMapAccess;
  LOldFlags: TMemoryMapFlags;
begin
  Result := False;
  if (not FIsOpen) or FIsAnonymous then Exit;

  if aNewSize = FSize then
    Exit(True);

  LOldFileName := FFileName;
  LOldAccess := FAccess;
  LOldFlags := FFlags;

  Close;
  Result := OpenFile(LOldFileName, LOldAccess, LOldFlags, aNewSize, 0);
end;

function TMemoryMap.Lock(aOffset: UInt64; aSize: UInt64): Boolean;
var
  LLockSize: UInt64;
begin
  Result := False;
  if not IsValid then Exit;
  if aOffset > FSize then Exit;

  if aSize = 0 then
    LLockSize := FSize - aOffset
  else
    LLockSize := aSize;
  if LLockSize > FSize - aOffset then Exit;

  Result := platform_mmap_lock(FPlatformMap, aOffset, LLockSize) = 0;
end;

function TMemoryMap.Unlock(aOffset: UInt64; aSize: UInt64): Boolean;
var
  LUnlockSize: UInt64;
begin
  Result := False;
  if not IsValid then Exit;
  if aOffset > FSize then Exit;

  if aSize = 0 then
    LUnlockSize := FSize - aOffset
  else
    LUnlockSize := aSize;
  if LUnlockSize > FSize - aOffset then Exit;

  Result := platform_mmap_unlock(FPlatformMap, aOffset, LUnlockSize) = 0;
end;

function TMemoryMap.IsValid: Boolean;
begin
  Result := FIsOpen and (FBaseAddress <> nil) and (FSize > 0);
end;

function TMemoryMap.GetPointer(aOffset: UInt64): Pointer;
begin
  if IsValid and (aOffset < FSize) then
    Result := Pointer(PByte(FBaseAddress) + aOffset)
  else
    Result := nil;
end;

function TMemoryMap.WriteLPBytes(aOffset: UInt64; const aBuf: RawByteString): Boolean;
var
  LPtr: PByte;
  LLen: UInt32;
  LNeed: UInt64;
begin
  Result := False;
  if not IsValid then Exit;
  if FAccess = mmaRead then Exit;
  if UInt64(Length(aBuf)) > High(UInt32) then Exit;

  LLen := Length(aBuf);
  LNeed := SizeOf(LLen) + UInt64(LLen);
  if (aOffset > FSize) or (LNeed > FSize - aOffset) then Exit;

  LPtr := PByte(PByte(FBaseAddress) + aOffset);
  Move(LLen, LPtr^, SizeOf(LLen));
  Inc(LPtr, SizeOf(LLen));
  if LLen > 0 then
    Move(aBuf[1], LPtr^, LLen);
  Result := True;
end;

function TMemoryMap.ReadLPBytes(aOffset: UInt64; out aBuf: RawByteString): Boolean;
var
  LPtr: PByte;
  LLen: UInt32;
  LNeed: UInt64;
begin
  Result := False;
  aBuf := '';
  if not IsValid then Exit;
  if (aOffset > FSize) or (UInt64(SizeOf(LLen)) > FSize - aOffset) then Exit;

  LPtr := PByte(PByte(FBaseAddress) + aOffset);
  Move(LPtr^, LLen, SizeOf(LLen));
  LNeed := SizeOf(LLen) + UInt64(LLen);
  if LNeed > FSize - aOffset then Exit;

  Inc(LPtr, SizeOf(LLen));
  SetLength(aBuf, LLen);
  if LLen > 0 then
    Move(LPtr^, aBuf[1], LLen);
  Result := True;
end;

function TMemoryMap.WriteLPUTF8(aOffset: UInt64; const S: UnicodeString): Boolean;
var
  LBytes: RawByteString;
begin
  LBytes := UTF8Encode(S);
  Result := WriteLPBytes(aOffset, LBytes);
end;

function TMemoryMap.ReadLPUTF8(aOffset: UInt64; out S: UTF8String): Boolean;
var
  LBytes: RawByteString;
begin
  Result := ReadLPBytes(aOffset, LBytes);
  if Result then
  begin
    SetCodePage(LBytes, CP_UTF8, False);
    S := UTF8String(LBytes);
  end;
end;

{ TSharedMemory }

constructor TSharedMemory.Create;
begin
  inherited Create;
  FName := '';
  FSize := 0;
  FMemoryMap := TMemoryMap.Create;
  FIsCreator := False;
end;

destructor TSharedMemory.Destroy;
begin
  Close;
  FMemoryMap.Free;
  inherited Destroy;
end;

function TSharedMemory.CreateShared(const aName: string; aSize: UInt64;
  aAccess: TMemoryMapAccess): Boolean;
var
  LMap: TPlatformMappedFile;
  LName: string;
begin
  Result := False;
  Close;

  if (aName = '') or (aSize = 0) then Exit;

  LName := aName;
  FMemoryMap.FAccess := aAccess;
  FMemoryMap.FFlags := [mmfShared];
  if platform_shm_create(PAnsiChar(LName), aSize, FMemoryMap.PlatformAccess, LMap) <> 0 then
    Exit;

  FName := aName;
  FSize := LMap.Size;
  FIsCreator := LMap.IsCreator;
  FMemoryMap.AttachPlatformMap(LMap, '', aAccess, [mmfShared], False);
  Result := True;
end;

function TSharedMemory.OpenShared(const aName: string; aAccess: TMemoryMapAccess): Boolean;
var
  LMap: TPlatformMappedFile;
  LName: string;
begin
  Result := False;
  Close;

  if aName = '' then Exit;

  LName := aName;
  FMemoryMap.FAccess := aAccess;
  FMemoryMap.FFlags := [mmfShared];
  if platform_shm_open(PAnsiChar(LName), FMemoryMap.PlatformAccess, LMap) <> 0 then
    Exit;

  FName := aName;
  FSize := LMap.Size;
  FIsCreator := False;
  FMemoryMap.AttachPlatformMap(LMap, '', aAccess, [mmfShared], False);
  Result := True;
end;

procedure TSharedMemory.Close;
begin
  if FMemoryMap.IsOpen then
    FMemoryMap.Close;

  FName := '';
  FSize := 0;
  FIsCreator := False;
end;

function TSharedMemory.IsValid: Boolean;
begin
  Result := FMemoryMap.IsValid;
end;

function TSharedMemory.GetPointer(aOffset: UInt64): Pointer;
begin
  Result := FMemoryMap.GetPointer(aOffset);
end;

function TSharedMemory.GetBaseAddress: Pointer;
begin
  Result := FMemoryMap.BaseAddress;
end;

function TSharedMemory.WriteLPBytes(aOffset: UInt64; const aBuf: RawByteString): Boolean;
begin
  Result := FMemoryMap.WriteLPBytes(aOffset, aBuf);
end;

function TSharedMemory.ReadLPBytes(aOffset: UInt64; out aBuf: RawByteString): Boolean;
begin
  Result := FMemoryMap.ReadLPBytes(aOffset, aBuf);
end;

function TSharedMemory.WriteLPUTF8(aOffset: UInt64; const S: UnicodeString): Boolean;
begin
  Result := FMemoryMap.WriteLPUTF8(aOffset, S);
end;

function TSharedMemory.ReadLPUTF8(aOffset: UInt64; out S: UTF8String): Boolean;
begin
  Result := FMemoryMap.ReadLPUTF8(aOffset, S);
end;

function TSharedMemory.Flush(aOffset: UInt64; aSize: UInt64): Boolean;
begin
  Result := FMemoryMap.Flush(aOffset, aSize);
end;

function TSharedMemory.FlushRange(aOffset: UInt64; aSize: UInt64): Boolean;
begin
  Result := FMemoryMap.FlushRange(aOffset, aSize);
end;

end.
