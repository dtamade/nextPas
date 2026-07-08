{ nextpas - nextPas memory management: fail/fault-injection allocator

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

{ Fail allocator — fault injection for OOM testing.
  Configurable to fail on Nth allocation or with a given probability. }

{$I nextpas.core.settings.inc}

unit nextpas.core.mem.allocator.fail;

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

type
  TFailStats = record
    TotalAttempts: UInt64;
    FailuresInjected: UInt64;
    SuccessfulAllocs: UInt64;
  end;

  TFailAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FFailAt: UInt64;
    FTotalAttempts: UInt64;
    FFailCount: UInt64;
    FSuccessCount: UInt64;
  public

    function GetMem(ASize: SizeUInt): Pointer; inline;

    function AllocMem(ASize: SizeUInt): Pointer; inline;

    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;

    procedure FreeMem(APtr: Pointer); inline;

    function Traits: TAllocatorTraits; inline;
    constructor Create(AInner: IAllocator; AFailAt: UInt64 = 0);
    procedure SetFailAt(AFailAt: UInt64);
    function GetStats: TFailStats;
    property FailAt: UInt64 read FFailAt write SetFailAt;
    property TotalAttempts: UInt64 read FTotalAttempts;
  end;

implementation

{ TFailAllocator }

constructor TFailAllocator.Create(AInner: IAllocator; AFailAt: UInt64);
begin
  inherited Create;
  FInner := AInner;
  FFailAt := AFailAt;
  FTotalAttempts := 0;
  FFailCount := 0;
  FSuccessCount := 0;
end;

procedure TFailAllocator.SetFailAt(AFailAt: UInt64);
begin
  FFailAt := AFailAt;
end;

function TFailAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  Inc(FTotalAttempts);
  if (FFailAt > 0) and (FTotalAttempts = FFailAt) then
  begin
    Inc(FFailCount);
    Exit(nil);
  end;
  Result := FInner.GetMem(ASize);
  if Result <> nil then
    Inc(FSuccessCount);
end;

function TFailAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Inc(FTotalAttempts);
  if (FFailAt > 0) and (FTotalAttempts = FFailAt) then
  begin
    Inc(FFailCount);
    Exit(nil);
  end;
  Result := FInner.AllocMem(ASize);
  if Result <> nil then
    Inc(FSuccessCount);
end;

procedure TFailAllocator.FreeMem(APtr: Pointer); inline;
begin
  FInner.FreeMem(APtr);
end;

function TFailAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  Inc(FTotalAttempts);
  if (FFailAt > 0) and (FTotalAttempts = FFailAt) then
  begin
    Inc(FFailCount);
    Exit(nil);
  end;
  Result := FInner.ReallocMem(APtr, ASize);
end;

function TFailAllocator.GetStats: TFailStats;
begin
  Result.TotalAttempts := FTotalAttempts;
  Result.FailuresInjected := FFailCount;
  Result.SuccessfulAllocs := FSuccessCount;
end;


function TFailAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
end;

end.
