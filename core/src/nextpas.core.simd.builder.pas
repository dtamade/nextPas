// Experimental: not part of stable surface.
unit nextpas.core.simd.builder;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}
{$CODEPAGE UTF8}

{
  === nextpas.core.simd.builder ===
  SIMD 向量 Builder 模式实现
  
  提供流式（Fluent）API，允许链式调用向量操作：
    TVecF32x4Builder.FromValues(1,2,3,4)
      .Add(other)
      .MulScalar(2.0)
      .Normalize
      .Build;
  
  对标 Rust portable-simd 的流式 API 设计风格
}

interface

uses
  nextpas.core.simd.base,
  nextpas.core.simd;

type
  { TVecF32x4Builder - TVecF32x4 的流式构建器 }
  TVecF32x4Builder = record
  private
    FValue: TVecF32x4;
  public
    // === 静态构造方法（起始点）===
    // 从 4 个独立值创建
    class function FromValues(v0, v1, v2, v3: Single): TVecF32x4Builder; static; inline;
    // 从单个值广播到所有通道
    class function Splat(value: Single): TVecF32x4Builder; static; inline;
    // 从内存加载
    class function Load(ptr: PSingle): TVecF32x4Builder; static; inline;
    // 从现有向量创建
    class function From(const v: TVecF32x4): TVecF32x4Builder; static; inline;
    // 零向量
    class function Zero: TVecF32x4Builder; static; inline;
    
    // === 算术操作（返回 Builder 以支持链式调用）===
    // 向量加法
    function Add(const other: TVecF32x4): TVecF32x4Builder; inline;
    // 向量减法
    function Sub(const other: TVecF32x4): TVecF32x4Builder; inline;
    // 向量乘法
    function Mul(const other: TVecF32x4): TVecF32x4Builder; inline;
    // 向量除法
    function Div_(const other: TVecF32x4): TVecF32x4Builder; inline;
    
    // 标量操作
    function AddScalar(s: Single): TVecF32x4Builder; inline;
    function SubScalar(s: Single): TVecF32x4Builder; inline;
    function MulScalar(s: Single): TVecF32x4Builder; inline;
    function DivScalar(s: Single): TVecF32x4Builder; inline;
    
    // === 数学操作 ===
    // 取绝对值
    function Abs_: TVecF32x4Builder; inline;
    // 取反
    function Neg: TVecF32x4Builder; inline;
    // 开方
    function Sqrt_: TVecF32x4Builder; inline;
    // 倒数
    function Rcp: TVecF32x4Builder; inline;
    // 倒数开方
    function Rsqrt: TVecF32x4Builder; inline;
    // 向下取整
    function Floor_: TVecF32x4Builder; inline;
    // 向上取整
    function Ceil_: TVecF32x4Builder; inline;
    // 四舍五入
    function Round_: TVecF32x4Builder; inline;
    // 截断
    function Trunc_: TVecF32x4Builder; inline;
    
    // === 向量操作 ===
    // 归一化
    function Normalize: TVecF32x4Builder; inline;
    // 夹紧到范围
    function Clamp(minVal, maxVal: Single): TVecF32x4Builder; inline;
    // 线性插值: self + (target - self) * t
    function Lerp(const target: TVecF32x4; t: Single): TVecF32x4Builder; inline;
    // 最小值
    function Min_(const other: TVecF32x4): TVecF32x4Builder; inline;
    // 最大值
    function Max_(const other: TVecF32x4): TVecF32x4Builder; inline;
    // FMA: self * a + b
    function Fma(const a, b: TVecF32x4): TVecF32x4Builder; inline;
    
    // === 终结操作（获取最终结果）===
    // 获取构建的向量
    function Build: TVecF32x4; inline;
    // 归约求和
    function ReduceAdd: Single; inline;
    // 归约最小值
    function ReduceMin: Single; inline;
    // 归约最大值
    function ReduceMax: Single; inline;
    // 点积
    function Dot(const other: TVecF32x4): Single; inline;
    // 获取长度
    function Length: Single; inline;
    // 获取长度平方
    function LengthSquared: Single; inline;
    
    // === 存储操作 ===
    // 存储到内存
    procedure StoreTo(ptr: PSingle); inline;
  end;

implementation

{ TVecF32x4Builder }

// === 静态构造方法 ===

class function TVecF32x4Builder.FromValues(v0, v1, v2, v3: Single): TVecF32x4Builder;
begin
  Result.FValue.f[0] := v0;
  Result.FValue.f[1] := v1;
  Result.FValue.f[2] := v2;
  Result.FValue.f[3] := v3;
end;

class function TVecF32x4Builder.Splat(value: Single): TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Splat(value);
end;

class function TVecF32x4Builder.Load(ptr: PSingle): TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Load(ptr);
end;

class function TVecF32x4Builder.From(const v: TVecF32x4): TVecF32x4Builder;
begin
  Result.FValue := v;
end;

class function TVecF32x4Builder.Zero: TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Splat(0.0);
end;

// === 算术操作 ===

function TVecF32x4Builder.Add(const other: TVecF32x4): TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Add(FValue, other);
end;

function TVecF32x4Builder.Sub(const other: TVecF32x4): TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Sub(FValue, other);
end;

function TVecF32x4Builder.Mul(const other: TVecF32x4): TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Mul(FValue, other);
end;

function TVecF32x4Builder.Div_(const other: TVecF32x4): TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Div(FValue, other);
end;

function TVecF32x4Builder.AddScalar(s: Single): TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Add(FValue, VecF32x4Splat(s));
end;

function TVecF32x4Builder.SubScalar(s: Single): TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Sub(FValue, VecF32x4Splat(s));
end;

function TVecF32x4Builder.MulScalar(s: Single): TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Mul(FValue, VecF32x4Splat(s));
end;

function TVecF32x4Builder.DivScalar(s: Single): TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Div(FValue, VecF32x4Splat(s));
end;

// === 数学操作 ===

function TVecF32x4Builder.Abs_: TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Abs(FValue);
end;

function TVecF32x4Builder.Neg: TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Sub(VecF32x4Splat(0.0), FValue);
end;

function TVecF32x4Builder.Sqrt_: TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Sqrt(FValue);
end;

function TVecF32x4Builder.Rcp: TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Rcp(FValue);
end;

function TVecF32x4Builder.Rsqrt: TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Rsqrt(FValue);
end;

function TVecF32x4Builder.Floor_: TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Floor(FValue);
end;

function TVecF32x4Builder.Ceil_: TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Ceil(FValue);
end;

function TVecF32x4Builder.Round_: TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Round(FValue);
end;

function TVecF32x4Builder.Trunc_: TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Trunc(FValue);
end;

// === 向量操作 ===

function TVecF32x4Builder.Normalize: TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Normalize(FValue);
end;

function TVecF32x4Builder.Clamp(minVal, maxVal: Single): TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Clamp(FValue, VecF32x4Splat(minVal), VecF32x4Splat(maxVal));
end;

function TVecF32x4Builder.Lerp(const target: TVecF32x4; t: Single): TVecF32x4Builder;
var
  diff: TVecF32x4;
begin
  // lerp = self + (target - self) * t
  diff := VecF32x4Sub(target, FValue);
  diff := VecF32x4Mul(diff, VecF32x4Splat(t));
  Result.FValue := VecF32x4Add(FValue, diff);
end;

function TVecF32x4Builder.Min_(const other: TVecF32x4): TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Min(FValue, other);
end;

function TVecF32x4Builder.Max_(const other: TVecF32x4): TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Max(FValue, other);
end;

function TVecF32x4Builder.Fma(const a, b: TVecF32x4): TVecF32x4Builder;
begin
  Result.FValue := VecF32x4Fma(FValue, a, b);
end;

// === 终结操作 ===

function TVecF32x4Builder.Build: TVecF32x4;
begin
  Result := FValue;
end;

function TVecF32x4Builder.ReduceAdd: Single;
begin
  Result := VecF32x4ReduceAdd(FValue);
end;

function TVecF32x4Builder.ReduceMin: Single;
begin
  Result := VecF32x4ReduceMin(FValue);
end;

function TVecF32x4Builder.ReduceMax: Single;
begin
  Result := VecF32x4ReduceMax(FValue);
end;

function TVecF32x4Builder.Dot(const other: TVecF32x4): Single;
begin
  Result := VecF32x4Dot(FValue, other);
end;

function TVecF32x4Builder.Length: Single;
begin
  Result := VecF32x4Length(FValue);
end;

function TVecF32x4Builder.LengthSquared: Single;
begin
  Result := VecF32x4Dot(FValue, FValue);
end;

// === 存储操作 ===

procedure TVecF32x4Builder.StoreTo(ptr: PSingle);
begin
  VecF32x4Store(ptr, FValue);
end;

end.
