unit nextpas.core.simd.mask;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.base;

{$IFDEF CPUX86_64}
function SharedMask2FirstSet(mask: TMask2): Integer;
function SharedMask4FirstSet(mask: TMask4): Integer;
function SharedMask8FirstSet(mask: TMask8): Integer;
function SharedMask16FirstSet(mask: TMask16): Integer;
{$ENDIF}

implementation

{$IFDEF CPUX86_64}

function SharedMask2FirstSet(mask: TMask2): Integer; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  and   edi, 3
  bsf   eax, edi
  jnz   @done
  mov   eax, -1
@done:
  {$ELSE}
  and   ecx, 3
  bsf   eax, ecx
  jnz   @done
  mov   eax, -1
@done:
  {$ENDIF}
end;

function SharedMask4FirstSet(mask: TMask4): Integer; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  and   edi, 15
  bsf   eax, edi
  jnz   @done
  mov   eax, -1
@done:
  {$ELSE}
  and   ecx, 15
  bsf   eax, ecx
  jnz   @done
  mov   eax, -1
@done:
  {$ENDIF}
end;

function SharedMask8FirstSet(mask: TMask8): Integer; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  movzx edi, dil
  bsf   eax, edi
  jnz   @done
  mov   eax, -1
@done:
  {$ELSE}
  movzx ecx, cl
  bsf   eax, ecx
  jnz   @done
  mov   eax, -1
@done:
  {$ENDIF}
end;

function SharedMask16FirstSet(mask: TMask16): Integer; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  movzx edi, di
  bsf   eax, edi
  jnz   @done
  mov   eax, -1
@done:
  {$ELSE}
  movzx ecx, cx
  bsf   eax, ecx
  jnz   @done
  mov   eax, -1
@done:
  {$ENDIF}
end;

{$ENDIF}

end.
