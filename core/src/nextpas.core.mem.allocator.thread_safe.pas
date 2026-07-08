{ nextpas - nextPas memory management: thread-safe wrapper allocator

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

{ Thread-safe wrapper allocator — wraps any allocator with mutex protection. }

{$I nextpas.core.settings.inc}

unit nextpas.core.mem.allocator.thread_safe;

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.mutex;

type
  TThreadSafeAllocator = class(TAllocator)
  private
    FInner: IAllocator;
    FLock: TMemMutex;
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    function DoAllocMem(ASize: SizeUInt): Pointer; override;
    function DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(APtr: Pointer); override;
  public
    constructor Create(AInner: IAllocator);
    destructor Destroy; override;
    function Traits: TAllocatorTraits; override;
  end;

implementation

{ TThreadSafeAllocator }

constructor TThreadSafeAllocator.Create(AInner: IAllocator);
begin
  inherited Create;
  FInner := AInner;
  FLock.Init;
end;

destructor TThreadSafeAllocator.Destroy;
begin
  FLock.Done;
  inherited Destroy;
end;

function TThreadSafeAllocator.Traits: TAllocatorTraits;
begin
  Result := FInner.Traits;
  Result.ThreadSafe := True;
end;

function TThreadSafeAllocator.DoGetMem(ASize: SizeUInt): Pointer;
begin
  FLock.Acquire;
  try
    Result := FInner.GetMem(ASize);
  finally
    FLock.Release;
  end;
end;

function TThreadSafeAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  FLock.Acquire;
  try
    Result := FInner.AllocMem(ASize);
  finally
    FLock.Release;
  end;
end;

function TThreadSafeAllocator.DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  FLock.Acquire;
  try
    Result := FInner.ReallocMem(APtr, ASize);
  finally
    FLock.Release;
  end;
end;

procedure TThreadSafeAllocator.DoFreeMem(APtr: Pointer);
begin
  FLock.Acquire;
  try
    FInner.FreeMem(APtr);
  finally
    FLock.Release;
  end;
end;

end.
