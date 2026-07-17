unit nextpas.core.simd.mask;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.base;

// Portable shared mask helpers used by backend register paths.
// x86-64 keeps asm leaves for All/Any/None/FirstSet; other hosts use Pascal.
// PopCount is pure Pascal on all hosts (small SWAR / bit loops).

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

function SharedMask2PopCount(mask: TMask2): Integer;
function SharedMask4PopCount(mask: TMask4): Integer;
function SharedMask8PopCount(mask: TMask8): Integer;
function SharedMask16PopCount(mask: TMask16): Integer;

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

{$ELSE}

function SharedMask2FirstSet(mask: TMask2): Integer;
var
  m: Byte;
begin
  m := mask and $03;
  if m = 0 then
    Exit(-1);
  if (m and 1) <> 0 then
    Exit(0);
  Result := 1;
end;

function SharedMask4FirstSet(mask: TMask4): Integer;
var
  m: Byte;
  i: Integer;
begin
  m := mask and $0F;
  if m = 0 then
    Exit(-1);
  for i := 0 to 3 do
    if (m and (1 shl i)) <> 0 then
      Exit(i);
  Result := -1;
end;

function SharedMask8FirstSet(mask: TMask8): Integer;
var
  m: Byte;
  i: Integer;
begin
  m := Byte(mask);
  if m = 0 then
    Exit(-1);
  for i := 0 to 7 do
    if (m and (1 shl i)) <> 0 then
      Exit(i);
  Result := -1;
end;

function SharedMask16FirstSet(mask: TMask16): Integer;
var
  m: Word;
  i: Integer;
begin
  m := Word(mask);
  if m = 0 then
    Exit(-1);
  for i := 0 to 15 do
    if (m and (Word(1) shl i)) <> 0 then
      Exit(i);
  Result := -1;
end;

function SharedMask2All(mask: TMask2): Boolean;
begin
  Result := (mask and $03) = $03;
end;

function SharedMask2Any(mask: TMask2): Boolean;
begin
  Result := (mask and $03) <> 0;
end;

function SharedMask2None(mask: TMask2): Boolean;
begin
  Result := (mask and $03) = 0;
end;

function SharedMask4All(mask: TMask4): Boolean;
begin
  Result := (mask and $0F) = $0F;
end;

function SharedMask4Any(mask: TMask4): Boolean;
begin
  Result := (mask and $0F) <> 0;
end;

function SharedMask4None(mask: TMask4): Boolean;
begin
  Result := (mask and $0F) = 0;
end;

function SharedMask8All(mask: TMask8): Boolean;
begin
  Result := Byte(mask) = $FF;
end;

function SharedMask8Any(mask: TMask8): Boolean;
begin
  Result := Byte(mask) <> 0;
end;

function SharedMask8None(mask: TMask8): Boolean;
begin
  Result := Byte(mask) = 0;
end;

function SharedMask16All(mask: TMask16): Boolean;
begin
  Result := Word(mask) = $FFFF;
end;

function SharedMask16Any(mask: TMask16): Boolean;
begin
  Result := Word(mask) <> 0;
end;

function SharedMask16None(mask: TMask16): Boolean;
begin
  Result := Word(mask) = 0;
end;

{$ENDIF}

function SharedMask2PopCount(mask: TMask2): Integer;
var
  m: Byte;
begin
  m := mask and $03;
  Result := (m and 1) + ((m shr 1) and 1);
end;

function SharedMask4PopCount(mask: TMask4): Integer;
var
  m: Byte;
begin
  m := mask and $0F;
  // SWAR 4-bit popcount
  m := m - ((m shr 1) and $5);
  m := (m and $3) + ((m shr 2) and $3);
  Result := m;
end;

function SharedMask8PopCount(mask: TMask8): Integer;
var
  m: Byte;
begin
  m := Byte(mask);
  m := m - ((m shr 1) and $55);
  m := (m and $33) + ((m shr 2) and $33);
  Result := Byte((m + (m shr 4)) and $0F);
end;

function SharedMask16PopCount(mask: TMask16): Integer;
var
  m: Word;
begin
  m := Word(mask);
  m := m - ((m shr 1) and $5555);
  m := (m and $3333) + ((m shr 2) and $3333);
  m := (m + (m shr 4)) and $0F0F;
  Result := Byte((m + (m shr 8)) and $1F);
end;

end.
