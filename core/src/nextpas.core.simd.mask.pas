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

function SharedMask2All(mask: TMask2): Boolean;
function SharedMask2Any(mask: TMask2): Boolean;
function SharedMask2None(mask: TMask2): Boolean;
function SharedMask4All(mask: TMask4): Boolean;
function SharedMask4Any(mask: TMask4): Boolean;
function SharedMask4None(mask: TMask4): Boolean;
function SharedMask8All(mask: TMask8): Boolean;
function SharedMask8Any(mask: TMask8): Boolean;
function SharedMask8None(mask: TMask8): Boolean;
function SharedMask16All(mask: TMask16): Boolean;
function SharedMask16Any(mask: TMask16): Boolean;
function SharedMask16None(mask: TMask16): Boolean;
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

// === All / Any / None ===

function SharedMask2All(mask: TMask2): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  and   edi, 3
  cmp   edi, 3
  sete  al
  {$ELSE}
  and   ecx, 3
  cmp   ecx, 3
  sete  al
  {$ENDIF}
end;

function SharedMask2Any(mask: TMask2): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  edi, 3
  setne al
  {$ELSE}
  test  ecx, 3
  setne al
  {$ENDIF}
end;

function SharedMask2None(mask: TMask2): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  edi, 3
  sete  al
  {$ELSE}
  test  ecx, 3
  sete  al
  {$ENDIF}
end;

function SharedMask4All(mask: TMask4): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  and   edi, 15
  cmp   edi, 15
  sete  al
  {$ELSE}
  and   ecx, 15
  cmp   ecx, 15
  sete  al
  {$ENDIF}
end;

function SharedMask4Any(mask: TMask4): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  edi, 15
  setne al
  {$ELSE}
  test  ecx, 15
  setne al
  {$ENDIF}
end;

function SharedMask4None(mask: TMask4): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  edi, 15
  sete  al
  {$ELSE}
  test  ecx, 15
  sete  al
  {$ENDIF}
end;

function SharedMask8All(mask: TMask8): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  cmp   dil, $FF
  sete  al
  {$ELSE}
  cmp   cl, $FF
  sete  al
  {$ENDIF}
end;

function SharedMask8Any(mask: TMask8): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  dil, dil
  setne al
  {$ELSE}
  test  cl, cl
  setne al
  {$ENDIF}
end;

function SharedMask8None(mask: TMask8): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  dil, dil
  sete  al
  {$ELSE}
  test  cl, cl
  sete  al
  {$ENDIF}
end;

function SharedMask16All(mask: TMask16): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  cmp   di, $FFFF
  sete  al
  {$ELSE}
  cmp   cx, $FFFF
  sete  al
  {$ENDIF}
end;

function SharedMask16Any(mask: TMask16): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  di, di
  setne al
  {$ELSE}
  test  cx, cx
  setne al
  {$ENDIF}
end;

function SharedMask16None(mask: TMask16): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  di, di
  sete  al
  {$ELSE}
  test  cx, cx
  sete  al
  {$ENDIF}
end;

{$ENDIF}

end.
