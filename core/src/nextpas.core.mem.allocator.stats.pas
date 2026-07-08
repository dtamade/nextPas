{ nextpas - nextPas memory management: statistics wrapper allocator

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

{ Stats allocator — wraps any allocator with performance statistics collection. }

{$I nextpas.core.settings.inc}

unit nextpas.core.mem.allocator.stats;

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base;

type
  TAllocatorStats = record
    AllocCount: UInt64;
    FreeCount: UInt64;
    ReallocCount: UInt64;
    TotalBytesAllocated: UInt64;
    TotalBytesFreed: UInt64;
    ActiveBytes: UInt64;
    PeakBytes: UInt64;
    ActiveAllocs: UInt64;
    PeakAllocs: UInt64;
    MinAllocSize: SizeUInt;
    MaxAllocSize: SizeUInt;
  end;

  TStatsAllocator = class(TAllocator)
  private
    FInner: IAllocator;
    FAllocCount: UInt64;
    FFreeCount: UInt64;
    FReallocCount: UInt64;
    FTotalBytesAlloc: UInt64;
    FTotalBytesFree: UInt64;
    FActiveBytes: UInt64;
    FPeakBytes: UInt64;
    FActiveAllocs: UInt64;
    FPeakAllocs: UInt64;
    FMinAllocSize: SizeUInt;
    FMaxAllocSize: SizeUInt;
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    function DoAllocMem(ASize: SizeUInt): Pointer; override;
    function DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(APtr: Pointer); override;
  public
    constructor Create(AInner: IAllocator);
    procedure Reset;
    function GetStats: TAllocatorStats;
    property ActiveBytes: UInt64 read FActiveBytes;
    property PeakBytes: UInt64 read FPeakBytes;
  end;

implementation

const
  STATS_HEADER_SIZE = SizeOf(SizeUInt);

{ TStatsAllocator }

constructor TStatsAllocator.Create(AInner: IAllocator);
begin
  inherited Create;
  FInner := AInner;
  Reset;
end;

procedure TStatsAllocator.Reset;
begin
  FAllocCount := 0;
  FFreeCount := 0;
  FReallocCount := 0;
  FTotalBytesAlloc := 0;
  FTotalBytesFree := 0;
  FActiveBytes := 0;
  FPeakBytes := 0;
  FActiveAllocs := 0;
  FPeakAllocs := 0;
  FMinAllocSize := High(SizeUInt);
  FMaxAllocSize := 0;
end;

function TStatsAllocator.DoGetMem(ASize: SizeUInt): Pointer;
var
  LPtr: PByte;
begin
  LPtr := PByte(FInner.GetMem(STATS_HEADER_SIZE + ASize));
  if LPtr = nil then
    Exit(nil);
  PSizeUInt(LPtr)^ := ASize;
  Inc(FAllocCount);
  Inc(FTotalBytesAlloc, ASize);
  Inc(FActiveBytes, ASize);
  Inc(FActiveAllocs);
  if FActiveBytes > FPeakBytes then
    FPeakBytes := FActiveBytes;
  if FActiveAllocs > FPeakAllocs then
    FPeakAllocs := FActiveAllocs;
  if ASize < FMinAllocSize then
    FMinAllocSize := ASize;
  if ASize > FMaxAllocSize then
    FMaxAllocSize := ASize;
  Result := Pointer(LPtr + STATS_HEADER_SIZE);
end;

function TStatsAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := DoGetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

procedure TStatsAllocator.DoFreeMem(APtr: Pointer);
var
  LPtr: PByte;
  LSize: SizeUInt;
begin
  if APtr = nil then
    Exit;
  LPtr := PByte(APtr) - STATS_HEADER_SIZE;
  LSize := PSizeUInt(LPtr)^;
  FInner.FreeMem(LPtr);
  Inc(FFreeCount);
  Inc(FTotalBytesFree, LSize);
  Dec(FActiveBytes, LSize);
  Dec(FActiveAllocs);
end;

function TStatsAllocator.DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
var
  LOldSize, LCopySize: SizeUInt;
  LOldPtr: PByte;
begin
  if APtr = nil then
    Exit(DoGetMem(ASize));
  if ASize = 0 then
  begin
    DoFreeMem(APtr);
    Exit(nil);
  end;

  LOldPtr := PByte(APtr) - STATS_HEADER_SIZE;
  LOldSize := PSizeUInt(LOldPtr)^;
  if ASize <= LOldSize then
    Exit(APtr);

  Result := DoGetMem(ASize);
  if Result = nil then
    Exit(nil);
  LCopySize := LOldSize;
  Move(APtr^, Result^, LCopySize);
  DoFreeMem(APtr);
  Inc(FReallocCount);
end;

function TStatsAllocator.GetStats: TAllocatorStats;
begin
  Result.AllocCount := FAllocCount;
  Result.FreeCount := FFreeCount;
  Result.ReallocCount := FReallocCount;
  Result.TotalBytesAllocated := FTotalBytesAlloc;
  Result.TotalBytesFreed := FTotalBytesFree;
  Result.ActiveBytes := FActiveBytes;
  Result.PeakBytes := FPeakBytes;
  Result.ActiveAllocs := FActiveAllocs;
  Result.PeakAllocs := FPeakAllocs;
  if FAllocCount > 0 then
    Result.MinAllocSize := FMinAllocSize
  else
    Result.MinAllocSize := 0;
  Result.MaxAllocSize := FMaxAllocSize;
end;

end.
