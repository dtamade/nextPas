unit nextpas.core.crypto.p256.field;

{$mode ObjFPC}{$H+}{$J-}
{$Q-}{$R-}

interface

uses
  SysUtils;

type
  TP256Fe = array[0..3] of QWord;

procedure P256FeZero(out A: TP256Fe);
procedure P256FeOne(out A: TP256Fe);
procedure P256FeCopy(const A: TP256Fe; out R: TP256Fe);
procedure P256FeFromBytes(const ABytes: TBytes; out R: TP256Fe);
procedure P256FeToBytes(const A: TP256Fe; out R: TBytes);

procedure P256FeAdd(const A, B: TP256Fe; out R: TP256Fe);
procedure P256FeSub(const A, B: TP256Fe; out R: TP256Fe);
procedure P256FeMul(const A, B: TP256Fe; out R: TP256Fe);
procedure P256FeSqr(const A: TP256Fe; out R: TP256Fe);
procedure P256FeInv(const A: TP256Fe; out R: TP256Fe);

function P256FeIsZero(const A: TP256Fe): QWord;
procedure P256FeCondCopy(const ASrc: TP256Fe; var ADst: TP256Fe; ACond: QWord);

implementation

const
  P256_P: TP256Fe = (
    QWord($FFFFFFFFFFFFFFFF),
    QWord($00000000FFFFFFFF),
    QWord($0000000000000000),
    QWord($FFFFFFFF00000001)
  );

procedure P256FeZero(out A: TP256Fe);
begin
  A[0] := 0; A[1] := 0; A[2] := 0; A[3] := 0;
end;

procedure P256FeOne(out A: TP256Fe);
begin
  A[0] := 1; A[1] := 0; A[2] := 0; A[3] := 0;
end;

procedure P256FeCopy(const A: TP256Fe; out R: TP256Fe);
begin
  R[0] := A[0]; R[1] := A[1]; R[2] := A[2]; R[3] := A[3];
end;

procedure P256FeFromBytes(const ABytes: TBytes; out R: TP256Fe);
var
  I: Integer;
begin
  P256FeZero(R);
  for I := 0 to 31 do
    R[3 - (I div 8)] := R[3 - (I div 8)] or (QWord(ABytes[I]) shl ((7 - (I mod 8)) * 8));
end;

procedure P256FeToBytes(const A: TP256Fe; out R: TBytes);
var
  I: Integer;
begin
  SetLength(R, 32);
  for I := 0 to 31 do
    R[I] := Byte(A[3 - (I div 8)] shr ((7 - (I mod 8)) * 8));
end;

procedure P256FeCondCopy(const ASrc: TP256Fe; var ADst: TP256Fe; ACond: QWord);
var
  LMask: QWord;
begin
  LMask := QWord(0) - ACond;
  ADst[0] := (ASrc[0] and LMask) or (ADst[0] and (not LMask));
  ADst[1] := (ASrc[1] and LMask) or (ADst[1] and (not LMask));
  ADst[2] := (ASrc[2] and LMask) or (ADst[2] and (not LMask));
  ADst[3] := (ASrc[3] and LMask) or (ADst[3] and (not LMask));
end;

function P256FeIsZero(const A: TP256Fe): QWord;
var
  LV: QWord;
begin
  LV := A[0] or A[1] or A[2] or A[3];
  Result := QWord(1) and (not ((LV or (QWord(0) - LV)) shr 63));
end;

// 256-bit add with carry out
function Add256(const A, B: TP256Fe; out R: TP256Fe): QWord;
var
  LT: QWord;
  LCarry: QWord;
begin
  LCarry := 0;
  R[0] := A[0] + B[0]; LCarry := QWord(Ord(R[0] < A[0]));
  LT := B[1] + LCarry; R[1] := A[1] + LT;
  LCarry := QWord(Ord(LT < B[1])) or QWord(Ord(R[1] < A[1]));
  LT := B[2] + LCarry; R[2] := A[2] + LT;
  LCarry := QWord(Ord(LT < B[2])) or QWord(Ord(R[2] < A[2]));
  LT := B[3] + LCarry; R[3] := A[3] + LT;
  Result := QWord(Ord(LT < B[3])) or QWord(Ord(R[3] < A[3]));
end;

// 256-bit subtract with borrow out
function Sub256(const A, B: TP256Fe; out R: TP256Fe): QWord;
var
  LBorrow: QWord;
begin
  LBorrow := 0;
  R[0] := A[0] - B[0]; LBorrow := QWord(Ord(A[0] < B[0]));
  R[1] := A[1] - B[1] - LBorrow;
  if LBorrow > 0 then LBorrow := QWord(Ord(A[1] <= B[1]))
  else LBorrow := QWord(Ord(A[1] < B[1]));
  R[2] := A[2] - B[2] - LBorrow;
  if LBorrow > 0 then LBorrow := QWord(Ord(A[2] <= B[2]))
  else LBorrow := QWord(Ord(A[2] < B[2]));
  R[3] := A[3] - B[3] - LBorrow;
  if LBorrow > 0 then Result := QWord(Ord(A[3] <= B[3]))
  else Result := QWord(Ord(A[3] < B[3]));
end;

procedure P256FeAdd(const A, B: TP256Fe; out R: TP256Fe);
var
  LOver, LBorrow: QWord;
  LT, LRes: TP256Fe;
begin
  LOver := Add256(A, B, LRes);
  LBorrow := Sub256(LRes, P256_P, LT);
  P256FeCondCopy(LT, LRes, LOver or (1 - LBorrow));
  R := LRes;
end;

procedure P256FeSub(const A, B: TP256Fe; out R: TP256Fe);
var
  LBorrow: QWord;
  LT, LRes: TP256Fe;
begin
  LBorrow := Sub256(A, B, LRes);
  Add256(LRes, P256_P, LT);
  P256FeCondCopy(LT, LRes, LBorrow);
  R := LRes;
end;

// 64x64 -> 128 bit multiply
{$IFDEF CPUX86_64}
{$ASMMODE ATT}
procedure Mul64(A, B: QWord; out Lo, Hi: QWord); assembler; nostackframe;
asm
  // A=rdi, B=rsi, @Lo=rdx, @Hi=rcx
  movq %rdx, %r8       // save @Lo (rdx will be clobbered by mulq)
  movq %rdi, %rax      // rax = A
  mulq %rsi            // rdx:rax = A * B
  movq %rax, (%r8)     // *Lo = rax
  movq %rdx, (%rcx)    // *Hi = rdx
end;
{$ELSE}
procedure Mul64(A, B: QWord; out Lo, Hi: QWord);
var
  AH, AL, BH, BL, M1, M2, M: QWord;
begin
  AH := A shr 32; AL := A and $FFFFFFFF;
  BH := B shr 32; BL := B and $FFFFFFFF;
  Lo := AL * BL;
  Hi := AH * BH;
  M1 := AL * BH;
  M2 := AH * BL;
  M := M1 + M2;
  if M < M1 then Hi := Hi + (QWord(1) shl 32);
  Lo := Lo + (M shl 32);
  if Lo < (M shl 32) then Inc(Hi);
  Hi := Hi + (M shr 32);
end;
{$ENDIF}

procedure P256FeMul(const A, B: TP256Fe; out R: TP256Fe);
var
  LT: array[0..7] of QWord;
  {$IFNDEF CPUX86_64}
  LLo, LHi: QWord;
  I, J: Integer;
  LCarry: QWord;
  {$ENDIF}
  C: array[0..15] of UInt32;
  S: TP256Fe;
  LI: Integer;
begin
  {$IFDEF CPUX86_64}
  // Full ASM schoolbook 4x4 multiply (16 mulq, no function calls)
  asm
    push %rbx
    push %r12
    push %r13
    push %r14
    push %r15

    movq A, %rsi
    movq B, %rbx

    // Column 0
    movq (%rsi), %rax
    mulq (%rbx)
    movq %rax, %r8
    movq %rdx, %r9

    // Column 1
    xorq %r10, %r10
    movq (%rsi), %rax
    mulq 8(%rbx)
    addq %rax, %r9
    adcq %rdx, %r10
    movq 8(%rsi), %rax
    mulq (%rbx)
    addq %rax, %r9
    adcq %rdx, %r10

    // Column 2
    xorq %r11, %r11
    movq (%rsi), %rax
    mulq 16(%rbx)
    addq %rax, %r10
    adcq %rdx, %r11
    movq 8(%rsi), %rax
    mulq 8(%rbx)
    addq %rax, %r10
    adcq %rdx, %r11
    movq 16(%rsi), %rax
    mulq (%rbx)
    addq %rax, %r10
    adcq %rdx, %r11

    // Column 3
    xorq %r12, %r12
    movq (%rsi), %rax
    mulq 24(%rbx)
    addq %rax, %r11
    adcq %rdx, %r12
    movq 8(%rsi), %rax
    mulq 16(%rbx)
    addq %rax, %r11
    adcq %rdx, %r12
    movq 16(%rsi), %rax
    mulq 8(%rbx)
    addq %rax, %r11
    adcq %rdx, %r12
    movq 24(%rsi), %rax
    mulq (%rbx)
    addq %rax, %r11
    adcq %rdx, %r12

    // Column 4
    xorq %r13, %r13
    movq 8(%rsi), %rax
    mulq 24(%rbx)
    addq %rax, %r12
    adcq %rdx, %r13
    movq 16(%rsi), %rax
    mulq 16(%rbx)
    addq %rax, %r12
    adcq %rdx, %r13
    movq 24(%rsi), %rax
    mulq 8(%rbx)
    addq %rax, %r12
    adcq %rdx, %r13

    // Column 5
    xorq %r14, %r14
    movq 16(%rsi), %rax
    mulq 24(%rbx)
    addq %rax, %r13
    adcq %rdx, %r14
    movq 24(%rsi), %rax
    mulq 16(%rbx)
    addq %rax, %r13
    adcq %rdx, %r14

    // Column 6
    xorq %r15, %r15
    movq 24(%rsi), %rax
    mulq 24(%rbx)
    addq %rax, %r14
    adcq %rdx, %r15

    // Store 8 limbs to LT
    leaq LT, %rcx
    movq %r8, (%rcx)
    movq %r9, 8(%rcx)
    movq %r10, 16(%rcx)
    movq %r11, 24(%rcx)
    movq %r12, 32(%rcx)
    movq %r13, 40(%rcx)
    movq %r14, 48(%rcx)
    movq %r15, 56(%rcx)

    pop %r15
    pop %r14
    pop %r13
    pop %r12
    pop %rbx
  end ['rax', 'rcx', 'rdx', 'rsi', 'rbx', 'r8', 'r9', 'r10', 'r11', 'r12', 'r13', 'r14', 'r15'];
  {$ELSE}
  FillChar(LT, SizeOf(LT), 0);
  for I := 0 to 3 do
  begin
    LCarry := 0;
    for J := 0 to 3 do
    begin
      Mul64(A[I], B[J], LLo, LHi);
      LLo := LLo + LT[I + J];
      if LLo < LT[I + J] then Inc(LHi);
      LLo := LLo + LCarry;
      if LLo < LCarry then Inc(LHi);
      LT[I + J] := LLo;
      LCarry := LHi;
    end;
    LT[I + 4] := LCarry;
  end;
  {$ENDIF}

  // Split into 32-bit words for NIST P-256 fast reduction
  for LI := 0 to 7 do
  begin
    C[LI * 2] := UInt32(LT[LI] and $FFFFFFFF);
    C[LI * 2 + 1] := UInt32(LT[LI] shr 32);
  end;

  // Base: low 256 bits
  R[0] := LT[0]; R[1] := LT[1]; R[2] := LT[2]; R[3] := LT[3];

  // +2*S1: (c15,c14,c13,c12,c11, 0, 0, 0)
  S[0] := 0;
  S[1] := QWord(C[11]) shl 32;
  S[2] := QWord(C[12]) or (QWord(C[13]) shl 32);
  S[3] := QWord(C[14]) or (QWord(C[15]) shl 32);
  P256FeAdd(R, S, R); P256FeAdd(R, S, R);

  // +2*S2: (0, c15, c14, c13, c12, 0, 0, 0)
  S[0] := 0;
  S[1] := QWord(C[12]) shl 32;
  S[2] := QWord(C[13]) or (QWord(C[14]) shl 32);
  S[3] := QWord(C[15]);
  P256FeAdd(R, S, R); P256FeAdd(R, S, R);

  // +S3: (c15, c14, 0, 0, 0, c10, c9, c8)
  S[0] := QWord(C[8]) or (QWord(C[9]) shl 32);
  S[1] := QWord(C[10]);
  S[2] := 0;
  S[3] := QWord(C[14]) or (QWord(C[15]) shl 32);
  P256FeAdd(R, S, R);

  // +S4: (c8, c13, c15, c14, c13, c11, c10, c9)
  S[0] := QWord(C[9]) or (QWord(C[10]) shl 32);
  S[1] := QWord(C[11]) or (QWord(C[13]) shl 32);
  S[2] := QWord(C[14]) or (QWord(C[15]) shl 32);
  S[3] := QWord(C[13]) or (QWord(C[8]) shl 32);
  P256FeAdd(R, S, R);

  // -D1: (c10, c8, 0, 0, 0, c13, c12, c11)
  S[0] := QWord(C[11]) or (QWord(C[12]) shl 32);
  S[1] := QWord(C[13]);
  S[2] := 0;
  S[3] := QWord(C[8]) or (QWord(C[10]) shl 32);
  P256FeSub(R, S, R);

  // -D2: (c11, c9, 0, 0, c15, c14, c13, c12)
  S[0] := QWord(C[12]) or (QWord(C[13]) shl 32);
  S[1] := QWord(C[14]) or (QWord(C[15]) shl 32);
  S[2] := 0;
  S[3] := QWord(C[9]) or (QWord(C[11]) shl 32);
  P256FeSub(R, S, R);

  // -D3: (c12, 0, c10, c9, c8, c15, c14, c13)
  S[0] := QWord(C[13]) or (QWord(C[14]) shl 32);
  S[1] := QWord(C[15]) or (QWord(C[8]) shl 32);
  S[2] := QWord(C[9]) or (QWord(C[10]) shl 32);
  S[3] := QWord(0) or (QWord(C[12]) shl 32);
  P256FeSub(R, S, R);

  // -D4: (c13, 0, c11, c10, c9, 0, c15, c14)
  S[0] := QWord(C[14]) or (QWord(C[15]) shl 32);
  S[1] := QWord(0) or (QWord(C[9]) shl 32);
  S[2] := QWord(C[10]) or (QWord(C[11]) shl 32);
  S[3] := QWord(0) or (QWord(C[13]) shl 32);
  P256FeSub(R, S, R);
end;

procedure P256FeSqr(const A: TP256Fe; out R: TP256Fe);
var
  LTmp: TP256Fe;
begin
  P256FeMul(A, A, LTmp);
  R := LTmp;
end;

procedure P256FeInv(const A: TP256Fe; out R: TP256Fe);
var
  LT: TP256Fe;
  I: Integer;
const
  PM2_0: QWord = QWord($FFFFFFFFFFFFFFFD);
  PM2_1: QWord = QWord($00000000FFFFFFFF);
  PM2_2: QWord = QWord($0000000000000000);
  PM2_3: QWord = QWord($FFFFFFFF00000001);
begin
  P256FeCopy(A, LT);
  P256FeOne(R);
  for I := 255 downto 0 do
  begin
    P256FeSqr(R, R);
    case I div 64 of
      0: if ((PM2_0 shr (I mod 64)) and 1) = 1 then P256FeMul(R, LT, R);
      1: if ((PM2_1 shr (I mod 64)) and 1) = 1 then P256FeMul(R, LT, R);
      2: ;
      3: if ((PM2_3 shr (I mod 64)) and 1) = 1 then P256FeMul(R, LT, R);
    end;
  end;
end;

end.
