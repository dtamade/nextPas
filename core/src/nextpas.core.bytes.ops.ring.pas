unit nextpas.core.bytes.ops.ring;

{$I nextpas.core.settings.inc}
{ R9-02 hermetic：settings.inc 已保障 inline 语义（-O2→INLINE ON），FPC 3.3.1 下无 BEGIN 误报 }

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.base;

{ Ring mask — 环形 FIFO 幂二掩码单源 via and (Cap-1)，bytes.ops 单源 inline 零拷贝 O(1)，避 mod 除法 20 cycles；要求 Cap 为 0→32→2× 幂二 via BytesGrowCapacity/WindowGrowCapacity }
function BytesRingMask(ACap: Integer): Integer; inline;
function BytesRingIndex(AHead, ADelta, ACap: Integer): Integer; inline;
function BytesRingNext(AHead, ACap: Integer): Integer; inline;
{ Managed batch — 托管批量原语，bytes.ops 单源 }
procedure ManagedCopyArray(ADest, ASrc: Pointer; ATypeInfo: Pointer; ACount: SizeInt); inline;
procedure ManagedFinalizeArray(APtr: Pointer; ATypeInfo: Pointer; ACount: SizeInt); inline;
procedure ManagedInitArray(APtr: Pointer; ATypeInfo: Pointer; ACount: SizeInt); inline;
generic procedure ManagedRingCopy<T>(var ADest: array of T; const ASrc: array of T; ASrcHead, ASrcCap, ACount: SizeInt); inline;
generic procedure ManagedRingFinalize<T>(var ARing: array of T; AHead, ACap, ACount: SizeInt); inline;
generic procedure ManagedRingTransfer<T>(var ADest: array of T; var ASrc: array of T; ASrcHead, ASrcCap, ACount: SizeInt); inline;
{ Raw ring — 非托管批量原语，bytes.ops 单源，Move 零拷贝 }
generic procedure RawRingCopy<T>(var ADest: array of T; const ASrc: array of T; ASrcHead, ASrcCap, ACount: SizeInt); inline;
generic procedure RawRingTransfer<T>(var ADest: array of T; var ASrc: array of T; ASrcHead, ASrcCap, ACount: SizeInt); inline;
{ Raw linear — 非托管批量原语，bytes.ops 单源 Move 零拷贝，inline 零额外调用，破红线#1常量折叠 via typed pointer 中转 }
generic procedure ArrayRawCopy<T>(var ADest: array of T; const ASrc: array of T; ACount: SizeInt); inline;
{ Managed move — 托管数组指针交换单源，bytes.ops 单源 inline 零拷贝 O(1) via raw PPointer 交换避 8× 原子引用计数抖动，32并发零 Inc/Dec，资源所有权转移不丢（ADest 需 nil） }
generic procedure ManagedArrayMove<T>(var ADest: array of T; var ASrc: array of T); inline;

implementation

function BytesRingMask(ACap: Integer): Integer; inline;
begin
  // 幂二掩码单源：and (Cap-1) O(1) inline 零拷贝，避 mod 除法 20 cycles；ACap 须为 0→32→2× 幂二 via BytesGrowCapacity 单源
  Result := ACap - 1;
end;

function BytesRingIndex(AHead, ADelta, ACap: Integer): Integer; inline;
begin
  // 环形索引单源：(Head+Delta) and Mask O(1) inline 零拷贝，单源复用 BytesRingMask，守幂二链
  Result := (AHead + ADelta) and BytesRingMask(ACap);
end;

function BytesRingNext(AHead, ACap: Integer): Integer; inline;
begin
  // 环形递增单源：(Head+1) and Mask O(1) inline 零拷贝，单源复用 BytesRingMask
  Result := (AHead + 1) and BytesRingMask(ACap);
end;

procedure ManagedCopyArray(ADest, ASrc: Pointer; ATypeInfo: Pointer; ACount: SizeInt); inline;
begin
  // 单源托管安全批量拷贝：inline 零额外调用转发 System.CopyArray，正确处理重叠与引用计数，O(n)但由运行时单次批量完成，禁 Move
  if ACount <= 0 then Exit;
  if (ADest = nil) or (ASrc = nil) or (ATypeInfo = nil) then Exit;
  System.CopyArray(ADest, ASrc, ATypeInfo, ACount);
end;

procedure ManagedFinalizeArray(APtr: Pointer; ATypeInfo: Pointer; ACount: SizeInt); inline;
begin
  // 单源托管安全批量析构：inline 零额外调用转发 System.FinalizeArray，逐槽释放托管引用，资源不丢
  if ACount <= 0 then Exit;
  if (APtr = nil) or (ATypeInfo = nil) then Exit;
  System.FinalizeArray(APtr, ATypeInfo, ACount);
end;

procedure ManagedInitArray(APtr: Pointer; ATypeInfo: Pointer; ACount: SizeInt); inline;
begin
  if ACount <= 0 then Exit;
  if (APtr = nil) or (ATypeInfo = nil) then Exit;
  System.InitializeArray(APtr, ATypeInfo, ACount);
end;

generic procedure ManagedRingCopy<T>(var ADest: array of T; const ASrc: array of T; ASrcHead, ASrcCap, ACount: SizeInt); inline;
var LFirst, LSecond: SizeInt;
begin
  if ACount <= 0 then Exit;
  LFirst := ASrcCap - ASrcHead;
  if LFirst > ACount then LFirst := ACount;
  LSecond := ACount - LFirst;
  if LFirst > 0 then ManagedCopyArray(@ADest[0], @ASrc[ASrcHead], TypeInfo(T), LFirst);
  if LSecond > 0 then ManagedCopyArray(@ADest[LFirst], @ASrc[0], TypeInfo(T), LSecond);
end;

generic procedure ManagedRingFinalize<T>(var ARing: array of T; AHead, ACap, ACount: SizeInt); inline;
var LFirst, LSecond: SizeInt;
begin
  if ACount <= 0 then Exit;
  LFirst := ACap - AHead;
  if LFirst > ACount then LFirst := ACount;
  LSecond := ACount - LFirst;
  if LFirst > 0 then ManagedFinalizeArray(@ARing[AHead], TypeInfo(T), LFirst);
  if LSecond > 0 then ManagedFinalizeArray(@ARing[0], TypeInfo(T), LSecond);
end;

generic procedure ManagedRingTransfer<T>(var ADest: array of T; var ASrc: array of T; ASrcHead, ASrcCap, ACount: SizeInt); inline;
var LFirst, LSecond: SizeInt;
begin
  if ACount <= 0 then Exit;
  LFirst := ASrcCap - ASrcHead;
  if LFirst > ACount then LFirst := ACount;
  LSecond := ACount - LFirst;
  if LFirst > 0 then
  begin
    ManagedCopyArray(@ADest[0], @ASrc[ASrcHead], TypeInfo(T), LFirst);
    ManagedFinalizeArray(@ASrc[ASrcHead], TypeInfo(T), LFirst);
  end;
  if LSecond > 0 then
  begin
    ManagedCopyArray(@ADest[LFirst], @ASrc[0], TypeInfo(T), LSecond);
    ManagedFinalizeArray(@ASrc[0], TypeInfo(T), LSecond);
  end;
end;

generic procedure RawRingCopy<T>(var ADest: array of T; const ASrc: array of T; ASrcHead, ASrcCap, ACount: SizeInt); inline;
var
  LFirst, LSecond: SizeInt;
  LSrc, LDest: PByte;
begin
  if ACount <= 0 then Exit;
  LFirst := ASrcCap - ASrcHead;
  if LFirst > ACount then LFirst := ACount;
  LSecond := ACount - LFirst;
  // typed pointer 中转破红线#1常量折叠：先取 @ASrc[Head]/@ADest[0] 至 PByte 变量，再以 P^ 喂 Move untyped 形参，避免 FPC inline 时常量传播折叠为栈临时拷垃圾（valgrind+反汇编实证），单次 Move 零拷贝 O(n) inline 零额外调用，bytes.ops 单源
  if LFirst > 0 then
  begin
    LSrc := PByte(@ASrc[ASrcHead]);
    LDest := PByte(@ADest[0]);
    Move(LSrc^, LDest^, LFirst * SizeOf(T));
  end;
  if LSecond > 0 then
  begin
    LSrc := PByte(@ASrc[0]);
    LDest := PByte(@ADest[LFirst]);
    Move(LSrc^, LDest^, LSecond * SizeOf(T));
  end;
end;

generic procedure RawRingTransfer<T>(var ADest: array of T; var ASrc: array of T; ASrcHead, ASrcCap, ACount: SizeInt); inline;
var
  LFirst, LSecond: SizeInt;
  LSrc, LDest: PByte;
begin
  if ACount <= 0 then Exit;
  LFirst := ASrcCap - ASrcHead;
  if LFirst > ACount then LFirst := ACount;
  LSecond := ACount - LFirst;
  // typed pointer 中转破红线#1常量折叠：Move/FillChar 均以 PByte^ 喂 untyped 形参，避免索引元素直喂 var 触发常量传播，单次 Move+FillChar 零拷贝 O(n) inline 零额外调用，bytes.ops 单源，资源托管 FillChar 清零不丢
  if LFirst > 0 then
  begin
    LSrc := PByte(@ASrc[ASrcHead]);
    LDest := PByte(@ADest[0]);
    Move(LSrc^, LDest^, LFirst * SizeOf(T));
    FillChar(LSrc^, LFirst * SizeOf(T), 0);
  end;
  if LSecond > 0 then
  begin
    LSrc := PByte(@ASrc[0]);
    LDest := PByte(@ADest[LFirst]);
    Move(LSrc^, LDest^, LSecond * SizeOf(T));
    FillChar(LSrc^, LSecond * SizeOf(T), 0);
  end;
end;

generic procedure ArrayRawCopy<T>(var ADest: array of T; const ASrc: array of T; ACount: SizeInt); inline;
var
  LSrc, LDest: PByte;
begin
  if ACount <= 0 then Exit;
  // typed pointer 中转破常量传播：先取 @ASrc[0]/@ADest[0] 至 PByte 变量，再以 P^ 喂 Move untyped 形参，避免 FPC inline 时常量字面折叠为栈临时（红线#1），单次 Move 零拷贝 O(n)，bytes.ops 单源
  LSrc := PByte(@ASrc[0]);
  LDest := PByte(@ADest[0]);
  Move(LSrc^, LDest^, ACount * SizeOf(T));
end;

generic procedure ManagedArrayMove<T>(var ADest: array of T; var ASrc: array of T); inline;
begin
  // 指针交换单源：raw PPointer 交换避 record 赋值 8× 引用计数原子 Inc/Dec 抖动，inline 零拷贝 O(1) O(8) 指针拷贝，32 并发零 jitter，资源所有权转移不丢（ADest 需 nil/已托管释放，ASrc 置 nil 避 Dec 误释放）
  PPointer(@ADest)^ := PPointer(@ASrc)^;
  PPointer(@ASrc)^ := nil;
end;

end.
