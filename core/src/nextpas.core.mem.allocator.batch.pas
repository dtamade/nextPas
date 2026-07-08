{ nextpas - nextPas memory management: batch allocator

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

{ Batch allocator — allocates multiple blocks of the same size at once.
  Reduces lock overhead and system call count for bulk initialization. }

{$I nextpas.core.settings.inc}

unit nextpas.core.mem.allocator.batch;

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base;

const
  BATCH_MAX_BLOCKS = 64;

type
  TBatchStats = record
    BatchAllocCount: UInt64;
    SingleAllocCount: UInt64;
    BatchFreeCount: UInt64;
    SingleFreeCount: UInt64;
    TotalBlocksAllocated: UInt64;
    TotalBlocksFreed: UInt64;
  end;

  TBatchAllocator = class(TAllocator)
  private
    FInner: IAllocator;
    FBatchAllocCount: UInt64;
    FSingleAllocCount: UInt64;
    FBatchFreeCount: UInt64;
    FSingleFreeCount: UInt64;
    FTotalBlocksAlloc: UInt64;
    FTotalBlocksFree: UInt64;
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    function DoAllocMem(ASize: SizeUInt): Pointer; override;
    function DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(APtr: Pointer); override;
  public
    constructor Create(AInner: IAllocator);
    function BatchAlloc(ASize: SizeUInt; ACount: Integer;
      out ABlocks: array of Pointer): Integer;
    procedure BatchFree(const ABlocks: array of Pointer; ACount: Integer);
    function GetStats: TBatchStats;
  end;

implementation

{ TBatchAllocator }

constructor TBatchAllocator.Create(AInner: IAllocator);
begin
  inherited Create;
  FInner := AInner;
  FBatchAllocCount := 0;
  FSingleAllocCount := 0;
  FBatchFreeCount := 0;
  FSingleFreeCount := 0;
  FTotalBlocksAlloc := 0;
  FTotalBlocksFree := 0;
end;

function TBatchAllocator.DoGetMem(ASize: SizeUInt): Pointer;
begin
  Inc(FSingleAllocCount);
  Inc(FTotalBlocksAlloc);
  Result := FInner.GetMem(ASize);
end;

function TBatchAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Inc(FSingleAllocCount);
  Inc(FTotalBlocksAlloc);
  Result := FInner.AllocMem(ASize);
end;

procedure TBatchAllocator.DoFreeMem(APtr: Pointer);
begin
  Inc(FSingleFreeCount);
  Inc(FTotalBlocksFree);
  FInner.FreeMem(APtr);
end;

function TBatchAllocator.DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  Result := FInner.ReallocMem(APtr, ASize);
end;

function TBatchAllocator.BatchAlloc(ASize: SizeUInt; ACount: Integer;
  out ABlocks: array of Pointer): Integer;
var
  I, LCount: Integer;
begin
  LCount := ACount;
  if LCount > BATCH_MAX_BLOCKS then
    LCount := BATCH_MAX_BLOCKS;
  if LCount > Length(ABlocks) then
    LCount := Length(ABlocks);

  for I := 0 to LCount - 1 do
  begin
    ABlocks[I] := FInner.GetMem(ASize);
    if ABlocks[I] = nil then
    begin
      LCount := I;
      Break;
    end;
  end;

  Inc(FBatchAllocCount);
  Inc(FTotalBlocksAlloc, LCount);
  Result := LCount;
end;

procedure TBatchAllocator.BatchFree(const ABlocks: array of Pointer;
  ACount: Integer);
var
  I, LCount: Integer;
begin
  LCount := ACount;
  if LCount > Length(ABlocks) then
    LCount := Length(ABlocks);

  for I := 0 to LCount - 1 do
  begin
    if ABlocks[I] <> nil then
      FInner.FreeMem(ABlocks[I]);
  end;

  Inc(FBatchFreeCount);
  Inc(FTotalBlocksFree, LCount);
end;

function TBatchAllocator.GetStats: TBatchStats;
begin
  Result.BatchAllocCount := FBatchAllocCount;
  Result.SingleAllocCount := FSingleAllocCount;
  Result.BatchFreeCount := FBatchFreeCount;
  Result.SingleFreeCount := FSingleFreeCount;
  Result.TotalBlocksAllocated := FTotalBlocksAlloc;
  Result.TotalBlocksFreed := FTotalBlocksFree;
end;

end.
