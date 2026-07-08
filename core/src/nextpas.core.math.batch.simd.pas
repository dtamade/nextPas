unit nextpas.core.math.batch.simd;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.simd;

// SIMD 优化的批量标量函数声明
function BatchSinSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
function BatchCosSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
function BatchSinCosSimdF32(const AInput: array of Single;
                            var ASinOutput, ACosOutput: array of Single): SizeInt;
function BatchExpSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
function BatchLnSimdF32(const AInput: array of Single;
                        var AOutput: array of Single): SizeInt;
function BatchLog2SimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
function BatchLog10SimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
function BatchSqrtSimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
function BatchAbsSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
function BatchNegSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
function BatchCeilSimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
function BatchFloorSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
function BatchRoundSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
function BatchTruncSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
function BatchLerpSimdF32(const AInput: array of Single;
                          AMin, AMax: Single;
                          var AOutput: array of Single): SizeInt;
function BatchClampSimdF32(const AInput: array of Single;
                           AMin, AMax: Single;
                           var AOutput: array of Single): SizeInt;
function BatchScaleOffsetSimdF32(const AInput: array of Single;
                                 AScale, AOffset: Single;
                                 var AOutput: array of Single): SizeInt;

implementation

uses
  nextpas.core.math.trig,
  nextpas.core.math.scalar;

// 临时占位实现 - 后续替换为真正的 SIMD 实现
function BatchSinSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Sin(AInput[i]);
  Result := LCount;
end;

function BatchCosSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Cos(AInput[i]);
  Result := LCount;
end;

function BatchSinCosSimdF32(const AInput: array of Single;
                            var ASinOutput, ACosOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(ASinOutput) then
    LCount := Length(ASinOutput);
  if LCount > Length(ACosOutput) then
    LCount := Length(ACosOutput);
  for i := 0 to LCount - 1 do
  begin
    ASinOutput[i] := Sin(AInput[i]);
    ACosOutput[i] := Cos(AInput[i]);
  end;
  Result := LCount;
end;

function BatchExpSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Exp(AInput[i]);
  Result := LCount;
end;

function BatchLnSimdF32(const AInput: array of Single;
                        var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Ln(AInput[i]);
  Result := LCount;
end;

function BatchLog2SimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Log2(AInput[i]);
  Result := LCount;
end;

function BatchLog10SimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Log10(AInput[i]);
  Result := LCount;
end;

function BatchSqrtSimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Sqrt(AInput[i]);
  Result := LCount;
end;

function BatchAbsSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Abs(AInput[i]);
  Result := LCount;
end;

function BatchNegSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := -AInput[i];
  Result := LCount;
end;

function BatchCeilSimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Single(Ceil(AInput[i]));
  Result := LCount;
end;

function BatchFloorSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Single(Floor(AInput[i]));
  Result := LCount;
end;

function BatchRoundSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Single(Round(AInput[i]));
  Result := LCount;
end;

function BatchTruncSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Single(Trunc(AInput[i]));
  Result := LCount;
end;

function BatchLerpSimdF32(const AInput: array of Single;
                          AMin, AMax: Single;
                          var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := AMin + (AMax - AMin) * AInput[i];
  Result := LCount;
end;

function BatchClampSimdF32(const AInput: array of Single;
                           AMin, AMax: Single;
                           var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
  begin
    if AInput[i] < AMin then
      AOutput[i] := AMin
    else if AInput[i] > AMax then
      AOutput[i] := AMax
    else
      AOutput[i] := AInput[i];
  end;
  Result := LCount;
end;

function BatchScaleOffsetSimdF32(const AInput: array of Single;
                                 AScale, AOffset: Single;
                                 var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := AInput[i] * AScale + AOffset;
  Result := LCount;
end;

end.
