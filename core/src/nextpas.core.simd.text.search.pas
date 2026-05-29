unit nextpas.core.simd.text.search;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.alloc;

// Count occurrences of a single byte in buffer (SIMD accelerated)
function ByteCountF32(AHaystack: PByte; ALen: SizeUInt; ANeedle: Byte): SizeUInt;

// Find all occurrences of needle in haystack, return count
// APositions: output array (caller-allocated), AMaxPositions: capacity
function MemSearchAll(AHaystack: Pointer; AHaystackLen: SizeUInt;
  ANeedle: Pointer; ANeedleLen: SizeUInt;
  APositions: PSizeUInt; AMaxPositions: SizeUInt): SizeUInt;

implementation

uses
  nextpas.core.simd;

function ByteCountF32(AHaystack: PByte; ALen: SizeUInt; ANeedle: Byte): SizeUInt;
var
  LI: SizeUInt;
  {$IFDEF SIMD_X86_AVAILABLE}
  LCount16: SizeUInt;
  {$ENDIF}
begin
  Result := 0;
  LI := 0;
  {$IFDEF SIMD_X86_AVAILABLE}
  LCount16 := ALen and (not SizeUInt(15));
  if LCount16 > 0 then
  asm
    push rbx
    mov rax, AHaystack
    xor ecx, ecx          // loop counter
    pxor xmm0, xmm0       // result accumulator

    // Broadcast needle byte to all 16 positions
    movd xmm1, ANeedle
    punpcklbw xmm1, xmm1
    pshuflw xmm1, xmm1, 0
    punpcklqdq xmm1, xmm1  // xmm1 = [needle x 16]

  @byte_count_loop:
    movdqu xmm2, [rax + rcx]
    pcmpeqb xmm2, xmm1     // compare: 0xFF where match
    pmovmskb ebx, xmm2     // bit mask of matches
    // SWAR popcount (safe on all x86, no POPCNT dependency)
    mov edx, ebx
    shr edx, 1
    and edx, $5555
    sub ebx, edx
    mov edx, ebx
    shr edx, 2
    and ebx, $3333
    and edx, $3333
    add ebx, edx
    mov edx, ebx
    shr edx, 4
    add ebx, edx
    and ebx, $0F0F
    mov edx, ebx
    shr edx, 8
    add ebx, edx
    and ebx, $FF
    add Result, rbx

    add ecx, 16
    cmp ecx, dword [LCount16]
    jb @byte_count_loop

    mov LI, rcx
    pop rbx
  end;
  {$ENDIF}
  while LI < ALen do
  begin
    if AHaystack[LI] = ANeedle then Inc(Result);
    Inc(LI);
  end;
end;

function MemSearchAll(AHaystack: Pointer; AHaystackLen: SizeUInt;
  ANeedle: Pointer; ANeedleLen: SizeUInt;
  APositions: PSizeUInt; AMaxPositions: SizeUInt): SizeUInt;
var
  LI, LJ: SizeUInt;
  LFirst: Byte;
  LFound: Boolean;
  LHay: PByte;
  LNdl: PByte;
begin
  Result := 0;
  if (ANeedleLen = 0) or (AHaystackLen < ANeedleLen) or (AMaxPositions = 0) then Exit;

  LHay := PByte(AHaystack);
  LNdl := PByte(ANeedle);
  LFirst := LNdl[0];

  LI := 0;
  while LI <= AHaystackLen - ANeedleLen do
  begin
    if LHay[LI] = LFirst then
    begin
      LFound := True;
      for LJ := 1 to ANeedleLen - 1 do
        if LHay[LI + LJ] <> LNdl[LJ] then
        begin
          LFound := False;
          Break;
        end;
      if LFound then
      begin
        APositions[Result] := LI;
        Inc(Result);
        if Result >= AMaxPositions then Exit;
      end;
    end;
    Inc(LI);
  end;
end;

end.
