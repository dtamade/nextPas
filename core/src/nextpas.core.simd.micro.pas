unit nextpas.core.simd.micro;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

// Zero-overhead SIMD micro-operations for hot paths.
// These bypass the dispatch table and Vec128ToRaw copies.
// Use for single-vector operations where dispatch overhead dominates.

type
  TMask16 = Word;

{$IFDEF CPUX86_64}
// Compare 16 bytes at AData with broadcast AValue, return bitmask
function MicroCmpEqU8x16(AData: PByte; AValue: Byte): TMask16; inline;

// Same as above but as standalone asm (for cases where inline doesn't help)
function MicroCmpEqU8x16_Asm(AData: PByte; AValue: Byte): TMask16;

// Compare 16 bytes at AData with 16 bytes at APattern, return bitmask
function MicroCmpEq16(AData, APattern: PByte): TMask16; inline;

// Find first set bit in mask (0-15), or -1 if none
function MicroCtz16(AMask: TMask16): Int32; inline;

// Count set bits in mask
function MicroPopcnt16(AMask: TMask16): Int32; inline;

// Load 16 bytes, test if any byte matches AValue
function MicroContainsByte(AData: PByte; AValue: Byte): Boolean; inline;
{$ENDIF}

implementation

{$IFDEF CPUX86_64}

function MicroCmpEqU8x16(AData: PByte; AValue: Byte): TMask16; inline;
begin
  Result := 0;
  asm
    movzx eax, AValue
    movd xmm0, eax
    punpcklbw xmm0, xmm0
    pshuflw xmm0, xmm0, 0
    punpcklqdq xmm0, xmm0
    mov rax, AData
    movdqu xmm1, [rax]
    pcmpeqb xmm1, xmm0
    pmovmskb eax, xmm1
    mov Result, ax
  end;
end;

// RDI=AData, SIL=AValue, returns AX
function MicroCmpEqU8x16_Asm(AData: PByte; AValue: Byte): TMask16; assembler; nostackframe;
asm
  movd xmm0, esi
  punpcklbw xmm0, xmm0
  pshuflw xmm0, xmm0, 0
  punpcklqdq xmm0, xmm0
  movdqu xmm1, [rdi]
  pcmpeqb xmm1, xmm0
  pmovmskb eax, xmm1
end;

function MicroCmpEq16(AData, APattern: PByte): TMask16; inline;
begin
  Result := 0;
  asm
    mov rax, AData
    mov rdx, APattern
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    pcmpeqb xmm0, xmm1
    pmovmskb eax, xmm0
    mov Result, ax
  end;
end;

function MicroCtz16(AMask: TMask16): Int32; inline;
begin
  if AMask = 0 then
    Result := -1
  else
  begin
    Result := 0;
    asm
      movzx eax, AMask
      bsf eax, eax
      mov Result, eax
    end;
  end;
end;

function MicroPopcnt16(AMask: TMask16): Int32; inline;
begin
  Result := 0;
  asm
    movzx eax, AMask
    popcnt eax, eax
    mov Result, eax
  end;
end;

function MicroContainsByte(AData: PByte; AValue: Byte): Boolean; inline;
begin
  Result := MicroCmpEqU8x16(AData, AValue) <> 0;
end;

{$ENDIF}

end.
