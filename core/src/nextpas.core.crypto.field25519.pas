unit nextpas.core.crypto.field25519;

{$mode objfpc}{$H+}{$J-}

interface

uses
  SysUtils;

type
  TFe25519 = array[0..9] of Int64;

const
  FE_ZERO: TFe25519 = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
  FE_ONE: TFe25519 = (1, 0, 0, 0, 0, 0, 0, 0, 0, 0);

procedure FeFromBytes(out H: TFe25519; const S: TBytes; AOffset: Integer);
procedure FeToBytes(out S: TBytes; const H: TFe25519);
procedure FeAdd(out H: TFe25519; const F, G: TFe25519);
procedure FeSub(out H: TFe25519; const F, G: TFe25519);
procedure FeNeg(out H: TFe25519; const F: TFe25519);
procedure FeMul(out H: TFe25519; constref F, G: TFe25519);
procedure FeSq(out H: TFe25519; const F: TFe25519);
procedure FeMul121666(out H: TFe25519; const F: TFe25519);
procedure FeCopy(out H: TFe25519; const F: TFe25519);
procedure FeCSwap(var F, G: TFe25519; B: Int64);
procedure FeInvert(out O: TFe25519; const Z: TFe25519);
procedure FePow2523(out O: TFe25519; const Z: TFe25519);
function FeIsNegative(const F: TFe25519): Integer;
function FeIsZero(const F: TFe25519): Boolean;

implementation

function Sar(AValue: Int64; AShift: Integer): Int64; inline;
begin
  Result := SarInt64(AValue, AShift);
end;

procedure FeFromBytes(out H: TFe25519; const S: TBytes; AOffset: Integer);
var
  H0, H1, H2, H3, H4, H5, H6, H7, H8, H9: Int64;
  C: Int64;

  function Load4(I: Integer): Int64; inline;
  begin
    Result := Int64(S[AOffset+I]) or (Int64(S[AOffset+I+1]) shl 8) or
              (Int64(S[AOffset+I+2]) shl 16) or (Int64(S[AOffset+I+3]) shl 24);
  end;

  function Load3(I: Integer): Int64; inline;
  begin
    Result := Int64(S[AOffset+I]) or (Int64(S[AOffset+I+1]) shl 8) or
              (Int64(S[AOffset+I+2]) shl 16);
  end;

begin
  H0 := Load4(0);
  H1 := Load3(4) shl 6;
  H2 := Load3(7) shl 5;
  H3 := Load3(10) shl 3;
  H4 := Load3(13) shl 2;
  H5 := Load4(16);
  H6 := Load3(20) shl 7;
  H7 := Load3(23) shl 5;
  H8 := Load3(26) shl 4;
  H9 := (Load3(29) and $7FFFFF) shl 2;

  C := Sar(H9 + (Int64(1) shl 24), 25); H0 := H0 + C * 19; H9 := H9 - (C shl 25);
  C := Sar(H1 + (Int64(1) shl 24), 25); H2 := H2 + C; H1 := H1 - (C shl 25);
  C := Sar(H3 + (Int64(1) shl 24), 25); H4 := H4 + C; H3 := H3 - (C shl 25);
  C := Sar(H5 + (Int64(1) shl 24), 25); H6 := H6 + C; H5 := H5 - (C shl 25);
  C := Sar(H7 + (Int64(1) shl 24), 25); H8 := H8 + C; H7 := H7 - (C shl 25);

  C := Sar(H0 + (Int64(1) shl 25), 26); H1 := H1 + C; H0 := H0 - (C shl 26);
  C := Sar(H2 + (Int64(1) shl 25), 26); H3 := H3 + C; H2 := H2 - (C shl 26);
  C := Sar(H4 + (Int64(1) shl 25), 26); H5 := H5 + C; H4 := H4 - (C shl 26);
  C := Sar(H6 + (Int64(1) shl 25), 26); H7 := H7 + C; H6 := H6 - (C shl 26);
  C := Sar(H8 + (Int64(1) shl 25), 26); H9 := H9 + C; H8 := H8 - (C shl 26);

  H[0] := H0; H[1] := H1; H[2] := H2; H[3] := H3; H[4] := H4;
  H[5] := H5; H[6] := H6; H[7] := H7; H[8] := H8; H[9] := H9;
end;

procedure FeToBytes(out S: TBytes; const H: TFe25519);
var
  T: TFe25519;
  Q, C: Int64;
begin
  T := H;
  Q := Sar(19 * T[9] + (Int64(1) shl 24), 25);
  Q := Sar(T[0] + Q, 26);
  Q := Sar(T[1] + Q, 25);
  Q := Sar(T[2] + Q, 26);
  Q := Sar(T[3] + Q, 25);
  Q := Sar(T[4] + Q, 26);
  Q := Sar(T[5] + Q, 25);
  Q := Sar(T[6] + Q, 26);
  Q := Sar(T[7] + Q, 25);
  Q := Sar(T[8] + Q, 26);
  Q := Sar(T[9] + Q, 25);
  T[0] := T[0] + 19 * Q;

  C := Sar(T[0], 26); T[1] := T[1] + C; T[0] := T[0] - (C shl 26);
  C := Sar(T[1], 25); T[2] := T[2] + C; T[1] := T[1] - (C shl 25);
  C := Sar(T[2], 26); T[3] := T[3] + C; T[2] := T[2] - (C shl 26);
  C := Sar(T[3], 25); T[4] := T[4] + C; T[3] := T[3] - (C shl 25);
  C := Sar(T[4], 26); T[5] := T[5] + C; T[4] := T[4] - (C shl 26);
  C := Sar(T[5], 25); T[6] := T[6] + C; T[5] := T[5] - (C shl 25);
  C := Sar(T[6], 26); T[7] := T[7] + C; T[6] := T[6] - (C shl 26);
  C := Sar(T[7], 25); T[8] := T[8] + C; T[7] := T[7] - (C shl 25);
  C := Sar(T[8], 26); T[9] := T[9] + C; T[8] := T[8] - (C shl 26);
  C := Sar(T[9], 25); T[9] := T[9] - (C shl 25);

  SetLength(S, 32);
  S[0]  := Byte(T[0]);
  S[1]  := Byte(T[0] shr 8);
  S[2]  := Byte(T[0] shr 16);
  S[3]  := Byte((T[0] shr 24) or (T[1] shl 2));
  S[4]  := Byte(T[1] shr 6);
  S[5]  := Byte(T[1] shr 14);
  S[6]  := Byte((T[1] shr 22) or (T[2] shl 3));
  S[7]  := Byte(T[2] shr 5);
  S[8]  := Byte(T[2] shr 13);
  S[9]  := Byte((T[2] shr 21) or (T[3] shl 5));
  S[10] := Byte(T[3] shr 3);
  S[11] := Byte(T[3] shr 11);
  S[12] := Byte((T[3] shr 19) or (T[4] shl 6));
  S[13] := Byte(T[4] shr 2);
  S[14] := Byte(T[4] shr 10);
  S[15] := Byte(T[4] shr 18);
  S[16] := Byte(T[5]);
  S[17] := Byte(T[5] shr 8);
  S[18] := Byte(T[5] shr 16);
  S[19] := Byte((T[5] shr 24) or (T[6] shl 1));
  S[20] := Byte(T[6] shr 7);
  S[21] := Byte(T[6] shr 15);
  S[22] := Byte((T[6] shr 23) or (T[7] shl 3));
  S[23] := Byte(T[7] shr 5);
  S[24] := Byte(T[7] shr 13);
  S[25] := Byte((T[7] shr 21) or (T[8] shl 4));
  S[26] := Byte(T[8] shr 4);
  S[27] := Byte(T[8] shr 12);
  S[28] := Byte((T[8] shr 20) or (T[9] shl 6));
  S[29] := Byte(T[9] shr 2);
  S[30] := Byte(T[9] shr 10);
  S[31] := Byte(T[9] shr 18);
end;

procedure FeAdd(out H: TFe25519; const F, G: TFe25519);
var I: Integer;
begin
  for I := 0 to 9 do H[I] := F[I] + G[I];
end;

procedure FeSub(out H: TFe25519; const F, G: TFe25519);
var I: Integer;
begin
  for I := 0 to 9 do H[I] := F[I] - G[I];
end;

procedure FeNeg(out H: TFe25519; const F: TFe25519);
var I: Integer;
begin
  for I := 0 to 9 do H[I] := -F[I];
end;

{$IFDEF CPUX86_64}
{$ASMMODE ATT}
procedure FeMul(out H: TFe25519; constref F, G: TFe25519); assembler; nostackframe;
// rdi=@H, rsi=@F, rdx=@G — handles aliasing (H may equal F or G)
// Stack layout: [rsp+0..79]=g_19[0..8], [rsp+80..159]=H_temp[0..9]
asm
  push %rbx; push %r12; push %r13; push %r14; push %r15; push %rbp
  movq %rdi, %r15; movq %rdx, %rbp
  sub $160, %rsp
  // Precompute g[i]*19
  movq 8(%rbp),%rax; imulq $19,%rax,%rax; movq %rax,0(%rsp)
  movq 16(%rbp),%rax; imulq $19,%rax,%rax; movq %rax,8(%rsp)
  movq 24(%rbp),%rax; imulq $19,%rax,%rax; movq %rax,16(%rsp)
  movq 32(%rbp),%rax; imulq $19,%rax,%rax; movq %rax,24(%rsp)
  movq 40(%rbp),%rax; imulq $19,%rax,%rax; movq %rax,32(%rsp)
  movq 48(%rbp),%rax; imulq $19,%rax,%rax; movq %rax,40(%rsp)
  movq 56(%rbp),%rax; imulq $19,%rax,%rax; movq %rax,48(%rsp)
  movq 64(%rbp),%rax; imulq $19,%rax,%rax; movq %rax,56(%rsp)
  movq 72(%rbp),%rax; imulq $19,%rax,%rax; movq %rax,64(%rsp)
  // H[0]
  movq 0(%rsi),%rax; imulq 0(%rbp),%rax; movq %rax,%r8
  movq 8(%rsi),%rax; addq %rax,%rax; imulq 64(%rsp),%rax; addq %rax,%r8
  movq 16(%rsi),%rax; imulq 56(%rsp),%rax; addq %rax,%r8
  movq 24(%rsi),%rax; addq %rax,%rax; imulq 48(%rsp),%rax; addq %rax,%r8
  movq 32(%rsi),%rax; imulq 40(%rsp),%rax; addq %rax,%r8
  movq 40(%rsi),%rax; addq %rax,%rax; imulq 32(%rsp),%rax; addq %rax,%r8
  movq 48(%rsi),%rax; imulq 24(%rsp),%rax; addq %rax,%r8
  movq 56(%rsi),%rax; addq %rax,%rax; imulq 16(%rsp),%rax; addq %rax,%r8
  movq 64(%rsi),%rax; imulq 8(%rsp),%rax; addq %rax,%r8
  movq 72(%rsi),%rax; addq %rax,%rax; imulq 0(%rsp),%rax; addq %rax,%r8
  movq %r8, 80(%rsp)
  // H[1]
  movq 0(%rsi),%rax; imulq 8(%rbp),%rax; movq %rax,%r8
  movq 8(%rsi),%rax; imulq 0(%rbp),%rax; addq %rax,%r8
  movq 16(%rsi),%rax; imulq 64(%rsp),%rax; addq %rax,%r8
  movq 24(%rsi),%rax; imulq 56(%rsp),%rax; addq %rax,%r8
  movq 32(%rsi),%rax; imulq 48(%rsp),%rax; addq %rax,%r8
  movq 40(%rsi),%rax; imulq 40(%rsp),%rax; addq %rax,%r8
  movq 48(%rsi),%rax; imulq 32(%rsp),%rax; addq %rax,%r8
  movq 56(%rsi),%rax; imulq 24(%rsp),%rax; addq %rax,%r8
  movq 64(%rsi),%rax; imulq 16(%rsp),%rax; addq %rax,%r8
  movq 72(%rsi),%rax; imulq 8(%rsp),%rax; addq %rax,%r8
  movq %r8, 88(%rsp)
  // H[2]
  movq 0(%rsi),%rax; imulq 16(%rbp),%rax; movq %rax,%r8
  movq 8(%rsi),%rax; addq %rax,%rax; imulq 8(%rbp),%rax; addq %rax,%r8
  movq 16(%rsi),%rax; imulq 0(%rbp),%rax; addq %rax,%r8
  movq 24(%rsi),%rax; addq %rax,%rax; imulq 64(%rsp),%rax; addq %rax,%r8
  movq 32(%rsi),%rax; imulq 56(%rsp),%rax; addq %rax,%r8
  movq 40(%rsi),%rax; addq %rax,%rax; imulq 48(%rsp),%rax; addq %rax,%r8
  movq 48(%rsi),%rax; imulq 40(%rsp),%rax; addq %rax,%r8
  movq 56(%rsi),%rax; addq %rax,%rax; imulq 32(%rsp),%rax; addq %rax,%r8
  movq 64(%rsi),%rax; imulq 24(%rsp),%rax; addq %rax,%r8
  movq 72(%rsi),%rax; addq %rax,%rax; imulq 16(%rsp),%rax; addq %rax,%r8
  movq %r8, 96(%rsp)
  // H[3]
  movq 0(%rsi),%rax; imulq 24(%rbp),%rax; movq %rax,%r8
  movq 8(%rsi),%rax; imulq 16(%rbp),%rax; addq %rax,%r8
  movq 16(%rsi),%rax; imulq 8(%rbp),%rax; addq %rax,%r8
  movq 24(%rsi),%rax; imulq 0(%rbp),%rax; addq %rax,%r8
  movq 32(%rsi),%rax; imulq 64(%rsp),%rax; addq %rax,%r8
  movq 40(%rsi),%rax; imulq 56(%rsp),%rax; addq %rax,%r8
  movq 48(%rsi),%rax; imulq 48(%rsp),%rax; addq %rax,%r8
  movq 56(%rsi),%rax; imulq 40(%rsp),%rax; addq %rax,%r8
  movq 64(%rsi),%rax; imulq 32(%rsp),%rax; addq %rax,%r8
  movq 72(%rsi),%rax; imulq 24(%rsp),%rax; addq %rax,%r8
  movq %r8, 104(%rsp)
  // H[4]
  movq 0(%rsi),%rax; imulq 32(%rbp),%rax; movq %rax,%r8
  movq 8(%rsi),%rax; addq %rax,%rax; imulq 24(%rbp),%rax; addq %rax,%r8
  movq 16(%rsi),%rax; imulq 16(%rbp),%rax; addq %rax,%r8
  movq 24(%rsi),%rax; addq %rax,%rax; imulq 8(%rbp),%rax; addq %rax,%r8
  movq 32(%rsi),%rax; imulq 0(%rbp),%rax; addq %rax,%r8
  movq 40(%rsi),%rax; addq %rax,%rax; imulq 64(%rsp),%rax; addq %rax,%r8
  movq 48(%rsi),%rax; imulq 56(%rsp),%rax; addq %rax,%r8
  movq 56(%rsi),%rax; addq %rax,%rax; imulq 48(%rsp),%rax; addq %rax,%r8
  movq 64(%rsi),%rax; imulq 40(%rsp),%rax; addq %rax,%r8
  movq 72(%rsi),%rax; addq %rax,%rax; imulq 32(%rsp),%rax; addq %rax,%r8
  movq %r8, 112(%rsp)
  // H[5]
  movq 0(%rsi),%rax; imulq 40(%rbp),%rax; movq %rax,%r8
  movq 8(%rsi),%rax; imulq 32(%rbp),%rax; addq %rax,%r8
  movq 16(%rsi),%rax; imulq 24(%rbp),%rax; addq %rax,%r8
  movq 24(%rsi),%rax; imulq 16(%rbp),%rax; addq %rax,%r8
  movq 32(%rsi),%rax; imulq 8(%rbp),%rax; addq %rax,%r8
  movq 40(%rsi),%rax; imulq 0(%rbp),%rax; addq %rax,%r8
  movq 48(%rsi),%rax; imulq 64(%rsp),%rax; addq %rax,%r8
  movq 56(%rsi),%rax; imulq 56(%rsp),%rax; addq %rax,%r8
  movq 64(%rsi),%rax; imulq 48(%rsp),%rax; addq %rax,%r8
  movq 72(%rsi),%rax; imulq 40(%rsp),%rax; addq %rax,%r8
  movq %r8, 120(%rsp)
  // H[6]
  movq 0(%rsi),%rax; imulq 48(%rbp),%rax; movq %rax,%r8
  movq 8(%rsi),%rax; addq %rax,%rax; imulq 40(%rbp),%rax; addq %rax,%r8
  movq 16(%rsi),%rax; imulq 32(%rbp),%rax; addq %rax,%r8
  movq 24(%rsi),%rax; addq %rax,%rax; imulq 24(%rbp),%rax; addq %rax,%r8
  movq 32(%rsi),%rax; imulq 16(%rbp),%rax; addq %rax,%r8
  movq 40(%rsi),%rax; addq %rax,%rax; imulq 8(%rbp),%rax; addq %rax,%r8
  movq 48(%rsi),%rax; imulq 0(%rbp),%rax; addq %rax,%r8
  movq 56(%rsi),%rax; addq %rax,%rax; imulq 64(%rsp),%rax; addq %rax,%r8
  movq 64(%rsi),%rax; imulq 56(%rsp),%rax; addq %rax,%r8
  movq 72(%rsi),%rax; addq %rax,%rax; imulq 48(%rsp),%rax; addq %rax,%r8
  movq %r8, 128(%rsp)
  // H[7]
  movq 0(%rsi),%rax; imulq 56(%rbp),%rax; movq %rax,%r8
  movq 8(%rsi),%rax; imulq 48(%rbp),%rax; addq %rax,%r8
  movq 16(%rsi),%rax; imulq 40(%rbp),%rax; addq %rax,%r8
  movq 24(%rsi),%rax; imulq 32(%rbp),%rax; addq %rax,%r8
  movq 32(%rsi),%rax; imulq 24(%rbp),%rax; addq %rax,%r8
  movq 40(%rsi),%rax; imulq 16(%rbp),%rax; addq %rax,%r8
  movq 48(%rsi),%rax; imulq 8(%rbp),%rax; addq %rax,%r8
  movq 56(%rsi),%rax; imulq 0(%rbp),%rax; addq %rax,%r8
  movq 64(%rsi),%rax; imulq 64(%rsp),%rax; addq %rax,%r8
  movq 72(%rsi),%rax; imulq 56(%rsp),%rax; addq %rax,%r8
  movq %r8, 136(%rsp)
  // H[8]
  movq 0(%rsi),%rax; imulq 64(%rbp),%rax; movq %rax,%r8
  movq 8(%rsi),%rax; addq %rax,%rax; imulq 56(%rbp),%rax; addq %rax,%r8
  movq 16(%rsi),%rax; imulq 48(%rbp),%rax; addq %rax,%r8
  movq 24(%rsi),%rax; addq %rax,%rax; imulq 40(%rbp),%rax; addq %rax,%r8
  movq 32(%rsi),%rax; imulq 32(%rbp),%rax; addq %rax,%r8
  movq 40(%rsi),%rax; addq %rax,%rax; imulq 24(%rbp),%rax; addq %rax,%r8
  movq 48(%rsi),%rax; imulq 16(%rbp),%rax; addq %rax,%r8
  movq 56(%rsi),%rax; addq %rax,%rax; imulq 8(%rbp),%rax; addq %rax,%r8
  movq 64(%rsi),%rax; imulq 0(%rbp),%rax; addq %rax,%r8
  movq 72(%rsi),%rax; addq %rax,%rax; imulq 64(%rsp),%rax; addq %rax,%r8
  movq %r8, 144(%rsp)
  // H[9]
  movq 0(%rsi),%rax; imulq 72(%rbp),%rax; movq %rax,%r8
  movq 8(%rsi),%rax; imulq 64(%rbp),%rax; addq %rax,%r8
  movq 16(%rsi),%rax; imulq 56(%rbp),%rax; addq %rax,%r8
  movq 24(%rsi),%rax; imulq 48(%rbp),%rax; addq %rax,%r8
  movq 32(%rsi),%rax; imulq 40(%rbp),%rax; addq %rax,%r8
  movq 40(%rsi),%rax; imulq 32(%rbp),%rax; addq %rax,%r8
  movq 48(%rsi),%rax; imulq 24(%rbp),%rax; addq %rax,%r8
  movq 56(%rsi),%rax; imulq 16(%rbp),%rax; addq %rax,%r8
  movq 64(%rsi),%rax; imulq 8(%rbp),%rax; addq %rax,%r8
  movq 72(%rsi),%rax; imulq 0(%rbp),%rax; addq %rax,%r8
  movq %r8, 152(%rsp)
  // Carry chain (from H_temp on stack)
  movq 80(%rsp),%r8; movq 88(%rsp),%r9; movq 96(%rsp),%r10; movq 104(%rsp),%r11
  movq 112(%rsp),%r12; movq 120(%rsp),%r13; movq 128(%rsp),%r14
  movq 136(%rsp),%rbx; movq 144(%rsp),%rcx; movq 152(%rsp),%rdi
  movq %r8,%rax; addq $33554432,%rax; sarq $26,%rax; addq %rax,%r9; shlq $26,%rax; subq %rax,%r8
  movq %r12,%rax; addq $33554432,%rax; sarq $26,%rax; addq %rax,%r13; shlq $26,%rax; subq %rax,%r12
  movq %r9,%rax; addq $16777216,%rax; sarq $25,%rax; addq %rax,%r10; shlq $25,%rax; subq %rax,%r9
  movq %r13,%rax; addq $16777216,%rax; sarq $25,%rax; addq %rax,%r14; shlq $25,%rax; subq %rax,%r13
  movq %r10,%rax; addq $33554432,%rax; sarq $26,%rax; addq %rax,%r11; shlq $26,%rax; subq %rax,%r10
  movq %r14,%rax; addq $33554432,%rax; sarq $26,%rax; addq %rax,%rbx; shlq $26,%rax; subq %rax,%r14
  movq %r11,%rax; addq $16777216,%rax; sarq $25,%rax; addq %rax,%r12; shlq $25,%rax; subq %rax,%r11
  movq %rbx,%rax; addq $16777216,%rax; sarq $25,%rax; addq %rax,%rcx; shlq $25,%rax; subq %rax,%rbx
  movq %r12,%rax; addq $33554432,%rax; sarq $26,%rax; addq %rax,%r13; shlq $26,%rax; subq %rax,%r12
  movq %rcx,%rax; addq $33554432,%rax; sarq $26,%rax; addq %rax,%rdi; shlq $26,%rax; subq %rax,%rcx
  movq %rdi,%rax; addq $16777216,%rax; sarq $25,%rax; imulq $19,%rax,%rdx; addq %rdx,%r8; shlq $25,%rax; subq %rax,%rdi
  movq %r8,%rax; addq $33554432,%rax; sarq $26,%rax; addq %rax,%r9; shlq $26,%rax; subq %rax,%r8
  // Store to output (safe now — all inputs consumed)
  movq %r8,0(%r15); movq %r9,8(%r15); movq %r10,16(%r15); movq %r11,24(%r15)
  movq %r12,32(%r15); movq %r13,40(%r15); movq %r14,48(%r15)
  movq %rbx,56(%r15); movq %rcx,64(%r15); movq %rdi,72(%r15)
  add $160,%rsp
  pop %rbp; pop %r15; pop %r14; pop %r13; pop %r12; pop %rbx
end;
{$ELSE}
procedure FeMul(out H: TFe25519; constref F, G: TFe25519);
  F1_2, F3_2, F5_2, F7_2, F9_2: Int64;
  G0, G1, G2, G3, G4, G5, G6, G7, G8, G9: Int64;
  G1_19, G2_19, G3_19, G4_19, G5_19, G6_19, G7_19, G8_19, G9_19: Int64;
  H0, H1, H2, H3, H4, H5, H6, H7, H8, H9: Int64;
  C: Int64;
begin
  F0 := F[0]; F1 := F[1]; F2 := F[2]; F3 := F[3]; F4 := F[4];
  F5 := F[5]; F6 := F[6]; F7 := F[7]; F8 := F[8]; F9 := F[9];
  F1_2 := 2*F1; F3_2 := 2*F3; F5_2 := 2*F5; F7_2 := 2*F7; F9_2 := 2*F9;
  G0 := G[0]; G1 := G[1]; G2 := G[2]; G3 := G[3]; G4 := G[4];
  G5 := G[5]; G6 := G[6]; G7 := G[7]; G8 := G[8]; G9 := G[9];
  G1_19 := 19*G1; G2_19 := 19*G2; G3_19 := 19*G3;
  G4_19 := 19*G4; G5_19 := 19*G5; G6_19 := 19*G6;
  G7_19 := 19*G7; G8_19 := 19*G8; G9_19 := 19*G9;

  H0 := F0*G0 + F1_2*G9_19 + F2*G8_19 + F3_2*G7_19 + F4*G6_19 +
        F5_2*G5_19 + F6*G4_19 + F7_2*G3_19 + F8*G2_19 + F9_2*G1_19;
  H1 := F0*G1 + F1*G0 + F2*G9_19 + F3*G8_19 + F4*G7_19 +
        F5*G6_19 + F6*G5_19 + F7*G4_19 + F8*G3_19 + F9*G2_19;
  H2 := F0*G2 + F1_2*G1 + F2*G0 + F3_2*G9_19 + F4*G8_19 +
        F5_2*G7_19 + F6*G6_19 + F7_2*G5_19 + F8*G4_19 + F9_2*G3_19;
  H3 := F0*G3 + F1*G2 + F2*G1 + F3*G0 + F4*G9_19 +
        F5*G8_19 + F6*G7_19 + F7*G6_19 + F8*G5_19 + F9*G4_19;
  H4 := F0*G4 + F1_2*G3 + F2*G2 + F3_2*G1 + F4*G0 +
        F5_2*G9_19 + F6*G8_19 + F7_2*G7_19 + F8*G6_19 + F9_2*G5_19;
  H5 := F0*G5 + F1*G4 + F2*G3 + F3*G2 + F4*G1 +
        F5*G0 + F6*G9_19 + F7*G8_19 + F8*G7_19 + F9*G6_19;
  H6 := F0*G6 + F1_2*G5 + F2*G4 + F3_2*G3 + F4*G2 +
        F5_2*G1 + F6*G0 + F7_2*G9_19 + F8*G8_19 + F9_2*G7_19;
  H7 := F0*G7 + F1*G6 + F2*G5 + F3*G4 + F4*G3 +
        F5*G2 + F6*G1 + F7*G0 + F8*G9_19 + F9*G8_19;
  H8 := F0*G8 + F1_2*G7 + F2*G6 + F3_2*G5 + F4*G4 +
        F5_2*G3 + F6*G2 + F7_2*G1 + F8*G0 + F9_2*G9_19;
  H9 := F0*G9 + F1*G8 + F2*G7 + F3*G6 + F4*G5 +
        F5*G4 + F6*G3 + F7*G2 + F8*G1 + F9*G0;

  C := Sar(H0 + (Int64(1) shl 25), 26); H1 := H1 + C; H0 := H0 - (C shl 26);
  C := Sar(H4 + (Int64(1) shl 25), 26); H5 := H5 + C; H4 := H4 - (C shl 26);
  C := Sar(H1 + (Int64(1) shl 24), 25); H2 := H2 + C; H1 := H1 - (C shl 25);
  C := Sar(H5 + (Int64(1) shl 24), 25); H6 := H6 + C; H5 := H5 - (C shl 25);
  C := Sar(H2 + (Int64(1) shl 25), 26); H3 := H3 + C; H2 := H2 - (C shl 26);
  C := Sar(H6 + (Int64(1) shl 25), 26); H7 := H7 + C; H6 := H6 - (C shl 26);
  C := Sar(H3 + (Int64(1) shl 24), 25); H4 := H4 + C; H3 := H3 - (C shl 25);
  C := Sar(H7 + (Int64(1) shl 24), 25); H8 := H8 + C; H7 := H7 - (C shl 25);
  C := Sar(H4 + (Int64(1) shl 25), 26); H5 := H5 + C; H4 := H4 - (C shl 26);
  C := Sar(H8 + (Int64(1) shl 25), 26); H9 := H9 + C; H8 := H8 - (C shl 26);
  C := Sar(H9 + (Int64(1) shl 24), 25); H0 := H0 + C * 19; H9 := H9 - (C shl 25);
  C := Sar(H0 + (Int64(1) shl 25), 26); H1 := H1 + C; H0 := H0 - (C shl 26);

  H[0] := H0; H[1] := H1; H[2] := H2; H[3] := H3; H[4] := H4;
  H[5] := H5; H[6] := H6; H[7] := H7; H[8] := H8; H[9] := H9;
end;
{$ENDIF}

{$IFDEF CPUX86_64}
{$I nextpas.core.crypto.field25519.fesq.x86_64.inc}
{$ENDIF}

procedure FeSq(out H: TFe25519; const F: TFe25519);
var
  F0, F1, F2, F3, F4, F5, F6, F7, F8, F9: Int64;
  F0_2, F1_2, F2_2, F3_2, F4_2, F5_2, F6_2, F7_2: Int64;
  F5_38, F6_19, F7_38, F8_19, F9_38: Int64;
  H0, H1, H2, H3, H4, H5, H6, H7, H8, H9: Int64;
  C: Int64;
begin
  {$IFDEF CPUX86_64}
  FeSqASM(H, F);
  Exit;
  {$ENDIF}
  F0 := F[0]; F1 := F[1]; F2 := F[2]; F3 := F[3]; F4 := F[4];
  F5 := F[5]; F6 := F[6]; F7 := F[7]; F8 := F[8]; F9 := F[9];
  F0_2 := 2*F0; F1_2 := 2*F1; F2_2 := 2*F2; F3_2 := 2*F3;
  F4_2 := 2*F4; F5_2 := 2*F5; F6_2 := 2*F6; F7_2 := 2*F7;
  F5_38 := 38*F5; F6_19 := 19*F6; F7_38 := 38*F7;
  F8_19 := 19*F8; F9_38 := 38*F9;

  H0 := F0*F0 + F1_2*F9_38 + F2_2*F8_19 + F3_2*F7_38 + F4_2*F6_19 + F5*F5_38;
  H1 := F0_2*F1 + F2*F9_38 + F3_2*F8_19 + F4*F7_38 + F5_2*F6_19;
  H2 := F0_2*F2 + F1_2*F1 + F3_2*F9_38 + F4_2*F8_19 + F5_2*F7_38 + F6*F6_19;
  H3 := F0_2*F3 + F1_2*F2 + F4*F9_38 + F5_2*F8_19 + F6*F7_38;
  H4 := F0_2*F4 + F1_2*F3_2 + F2*F2 + F5_2*F9_38 + F6_2*F8_19 + F7*F7_38;
  H5 := F0_2*F5 + F1_2*F4 + F2_2*F3 + F6*F9_38 + F7_2*F8_19;
  H6 := F0_2*F6 + F1_2*F5_2 + F2_2*F4 + F3_2*F3 + F7_2*F9_38 + F8*F8_19;
  H7 := F0_2*F7 + F1_2*F6 + F2_2*F5 + F3_2*F4 + F8*F9_38;
  H8 := F0_2*F8 + F1_2*F7_2 + F2_2*F6 + F3_2*F5_2 + F4*F4 + F9*F9_38;
  H9 := F0_2*F9 + F1_2*F8 + F2_2*F7 + F3_2*F6 + F4_2*F5;

  C := Sar(H0 + (Int64(1) shl 25), 26); H1 := H1 + C; H0 := H0 - (C shl 26);
  C := Sar(H4 + (Int64(1) shl 25), 26); H5 := H5 + C; H4 := H4 - (C shl 26);
  C := Sar(H1 + (Int64(1) shl 24), 25); H2 := H2 + C; H1 := H1 - (C shl 25);
  C := Sar(H5 + (Int64(1) shl 24), 25); H6 := H6 + C; H5 := H5 - (C shl 25);
  C := Sar(H2 + (Int64(1) shl 25), 26); H3 := H3 + C; H2 := H2 - (C shl 26);
  C := Sar(H6 + (Int64(1) shl 25), 26); H7 := H7 + C; H6 := H6 - (C shl 26);
  C := Sar(H3 + (Int64(1) shl 24), 25); H4 := H4 + C; H3 := H3 - (C shl 25);
  C := Sar(H7 + (Int64(1) shl 24), 25); H8 := H8 + C; H7 := H7 - (C shl 25);
  C := Sar(H4 + (Int64(1) shl 25), 26); H5 := H5 + C; H4 := H4 - (C shl 26);
  C := Sar(H8 + (Int64(1) shl 25), 26); H9 := H9 + C; H8 := H8 - (C shl 26);
  C := Sar(H9 + (Int64(1) shl 24), 25); H0 := H0 + C * 19; H9 := H9 - (C shl 25);
  C := Sar(H0 + (Int64(1) shl 25), 26); H1 := H1 + C; H0 := H0 - (C shl 26);

  H[0] := H0; H[1] := H1; H[2] := H2; H[3] := H3; H[4] := H4;
  H[5] := H5; H[6] := H6; H[7] := H7; H[8] := H8; H[9] := H9;
end;

procedure FeInvert(out O: TFe25519; const Z: TFe25519);
var
  T0, T1, T2, T3: TFe25519;
  I: Integer;
begin
  FeSq(T0, Z);
  FeSq(T1, T0); FeSq(T1, T1);
  FeMul(T1, Z, T1);
  FeMul(T0, T0, T1);
  FeSq(T2, T0);
  FeMul(T1, T1, T2);
  FeSq(T2, T1); for I := 1 to 4 do FeSq(T2, T2);
  FeMul(T1, T2, T1);
  FeSq(T2, T1); for I := 1 to 9 do FeSq(T2, T2);
  FeMul(T2, T2, T1);
  FeSq(T3, T2); for I := 1 to 19 do FeSq(T3, T3);
  FeMul(T2, T3, T2);
  FeSq(T2, T2); for I := 1 to 9 do FeSq(T2, T2);
  FeMul(T1, T2, T1);
  FeSq(T2, T1); for I := 1 to 49 do FeSq(T2, T2);
  FeMul(T2, T2, T1);
  FeSq(T3, T2); for I := 1 to 99 do FeSq(T3, T3);
  FeMul(T2, T3, T2);
  FeSq(T2, T2); for I := 1 to 49 do FeSq(T2, T2);
  FeMul(T1, T2, T1);
  FeSq(T1, T1); for I := 1 to 4 do FeSq(T1, T1);
  FeMul(O, T1, T0);
end;

procedure FePow2523(out O: TFe25519; const Z: TFe25519);
var
  T0, T1, T2: TFe25519;
  I: Integer;
begin
  FeSq(T0, Z);
  FeSq(T1, T0); FeSq(T1, T1);
  FeMul(T1, Z, T1);
  FeMul(T0, T0, T1);
  FeSq(T0, T0);
  FeMul(T0, T1, T0);
  FeSq(T1, T0); for I := 1 to 4 do FeSq(T1, T1);
  FeMul(T0, T1, T0);
  FeSq(T1, T0); for I := 1 to 9 do FeSq(T1, T1);
  FeMul(T1, T1, T0);
  FeSq(T2, T1); for I := 1 to 19 do FeSq(T2, T2);
  FeMul(T1, T2, T1);
  FeSq(T1, T1); for I := 1 to 9 do FeSq(T1, T1);
  FeMul(T0, T1, T0);
  FeSq(T1, T0); for I := 1 to 49 do FeSq(T1, T1);
  FeMul(T1, T1, T0);
  FeSq(T2, T1); for I := 1 to 99 do FeSq(T2, T2);
  FeMul(T1, T2, T1);
  FeSq(T1, T1); for I := 1 to 49 do FeSq(T1, T1);
  FeMul(T0, T1, T0);
  FeSq(T0, T0); FeSq(T0, T0);
  FeMul(O, T0, Z);
end;

function FeIsNegative(const F: TFe25519): Integer;
var S: TBytes;
begin
  FeToBytes(S, F);
  Result := Integer(S[0] and 1);
end;

function FeIsZero(const F: TFe25519): Boolean;
var
  S: TBytes;
  I: Integer;
  D: Byte;
begin
  FeToBytes(S, F);
  D := 0;
  for I := 0 to 31 do D := D or S[I];
  Result := (D = 0);
end;

procedure FeMul121666(out H: TFe25519; const F: TFe25519);
var
  H0, H1, H2, H3, H4, H5, H6, H7, H8, H9: Int64;
  C: Int64;
begin
  H0 := Int64(121666) * F[0];
  H1 := Int64(121666) * F[1];
  H2 := Int64(121666) * F[2];
  H3 := Int64(121666) * F[3];
  H4 := Int64(121666) * F[4];
  H5 := Int64(121666) * F[5];
  H6 := Int64(121666) * F[6];
  H7 := Int64(121666) * F[7];
  H8 := Int64(121666) * F[8];
  H9 := Int64(121666) * F[9];

  C := Sar(H9 + (Int64(1) shl 24), 25); H0 := H0 + C * 19; H9 := H9 - (C shl 25);
  C := Sar(H0 + (Int64(1) shl 25), 26); H1 := H1 + C; H0 := H0 - (C shl 26);
  C := Sar(H1 + (Int64(1) shl 24), 25); H2 := H2 + C; H1 := H1 - (C shl 25);
  C := Sar(H2 + (Int64(1) shl 25), 26); H3 := H3 + C; H2 := H2 - (C shl 26);
  C := Sar(H3 + (Int64(1) shl 24), 25); H4 := H4 + C; H3 := H3 - (C shl 25);
  C := Sar(H4 + (Int64(1) shl 25), 26); H5 := H5 + C; H4 := H4 - (C shl 26);
  C := Sar(H5 + (Int64(1) shl 24), 25); H6 := H6 + C; H5 := H5 - (C shl 25);
  C := Sar(H6 + (Int64(1) shl 25), 26); H7 := H7 + C; H6 := H6 - (C shl 26);
  C := Sar(H7 + (Int64(1) shl 24), 25); H8 := H8 + C; H7 := H7 - (C shl 25);
  C := Sar(H8 + (Int64(1) shl 25), 26); H9 := H9 + C; H8 := H8 - (C shl 26);

  H[0] := H0; H[1] := H1; H[2] := H2; H[3] := H3; H[4] := H4;
  H[5] := H5; H[6] := H6; H[7] := H7; H[8] := H8; H[9] := H9;
end;

procedure FeCopy(out H: TFe25519; const F: TFe25519);
var I: Integer;
begin
  for I := 0 to 9 do H[I] := F[I];
end;

procedure FeCSwap(var F, G: TFe25519; B: Int64);
var
  I: Integer;
  X: Int64;
  Mask: Int64;
begin
  Mask := -B;
  for I := 0 to 9 do
  begin
    X := Mask and (F[I] xor G[I]);
    F[I] := F[I] xor X;
    G[I] := G[I] xor X;
  end;
end;

end.
