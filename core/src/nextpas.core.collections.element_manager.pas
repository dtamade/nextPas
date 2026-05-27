unit nextpas.core.collections.element_manager;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# nextpas.core.collections.element_manager

## Abstract 摘要

Element manager, an interface for managing the allocation and
release of elements and providing some element operations.
元素管理器, 用于管理元素的分配和释放和提供一些元素操作的接口.

## Declaration 声明

For forwarding or using it for your own project, please retain the copyright notice of this project. Thank you.
转发或者用于自己项目请保留本项目的版权声明,谢谢.

Author:    fafafaStudio
Contact:   dtamade@gmail.com | QQ Group: 685403987 | QQ:179033731
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

{$I nextpas.core.settings.inc}

interface

  uses
    sysutils,
    typinfo,
    nextpas.core.base,
    nextpas.core.math,
    nextpas.core.mem.utils,
    nextpas.core.mem.allocator,
    nextpas.core.collections.element_manager.intf;

  type

  { TElementManager 泛型元素分配器实现 }

  generic TElementManager<T> = class(TInterfacedObject, specialize IElementManager<T>)
  type
    PElement = ^T;
  private
    FAllocator:       IAllocator;
    FElementSize:     SizeUInt;
    FIsManagedType:   Boolean;
    FElementTypeInfo: PTypeInfo;
  private
    procedure CopyElementsUnCheckedInternal(aSrc, aDst: PElement; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
  public
    constructor Create(aAllocator: IAllocator); overload;
    constructor Create; overload;

    function  GeTAllocator: IAllocator; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    function  GetElementSize: SizeUInt; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    function  GetIsManagedType: Boolean; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    function  GetElementTypeInfo: PTypeInfo; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}

    procedure InitializeElements(aPtr: Pointer; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    procedure InitializeElementsUnChecked(aPtr: Pointer; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    procedure FinalizeManagedElements(aPtr: Pointer; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    procedure FinalizeManagedElementsUnChecked(aPtr: Pointer; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}

    function  AllocElements(aElementCount: SizeUInt): PElement; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    function  AllocElement: PElement; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    function  ReallocElements(aDst: Pointer; aElementCount, aNewElementCount: SizeUInt): PElement; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    procedure FreeElements(aDst: Pointer; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    procedure FreeElement(aDst: Pointer); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}

    function  IsOverlap(aSrc, aDst: Pointer; aElementCount: SizeUInt): Boolean; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}

    procedure CopyElements(aSrc, aDst: PElement; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    procedure CopyElementsUnChecked(aSrc, aDst: PElement; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}

    procedure CopyElementsNonOverlap(aSrc, aDst: PElement; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    procedure CopyElementsNonOverlapUnChecked(aSrc, aDst: PElement; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}

    procedure FillElements(aDst: Pointer; aValue: T; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    procedure ZeroElements(aDst: Pointer; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}

    property  ElementSize:     SizeUInt   read GetElementSize;
    property  IsManagedType:   Boolean    read GetIsManagedType;
    property  ElementTypeInfo: PTypeInfo  read GetElementTypeInfo;
    property  Allocator:       IAllocator read GeTAllocator;
  end;


implementation

{ TElementManager }

constructor TElementManager.Create(aAllocator: IAllocator);
begin
  inherited Create;
  FAllocator       := aAllocator;
  FElementSize     := SizeOf(T);
  FIsManagedType   := system.IsManagedType(T);
  FElementTypeInfo := system.TypeInfo(T);
end;

constructor TElementManager.Create;
begin
  Create(nextpas.core.mem.allocator.GetRtlAllocator);
end;

function TElementManager.GeTAllocator: IAllocator;
begin
  Result := FAllocator;
end;

procedure TElementManager.InitializeElements(aPtr: Pointer; aElementCount: SizeUInt);
begin
  if aElementCount = 0 then
    exit;

  if aPtr = nil then
    raise EArgumentNil.Create('TElementManager.InitializeElements: aPtr is nil');

  InitializeElementsUnChecked(aPtr, aElementCount);
end;

procedure TElementManager.InitializeElementsUnChecked(aPtr: Pointer; aElementCount: SizeUInt);
begin
  if aElementCount = 1 then
    Initialize(T(aPtr^))
  else
    InitializeArray(aPtr,FElementTypeInfo,aElementCount); // FillChar(aPtr^, aElementCount * FElementSize, 0);
end;

procedure TElementManager.FinalizeManagedElements(aPtr: Pointer; aElementCount: SizeUInt);
begin
  if aElementCount = 0 then
    exit;

  if aPtr = nil then
    raise EArgumentNil.Create('TElementManager.FinalizeManagedElements: aPtr is nil');

  FinalizeManagedElementsUnChecked(aPtr, aElementCount);
end;

procedure TElementManager.FinalizeManagedElementsUnChecked(aPtr: Pointer; aElementCount: SizeUInt);
begin
  if aElementCount = 0 then
    exit;

  if aElementCount = 1 then
    Finalize(T(aPtr^))
  else
    FinalizeArray(aPtr, FElementTypeInfo, aElementCount);
end;

procedure TElementManager.CopyElementsNonOverlapUnChecked(aSrc, aDst: PElement; aElementCount: SizeUInt);
begin
  if aElementCount = 0 then
    exit;

  case aElementCount of
    1:aDst[0] := aSrc[0];
    2:begin
      aDst[0] := aSrc[0];
      aDst[1] := aSrc[1];
    end;
    3:begin
      aDst[0] := aSrc[0];
      aDst[1] := aSrc[1];
      aDst[2] := aSrc[2];
    end;
    4:begin
      aDst[0] := aSrc[0];
      aDst[1] := aSrc[1];
      aDst[2] := aSrc[2];
      aDst[3] := aSrc[3];
    end;
    5:begin
      aDst[0] := aSrc[0];
      aDst[1] := aSrc[1];
      aDst[2] := aSrc[2];
      aDst[3] := aSrc[3];
      aDst[4] := aSrc[4];
    end;
    6:begin
      aDst[0] := aSrc[0];
      aDst[1] := aSrc[1];
      aDst[2] := aSrc[2];
      aDst[3] := aSrc[3];
      aDst[4] := aSrc[4];
      aDst[5] := aSrc[5];
    end;
    7:begin
      aDst[0] := aSrc[0];
      aDst[1] := aSrc[1];
      aDst[2] := aSrc[2];
      aDst[3] := aSrc[3];
      aDst[4] := aSrc[4];
      aDst[5] := aSrc[5];
      aDst[6] := aSrc[6];
    end;
    8:begin
      aDst[0] := aSrc[0];
      aDst[1] := aSrc[1];
      aDst[2] := aSrc[2];
      aDst[3] := aSrc[3];
      aDst[4] := aSrc[4];
      aDst[5] := aSrc[5];
      aDst[6] := aSrc[6];
      aDst[7] := aSrc[7];
    end;
  else
    if FIsManagedType then
      CopyArray(aDst, aSrc, FElementTypeInfo, aElementCount)
    else
      nextpas.core.mem.utils.CopyUnChecked(aSrc, aDst, aElementCount * FElementSize);
  end;
end;

procedure TElementManager.CopyElementsUnCheckedInternal(aSrc, aDst: PElement; aElementCount: SizeUInt);
var
  LPSrcTail:        ^T;
  LPDstTail:        ^T;
  LIsReverse:       boolean;
  LOverlapCount:    SizeUInt;
  LNonOverlapCount: SizeUInt;
begin
  { 非托管类型,直接拷贝 }
  if not FIsManagedType then
  begin
    nextpas.core.mem.utils.CopyUnChecked(aSrc, aDst, aElementCount * FElementSize);
    exit;
  end;

  { 托管类型 }
  LPSrcTail  := aSrc + aElementCount;
  LPDstTail  := aDst + aElementCount ;
  LIsReverse := (aSrc > aDst);

  if LIsReverse then
    LOverlapCount := LPDstTail - aSrc
    else
    LOverlapCount := LPSrcTail - aDst;

  LNonOverlapCount := aElementCount - LOverlapCount;

  { 小重叠 直接拷贝两手 }
  if LNonOverlapCount >= LOverlapCount then
  begin
    if LIsReverse then
    begin
      CopyArray(aDst, aSrc, FElementTypeInfo, LOverlapCount);
      CopyArray(aDst + LOverlapCount, aSrc + LOverlapCount, FElementTypeInfo, LNonOverlapCount);
    end
    else
    begin
      CopyArray(LPDstTail - LOverlapCount, LPSrcTail - LOverlapCount, FElementTypeInfo, LOverlapCount);
      CopyArray(aDst, aSrc, FElementTypeInfo, LNonOverlapCount);
    end;
  end
  else
  begin
    { 大重叠 }
    if LIsReverse then
    begin
      FinalizeManagedElementsUnChecked(aDst, LOverlapCount);
      nextpas.core.mem.utils.CopyUnChecked(aSrc, aDst, LOverlapCount * FElementSize);
      nextpas.core.mem.utils.Zero(LPDstTail - LNonOverlapCount, LNonOverlapCount * FElementSize);
      CopyArray(LPDstTail - LNonOverlapCount, LPSrcTail - LNonOverlapCount, FElementTypeInfo, LNonOverlapCount);
    end
    else
    begin
      FinalizeManagedElementsUnChecked(LPDstTail - LNonOverlapCount, LNonOverlapCount);
      nextpas.core.mem.utils.CopyUnChecked(aSrc + LNonOverlapCount, aDst + LNonOverlapCount, LOverlapCount * FElementSize);
      nextpas.core.mem.utils.Zero(aDst, LNonOverlapCount * FElementSize);
      CopyArray(aDst, aSrc, FElementTypeInfo, LNonOverlapCount);
    end;
  end;
end;

function TElementManager.GetElementSize: SizeUInt;
begin
  Result := FElementSize;
end;

function TElementManager.GetIsManagedType: Boolean;
begin
  Result := FIsManagedType;
end;

function TElementManager.GetElementTypeInfo: PTypeInfo;
begin
  Result := FElementTypeInfo;
end;

function TElementManager.AllocElements(aElementCount: SizeUInt): PElement;
begin
  if aElementCount = 0 then
    Exit(nil);

  // size overflow guard: aElementCount * FElementSize
  if (aElementCount > 0) and (aElementCount > High(SizeUInt) div FElementSize) then
    raise EOverflow.Create('TElementManager.AllocElements: size overflow');

  Result := FAllocator.GetMem(aElementCount * FElementSize);

  if (Result <> nil) and FIsManagedType then
    InitializeElementsUnChecked(Result, aElementCount);
end;

function TElementManager.AllocElement: PElement;
begin
  Result := AllocElements(1);
end;

function TElementManager.ReallocElements(aDst: Pointer; aElementCount, aNewElementCount: SizeUInt): PElement;
begin
  { 分配 }
  if aDst = nil then
  begin
    if aNewElementCount > 0 then
      Result := AllocElements(aNewElementCount)
    else
      Exit(nil); // aDst=nil 且新容量=0 => 无操作，返回 nil

    exit;
  end;

  { 释放 }
  if aNewElementCount = 0 then
  begin
    FreeElements(aDst, aElementCount);
    Exit(nil);
  end;

  { 调整 }

  // size overflow guard before any pointer arithmetic or allocation
  if (aNewElementCount > 0) and (aNewElementCount > High(SizeUInt) div FElementSize) then
    raise EOverflow.Create('TElementManager.ReallocElements: size overflow');

  { 托管元素缩小前,反初始化因缩小而放弃的内存 }
  if FIsManagedType and (aNewElementCount < aElementCount) then
    FinalizeManagedElements(Pointer(aDst + (aNewElementCount * FElementSize)), aElementCount - aNewElementCount);

  { 调整内存 }
  Result := FAllocator.ReallocMem(aDst, aNewElementCount * FElementSize);

  { 托管元素扩大时,初始化新扩大的内存 }
  if FIsManagedType and (aNewElementCount > aElementCount) then
    InitializeElements(Pointer(Result + aElementCount), aNewElementCount - aElementCount);
end;

procedure TElementManager.FreeElements(aDst: Pointer; aElementCount: SizeUInt);
begin
  if aElementCount = 0 then
    exit;

  if aDst = nil then
    raise EArgumentNil.Create('TElementManager.FreeElements: aDst is nil');

  if FIsManagedType then
    FinalizeManagedElements(aDst, aElementCount);

  FAllocator.FreeMem(aDst);
end;

procedure TElementManager.FreeElement(aDst: Pointer);
begin
  FreeElements(aDst, 1);
end;

function TElementManager.IsOverlap(aSrc, aDst: Pointer; aElementCount: SizeUInt): Boolean;
var
  LSize: SizeUInt;
begin
  LSize  := aElementCount * FElementSize;
  Result := nextpas.core.mem.utils.IsOverlap(aSrc, LSize, aDst, LSize);
end;

procedure TElementManager.CopyElements(aSrc, aDst: PElement; aElementCount: SizeUInt);
begin
  if aElementCount = 0 then
    exit;

  if aSrc = nil then
    raise EArgumentNil.Create('TElementManager.CopyElements: aSrc is nil');

  if aDst = nil then
    raise EArgumentNil.Create('TElementManager.CopyElements: aDst is nil');

  if aSrc = aDst then
    raise EInvalidArgument.Create('TElementManager.CopyElements: aSrc and aDst are the same');

  CopyElementsUnChecked(aSrc, aDst, aElementCount);
end;

procedure TElementManager.CopyElementsUnChecked(aSrc, aDst: PElement; aElementCount: SizeUInt);
begin
  if aElementCount = 0 then
    exit;

  if IsOverlap(aSrc, aDst, aElementCount) then
    CopyElementsUnCheckedInternal(aSrc, aDst, aElementCount)
  else
    CopyElementsNonOverlapUnChecked(aSrc, aDst, aElementCount); // 不重叠,直接拷贝
end;

procedure TElementManager.CopyElementsNonOverlap(aSrc, aDst: PElement; aElementCount: SizeUInt);
begin
  if aElementCount = 0 then
    exit;

  if aSrc = nil then
    raise EArgumentNil.Create('TElementManager.CopyElementsNonOverlap: aSrc is nil');

  if aDst = nil then
    raise EArgumentNil.Create('TElementManager.CopyElementsNonOverlap: aDst is nil');

  if aSrc = aDst then
    raise EInvalidArgument.Create('TElementManager.CopyElementsNonOverlap: aSrc and aDst are the same');

  CopyElementsNonOverlapUnChecked(aSrc, aDst, aElementCount);
end;

procedure TElementManager.FillElements(aDst: Pointer; aValue: T; aElementCount: SizeUInt);
var
  LPDst:      ^T;
  LBlockSize: SizeUInt;
  LSize:      SizeUInt;
begin
  if aElementCount = 0 then
    exit;

  if aDst = nil then
    raise EArgumentNil.Create('TElementManager.FillElements: aDst is nil');

  if FIsManagedType or (FElementSize > 8) then
  begin
    LPDst  := aDst;
    LPDst^ := aValue;

    if aElementCount > 1 then
    begin
      LBlockSize := 1;

      while LBlockSize < aElementCount do
      begin
        LSize := Min(LBlockSize, aElementCount - LBlockSize);
        CopyElementsNonOverlapUnChecked(LPDst, Pointer(LPDst + LBlockSize), LSize);
        inc(LBlockSize, LSize);
      end;
    end;

  end
  else
  begin
    case FElementSize of
      1: nextpas.core.mem.utils.Fill8(aDst, aElementCount,  PUInt8(@aValue)^);
      2: nextpas.core.mem.utils.Fill16(aDst, aElementCount, PUInt16(@aValue)^);
      4: nextpas.core.mem.utils.Fill32(aDst, aElementCount, PUInt32(@aValue)^);
      8: nextpas.core.mem.utils.Fill64(aDst, aElementCount, PUInt64(@aValue)^);
    end;
  end;
end;

procedure TElementManager.ZeroElements(aDst: Pointer; aElementCount: SizeUInt);
begin
  if aElementCount = 0 then
    exit;

  if aDst = nil then
    raise EArgumentNil.Create('TElementManager.ZeroElements: aDst is nil');

  if FIsManagedType then
    FinalizeManagedElementsUnChecked(aDst, aElementCount)
  else
  begin
    case FElementSize of
      1: nextpas.core.mem.utils.Fill8(aDst,  aElementCount, 0);
      2: nextpas.core.mem.utils.Fill16(aDst, aElementCount, 0);
      4: nextpas.core.mem.utils.Fill32(aDst, aElementCount, 0);
      8: nextpas.core.mem.utils.Fill64(aDst, aElementCount, 0);
    else
      nextpas.core.mem.utils.Zero(aDst, aElementCount * FElementSize);
    end;
  end;
end;


end.
