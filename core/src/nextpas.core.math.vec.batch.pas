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

implementation

uses
  nextpas.core.math.scalar;

{ BatchDot - TVec2f }
function BatchDot(const ALeft, ARight: array of TVec2f;
                  var AResults: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(ALeft);
  if LCount > Length(ARight) then
    LCount := Length(ARight);
  if LCount > Length(AResults) then
    LCount := Length(AResults);
  for i := 0 to LCount - 1 do
    AResults[i] := ALeft[i].Dot(ARight[i]);
  Result := LCount;
end;

{ BatchDot - TVec3f }
function BatchDot(const ALeft, ARight: array of TVec3f;
                  var AResults: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(ALeft);
  if LCount > Length(ARight) then
    LCount := Length(ARight);
  if LCount > Length(AResults) then
    LCount := Length(AResults);
  for i := 0 to LCount - 1 do
    AResults[i] := ALeft[i].Dot(ARight[i]);
  Result := LCount;
end;

{ BatchDot - TVec4f }
function BatchDot(const ALeft, ARight: array of TVec4f;
                  var AResults: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(ALeft);
  if LCount > Length(ARight) then
    LCount := Length(ARight);
  if LCount > Length(AResults) then
    LCount := Length(AResults);
  for i := 0 to LCount - 1 do
    AResults[i] := ALeft[i].Dot(ARight[i]);
  Result := LCount;
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
var
  i, LCount: SizeInt;
begin
  LCount := Length(AVectors);
  for i := 0 to LCount - 1 do
    AVectors[i] := AVectors[i].Normalize;
  Result := LCount;
end;

{ BatchNormalize - TVec4f 原地 }
function BatchNormalize(var AVectors: array of TVec4f): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AVectors);
  for i := 0 to LCount - 1 do
    AVectors[i] := AVectors[i].Normalize;
  Result := LCount;
end;

{ BatchNormalize - TVec3f 带输出 }
function BatchNormalize(const ASource: array of TVec3f;
                        var ADest: array of TVec3f): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(ASource);
  if LCount > Length(ADest) then
    LCount := Length(ADest);
  for i := 0 to LCount - 1 do
    ADest[i] := ASource[i].Normalize;
  Result := LCount;
end;

{ BatchTransform - TMat3f * TVec2f }
function BatchTransform(const AMatrix: TMat3f;
                        const ASource: array of TVec2f;
                        var ADest: array of TVec2f): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(ASource);
  if LCount > Length(ADest) then
    LCount := Length(ADest);
  for i := 0 to LCount - 1 do
    ADest[i] := (AMatrix * TVec3f.Create(ASource[i].X, ASource[i].Y, 1.0)).XY;
  Result := LCount;
end;

{ BatchTransform - TMat4f * TVec3f }
function BatchTransform(const AMatrix: TMat4f;
                        const ASource: array of TVec3f;
                        var ADest: array of TVec3f): SizeInt;
var
  i, LCount: SizeInt;
  LTemp: TVec4f;
begin
  LCount := Length(ASource);
  if LCount > Length(ADest) then
    LCount := Length(ADest);
  for i := 0 to LCount - 1 do
  begin
    LTemp := AMatrix * TVec4f.Create(ASource[i].X, ASource[i].Y, ASource[i].Z, 1.0);
    ADest[i] := TVec3f.Create(LTemp.X, LTemp.Y, LTemp.Z);
  end;
  Result := LCount;
end;

{ BatchLerp - TVec3f }
function BatchLerp(const AStart, AEnd: array of TVec3f;
                   const AT: Single;
                   var ADest: array of TVec3f): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AStart);
  if LCount > Length(AEnd) then
    LCount := Length(AEnd);
  if LCount > Length(ADest) then
    LCount := Length(ADest);
  for i := 0 to LCount - 1 do
    ADest[i] := AStart[i].Lerp(AEnd[i], AT);
  Result := LCount;
end;

{ BatchClamp - TVec3f }
function BatchClamp(const AVectors: array of TVec3f;
                    const AMin, AMax: TVec3f;
                    var ADest: array of TVec3f): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AVectors);
  if LCount > Length(ADest) then
    LCount := Length(ADest);
  for i := 0 to LCount - 1 do
    ADest[i] := AVectors[i].Clamp(AMin, AMax);
  Result := LCount;
end;

end.
