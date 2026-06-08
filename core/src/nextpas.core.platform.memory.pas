unit nextpas.core.platform.memory;

{$I nextpas.core.settings.inc}

interface

type
  TPlatformAlignedAllocBackend = (
    paabFallback,
    paabWindowsCRT,
    paabPosix
  );

function platform_aligned_alloc(ASize, AAlignment: SizeUInt): Pointer;
function platform_aligned_realloc(APtr: Pointer; ANewSize, AAlignment: SizeUInt): Pointer;
procedure platform_aligned_free(APtr: Pointer);
function platform_aligned_alloc_backend: TPlatformAlignedAllocBackend;
function platform_aligned_alloc_is_native: Boolean;

implementation

const
  PLATFORM_ALIGNED_ALLOC_MAGIC = UInt32($4E50414D);

type
  PPlatformAlignedAllocHeader = ^TPlatformAlignedAllocHeader;
  TPlatformAlignedAllocHeader = record
    RawPtr: Pointer;
    Size: SizeUInt;
    Alignment: SizeUInt;
    Magic: UInt32;
  end;

function IsPowerOfTwo(AValue: SizeUInt): Boolean; inline;
begin
  Result := (AValue <> 0) and ((AValue and (AValue - 1)) = 0);
end;

function IsValidAlignment(AAlignment: SizeUInt): Boolean; inline;
begin
  Result := (AAlignment >= SizeOf(Pointer)) and IsPowerOfTwo(AAlignment);
end;

function TryAddSizeUInt(ALeft, ARight: SizeUInt; out ASum: SizeUInt): Boolean; inline;
begin
  if ALeft > High(SizeUInt) - ARight then
  begin
    ASum := 0;
    Exit(False);
  end;
  ASum := ALeft + ARight;
  Result := True;
end;

function TryBuildRawSize(ASize, AAlignment: SizeUInt; out ARawSize: SizeUInt): Boolean;
var
  LPadding: SizeUInt;
begin
  LPadding := AAlignment - 1;
  if not TryAddSizeUInt(ASize, LPadding, ARawSize) then
    Exit(False);
  Result := TryAddSizeUInt(ARawSize, SizeOf(TPlatformAlignedAllocHeader), ARawSize);
end;

function AlignPtr(APtr: Pointer; AAlignment: SizeUInt): Pointer; inline;
var
  LAddr: PtrUInt;
begin
  LAddr := PtrUInt(APtr);
  Result := Pointer((LAddr + PtrUInt(AAlignment - 1)) and not PtrUInt(AAlignment - 1));
end;

function HeaderOf(APtr: Pointer): PPlatformAlignedAllocHeader; inline;
begin
  Result := PPlatformAlignedAllocHeader(PtrUInt(APtr) - SizeOf(TPlatformAlignedAllocHeader));
end;

function platform_aligned_alloc(ASize, AAlignment: SizeUInt): Pointer;
var
  LRawSize: SizeUInt;
  LRaw: Pointer;
  LAligned: Pointer;
  LHeader: PPlatformAlignedAllocHeader;
begin
  Result := nil;
  if ASize = 0 then
    Exit;
  if not IsValidAlignment(AAlignment) then
    Exit;
  if not TryBuildRawSize(ASize, AAlignment, LRawSize) then
    Exit;

  LRaw := SysGetMem(LRawSize);
  if LRaw = nil then
    Exit;

  LAligned := AlignPtr(Pointer(PtrUInt(LRaw) + SizeOf(TPlatformAlignedAllocHeader)), AAlignment);
  LHeader := HeaderOf(LAligned);
  LHeader^.RawPtr := LRaw;
  LHeader^.Size := ASize;
  LHeader^.Alignment := AAlignment;
  LHeader^.Magic := PLATFORM_ALIGNED_ALLOC_MAGIC;
  Result := LAligned;
end;

procedure platform_aligned_free(APtr: Pointer);
var
  LHeader: PPlatformAlignedAllocHeader;
begin
  if APtr = nil then
    Exit;

  LHeader := HeaderOf(APtr);
  if LHeader^.Magic <> PLATFORM_ALIGNED_ALLOC_MAGIC then
    Exit;
  SysFreeMem(LHeader^.RawPtr);
end;

function platform_aligned_realloc(APtr: Pointer; ANewSize, AAlignment: SizeUInt): Pointer;
var
  LHeader: PPlatformAlignedAllocHeader;
  LOldSize: SizeUInt;
begin
  if APtr = nil then
    Exit(platform_aligned_alloc(ANewSize, AAlignment));
  if ANewSize = 0 then
  begin
    platform_aligned_free(APtr);
    Exit(nil);
  end;
  if not IsValidAlignment(AAlignment) then
    Exit(nil);

  LHeader := HeaderOf(APtr);
  if LHeader^.Magic <> PLATFORM_ALIGNED_ALLOC_MAGIC then
    Exit(nil);
  LOldSize := LHeader^.Size;

  Result := platform_aligned_alloc(ANewSize, AAlignment);
  if Result = nil then
    Exit;

  if LOldSize < ANewSize then
    Move(APtr^, Result^, LOldSize)
  else
    Move(APtr^, Result^, ANewSize);
  platform_aligned_free(APtr);
end;

function platform_aligned_alloc_backend: TPlatformAlignedAllocBackend;
begin
  Result := paabFallback;
end;

function platform_aligned_alloc_is_native: Boolean;
begin
  Result := platform_aligned_alloc_backend <> paabFallback;
end;

end.
