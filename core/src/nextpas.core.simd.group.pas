unit nextpas.core.simd.group;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

type
  TGroupMask = Word;

function GroupMatch(ACtrl: PByte; AValue: Byte): TGroupMask; inline;
function GroupCtz(AMask: TGroupMask): Int32; inline;
function GroupPopcnt(AMask: TGroupMask): Int32; inline;

implementation

{$IFDEF CPUX86_64}

function GroupMatch(ACtrl: PByte; AValue: Byte): TGroupMask; inline;
begin
  Result := 0;
  asm
    movzx eax, AValue
    movd xmm0, eax
    punpcklbw xmm0, xmm0
    pshuflw xmm0, xmm0, 0
    punpcklqdq xmm0, xmm0
    mov rax, ACtrl
    movdqu xmm1, [rax]
    pcmpeqb xmm1, xmm0
    pmovmskb eax, xmm1
    mov Result, ax
  end;
end;

function GroupCtz(AMask: TGroupMask): Int32; inline;
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

function GroupPopcnt(AMask: TGroupMask): Int32; inline;
var
  m: UInt32;
begin
  m := AMask;
  m := m - ((m shr 1) and $5555);
  m := (m and $3333) + ((m shr 2) and $3333);
  m := (m + (m shr 4)) and $0F0F;
  Result := Int32((m + (m shr 8)) and $FF);
end;

{$ELSEIF Defined(CPUAARCH64)}

function GroupMatch(ACtrl: PByte; AValue: Byte): TGroupMask; inline;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if ACtrl[i] = AValue then
      Result := Result or TGroupMask(1 shl i);
end;

function GroupCtz(AMask: TGroupMask): Int32; inline;
var
  i: Integer;
begin
  if AMask = 0 then Exit(-1);
  for i := 0 to 15 do
    if (AMask and (1 shl i)) <> 0 then Exit(i);
  Result := -1;
end;

function GroupPopcnt(AMask: TGroupMask): Int32; inline;
var
  m: UInt32;
begin
  m := AMask;
  m := m - ((m shr 1) and $5555);
  m := (m and $3333) + ((m shr 2) and $3333);
  m := (m + (m shr 4)) and $0F0F;
  Result := Int32((m + (m shr 8)) and $FF);
end;

{$ELSE}

function GroupMatch(ACtrl: PByte; AValue: Byte): TGroupMask; inline;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if ACtrl[i] = AValue then
      Result := Result or TGroupMask(1 shl i);
end;

function GroupCtz(AMask: TGroupMask): Int32; inline;
var
  i: Integer;
begin
  if AMask = 0 then Exit(-1);
  for i := 0 to 15 do
    if (AMask and (1 shl i)) <> 0 then Exit(i);
  Result := -1;
end;

function GroupPopcnt(AMask: TGroupMask): Int32; inline;
var
  m: UInt32;
begin
  m := AMask;
  m := m - ((m shr 1) and $5555);
  m := (m and $3333) + ((m shr 2) and $3333);
  m := (m + (m shr 4)) and $0F0F;
  Result := Int32((m + (m shr 8)) and $FF);
end;

{$ENDIF}

end.
