// NEON AArch64 直联 — 热路径 AArch64 asm，其余 scalar（仍 inline，全平台可 bench）— Phase5
// x86_64 host 上仅走 scalar 分支，不触发 ICE；AArch64 上走 NEON，实现与 x86_64 SSE2 同语义
{$PUSH}{$Q-}{$R-}

// ——— F32x4 热路径 NEON ———
function InlineVecF32x4Add(const a, b: TVecF32x4): TVecF32x4; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecF32x4);
  asm
    ldr q0, [a]
    ldr q1, [b]
    fadd v0.4s, v0.4s, v1.4s
    str q0, [Result]
  end;
{$ELSE}
  Result.f[0]:=a.f[0]+b.f[0]; Result.f[1]:=a.f[1]+b.f[1]; Result.f[2]:=a.f[2]+b.f[2]; Result.f[3]:=a.f[3]+b.f[3];
{$ENDIF}
end;

function InlineVecF32x4Sub(const a, b: TVecF32x4): TVecF32x4; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecF32x4);
  asm
    ldr q0, [a]
    ldr q1, [b]
    fsub v0.4s, v0.4s, v1.4s
    str q0, [Result]
  end;
{$ELSE}
  Result.f[0]:=a.f[0]-b.f[0]; Result.f[1]:=a.f[1]-b.f[1]; Result.f[2]:=a.f[2]-b.f[2]; Result.f[3]:=a.f[3]-b.f[3];
{$ENDIF}
end;

function InlineVecF32x4Mul(const a, b: TVecF32x4): TVecF32x4; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecF32x4);
  asm
    ldr q0, [a]
    ldr q1, [b]
    fmul v0.4s, v0.4s, v1.4s
    str q0, [Result]
  end;
{$ELSE}
  Result.f[0]:=a.f[0]*b.f[0]; Result.f[1]:=a.f[1]*b.f[1]; Result.f[2]:=a.f[2]*b.f[2]; Result.f[3]:=a.f[3]*b.f[3];
{$ENDIF}
end;

function InlineVecF32x4Div(const a, b: TVecF32x4): TVecF32x4; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecF32x4);
  asm
    ldr q0, [a]
    ldr q1, [b]
    fdiv v0.4s, v0.4s, v1.4s
    str q0, [Result]
  end;
{$ELSE}
  Result.f[0]:=a.f[0]/b.f[0]; Result.f[1]:=a.f[1]/b.f[1]; Result.f[2]:=a.f[2]/b.f[2]; Result.f[3]:=a.f[3]/b.f[3];
{$ENDIF}
end;

function InlineVecF32x4Min(const a, b: TVecF32x4): TVecF32x4; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecF32x4);
  asm
    ldr q0, [a]
    ldr q1, [b]
    fmin v0.4s, v0.4s, v1.4s
    str q0, [Result]
  end;
{$ELSE}
  if a.f[0]<b.f[0] then Result.f[0]:=a.f[0] else Result.f[0]:=b.f[0];
  if a.f[1]<b.f[1] then Result.f[1]:=a.f[1] else Result.f[1]:=b.f[1];
  if a.f[2]<b.f[2] then Result.f[2]:=a.f[2] else Result.f[2]:=b.f[2];
  if a.f[3]<b.f[3] then Result.f[3]:=a.f[3] else Result.f[3]:=b.f[3];
{$ENDIF}
end;

function InlineVecF32x4Max(const a, b: TVecF32x4): TVecF32x4; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecF32x4);
  asm
    ldr q0, [a]
    ldr q1, [b]
    fmax v0.4s, v0.4s, v1.4s
    str q0, [Result]
  end;
{$ELSE}
  if a.f[0]>b.f[0] then Result.f[0]:=a.f[0] else Result.f[0]:=b.f[0];
  if a.f[1]>b.f[1] then Result.f[1]:=a.f[1] else Result.f[1]:=b.f[1];
  if a.f[2]>b.f[2] then Result.f[2]:=a.f[2] else Result.f[2]:=b.f[2];
  if a.f[3]>b.f[3] then Result.f[3]:=a.f[3] else Result.f[3]:=b.f[3];
{$ENDIF}
end;

function InlineVecF32x4Abs(const a: TVecF32x4): TVecF32x4; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecF32x4);
  asm
    ldr q0, [a]
    fabs v0.4s, v0.4s
    str q0, [Result]
  end;
{$ELSE}
  if a.f[0]<0 then Result.f[0]:=-a.f[0] else Result.f[0]:=a.f[0];
  if a.f[1]<0 then Result.f[1]:=-a.f[1] else Result.f[1]:=a.f[1];
  if a.f[2]<0 then Result.f[2]:=-a.f[2] else Result.f[2]:=a.f[2];
  if a.f[3]<0 then Result.f[3]:=-a.f[3] else Result.f[3]:=a.f[3];
{$ENDIF}
end;

function InlineVecF32x4Sqrt(const a: TVecF32x4): TVecF32x4; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecF32x4);
  asm
    ldr q0, [a]
    fsqrt v0.4s, v0.4s
    str q0, [Result]
  end;
{$ELSE}
  Result.f[0]:=Sqrt(a.f[0]); Result.f[1]:=Sqrt(a.f[1]); Result.f[2]:=Sqrt(a.f[2]); Result.f[3]:=Sqrt(a.f[3]);
{$ENDIF}
end;

function InlineVecF32x4Neg(const a: TVecF32x4): TVecF32x4; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecF32x4);
  asm
    ldr q0, [a]
    fneg v0.4s, v0.4s
    str q0, [Result]
  end;
{$ELSE}
  Result.f[0]:=-a.f[0]; Result.f[1]:=-a.f[1]; Result.f[2]:=-a.f[2]; Result.f[3]:=-a.f[3];
{$ENDIF}
end;

function InlineVecF32x4Load(p: PSingle): TVecF32x4; inline;
begin
  Move(p^, Result, SizeOf(Result));
end;
procedure InlineVecF32x4Store(p: PSingle; const a: TVecF32x4); inline;
begin
  Move(a, p^, SizeOf(a));
end;
function InlineVecF32x4Splat(v: Single): TVecF32x4; inline;
begin
  Result.f[0]:=v; Result.f[1]:=v; Result.f[2]:=v; Result.f[3]:=v;
end;
function InlineVecF32x4Zero: TVecF32x4; inline;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

function InlineVecF64x2Add(const a, b: TVecF64x2): TVecF64x2; inline;
begin
  Result.d[0]:=a.d[0]+b.d[0]; Result.d[1]:=a.d[1]+b.d[1];
end;
function InlineVecF64x2Sub(const a, b: TVecF64x2): TVecF64x2; inline;
begin
  Result.d[0]:=a.d[0]-b.d[0]; Result.d[1]:=a.d[1]-b.d[1];
end;
function InlineVecF64x2Mul(const a, b: TVecF64x2): TVecF64x2; inline;
begin
  Result.d[0]:=a.d[0]*b.d[0]; Result.d[1]:=a.d[1]*b.d[1];
end;
function InlineVecF64x2Div(const a, b: TVecF64x2): TVecF64x2; inline;
begin
  Result.d[0]:=a.d[0]/b.d[0]; Result.d[1]:=a.d[1]/b.d[1];
end;
function InlineVecF64x2Min(const a, b: TVecF64x2): TVecF64x2; inline;
begin
  if a.d[0]<b.d[0] then Result.d[0]:=a.d[0] else Result.d[0]:=b.d[0];
  if a.d[1]<b.d[1] then Result.d[1]:=a.d[1] else Result.d[1]:=b.d[1];
end;
function InlineVecF64x2Max(const a, b: TVecF64x2): TVecF64x2; inline;
begin
  if a.d[0]>b.d[0] then Result.d[0]:=a.d[0] else Result.d[0]:=b.d[0];
  if a.d[1]>b.d[1] then Result.d[1]:=a.d[1] else Result.d[1]:=b.d[1];
end;

function InlineVecI32x4Add(const a, b: TVecI32x4): TVecI32x4; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecI32x4);
  asm
    ldr q0, [a]
    ldr q1, [b]
    add v0.4s, v0.4s, v1.4s
    str q0, [Result]
  end;
{$ELSE}
  Result.i[0]:=a.i[0]+b.i[0]; Result.i[1]:=a.i[1]+b.i[1]; Result.i[2]:=a.i[2]+b.i[2]; Result.i[3]:=a.i[3]+b.i[3];
{$ENDIF}
end;
function InlineVecI32x4Sub(const a, b: TVecI32x4): TVecI32x4; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecI32x4);
  asm
    ldr q0, [a]
    ldr q1, [b]
    sub v0.4s, v0.4s, v1.4s
    str q0, [Result]
  end;
{$ELSE}
  Result.i[0]:=a.i[0]-b.i[0]; Result.i[1]:=a.i[1]-b.i[1]; Result.i[2]:=a.i[2]-b.i[2]; Result.i[3]:=a.i[3]-b.i[3];
{$ENDIF}
end;
function InlineVecI32x4Mul(const a, b: TVecI32x4): TVecI32x4; inline;
begin
  Result.i[0]:=a.i[0]*b.i[0]; Result.i[1]:=a.i[1]*b.i[1]; Result.i[2]:=a.i[2]*b.i[2]; Result.i[3]:=a.i[3]*b.i[3];
end;
function InlineVecI32x4And(const a, b: TVecI32x4): TVecI32x4; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecI32x4);
  asm
    ldr q0, [a]
    ldr q1, [b]
    and v0.16b, v0.16b, v1.16b
    str q0, [Result]
  end;
{$ELSE}
  Result.i[0]:=a.i[0] and b.i[0]; Result.i[1]:=a.i[1] and b.i[1]; Result.i[2]:=a.i[2] and b.i[2]; Result.i[3]:=a.i[3] and b.i[3];
{$ENDIF}
end;
function InlineVecI32x4Or(const a, b: TVecI32x4): TVecI32x4; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecI32x4);
  asm
    ldr q0, [a]
    ldr q1, [b]
    orr v0.16b, v0.16b, v1.16b
    str q0, [Result]
  end;
{$ELSE}
  Result.i[0]:=a.i[0] or b.i[0]; Result.i[1]:=a.i[1] or b.i[1]; Result.i[2]:=a.i[2] or b.i[2]; Result.i[3]:=a.i[3] or b.i[3];
{$ENDIF}
end;
function InlineVecI32x4Xor(const a, b: TVecI32x4): TVecI32x4; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecI32x4);
  asm
    ldr q0, [a]
    ldr q1, [b]
    eor v0.16b, v0.16b, v1.16b
    str q0, [Result]
  end;
{$ELSE}
  Result.i[0]:=a.i[0] xor b.i[0]; Result.i[1]:=a.i[1] xor b.i[1]; Result.i[2]:=a.i[2] xor b.i[2]; Result.i[3]:=a.i[3] xor b.i[3];
{$ENDIF}
end;
function InlineVecI32x4Min(const a, b: TVecI32x4): TVecI32x4; inline;
begin
  if a.i[0]<b.i[0] then Result.i[0]:=a.i[0] else Result.i[0]:=b.i[0];
  if a.i[1]<b.i[1] then Result.i[1]:=a.i[1] else Result.i[1]:=b.i[1];
  if a.i[2]<b.i[2] then Result.i[2]:=a.i[2] else Result.i[2]:=b.i[2];
  if a.i[3]<b.i[3] then Result.i[3]:=a.i[3] else Result.i[3]:=b.i[3];
end;
function InlineVecI32x4Max(const a, b: TVecI32x4): TVecI32x4; inline;
begin
  if a.i[0]>b.i[0] then Result.i[0]:=a.i[0] else Result.i[0]:=b.i[0];
  if a.i[1]>b.i[1] then Result.i[1]:=a.i[1] else Result.i[1]:=b.i[1];
  if a.i[2]>b.i[2] then Result.i[2]:=a.i[2] else Result.i[2]:=b.i[2];
  if a.i[3]>b.i[3] then Result.i[3]:=a.i[3] else Result.i[3]:=b.i[3];
end;
function InlineVecI32x4CmpEq(const a, b: TVecI32x4): TMask4; inline;
begin
  Result:=0;
  if a.i[0]=b.i[0] then Result:=Result or 1;
  if a.i[1]=b.i[1] then Result:=Result or 2;
  if a.i[2]=b.i[2] then Result:=Result or 4;
  if a.i[3]=b.i[3] then Result:=Result or 8;
end;

function InlineVecU8x16Add(const a, b: TVecU8x16): TVecU8x16; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecU8x16);
  asm
    ldr q0, [a]
    ldr q1, [b]
    add v0.16b, v0.16b, v1.16b
    str q0, [Result]
  end;
{$ELSE}
  Result.u[0]:=Byte(a.u[0]+b.u[0]); Result.u[1]:=Byte(a.u[1]+b.u[1]); Result.u[2]:=Byte(a.u[2]+b.u[2]); Result.u[3]:=Byte(a.u[3]+b.u[3]);
  Result.u[4]:=Byte(a.u[4]+b.u[4]); Result.u[5]:=Byte(a.u[5]+b.u[5]); Result.u[6]:=Byte(a.u[6]+b.u[6]); Result.u[7]:=Byte(a.u[7]+b.u[7]);
  Result.u[8]:=Byte(a.u[8]+b.u[8]); Result.u[9]:=Byte(a.u[9]+b.u[9]); Result.u[10]:=Byte(a.u[10]+b.u[10]); Result.u[11]:=Byte(a.u[11]+b.u[11]);
  Result.u[12]:=Byte(a.u[12]+b.u[12]); Result.u[13]:=Byte(a.u[13]+b.u[13]); Result.u[14]:=Byte(a.u[14]+b.u[14]); Result.u[15]:=Byte(a.u[15]+b.u[15]);
{$ENDIF}
end;
function InlineVecU8x16Sub(const a, b: TVecU8x16): TVecU8x16; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecU8x16);
  asm
    ldr q0, [a]
    ldr q1, [b]
    sub v0.16b, v0.16b, v1.16b
    str q0, [Result]
  end;
{$ELSE}
  Result.u[0]:=Byte(a.u[0]-b.u[0]); Result.u[1]:=Byte(a.u[1]-b.u[1]); Result.u[2]:=Byte(a.u[2]-b.u[2]); Result.u[3]:=Byte(a.u[3]-b.u[3]);
  Result.u[4]:=Byte(a.u[4]-b.u[4]); Result.u[5]:=Byte(a.u[5]-b.u[5]); Result.u[6]:=Byte(a.u[6]-b.u[6]); Result.u[7]:=Byte(a.u[7]-b.u[7]);
  Result.u[8]:=Byte(a.u[8]-b.u[8]); Result.u[9]:=Byte(a.u[9]-b.u[9]); Result.u[10]:=Byte(a.u[10]-b.u[10]); Result.u[11]:=Byte(a.u[11]-b.u[11]);
  Result.u[12]:=Byte(a.u[12]-b.u[12]); Result.u[13]:=Byte(a.u[13]-b.u[13]); Result.u[14]:=Byte(a.u[14]-b.u[14]); Result.u[15]:=Byte(a.u[15]-b.u[15]);
{$ENDIF}
end;
function InlineVecU8x16SatAdd(const a, b: TVecU8x16): TVecU8x16; inline;
var i, s: Integer;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecU8x16);
  asm
    ldr q0, [a]
    ldr q1, [b]
    uqadd v0.16b, v0.16b, v1.16b
    str q0, [Result]
  end;
{$ELSE}
  for i:=0 to 15 do begin s:=Integer(a.u[i])+Integer(b.u[i]); if s>255 then s:=255; Result.u[i]:=Byte(s); end;
{$ENDIF}
end;
function InlineVecU8x16SatSub(const a, b: TVecU8x16): TVecU8x16; inline;
var i, s: Integer;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecU8x16);
  asm
    ldr q0, [a]
    ldr q1, [b]
    uqsub v0.16b, v0.16b, v1.16b
    str q0, [Result]
  end;
{$ELSE}
  for i:=0 to 15 do begin s:=Integer(a.u[i])-Integer(b.u[i]); if s<0 then s:=0; Result.u[i]:=Byte(s); end;
{$ENDIF}
end;
function InlineVecU8x16And(const a, b: TVecU8x16): TVecU8x16; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecU8x16);
  asm
    ldr q0, [a]
    ldr q1, [b]
    and v0.16b, v0.16b, v1.16b
    str q0, [Result]
  end;
{$ELSE}
  Result.u[0]:=a.u[0] and b.u[0]; Result.u[1]:=a.u[1] and b.u[1]; Result.u[2]:=a.u[2] and b.u[2]; Result.u[3]:=a.u[3] and b.u[3];
  Result.u[4]:=a.u[4] and b.u[4]; Result.u[5]:=a.u[5] and b.u[5]; Result.u[6]:=a.u[6] and b.u[6]; Result.u[7]:=a.u[7] and b.u[7];
  Result.u[8]:=a.u[8] and b.u[8]; Result.u[9]:=a.u[9] and b.u[9]; Result.u[10]:=a.u[10] and b.u[10]; Result.u[11]:=a.u[11] and b.u[11];
  Result.u[12]:=a.u[12] and b.u[12]; Result.u[13]:=a.u[13] and b.u[13]; Result.u[14]:=a.u[14] and b.u[14]; Result.u[15]:=a.u[15] and b.u[15];
{$ENDIF}
end;
function InlineVecU8x16Or(const a, b: TVecU8x16): TVecU8x16; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecU8x16);
  asm
    ldr q0, [a]
    ldr q1, [b]
    orr v0.16b, v0.16b, v1.16b
    str q0, [Result]
  end;
{$ELSE}
  Result.u[0]:=a.u[0] or b.u[0]; Result.u[1]:=a.u[1] or b.u[1]; Result.u[2]:=a.u[2] or b.u[2]; Result.u[3]:=a.u[3] or b.u[3];
  Result.u[4]:=a.u[4] or b.u[4]; Result.u[5]:=a.u[5] or b.u[5]; Result.u[6]:=a.u[6] or b.u[6]; Result.u[7]:=a.u[7] or b.u[7];
  Result.u[8]:=a.u[8] or b.u[8]; Result.u[9]:=a.u[9] or b.u[9]; Result.u[10]:=a.u[10] or b.u[10]; Result.u[11]:=a.u[11] or b.u[11];
  Result.u[12]:=a.u[12] or b.u[12]; Result.u[13]:=a.u[13] or b.u[13]; Result.u[14]:=a.u[14] or b.u[14]; Result.u[15]:=a.u[15] or b.u[15];
{$ENDIF}
end;
function InlineVecU8x16Xor(const a, b: TVecU8x16): TVecU8x16; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecU8x16);
  asm
    ldr q0, [a]
    ldr q1, [b]
    eor v0.16b, v0.16b, v1.16b
    str q0, [Result]
  end;
{$ELSE}
  Result.u[0]:=a.u[0] xor b.u[0]; Result.u[1]:=a.u[1] xor b.u[1]; Result.u[2]:=a.u[2] xor b.u[2]; Result.u[3]:=a.u[3] xor b.u[3];
  Result.u[4]:=a.u[4] xor b.u[4]; Result.u[5]:=a.u[5] xor b.u[5]; Result.u[6]:=a.u[6] xor b.u[6]; Result.u[7]:=a.u[7] xor b.u[7];
  Result.u[8]:=a.u[8] xor b.u[8]; Result.u[9]:=a.u[9] xor b.u[9]; Result.u[10]:=a.u[10] xor b.u[10]; Result.u[11]:=a.u[11] xor b.u[11];
  Result.u[12]:=a.u[12] xor b.u[12]; Result.u[13]:=a.u[13] xor b.u[13]; Result.u[14]:=a.u[14] xor b.u[14]; Result.u[15]:=a.u[15] xor b.u[15];
{$ENDIF}
end;
function InlineVecU8x16Min(const a, b: TVecU8x16): TVecU8x16; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecU8x16);
  asm
    ldr q0, [a]
    ldr q1, [b]
    umin v0.16b, v0.16b, v1.16b
    str q0, [Result]
  end;
{$ELSE}
  if a.u[0]<b.u[0] then Result.u[0]:=a.u[0] else Result.u[0]:=b.u[0];
  if a.u[1]<b.u[1] then Result.u[1]:=a.u[1] else Result.u[1]:=b.u[1];
  if a.u[2]<b.u[2] then Result.u[2]:=a.u[2] else Result.u[2]:=b.u[2];
  if a.u[3]<b.u[3] then Result.u[3]:=a.u[3] else Result.u[3]:=b.u[3];
  if a.u[4]<b.u[4] then Result.u[4]:=a.u[4] else Result.u[4]:=b.u[4];
  if a.u[5]<b.u[5] then Result.u[5]:=a.u[5] else Result.u[5]:=b.u[5];
  if a.u[6]<b.u[6] then Result.u[6]:=a.u[6] else Result.u[6]:=b.u[6];
  if a.u[7]<b.u[7] then Result.u[7]:=a.u[7] else Result.u[7]:=b.u[7];
  if a.u[8]<b.u[8] then Result.u[8]:=a.u[8] else Result.u[8]:=b.u[8];
  if a.u[9]<b.u[9] then Result.u[9]:=a.u[9] else Result.u[9]:=b.u[9];
  if a.u[10]<b.u[10] then Result.u[10]:=a.u[10] else Result.u[10]:=b.u[10];
  if a.u[11]<b.u[11] then Result.u[11]:=a.u[11] else Result.u[11]:=b.u[11];
  if a.u[12]<b.u[12] then Result.u[12]:=a.u[12] else Result.u[12]:=b.u[12];
  if a.u[13]<b.u[13] then Result.u[13]:=a.u[13] else Result.u[13]:=b.u[13];
  if a.u[14]<b.u[14] then Result.u[14]:=a.u[14] else Result.u[14]:=b.u[14];
  if a.u[15]<b.u[15] then Result.u[15]:=a.u[15] else Result.u[15]:=b.u[15];
{$ENDIF}
end;
function InlineVecU8x16Max(const a, b: TVecU8x16): TVecU8x16; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecU8x16);
  asm
    ldr q0, [a]
    ldr q1, [b]
    umax v0.16b, v0.16b, v1.16b
    str q0, [Result]
  end;
{$ELSE}
  if a.u[0]>b.u[0] then Result.u[0]:=a.u[0] else Result.u[0]:=b.u[0];
  if a.u[1]>b.u[1] then Result.u[1]:=a.u[1] else Result.u[1]:=b.u[1];
  if a.u[2]>b.u[2] then Result.u[2]:=a.u[2] else Result.u[2]:=b.u[2];
  if a.u[3]>b.u[3] then Result.u[3]:=a.u[3] else Result.u[3]:=b.u[3];
  if a.u[4]>b.u[4] then Result.u[4]:=a.u[4] else Result.u[4]:=b.u[4];
  if a.u[5]>b.u[5] then Result.u[5]:=a.u[5] else Result.u[5]:=b.u[5];
  if a.u[6]>b.u[6] then Result.u[6]:=a.u[6] else Result.u[6]:=b.u[6];
  if a.u[7]>b.u[7] then Result.u[7]:=a.u[7] else Result.u[7]:=b.u[7];
  if a.u[8]>b.u[8] then Result.u[8]:=a.u[8] else Result.u[8]:=b.u[8];
  if a.u[9]>b.u[9] then Result.u[9]:=a.u[9] else Result.u[9]:=b.u[9];
  if a.u[10]>b.u[10] then Result.u[10]:=a.u[10] else Result.u[10]:=b.u[10];
  if a.u[11]>b.u[11] then Result.u[11]:=a.u[11] else Result.u[11]:=b.u[11];
  if a.u[12]>b.u[12] then Result.u[12]:=a.u[12] else Result.u[12]:=b.u[12];
  if a.u[13]>b.u[13] then Result.u[13]:=a.u[13] else Result.u[13]:=b.u[13];
  if a.u[14]>b.u[14] then Result.u[14]:=a.u[14] else Result.u[14]:=b.u[14];
  if a.u[15]>b.u[15] then Result.u[15]:=a.u[15] else Result.u[15]:=b.u[15];
{$ENDIF}
end;
function InlineVecU8x16CmpEq(const a, b: TVecU8x16): TMask16; inline;
begin
  Result:=0;
  if a.u[0]=b.u[0] then Result:=Result or 1;
  if a.u[1]=b.u[1] then Result:=Result or 2;
  if a.u[2]=b.u[2] then Result:=Result or 4;
  if a.u[3]=b.u[3] then Result:=Result or 8;
  if a.u[4]=b.u[4] then Result:=Result or 16;
  if a.u[5]=b.u[5] then Result:=Result or 32;
  if a.u[6]=b.u[6] then Result:=Result or 64;
  if a.u[7]=b.u[7] then Result:=Result or 128;
  if a.u[8]=b.u[8] then Result:=Result or 256;
  if a.u[9]=b.u[9] then Result:=Result or 512;
  if a.u[10]=b.u[10] then Result:=Result or 1024;
  if a.u[11]=b.u[11] then Result:=Result or 2048;
  if a.u[12]=b.u[12] then Result:=Result or 4096;
  if a.u[13]=b.u[13] then Result:=Result or 8192;
  if a.u[14]=b.u[14] then Result:=Result or 16384;
  if a.u[15]=b.u[15] then Result:=Result or 32768;
end;
function InlineVecU8x16Load(p: PByte): TVecU8x16; inline;
begin Move(p^, Result, SizeOf(Result)); end;
procedure InlineVecU8x16Store(p: PByte; const a: TVecU8x16); inline;
begin Move(a, p^, SizeOf(a)); end;
function InlineVecU8x16Splat(v: Byte): TVecU8x16; inline;
begin FillChar(Result, SizeOf(Result), v); end;

function InlineVecU16x8Add(const a, b: TVecU16x8): TVecU16x8; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecU16x8);
  asm
    ldr q0, [a]
    ldr q1, [b]
    add v0.8h, v0.8h, v1.8h
    str q0, [Result]
  end;
{$ELSE}
  Result.u[0]:=a.u[0]+b.u[0]; Result.u[1]:=a.u[1]+b.u[1]; Result.u[2]:=a.u[2]+b.u[2]; Result.u[3]:=a.u[3]+b.u[3];
  Result.u[4]:=a.u[4]+b.u[4]; Result.u[5]:=a.u[5]+b.u[5]; Result.u[6]:=a.u[6]+b.u[6]; Result.u[7]:=a.u[7]+b.u[7];
{$ENDIF}
end;
function InlineVecU16x8Min(const a, b: TVecU16x8): TVecU16x8; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecU16x8);
  asm
    ldr q0, [a]
    ldr q1, [b]
    umin v0.8h, v0.8h, v1.8h
    str q0, [Result]
  end;
{$ELSE}
  if a.u[0]<b.u[0] then Result.u[0]:=a.u[0] else Result.u[0]:=b.u[0];
  if a.u[1]<b.u[1] then Result.u[1]:=a.u[1] else Result.u[1]:=b.u[1];
  if a.u[2]<b.u[2] then Result.u[2]:=a.u[2] else Result.u[2]:=b.u[2];
  if a.u[3]<b.u[3] then Result.u[3]:=a.u[3] else Result.u[3]:=b.u[3];
  if a.u[4]<b.u[4] then Result.u[4]:=a.u[4] else Result.u[4]:=b.u[4];
  if a.u[5]<b.u[5] then Result.u[5]:=a.u[5] else Result.u[5]:=b.u[5];
  if a.u[6]<b.u[6] then Result.u[6]:=a.u[6] else Result.u[6]:=b.u[6];
  if a.u[7]<b.u[7] then Result.u[7]:=a.u[7] else Result.u[7]:=b.u[7];
{$ENDIF}
end;
function InlineVecU16x8Max(const a, b: TVecU16x8): TVecU16x8; inline;
begin
{$IFDEF CPUAARCH64}
  Result := Default(TVecU16x8);
  asm
    ldr q0, [a]
    ldr q1, [b]
    umax v0.8h, v0.8h, v1.8h
    str q0, [Result]
  end;
{$ELSE}
  if a.u[0]>b.u[0] then Result.u[0]:=a.u[0] else Result.u[0]:=b.u[0];
  if a.u[1]>b.u[1] then Result.u[1]:=a.u[1] else Result.u[1]:=b.u[1];
  if a.u[2]>b.u[2] then Result.u[2]:=a.u[2] else Result.u[2]:=b.u[2];
  if a.u[3]>b.u[3] then Result.u[3]:=a.u[3] else Result.u[3]:=b.u[3];
  if a.u[4]>b.u[4] then Result.u[4]:=a.u[4] else Result.u[4]:=b.u[4];
  if a.u[5]>b.u[5] then Result.u[5]:=a.u[5] else Result.u[5]:=b.u[5];
  if a.u[6]>b.u[6] then Result.u[6]:=a.u[6] else Result.u[6]:=b.u[6];
  if a.u[7]>b.u[7] then Result.u[7]:=a.u[7] else Result.u[7]:=b.u[7];
{$ENDIF}
end;

function InlineVecF32x8Add(const a, b: TVecF32x8): TVecF32x8; inline;
begin
  Result.lo:=InlineVecF32x4Add(a.lo,b.lo); Result.hi:=InlineVecF32x4Add(a.hi,b.hi);
end;
function InlineVecF32x8Mul(const a, b: TVecF32x8): TVecF32x8; inline;
begin
  Result.lo:=InlineVecF32x4Mul(a.lo,b.lo); Result.hi:=InlineVecF32x4Mul(a.hi,b.hi);
end;

{$POP}
