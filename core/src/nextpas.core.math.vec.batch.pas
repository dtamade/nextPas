unit nextpas.core.math.vec.batch;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math.base,
  nextpas.core.math.vec,
  nextpas.core.math.mat;

{** * 计算两个向量数组的点积结果数组
 * @param ALeft 左操作数数组
 * @param ARight 右操作数数组
 * @param AResults 结果数组（调用方预分配）
 * @return 处理的元素数量
 *}
function BatchDot(const ALeft, ARight: array of TVec2f;
                  var AResults: array of Single): SizeInt; overload;
function BatchDot(const ALeft, ARight: array of TVec3f;
                  var AResults: array of Single): SizeInt; overload;
function BatchDot(const ALeft, ARight: array of TVec4f;
                  var AResults: array of Single): SizeInt; overload;

{** * 批量归一化向量数组（原地修改）
 * @param AVectors 输入/输出向量数组
 * @return 处理的元素数量
 *}
function BatchNormalize(var AVectors: array of TVec2f): SizeInt; overload;
function BatchNormalize(var AVectors: array of TVec3f): SizeInt; overload;
function BatchNormalize(var AVectors: array of TVec4f): SizeInt; overload;

{** * 批量归一化向量数组（带输出）
 * @param ASource 源向量数组
 * @param ADest 目标向量数组
 * @return 处理的元素数量
 *}
function BatchNormalize(const ASource: array of TVec3f;
                        var ADest: array of TVec3f): SizeInt; overload;

{** * 批量变换向量数组（矩阵 * 向量）
 * @param AMatrix 变换矩阵
 * @param ASource 源向量数组
 * @param ADest 目标向量数组
 * @return 处理的元素数量
 *}
function BatchTransform(const AMatrix: TMat3f;
                        const ASource: array of TVec2f;
                        var ADest: array of TVec2f): SizeInt; overload;

function BatchTransform(const AMatrix: TMat4f;
                        const ASource: array of TVec3f;
                        var ADest: array of TVec3f): SizeInt; overload;

{** * 批量线性插值
 * @param AStart 起始向量数组
 * @param AEnd 结束向量数组
 * @param AT 插值参数
 * @param ADest 目标数组
 * @return 处理的元素数量
 *}
function BatchLerp(const AStart, AEnd: array of TVec3f;
                   const AT: Single;
                   var ADest: array of TVec3f): SizeInt; overload;

{** * 批量约束向量到指定范围
 * @param AVectors 输入向量数组
 * @param AMin 最小值向量
 * @param AMax 最大值向量
 * @param ADest 目标数组
 * @return 处理的元素数量
 *}
function BatchClamp(const AVectors: array of TVec3f;
                    const AMin, AMax: TVec3f;
                    var ADest: array of TVec3f): SizeInt; overload;

{ Double (TVec*d) — minimal public parity with F32 core set.
  M-V1: value-type element loops via TVec*d methods (no private simd backend).
  Same length policy as scalar Batch: equal lengths required; empty → 0. }

function BatchDot(const ALeft, ARight: array of TVec2d;
                  var AResults: array of Double): SizeInt; overload;
function BatchDot(const ALeft, ARight: array of TVec3d;
                  var AResults: array of Double): SizeInt; overload;
function BatchDot(const ALeft, ARight: array of TVec4d;
                  var AResults: array of Double): SizeInt; overload;

function BatchNormalize(var AVectors: array of TVec2d): SizeInt; overload;
function BatchNormalize(var AVectors: array of TVec3d): SizeInt; overload;
function BatchNormalize(var AVectors: array of TVec4d): SizeInt; overload;
function BatchNormalize(const ASource: array of TVec3d;
                        var ADest: array of TVec3d): SizeInt; overload;

function BatchTransform(const AMatrix: TMat3d;
                        const ASource: array of TVec2d;
                        var ADest: array of TVec2d): SizeInt; overload;
function BatchTransform(const AMatrix: TMat4d;
                        const ASource: array of TVec3d;
                        var ADest: array of TVec3d): SizeInt; overload;

function BatchLerp(const AStart, AEnd: array of TVec3d;
                   const AT: Double;
                   var ADest: array of TVec3d): SizeInt; overload;

function BatchClamp(const AVectors: array of TVec3d;
                    const AMin, AMax: TVec3d;
                    var ADest: array of TVec3d): SizeInt; overload;

implementation

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.math.scalar,
  nextpas.core.math.vec.batch.simd;

{ Length policy (usability Wave-2): same as math.batch.simd ResolveEqualOrMin. }

function ResolveEqualOrMin(const A, B: SizeInt): SizeInt; inline;
begin
  if (A = 0) or (B = 0) then
    Exit(0);
  if A = B then
    Exit(A);
{$IFDEF NEXTPAS_MATH_BATCH_TRUNCATE_MIN}
  if A < B then
    Result := A
  else
    Result := B;
{$ELSE}
  raise EArgumentError.Create(
    'Batch: array lengths must match (got ' + IntToStr(Int64(A)) +
    ' vs ' + IntToStr(Int64(B)) + ')');
{$ENDIF}
end;

function ResolveEqualOrMin3(const A, B, C: SizeInt): SizeInt; inline;
begin
  Result := ResolveEqualOrMin(ResolveEqualOrMin(A, B), C);
end;

{ BatchDot - TVec2f }
function BatchDot(const ALeft, ARight: array of TVec2f;
                  var AResults: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := ResolveEqualOrMin3(Length(ALeft), Length(ARight), Length(AResults));
  for i := 0 to LCount - 1 do
    AResults[i] := ALeft[i].Dot(ARight[i]);
  Result := LCount;
end;

{ BatchDot - TVec3f }
function BatchDot(const ALeft, ARight: array of TVec3f;
                  var AResults: array of Single): SizeInt;
begin
  Result := BatchDotSimd3f(ALeft, ARight, AResults);
end;

{ BatchDot - TVec4f }
function BatchDot(const ALeft, ARight: array of TVec4f;
                  var AResults: array of Single): SizeInt;
begin
  Result := BatchDotSimd4f(ALeft, ARight, AResults);
end;

{ BatchNormalize - TVec2f 原地 }
function BatchNormalize(var AVectors: array of TVec2f): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AVectors);
  for i := 0 to LCount - 1 do
    AVectors[i] := AVectors[i].Normalize;
  Result := LCount;
end;

{ BatchNormalize - TVec3f 原地 }
function BatchNormalize(var AVectors: array of TVec3f): SizeInt;
begin
  Result := BatchNormalizeSimd3f(AVectors);
end;

{ BatchNormalize - TVec4f 原地 }
function BatchNormalize(var AVectors: array of TVec4f): SizeInt;
begin
  Result := BatchNormalizeSimd4f(AVectors);
end;

{ BatchNormalize - TVec3f 带输出 }
function BatchNormalize(const ASource: array of TVec3f;
                        var ADest: array of TVec3f): SizeInt;
begin
  Result := BatchNormalizeSimd3f(ASource, ADest);
end;

{ BatchTransform - TMat3f * TVec2f }
function BatchTransform(const AMatrix: TMat3f;
                        const ASource: array of TVec2f;
                        var ADest: array of TVec2f): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := ResolveEqualOrMin(Length(ASource), Length(ADest));
  for i := 0 to LCount - 1 do
    ADest[i] := (AMatrix * TVec3f.Create(ASource[i].X, ASource[i].Y, 1.0)).XY;
  Result := LCount;
end;

{ BatchTransform - TMat4f * TVec3f }
function BatchTransform(const AMatrix: TMat4f;
                        const ASource: array of TVec3f;
                        var ADest: array of TVec3f): SizeInt;
begin
  Result := BatchTransformSimd4f(AMatrix, ASource, ADest);
end;

{ BatchLerp - TVec3f }
function BatchLerp(const AStart, AEnd: array of TVec3f;
                   const AT: Single;
                   var ADest: array of TVec3f): SizeInt;
begin
  Result := BatchLerpSimd3f(AStart, AEnd, AT, ADest);
end;

{ BatchClamp - TVec3f }
function BatchClamp(const AVectors: array of TVec3f;
                    const AMin, AMax: TVec3f;
                    var ADest: array of TVec3f): SizeInt;
begin
  Result := BatchClampSimd3f(AVectors, AMin, AMax, ADest);
end;

{ ---------- Double minimal set (M-V1) ---------- }

function BatchDot(const ALeft, ARight: array of TVec2d;
                  var AResults: array of Double): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := ResolveEqualOrMin3(Length(ALeft), Length(ARight), Length(AResults));
  for i := 0 to LCount - 1 do
    AResults[i] := ALeft[i].Dot(ARight[i]);
  Result := LCount;
end;

function BatchDot(const ALeft, ARight: array of TVec3d;
                  var AResults: array of Double): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := ResolveEqualOrMin3(Length(ALeft), Length(ARight), Length(AResults));
  for i := 0 to LCount - 1 do
    AResults[i] := ALeft[i].Dot(ARight[i]);
  Result := LCount;
end;

function BatchDot(const ALeft, ARight: array of TVec4d;
                  var AResults: array of Double): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := ResolveEqualOrMin3(Length(ALeft), Length(ARight), Length(AResults));
  for i := 0 to LCount - 1 do
    AResults[i] := ALeft[i].Dot(ARight[i]);
  Result := LCount;
end;

function BatchNormalize(var AVectors: array of TVec2d): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AVectors);
  for i := 0 to LCount - 1 do
    AVectors[i] := AVectors[i].Normalize;
  Result := LCount;
end;

function BatchNormalize(var AVectors: array of TVec3d): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AVectors);
  for i := 0 to LCount - 1 do
    AVectors[i] := AVectors[i].Normalize;
  Result := LCount;
end;

function BatchNormalize(var AVectors: array of TVec4d): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AVectors);
  for i := 0 to LCount - 1 do
    AVectors[i] := AVectors[i].Normalize;
  Result := LCount;
end;

function BatchNormalize(const ASource: array of TVec3d;
                        var ADest: array of TVec3d): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := ResolveEqualOrMin(Length(ASource), Length(ADest));
  for i := 0 to LCount - 1 do
    ADest[i] := ASource[i].Normalize;
  Result := LCount;
end;

function BatchTransform(const AMatrix: TMat3d;
                        const ASource: array of TVec2d;
                        var ADest: array of TVec2d): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := ResolveEqualOrMin(Length(ASource), Length(ADest));
  for i := 0 to LCount - 1 do
    ADest[i] := (AMatrix * TVec3d.Create(ASource[i].X, ASource[i].Y, 1.0)).XY;
  Result := LCount;
end;

function BatchTransform(const AMatrix: TMat4d;
                        const ASource: array of TVec3d;
                        var ADest: array of TVec3d): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := ResolveEqualOrMin(Length(ASource), Length(ADest));
  for i := 0 to LCount - 1 do
    ADest[i] := AMatrix.MultPoint(ASource[i]);
  Result := LCount;
end;

function BatchLerp(const AStart, AEnd: array of TVec3d;
                   const AT: Double;
                   var ADest: array of TVec3d): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := ResolveEqualOrMin3(Length(AStart), Length(AEnd), Length(ADest));
  for i := 0 to LCount - 1 do
    ADest[i] := AStart[i].Lerp(AEnd[i], AT);
  Result := LCount;
end;

function BatchClamp(const AVectors: array of TVec3d;
                    const AMin, AMax: TVec3d;
                    var ADest: array of TVec3d): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := ResolveEqualOrMin(Length(AVectors), Length(ADest));
  for i := 0 to LCount - 1 do
    ADest[i] := AVectors[i].Clamp(AMin, AMax);
  Result := LCount;
end;

end.
