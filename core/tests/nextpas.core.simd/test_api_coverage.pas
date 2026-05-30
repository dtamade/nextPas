program test_api_coverage;
{$mode objfpc}{$H+}
{$Q-}{$R-}

uses
  SysUtils, Math,
  nextpas.core.simd.base,
  nextpas.core.simd;

var
  GPass, GFail: Integer;

procedure Check(cond: Boolean; const msg: string);
begin
  Inc(GPass);
  if not cond then
  begin
    WriteLn('FAIL: ', msg);
    Inc(GFail);
    Halt(1);
  end;
end;

procedure CheckFloat(actual, expected: Single; const msg: string; eps: Single = 1e-5);
begin
  Check(Abs(actual - expected) < eps,
    msg + Format(' (got %g, exp %g)', [actual, expected]));
end;

procedure CheckDouble(actual, expected: Double; const msg: string; eps: Double = 1e-9);
begin
  Check(Abs(actual - expected) < eps,
    msg + Format(' (got %g, exp %g)', [actual, expected]));
end;

// === Constructors (5) ===

procedure TestVecF32x4Make;
var v: TVecF32x4;
begin
  v := VecF32x4Make(1.0, 2.0, 3.0, 4.0);
  CheckFloat(v.f[0], 1.0, 'F32x4Make lane0');
  CheckFloat(v.f[1], 2.0, 'F32x4Make lane1');
  CheckFloat(v.f[2], 3.0, 'F32x4Make lane2');
  CheckFloat(v.f[3], 4.0, 'F32x4Make lane3');
  v := VecF32x4Make(0.0, 0.0, 0.0, 0.0);
  CheckFloat(v.f[0], 0.0, 'F32x4Make zeros');
  v := VecF32x4Make(-1.5, -2.5, -3.5, -4.5);
  CheckFloat(v.f[0], -1.5, 'F32x4Make neg0');
  CheckFloat(v.f[3], -4.5, 'F32x4Make neg3');
end;

procedure TestVecI32x4Make;
var v: TVecI32x4;
begin
  v := VecI32x4Make(10, 20, 30, 40);
  Check(v.i[0] = 10, 'I32x4Make lane0');
  Check(v.i[1] = 20, 'I32x4Make lane1');
  Check(v.i[2] = 30, 'I32x4Make lane2');
  Check(v.i[3] = 40, 'I32x4Make lane3');
  v := VecI32x4Make(0, -1, 2147483647, -2147483648);
  Check(v.i[0] = 0, 'I32x4Make zero');
  Check(v.i[1] = -1, 'I32x4Make neg1');
  Check(v.i[2] = 2147483647, 'I32x4Make MaxInt');
  Check(v.i[3] = -2147483648, 'I32x4Make MinInt');
end;

procedure TestVecF64x2Make;
var v: TVecF64x2;
begin
  v := VecF64x2Make(1.5, 2.5);
  CheckDouble(v.d[0], 1.5, 'F64x2Make lane0');
  CheckDouble(v.d[1], 2.5, 'F64x2Make lane1');
  v := VecF64x2Make(0.0, 0.0);
  CheckDouble(v.d[0], 0.0, 'F64x2Make zero0');
  v := VecF64x2Make(-100.25, 999.999);
  CheckDouble(v.d[0], -100.25, 'F64x2Make neg');
  CheckDouble(v.d[1], 999.999, 'F64x2Make large');
end;

procedure TestVecF32x8Make;
var v: TVecF32x8;
begin
  v := VecF32x8Make(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0);
  CheckFloat(v.f[0], 1.0, 'F32x8Make lane0');
  CheckFloat(v.f[3], 4.0, 'F32x8Make lane3');
  CheckFloat(v.f[7], 8.0, 'F32x8Make lane7');
  v := VecF32x8Make(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
  CheckFloat(v.f[4], 0.0, 'F32x8Make zero4');
end;

procedure TestVecF64x4Make;
var v: TVecF64x4;
begin
  v := VecF64x4Make(1.1, 2.2, 3.3, 4.4);
  CheckDouble(v.d[0], 1.1, 'F64x4Make lane0');
  CheckDouble(v.d[1], 2.2, 'F64x4Make lane1');
  CheckDouble(v.d[2], 3.3, 'F64x4Make lane2');
  CheckDouble(v.d[3], 4.4, 'F64x4Make lane3');
  v := VecF64x4Make(0.0, -0.0, 1e100, -1e100);
  CheckDouble(v.d[0], 0.0, 'F64x4Make zero');
  CheckDouble(v.d[2], 1e100, 'F64x4Make large');
end;

// === Integer Abs (4) ===

procedure TestVecI32x4Abs;
var a, r: TVecI32x4;
begin
  a := VecI32x4Make(-5, 3, -100, 0);
  r := VecI32x4Abs(a);
  Check(r.i[0] = 5, 'I32x4Abs neg->pos');
  Check(r.i[1] = 3, 'I32x4Abs pos unchanged');
  Check(r.i[2] = 100, 'I32x4Abs neg100');
  Check(r.i[3] = 0, 'I32x4Abs zero');
  a := VecI32x4Make(2147483647, -2147483647, 1, -1);
  r := VecI32x4Abs(a);
  Check(r.i[0] = 2147483647, 'I32x4Abs MaxInt');
  Check(r.i[1] = 2147483647, 'I32x4Abs -MaxInt');
  Check(r.i[3] = 1, 'I32x4Abs -1');
end;

procedure TestVecI32x8Abs;
var a, r: TVecI32x8;
    i: Integer;
begin
  for i := 0 to 7 do a.i[i] := -(i + 1);
  r := VecI32x8Abs(a);
  for i := 0 to 7 do
    Check(r.i[i] = i + 1, 'I32x8Abs lane' + IntToStr(i));
  for i := 0 to 7 do a.i[i] := 0;
  r := VecI32x8Abs(a);
  Check(r.i[0] = 0, 'I32x8Abs zeros');
end;

procedure TestVecI16x8Abs;
var a, r: TVecI16x8;
begin
  a.i[0] := -1; a.i[1] := 1; a.i[2] := -32767; a.i[3] := 32767;
  a.i[4] := 0; a.i[5] := -100; a.i[6] := 100; a.i[7] := -1;
  r := VecI16x8Abs(a);
  Check(r.i[0] = 1, 'I16x8Abs -1');
  Check(r.i[1] = 1, 'I16x8Abs +1');
  Check(r.i[2] = 32767, 'I16x8Abs -32767');
  Check(r.i[3] = 32767, 'I16x8Abs +32767');
  Check(r.i[4] = 0, 'I16x8Abs 0');
  Check(r.i[5] = 100, 'I16x8Abs -100');
end;

procedure TestVecI8x16Abs;
var a, r: TVecI8x16;
    i: Integer;
begin
  for i := 0 to 15 do a.i[i] := Int8(-(i + 1));
  r := VecI8x16Abs(a);
  for i := 0 to 15 do
    Check(r.i[i] = Int8(i + 1), 'I8x16Abs lane' + IntToStr(i));
  a.i[0] := 0; a.i[1] := 127; a.i[2] := -127;
  r := VecI8x16Abs(a);
  Check(r.i[0] = 0, 'I8x16Abs zero');
  Check(r.i[1] = 127, 'I8x16Abs +127');
  Check(r.i[2] = 127, 'I8x16Abs -127');
end;

// === Integer Splat/Zero/Load/Store (8) ===

procedure TestVecI32x4Splat;
var v: TVecI32x4;
begin
  v := VecI32x4Splat(42);
  Check(v.i[0] = 42, 'I32x4Splat 42 lane0');
  Check(v.i[1] = 42, 'I32x4Splat 42 lane1');
  Check(v.i[2] = 42, 'I32x4Splat 42 lane2');
  Check(v.i[3] = 42, 'I32x4Splat 42 lane3');
  v := VecI32x4Splat(0);
  Check(v.i[0] = 0, 'I32x4Splat 0');
  v := VecI32x4Splat(-1);
  Check(v.i[0] = -1, 'I32x4Splat -1');
  Check(v.i[3] = -1, 'I32x4Splat -1 lane3');
end;

procedure TestVecI32x4Zero;
var v: TVecI32x4;
begin
  v := VecI32x4Zero;
  Check(v.i[0] = 0, 'I32x4Zero lane0');
  Check(v.i[1] = 0, 'I32x4Zero lane1');
  Check(v.i[2] = 0, 'I32x4Zero lane2');
  Check(v.i[3] = 0, 'I32x4Zero lane3');
end;

procedure TestVecI32x4LoadStore;
var
  src: array[0..3] of Int32;
  dst: array[0..3] of Int32;
  v: TVecI32x4;
begin
  src[0] := 100; src[1] := 200; src[2] := 300; src[3] := 400;
  v := VecI32x4Load(@src[0]);
  Check(v.i[0] = 100, 'I32x4Load lane0');
  Check(v.i[1] = 200, 'I32x4Load lane1');
  Check(v.i[2] = 300, 'I32x4Load lane2');
  Check(v.i[3] = 400, 'I32x4Load lane3');
  FillChar(dst, SizeOf(dst), 0);
  VecI32x4Store(@dst[0], v);
  Check(dst[0] = 100, 'I32x4Store lane0');
  Check(dst[1] = 200, 'I32x4Store lane1');
  Check(dst[2] = 300, 'I32x4Store lane2');
  Check(dst[3] = 400, 'I32x4Store lane3');
  // boundary: zeros
  src[0] := 0; src[1] := 0; src[2] := 0; src[3] := 0;
  v := VecI32x4Load(@src[0]);
  Check(v.i[0] = 0, 'I32x4Load zeros');
end;

procedure TestVecI32x8Splat;
var v: TVecI32x8;
    i: Integer;
begin
  v := VecI32x8Splat(77);
  for i := 0 to 7 do
    Check(v.i[i] = 77, 'I32x8Splat 77 lane' + IntToStr(i));
  v := VecI32x8Splat(0);
  Check(v.i[0] = 0, 'I32x8Splat 0');
  v := VecI32x8Splat(-999);
  Check(v.i[7] = -999, 'I32x8Splat -999 lane7');
end;

procedure TestVecI32x8Zero;
var v: TVecI32x8;
    i: Integer;
begin
  v := VecI32x8Zero;
  for i := 0 to 7 do
    Check(v.i[i] = 0, 'I32x8Zero lane' + IntToStr(i));
end;

procedure TestVecI32x8LoadStore;
var
  src: array[0..7] of Int32;
  dst: array[0..7] of Int32;
  v: TVecI32x8;
  i: Integer;
begin
  for i := 0 to 7 do src[i] := (i + 1) * 10;
  v := VecI32x8Load(@src[0]);
  for i := 0 to 7 do
    Check(v.i[i] = (i + 1) * 10, 'I32x8Load lane' + IntToStr(i));
  FillChar(dst, SizeOf(dst), 0);
  VecI32x8Store(@dst[0], v);
  for i := 0 to 7 do
    Check(dst[i] = (i + 1) * 10, 'I32x8Store lane' + IntToStr(i));
end;

procedure TestClampReduce;
var a4, lo4, hi4, r4: TVecI32x4; a8, lo8, hi8, r8: TVecI32x8;
begin
  a4 := VecI32x4Make(-10, 5, 50, 100);
  lo4 := VecI32x4Splat(0); hi4 := VecI32x4Splat(20);
  r4 := VecI32x4Clamp(a4, lo4, hi4);
  Check(r4.i[0] = 0, 'Clamp[-10]'); Check(r4.i[1] = 5, 'Clamp[5]'); Check(r4.i[2] = 20, 'Clamp[50]');
  a4 := VecI32x4Make(1, 2, 3, 4);
  Check(VecI32x4ReduceAdd(a4) = 10, 'ReduceAdd'); Check(VecI32x4ReduceMin(a4) = 1, 'ReduceMin'); Check(VecI32x4ReduceMax(a4) = 4, 'ReduceMax');
  a8.i[0]:=1;a8.i[1]:=2;a8.i[2]:=3;a8.i[3]:=4;a8.i[4]:=5;a8.i[5]:=6;a8.i[6]:=7;a8.i[7]:=8;
  Check(VecI32x8ReduceAdd(a8)=36,'I32x8ReduceAdd'); Check(VecI32x8ReduceMin(a8)=1,'I32x8ReduceMin'); Check(VecI32x8ReduceMax(a8)=8,'I32x8ReduceMax');
  lo8:=VecI32x8Splat(3); hi8:=VecI32x8Splat(6); r8:=VecI32x8Clamp(a8,lo8,hi8);
  Check(r8.i[0]=3,'I32x8Clamp[1]'); Check(r8.i[7]=6,'I32x8Clamp[8]');
end;

procedure TestLerp;
var a,b,r: TVecF32x4; da,db,dr: TVecF64x4;
begin
  a:=VecF32x4Make(0,10,20,30); b:=VecF32x4Make(100,110,120,130);
  r:=VecF32x4Lerp(a,b,0.0); Check(Abs(r.f[0])<1e-5,'Lerp t=0');
  r:=VecF32x4Lerp(a,b,1.0); Check(Abs(r.f[0]-100)<1e-5,'Lerp t=1');
  r:=VecF32x4Lerp(a,b,0.5); Check(Abs(r.f[0]-50)<1e-4,'Lerp t=0.5');
  da:=VecF64x4Make(0,100,200,300); db:=VecF64x4Make(10,110,210,310);
  dr:=VecF64x4Lerp(da,db,0.5); Check(Abs(dr.d[0]-5.0)<1e-10,'F64Lerp');
end;

procedure TestCmpNe;
var a,b: TVecU32x4; m: TMask4;
begin
  a.u[0]:=1;a.u[1]:=2;a.u[2]:=3;a.u[3]:=4; b.u[0]:=1;b.u[1]:=99;b.u[2]:=3;b.u[3]:=99;
  m:=VecU32x4CmpNe(a,b); Check((m and 1)=0,'CmpNe eq'); Check((m and 2)<>0,'CmpNe ne');
end;

procedure TestArrayF64;
var src,src2,src3,dst: array[0..3] of Double;
begin
  src[0]:=0;src[1]:=Pi/2;src[2]:=Pi;src[3]:=1;
  ArraySinF64(@src[0],@dst[0],4); Check(Abs(dst[0])<1e-10,'Sin[0]'); Check(Abs(dst[1]-1.0)<1e-10,'Sin[pi/2]');
  ArrayCosF64(@src[0],@dst[0],4); Check(Abs(dst[0]-1.0)<1e-10,'Cos[0]');
  src[0]:=1;src[1]:=Exp(1.0);src[2]:=Exp(2.0);src[3]:=1;
  ArrayLogF64(@src[0],@dst[0],4); Check(Abs(dst[0])<1e-10,'Log[1]'); Check(Abs(dst[1]-1.0)<1e-10,'Log[e]');
  src[0]:=0;src[1]:=1;src[2]:=2;src[3]:=3;
  ArrayExpF64(@src[0],@dst[0],4); Check(Abs(dst[0]-1.0)<1e-10,'Exp[0]');
  src[0]:=1;src[1]:=2;src[2]:=3;src[3]:=4; src2[0]:=10;src2[1]:=20;src2[2]:=30;src2[3]:=40; src3[0]:=100;src3[1]:=200;src3[2]:=300;src3[3]:=400;
  ArrayFmaF64(@src[0],@src2[0],@src3[0],@dst[0],4); Check(Abs(dst[0]-110)<1e-10,'Fma');
  ArrayMinF64(@src[0],@src2[0],@dst[0],4); Check(dst[0]=1.0,'Min');
  ArrayMaxF64(@src[0],@src2[0],@dst[0],4); Check(dst[0]=10.0,'Max');
end;

procedure TestF32x8ExtMath;
var a,b,c,r: TVecF32x8; i: Integer;
begin
  a := VecF32x8Make(1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5);
  r := VecF32x8Floor(a);
  Check(r.f[0]=1.0,'F32x8Floor[0]'); Check(r.f[7]=8.0,'F32x8Floor[7]');
  r := VecF32x8Ceil(a);
  Check(r.f[0]=2.0,'F32x8Ceil[0]'); Check(r.f[7]=9.0,'F32x8Ceil[7]');
  r := VecF32x8Round(a);
  Check(r.f[0]=2.0,'F32x8Round[0]');
  r := VecF32x8Trunc(a);
  Check(r.f[0]=1.0,'F32x8Trunc[0]'); Check(r.f[7]=8.0,'F32x8Trunc[7]');
  a := VecF32x8Make(-5,0,5,10,15,20,25,30);
  b := VecF32x8Splat(0); c := VecF32x8Splat(20);
  r := VecF32x8Clamp(a, b, c);
  Check(r.f[0]=0,'F32x8Clamp[-5]'); Check(r.f[2]=5,'F32x8Clamp[5]'); Check(r.f[7]=20,'F32x8Clamp[30]');
  a := VecF32x8Make(1,2,3,4,5,6,7,8); b := VecF32x8Make(10,20,30,40,50,60,70,80); c := VecF32x8Make(100,200,300,400,500,600,700,800);
  r := VecF32x8Fma(a, b, c);
  Check(Abs(r.f[0]-110)<1e-4,'F32x8Fma[0]'); Check(Abs(r.f[7]-1440)<1e-1,'F32x8Fma[7]');
  r := VecF32x8Load(PSingle(@a.f[0]));
  Check(r.f[0]=1.0,'F32x8Load'); Check(r.f[7]=8.0,'F32x8Load[7]');
  r := VecF32x8Zero;
  for i:=0 to 7 do Check(r.f[i]=0,'F32x8Zero['+IntToStr(i)+']');
  r := VecF32x8Splat(3.14);
  for i:=0 to 7 do Check(Abs(r.f[i]-3.14)<1e-5,'F32x8Splat['+IntToStr(i)+']');
  a := VecF32x8Make(1,2,3,4,5,6,7,8);
  VecF32x8Store(PSingle(@b.f[0]), a);
  Check(b.f[0]=1.0,'F32x8Store[0]'); Check(b.f[7]=8.0,'F32x8Store[7]');
end;

procedure TestF64x4ExtMath;
var a,b,c,r: TVecF64x4; i: Integer;
begin
  a := VecF64x4Make(1.5, 2.5, 3.5, 4.5);
  r := VecF64x4Floor(a);
  Check(r.d[0]=1.0,'F64x4Floor[0]'); Check(r.d[3]=4.0,'F64x4Floor[3]');
  r := VecF64x4Ceil(a);
  Check(r.d[0]=2.0,'F64x4Ceil[0]'); Check(r.d[3]=5.0,'F64x4Ceil[3]');
  r := VecF64x4Round(a);
  Check(r.d[0]=2.0,'F64x4Round[0]');
  r := VecF64x4Trunc(a);
  Check(r.d[0]=1.0,'F64x4Trunc[0]'); Check(r.d[3]=4.0,'F64x4Trunc[3]');
  a := VecF64x4Make(-5,5,25,50); b := VecF64x4Make(0,0,0,0); c := VecF64x4Make(20,20,20,20);
  r := VecF64x4Clamp(a, b, c);
  Check(r.d[0]=0,'F64x4Clamp[-5]'); Check(r.d[1]=5,'F64x4Clamp[5]'); Check(r.d[3]=20,'F64x4Clamp[50]');
  a := VecF64x4Make(1,2,3,4); b := VecF64x4Make(10,20,30,40); c := VecF64x4Make(100,200,300,400);
  r := VecF64x4Fma(a, b, c);
  Check(Abs(r.d[0]-110)<1e-10,'F64x4Fma[0]'); Check(Abs(r.d[3]-560)<1e-10,'F64x4Fma[3]');
  r := VecF64x4Load(PDouble(@a.d[0]));
  Check(r.d[0]=1.0,'F64x4Load'); Check(r.d[3]=4.0,'F64x4Load[3]');
  r := VecF64x4Zero;
  for i:=0 to 3 do Check(r.d[i]=0,'F64x4Zero['+IntToStr(i)+']');
  r := VecF64x4Splat(2.718);
  for i:=0 to 3 do Check(Abs(r.d[i]-2.718)<1e-10,'F64x4Splat['+IntToStr(i)+']');
  a := VecF64x4Make(10,20,30,40);
  VecF64x4Store(PDouble(@b.d[0]), a);
  Check(b.d[0]=10,'F64x4Store[0]'); Check(b.d[3]=40,'F64x4Store[3]');
end;

procedure TestF64x2Clamp;
var a,lo,hi,r: TVecF64x2;
begin
  a := VecF64x2Make(-10, 50); lo := VecF64x2Make(0, 0); hi := VecF64x2Make(20, 20);
  r := VecF64x2Clamp(a, lo, hi);
  Check(r.d[0]=0,'F64x2Clamp[-10]'); Check(r.d[1]=20,'F64x2Clamp[50]');
end;

procedure TestNarrowCmpLeGeNe;
var a16,b16: TVecI16x8; au8,bu8: TVecU8x16; ai8,bi8: TVecI8x16; au16,bu16: TVecU16x8;
    m8: TMask8; m16: TMask16; i: Integer;
begin
  for i:=0 to 7 do begin a16.i[i]:=Int16(i); b16.i[i]:=Int16(4); end;
  m8 := VecI16x8CmpLe(a16, b16);
  Check((m8 and $1F)=$1F,'I16x8CmpLe 0..4<=4');
  Check((m8 and $20)=0,'I16x8CmpLe 5>4');
  m8 := VecI16x8CmpGe(a16, b16);
  Check((m8 and $10)<>0,'I16x8CmpGe 4>=4');
  Check((m8 and $01)=0,'I16x8CmpGe 0<4');
  m8 := VecI16x8CmpNe(a16, b16);
  Check((m8 and $10)=0,'I16x8CmpNe 4=4 → 0');
  Check((m8 and $01)<>0,'I16x8CmpNe 0<>4 → 1');

  for i:=0 to 15 do begin ai8.i[i]:=Int8(i); bi8.i[i]:=Int8(8); end;
  m16 := VecI8x16CmpLe(ai8, bi8);
  Check((m16 and $1FF)=$1FF,'I8x16CmpLe 0..8<=8');
  m16 := VecI8x16CmpGe(ai8, bi8);
  Check((m16 and $100)<>0,'I8x16CmpGe 8>=8');
  m16 := VecI8x16CmpNe(ai8, bi8);
  Check((m16 and $100)=0,'I8x16CmpNe 8=8');

  for i:=0 to 15 do begin au8.u[i]:=Byte(i); bu8.u[i]:=Byte(8); end;
  m16 := VecU8x16CmpLe(au8, bu8);
  Check((m16 and $1FF)=$1FF,'U8x16CmpLe 0..8<=8');
  m16 := VecU8x16CmpGe(au8, bu8);
  Check((m16 and $100)<>0,'U8x16CmpGe 8>=8');
  m16 := VecU8x16CmpNe(au8, bu8);
  Check((m16 and $100)=0,'U8x16CmpNe 8=8');

  for i:=0 to 7 do begin au16.u[i]:=Word(i); bu16.u[i]:=Word(4); end;
  m8 := VecU16x8CmpLe(au16, bu16);
  Check((m8 and $1F)=$1F,'U16x8CmpLe 0..4<=4');
  m8 := VecU16x8CmpGe(au16, bu16);
  Check((m8 and $10)<>0,'U16x8CmpGe 4>=4');
  m8 := VecU16x8CmpNe(au16, bu16);
  Check((m8 and $10)=0,'U16x8CmpNe 4=4');
end;

procedure TestBatchF64Extra;
var src,src2,dst: array[0..3] of Double;
    sf,sf2,sfd: array[0..3] of Single;
    dotResult: Double;
begin
  src[0]:=10; src[1]:=20; src[2]:=30; src[3]:=40;
  ArrayAddScalarF64(@src[0], @dst[0], 4, 5.0);
  Check(Abs(dst[0]-15)<1e-10,'AddScalarF64[0]'); Check(Abs(dst[3]-45)<1e-10,'AddScalarF64[3]');
  ArrayMulScalarF64(@src[0], @dst[0], 4, 2.0);
  Check(Abs(dst[0]-20)<1e-10,'MulScalarF64[0]'); Check(Abs(dst[3]-80)<1e-10,'MulScalarF64[3]');
  src[0]:=-5; src[1]:=5; src[2]:=15; src[3]:=25;
  ArrayClampF64(@src[0], @dst[0], 4, 0, 20);
  Check(Abs(dst[0])<1e-10,'ClampF64[-5→0]'); Check(Abs(dst[1]-5)<1e-10,'ClampF64[5]'); Check(Abs(dst[3]-20)<1e-10,'ClampF64[25→20]');
  src[0]:=1; src[1]:=2; src[2]:=3; src[3]:=4;
  src2[0]:=10; src2[1]:=20; src2[2]:=30; src2[3]:=40;
  dotResult := ReduceDotF64(@src[0], @src2[0], 4);
  Check(Abs(dotResult - 300)<1e-10,'ReduceDotF64=300');
  sf[0]:=10; sf[1]:=5; sf[2]:=3; sf[3]:=8;
  sf2[0]:=7; sf2[1]:=2; sf2[2]:=9; sf2[3]:=1;
  ArrayAbsDiffF32(@sf[0], @sf2[0], @sfd[0], 4);
  Check(Abs(sfd[0]-3)<1e-5,'AbsDiffF32[0]'); Check(Abs(sfd[2]-6)<1e-5,'AbsDiffF32[2]');
  sf[0]:=10; sf[1]:=20; sf[2]:=30; sf[3]:=40;
  ArrayNormF32(@sf[0], @sfd[0], 4, 25.0, 0.1);
  Check(Abs(sfd[0]-(-1.5))<1e-4,'NormF32[0]');
end;

begin
  GPass:=0; GFail:=0;
  WriteLn('=== API Coverage Test ===');
  TestVecF32x4Make; TestVecI32x4Make; TestVecF64x2Make; TestVecF32x8Make; TestVecF64x4Make;
  TestVecI32x4Abs; TestVecI32x8Abs; TestVecI16x8Abs; TestVecI8x16Abs;
  TestVecI32x4Splat; TestVecI32x4Zero; TestVecI32x4LoadStore;
  TestVecI32x8Splat; TestVecI32x8Zero; TestVecI32x8LoadStore;
  TestClampReduce; TestLerp; TestCmpNe; TestArrayF64;
  TestF32x8ExtMath; TestF64x4ExtMath; TestF64x2Clamp;
  TestNarrowCmpLeGeNe; TestBatchF64Extra;
  WriteLn(Format('--- %d tests passed, %d failed ---',[GPass,GFail]));
  if GFail=0 then WriteLn('ALL PASS');
end.
