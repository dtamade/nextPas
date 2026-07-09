{ nextpas - nextPas memory management: prefix metadata allocator

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

{ Prefix allocator — stores allocation size before each pointer.
  Enables O(1) size query for any allocated pointer without lookup table. }

{$I nextpas.core.settings.inc}

unit nextpas.core.mem.allocator.prefix;

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

const
  PREFIX_SIZE = SizeOf(SizeUInt);

type
  TPrefixStats = record
    AllocCount: UInt64;
    FreeCount: UInt64;
    ActiveAllocs: UInt64;
    TotalBytes: UInt64;
  end;

  TPrefixAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FAllocCount: UInt64;
    FFreeCount: UInt64;
    FActiveAllocs: UInt64;
    FTotalBytes: UInt64;
  public
    constructor Create(AInner: IAllocator);
    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;
    function GetAllocationSize(APtr: Pointer): SizeUInt;
    function GetStats: TPrefixStats;
    property ActiveAllocs: UInt64 read FActiveAllocs;
    function Traits: TAllocatorTraits; inline;
  end;

implementation

{ TPrefixAllocator }

constructor TPrefixAllocator.Create(AInner: IAllocator);
begin
  inherited Create;
  FInner := AInner;
  FAllocCount := 0;
  FFreeCount := 0;
  FActiveAllocs := 0;
  FTotalBytes := 0;
end;

function TPrefixAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
var
  LPtr: PByte;
begin
  if ASize = 0 then
    Exit(nil);

  LPtr := PByte(FInner.GetMem(PREFIX_SIZE + ASize));
  if LPtr = nil then
    Exit(nil);

  PSizeUInt(LPtr)^ := ASize;
  Inc(FAllocCount);
  Inc(FActiveAllocs);
  Inc(FTotalBytes, ASize);
  Result := Pointer(LPtr + PREFIX_SIZE);
end;

function TPrefixAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

procedure TPrefixAllocator.FreeMem(APtr: Pointer); inline;
var
  LPtr: PByte;
  LSize: SizeUInt;
begin
  if APtr = nil then
    Exit;

  LPtr := PByte(APtr) - PREFIX_SIZE;
  LSize := PSizeUInt(LPtr)^;
  FInner.FreeMem(LPtr);
  Inc(FFreeCount);
  Dec(FActiveAllocs);
  Dec(FTotalBytes, LSize);
end;

function TPrefixAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
var
  LOldSize, LCopySize: SizeUInt;
begin
  if ASize = 0 then
  begin
    FreeMem(APtr);
    Exit(nil);
  end;
  if APtr = nil then
    Exit(GetMem(ASize));

  LOldSize := GetAllocationSize(APtr);
  if ASize <= LOldSize then
    Exit(APtr);

  Result := GetMem(ASize);
  if Result = nil then
    Exit(nil);
  LCopySize := LOldSize;
  Move(APtr^, Result^, LCopySize);
  FreeMem(APtr);
end;

function TPrefixAllocator.GetAllocationSize(APtr: Pointer): SizeUInt;
begin
  if APtr = nil then
    Exit(0);
  Result := PSizeUInt(PByte(APtr) - PREFIX_SIZE)^;
end;

function TPrefixAllocator.GetStats: TPrefixStats;
begin
  Result.AllocCount := FAllocCount;
  Result.FreeCount := FFreeCount;
  Result.ActiveAllocs := FActiveAllocs;
  Result.TotalBytes := FTotalBytes;
end;

function TPrefixAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.SupportsRealloc := True;
end;

end.
