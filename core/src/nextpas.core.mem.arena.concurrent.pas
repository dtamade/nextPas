{
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

# nextpas.core.mem.arena.concurrent - 线程安全 Arena 包装
## Abstract 摘要

Thread-safe wrapper for IArena implementations.
IArena 实现的线程安全包装。

## Design 设计

- mutex-protected delegation to inner IArena
- Forward all IArena methods under lock
- Preserve arena semantics (Alloc/SaveMark/RestoreToMark/Reset/Stats)

## Declaration 声明

Author:    fafafaStudio
Contact:   dtamade@gmail.com | QQ Group: 685403987 | QQ:179033731
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.arena.concurrent;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.intf,
  nextpas.core.mem.arena.local,
  nextpas.core.mem.mutex,
  nextpas.core.mem.error;

type
  {**
   * TArenaConcurrent
   *
   * @desc Thread-safe wrapper for IArena (mutex-protected).
   *       IArena 实现的线程安全包装。
   *}
  TArenaConcurrent = class(TInterfacedObject, IArena)
  private
    {**
     * Lock ordering: TArenaConcurrent uses a single mutex (FLock).
     * No nesting with other locks — safe to call from any context.
     *
     * 锁顺序：单锁（FLock），不与其他锁嵌套，可在任意上下文调用。
     * All IArena methods (Alloc/SaveMark/RestoreToMark/Reset/UsedSize/
     * RemainingSize/Stats) are serialized under FLock.
     *}
    FInner: IArena;
    FLock: TMemMutex;
  public
    constructor Create(aInner: IArena); overload;
    constructor Create(aTotalSize: SizeUInt); overload;
    destructor Destroy; override;

    { IArena }
    function Alloc(aSize: SizeUInt): Pointer;
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    function AllocZeroed(aSize: SizeUInt): Pointer;
    function SaveMark: TArenaMark;
    procedure RestoreToMark(aMark: TArenaMark);
    procedure Reset;
    function UsedSize: SizeUInt;
    function RemainingSize: SizeUInt;
    function Stats: TArenaStats;

    property Inner: IArena read FInner;
  end;

implementation

{ TArenaConcurrent }

constructor TArenaConcurrent.Create(aInner: IArena);
begin
  inherited Create;
  if aInner = nil then
    raise EAllocError.Create(aeInvalidLayout, 'TArenaConcurrent: inner arena cannot be nil');
  FLock.Init;
  FInner := aInner;
end;

constructor TArenaConcurrent.Create(aTotalSize: SizeUInt);
begin
  Create(TLocalArena.Create(aTotalSize));
end;

destructor TArenaConcurrent.Destroy;
begin
  FLock.Acquire;
  try
    FInner := nil;
  finally
    FLock.Release;
  end;
  FLock.Done;
  inherited Destroy;
end;

function TArenaConcurrent.Alloc(aSize: SizeUInt): Pointer;
begin
  FLock.Acquire;
  try
    Result := FInner.Alloc(aSize);
  finally
    FLock.Release;
  end;
end;

function TArenaConcurrent.AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
begin
  FLock.Acquire;
  try
    Result := FInner.AllocAligned(aSize, aAlignment);
  finally
    FLock.Release;
  end;
end;

function TArenaConcurrent.AllocZeroed(aSize: SizeUInt): Pointer;
begin
  FLock.Acquire;
  try
    Result := FInner.AllocZeroed(aSize);
  finally
    FLock.Release;
  end;
end;

function TArenaConcurrent.SaveMark: TArenaMark;
begin
  FLock.Acquire;
  try
    Result := FInner.SaveMark;
  finally
    FLock.Release;
  end;
end;

procedure TArenaConcurrent.RestoreToMark(aMark: TArenaMark);
begin
  FLock.Acquire;
  try
    FInner.RestoreToMark(aMark);
  finally
    FLock.Release;
  end;
end;

procedure TArenaConcurrent.Reset;
begin
  FLock.Acquire;
  try
    FInner.Reset;
  finally
    FLock.Release;
  end;
end;

function TArenaConcurrent.UsedSize: SizeUInt;
begin
  FLock.Acquire;
  try
    Result := FInner.UsedSize;
  finally
    FLock.Release;
  end;
end;

function TArenaConcurrent.RemainingSize: SizeUInt;
begin
  FLock.Acquire;
  try
    Result := FInner.RemainingSize;
  finally
    FLock.Release;
  end;
end;

function TArenaConcurrent.Stats: TArenaStats;
begin
  FLock.Acquire;
  try
    Result := FInner.Stats;
  finally
    FLock.Release;
  end;
end;

end.
