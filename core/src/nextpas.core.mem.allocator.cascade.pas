{ nextpas - nextPas memory management: cascade/fallback allocator

  Copyright (c) 2026 the nextPas contributors

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:

  1. Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.
  2. Redistributions in binary form must reproduce the above copyright notice,
     this list of conditions and the following disclaimer in the documentation
     and/or other materials provided with the distribution.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
  POSSIBILITY OF SUCH DAMAGE.
}

{ Cascade allocator — tries multiple inner allocators in sequence.
  First successful allocation wins. Header stores which allocator was used. }

{$I nextpas.core.settings.inc}

unit nextpas.core.mem.allocator.cascade;

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

const
  CASCADE_MAX_ALLOCATORS = 8;
  CASCADE_HEADER_SIZE = SizeOf(Integer);

type
  TCascadeStats = record
    AllocAttempts: UInt64;
    AllocatorHits: array[0..CASCADE_MAX_ALLOCATORS-1] of UInt64;
    AllocatorCount: Integer;
  end;

  TCascadeAllocator = class(TInterfacedObject, IAllocator)
  private
    FAllocators: array[0..CASCADE_MAX_ALLOCATORS-1] of IAllocator;
    FAllocatorCount: Integer;
    FAllocAttempts: UInt64;
    FAllocatorHits: array[0..CASCADE_MAX_ALLOCATORS-1] of UInt64;
  public

    function GetMem(ASize: SizeUInt): Pointer; inline;

    function AllocMem(ASize: SizeUInt): Pointer; inline;

    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;

    procedure FreeMem(APtr: Pointer); inline;

    function Traits: TAllocatorTraits; inline;
    constructor Create(const AAllocators: array of IAllocator);
    function GetStats: TCascadeStats;
    property AllocatorCount: Integer read FAllocatorCount;
  end;

implementation

{ TCascadeAllocator }

constructor TCascadeAllocator.Create(const AAllocators: array of IAllocator);
var
  I, LCount: Integer;
begin
  inherited Create;
  LCount := Length(AAllocators);
  if LCount > CASCADE_MAX_ALLOCATORS then
    LCount := CASCADE_MAX_ALLOCATORS;
  FAllocatorCount := LCount;
  for I := 0 to LCount - 1 do
  begin
    FAllocators[I] := AAllocators[I];
    FAllocatorHits[I] := 0;
  end;
  FAllocAttempts := 0;
end;

function TCascadeAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
var
  I: Integer;
  LPtr: PByte;
begin
  Inc(FAllocAttempts);
  for I := 0 to FAllocatorCount - 1 do
  begin
    LPtr := PByte(FAllocators[I].GetMem(CASCADE_HEADER_SIZE + ASize));
    if LPtr <> nil then
    begin
      PInteger(LPtr)^ := I;
      Inc(FAllocatorHits[I]);
      Exit(Pointer(LPtr + CASCADE_HEADER_SIZE));
    end;
  end;
  Result := nil;
end;

function TCascadeAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

procedure TCascadeAllocator.FreeMem(APtr: Pointer); inline;
var
  LPtr: PByte;
  LIdx: Integer;
begin
  if APtr = nil then
    Exit;
  LPtr := PByte(APtr) - CASCADE_HEADER_SIZE;
  LIdx := PInteger(LPtr)^;
  if (LIdx >= 0) and (LIdx < FAllocatorCount) then
    FAllocators[LIdx].FreeMem(LPtr);
end;

function TCascadeAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
var
  LOldPtr: PByte;
  LIdx: Integer;
  LOldSize, LCopySize: SizeUInt;
begin
  if APtr = nil then
    Exit(GetMem(ASize));
  if ASize = 0 then
  begin
    FreeMem(APtr);
    Exit(nil);
  end;

  LOldPtr := PByte(APtr) - CASCADE_HEADER_SIZE;
  LIdx := PInteger(LOldPtr)^;
  if (LIdx < 0) or (LIdx >= FAllocatorCount) then
    Exit(nil);

  { Allocate new block via cascade, copy, free old }
  Result := GetMem(ASize);
  if Result = nil then
    Exit(nil);
  { Copy old data — we don't know exact old size, copy up to new size }
  LCopySize := ASize;
  Move(APtr^, Result^, LCopySize);
  FreeMem(APtr);
end;

function TCascadeAllocator.GetStats: TCascadeStats;
var
  I: Integer;
begin
  Result.AllocAttempts := FAllocAttempts;
  Result.AllocatorCount := FAllocatorCount;
  for I := 0 to FAllocatorCount - 1 do
    Result.AllocatorHits[I] := FAllocatorHits[I];
end;


function TCascadeAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
end;

end.
