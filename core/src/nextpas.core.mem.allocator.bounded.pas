{ nextpas - nextPas memory management: bounded/memory-limited allocator

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

{ Bounded allocator — limits maximum memory usage. Returns nil when limit exceeded. }

{$I nextpas.core.settings.inc}

unit nextpas.core.mem.allocator.bounded;

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base;

type
  TBoundedStats = record
    AllocCount: UInt64;
    FreeCount: UInt64;
    RejectedCount: UInt64;
    ActiveBytes: UInt64;
    PeakBytes: UInt64;
    LimitBytes: UInt64;
  end;

  TBoundedAllocator = class(TAllocator)
  private
    FInner: IAllocator;
    FLimitBytes: UInt64;
    FActiveBytes: UInt64;
    FPeakBytes: UInt64;
    FAllocCount: UInt64;
    FFreeCount: UInt64;
    FRejectedCount: UInt64;
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    function DoAllocMem(ASize: SizeUInt): Pointer; override;
    function DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(APtr: Pointer); override;
  public
    constructor Create(AInner: IAllocator; ALimitBytes: UInt64);
    procedure SetLimit(ALimitBytes: UInt64);
    function GetStats: TBoundedStats;
    property LimitBytes: UInt64 read FLimitBytes write SetLimit;
    property ActiveBytes: UInt64 read FActiveBytes;
    property PeakBytes: UInt64 read FPeakBytes;
  end;

implementation

const
  HEADER_SIZE = SizeOf(SizeUInt);

{ TBoundedAllocator }

constructor TBoundedAllocator.Create(AInner: IAllocator; ALimitBytes: UInt64);
begin
  inherited Create;
  FInner := AInner;
  FLimitBytes := ALimitBytes;
  FActiveBytes := 0;
  FPeakBytes := 0;
  FAllocCount := 0;
  FFreeCount := 0;
  FRejectedCount := 0;
end;

procedure TBoundedAllocator.SetLimit(ALimitBytes: UInt64);
begin
  FLimitBytes := ALimitBytes;
end;

function TBoundedAllocator.DoGetMem(ASize: SizeUInt): Pointer;
var
  LPtr: PByte;
begin
  if (FLimitBytes > 0) and (FActiveBytes + ASize > FLimitBytes) then
  begin
    Inc(FRejectedCount);
    Exit(nil);
  end;
  LPtr := PByte(FInner.GetMem(HEADER_SIZE + ASize));
  if LPtr = nil then
    Exit(nil);
  PSizeUInt(LPtr)^ := ASize;
  Inc(FActiveBytes, ASize);
  if FActiveBytes > FPeakBytes then
    FPeakBytes := FActiveBytes;
  Inc(FAllocCount);
  Result := Pointer(LPtr + HEADER_SIZE);
end;

function TBoundedAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := DoGetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

procedure TBoundedAllocator.DoFreeMem(APtr: Pointer);
var
  LPtr: PByte;
  LSize: SizeUInt;
begin
  if APtr = nil then
    Exit;
  LPtr := PByte(APtr) - HEADER_SIZE;
  LSize := PSizeUInt(LPtr)^;
  FInner.FreeMem(LPtr);
  Dec(FActiveBytes, LSize);
  Inc(FFreeCount);
end;

function TBoundedAllocator.DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
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

  LOldPtr := PByte(APtr) - HEADER_SIZE;
  LOldSize := PSizeUInt(LOldPtr)^;
  if ASize <= LOldSize then
    Exit(APtr);

  if (FLimitBytes > 0) and (FActiveBytes - LOldSize + ASize > FLimitBytes) then
  begin
    Inc(FRejectedCount);
    Exit(nil);
  end;

  Result := DoGetMem(ASize);
  if Result = nil then
    Exit(nil);
  LCopySize := LOldSize;
  Move(APtr^, Result^, LCopySize);
  DoFreeMem(APtr);
end;

function TBoundedAllocator.GetStats: TBoundedStats;
begin
  Result.AllocCount := FAllocCount;
  Result.FreeCount := FFreeCount;
  Result.RejectedCount := FRejectedCount;
  Result.ActiveBytes := FActiveBytes;
  Result.PeakBytes := FPeakBytes;
  Result.LimitBytes := FLimitBytes;
end;

end.
