unit nextpas.core.atomic.core;

{$I nextpas.core.settings.inc}
{$MACRO ON}

// Tagged pointer: tag bits (low-bit tagging mode)
{$IFNDEF NEXTPAS_ATOMIC_TAG_BITS_32}
  {$DEFINE NEXTPAS_ATOMIC_TAG_BITS_32 := 2}
{$ENDIF}
{$IFNDEF NEXTPAS_ATOMIC_TAG_BITS_64}
  {$DEFINE NEXTPAS_ATOMIC_TAG_BITS_64 := 3}
{$ENDIF}

// Enable extra runtime checks for tagged pointer packing (debug only)
{$IFDEF DEBUG}
  {$DEFINE NEXTPAS_ATOMIC_TAGGED_PTR_CHECKS}
{$ENDIF}

interface

uses
  nextpas.core.errors;

type
  memory_order_t = (
    mo_relaxed,
    mo_consume,
    mo_acquire,
    mo_release,
    mo_acq_rel,
    mo_seq_cst
  );

procedure cpu_pause;
procedure atomic_seq_cst_fence;
procedure atomic_thread_fence(aOrder: memory_order_t);
procedure atomic_signal_fence(aOrder: memory_order_t);

type
  atomic_tagged_ptr_t = type PtrUInt;

function atomic_tagged_ptr(aPtr: Pointer; aTag: {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF}): atomic_tagged_ptr_t; inline;
function atomic_tagged_ptr_get_ptr(const aTaggedPtr: atomic_tagged_ptr_t): Pointer; inline;
function atomic_tagged_ptr_get_tag(const aTaggedPtr: atomic_tagged_ptr_t): {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF}; inline;
function atomic_tagged_ptr_next(const aTaggedPtr: atomic_tagged_ptr_t): {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF}; inline;

implementation

{$IF DEFINED(CPUX86_64)}
const
  TAG_BITS = 16;
  TAG_SHIFT = (SizeOf(PtrUInt) * 8) - TAG_BITS;
  PTR_MASK: PtrUInt = (PtrUInt(1) shl TAG_SHIFT) - 1;
{$ELSE}
const
  {$IFDEF CPU64}
  TAG_BITS = NEXTPAS_ATOMIC_TAG_BITS_64;
  {$ELSE}
  TAG_BITS = NEXTPAS_ATOMIC_TAG_BITS_32;
  {$ENDIF}
  TAG_MASK: PtrUInt = (PtrUInt(1) shl TAG_BITS) - 1;
  PTR_MASK: PtrUInt = ((not PtrUInt(0)) shr TAG_BITS) shl TAG_BITS;
{$ENDIF}

{$IF DEFINED(CPUX86_64)}
const
  MAX_TAG: UInt16 = $FFFF;
{$ELSEIF DEFINED(CPU64)}
const
  MAX_TAG: UInt16 = UInt16((PtrUInt(1) shl TAG_BITS) - 1);
{$ELSE}
const
  MAX_TAG: UInt32 = UInt32((PtrUInt(1) shl TAG_BITS) - 1);
{$ENDIF}

{$IF DEFINED(CPUX86_64)}
function _x86_64_pointer_to_low48(const aPtr: Pointer): PtrUInt; inline;
var
  LValue: PtrUInt;
  LLow48: PtrUInt;
  LCanonical: PtrUInt;
  LSignBit: PtrUInt;
  LHighMask: PtrUInt;
begin
  LValue := PtrUInt(aPtr);
  LLow48 := LValue and PTR_MASK;
  LSignBit := PtrUInt(1) shl (TAG_SHIFT - 1);
  LHighMask := not PTR_MASK;
  if (LLow48 and LSignBit) <> 0 then
    LCanonical := LLow48 or LHighMask
  else
    LCanonical := LLow48;

  if LCanonical <> LValue then
    raise EArgumentError.Create('atomic_tagged_ptr: pointer out of range for x86_64 packing');

  Result := LLow48;
end;

function _x86_64_low48_to_pointer(const aValue: PtrUInt): Pointer; inline;
var
  LCanonical: PtrUInt;
  LSignBit: PtrUInt;
  LHighMask: PtrUInt;
begin
  LSignBit := PtrUInt(1) shl (TAG_SHIFT - 1);
  LHighMask := not PTR_MASK;
  if (aValue and LSignBit) <> 0 then
    LCanonical := aValue or LHighMask
  else
    LCanonical := aValue and PTR_MASK;
  Result := Pointer(LCanonical);
end;
{$ENDIF}

{$IF DEFINED(CPUPPC) OR DEFINED(CPUPPC64)}
procedure atomic_seq_cst_fence; assembler; nostackframe;
asm
  sync
end;
{$ELSE}
procedure atomic_seq_cst_fence;
begin
  ReadWriteBarrier;
end;
{$ENDIF}

procedure cpu_pause;
begin
  {$IF DEFINED(CPUX86_64)}
    asm
      pause
    end;
  {$ELSEIF DEFINED(CPUX86)}
    asm
      pause
    end;
  {$ELSEIF DEFINED(CPUAARCH64)}
    asm
      yield
    end;
  {$ELSEIF DEFINED(CPUARM)}
    asm
      yield
    end;
  {$ELSE}
  {$ENDIF}
end;

// FPC does not expose a dedicated compiler-fence intrinsic here, so use an
// empty assembler procedure as a compiler-only barrier for signal fences.
procedure _compiler_signal_fence; assembler; nostackframe;
asm
end;

procedure atomic_thread_fence(aOrder: memory_order_t);
begin
  case aOrder of
    mo_relaxed:;
    mo_consume: ReadBarrier;
    mo_acquire: ReadBarrier;
    mo_release: WriteBarrier;
    mo_acq_rel: ReadWriteBarrier;
    mo_seq_cst: atomic_seq_cst_fence;
  end;
end;

procedure atomic_signal_fence(aOrder: memory_order_t);
begin
  case aOrder of
    mo_relaxed:;
    mo_consume,
    mo_acquire,
    mo_release,
    mo_acq_rel,
    mo_seq_cst:
      _compiler_signal_fence;
  end;
end;

function atomic_tagged_ptr(aPtr: Pointer; aTag: {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF}): atomic_tagged_ptr_t;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  {$IF DEFINED(CPUX86_64)}
    {$IFDEF NEXTPAS_ATOMIC_TAGGED_PTR_CHECKS}
      _x86_64_pointer_to_low48(aPtr);
    {$ENDIF}
  {$ELSE}
    if (PtrUInt(aPtr) and TAG_MASK) <> 0 then
      raise EArgumentError.Create('atomic_tagged_ptr: pointer not aligned for low-bit tag packing');
    if (PtrUInt(aTag) and (not TAG_MASK)) <> 0 then
      raise EArgumentError.Create('atomic_tagged_ptr: tag does not fit TAG_BITS');
    {$IFDEF NEXTPAS_ATOMIC_TAGGED_PTR_CHECKS}
      Assert((PtrUInt(aPtr) and TAG_MASK) = 0, 'atomic_tagged_ptr: pointer not aligned for low-bit tag packing');
      Assert((PtrUInt(aTag) and (not TAG_MASK)) = 0, 'atomic_tagged_ptr: tag does not fit TAG_BITS');
    {$ENDIF}
  {$ENDIF}

  {$IF DEFINED(CPUX86_64)}
  Result := _x86_64_pointer_to_low48(aPtr) or (PtrUInt(aTag) shl TAG_SHIFT);
  {$ELSE}
  Result := (PtrUInt(aPtr) and PTR_MASK) or (PtrUInt(aTag) and TAG_MASK);
  {$ENDIF}
  {$POP}
end;

function atomic_tagged_ptr_get_ptr(const aTaggedPtr: atomic_tagged_ptr_t): Pointer;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  {$IF DEFINED(CPUX86_64)}
  Result := _x86_64_low48_to_pointer(PtrUInt(aTaggedPtr) and PTR_MASK);
  {$ELSE}
  Result := Pointer(PtrUInt(aTaggedPtr) and PTR_MASK);
  {$ENDIF}
  {$POP}
end;

function atomic_tagged_ptr_get_tag(const aTaggedPtr: atomic_tagged_ptr_t): {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF};
begin
  {$IF DEFINED(CPUX86_64)}
  Result := UInt16(PtrUInt(aTaggedPtr) shr TAG_SHIFT);
  {$ELSEIF DEFINED(CPU64)}
  Result := UInt16(PtrUInt(aTaggedPtr) and TAG_MASK);
  {$ELSE}
  Result := UInt32(PtrUInt(aTaggedPtr) and TAG_MASK);
  {$ENDIF}
end;

function atomic_tagged_ptr_next(const aTaggedPtr: atomic_tagged_ptr_t): {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF};
var
  LTag: {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF};
begin
  LTag := atomic_tagged_ptr_get_tag(aTaggedPtr);
  if LTag = MAX_TAG then
    Result := 1
  else
    Result := LTag + 1;
end;

end.
