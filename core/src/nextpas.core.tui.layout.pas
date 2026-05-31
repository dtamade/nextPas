unit nextpas.core.tui.layout;

{**
 * @desc 基于约束的一维切分（对齐 ratatui 布局语义，不用 cassowary）。
 *
 * 支持 Length / Min / Max / Percentage / Fill 五种约束，用确定性多遍算法
 * 求解。算法在测试集上匹配 ratatui 语义，但不泛化到混合 Min+Max 或 Ratio。
 *
 * 算法（total = Area.Width 或 Area.Height）：
 *   1. Length：每个 Length(L) 取恰好 L（钳到 [0, remaining]）。
 *   2. Percentage：取 floor(total * P / 100)（用原始 total，使百分比在
 *      兄弟 Length 增减时保持稳定）。
 *   3. Max：取至多 Value，不超过剩余。
 *   4. Min：剩余空间在 Min 槽间均分，每槽尽量 >= Min(N)（remaining 不足时
 *      回钳到剩余）。
 *   5. Fill：剩余按权重分配，残差给最后一个 Fill 槽。
 *   6. 残差吸收进最后一个非 Max 槽（reverse-priority）。
 *
 * 输出位置左到右（或上到下）分配，相邻 rect 共享边无间隙。
 *}

{$I nextpas.core.settings.inc}
{$packenum 1}

interface

uses
  nextpas.core.tui.base;

type
  TConstraintKind = (ckLength, ckMin, ckMax, ckPercentage, ckFill);

  TConstraint = packed record
    Kind: TConstraintKind;
    Value: Word;
    Value2: Word;   { ckFill: 权重；其余未用 }
  end;

  TConstraints = array of TConstraint;
  TRectArray = array of TRect;
  TIntArray = array of Integer;

  TLayout = record
    Direction: TDirection;
    Constraints: TConstraints;

    class function Default: TLayout; static;
    class function Horizontal(const ACs: array of TConstraint): TLayout; static;
    class function Vertical(const ACs: array of TConstraint): TLayout; static;

    function WithDirection(ADirection: TDirection): TLayout;
    function WithConstraints(const ACs: array of TConstraint): TLayout;
    function Split(const AArea: TRect): TRectArray;
  end;

function LengthConstraint(AN: Word): TConstraint; inline;
function MinConstraint(AN: Word): TConstraint; inline;
function MaxConstraint(AN: Word): TConstraint; inline;
function PercentageConstraint(AN: Word): TConstraint; inline;
function FillConstraint(AWeight: Word): TConstraint; inline;
function RatioConstraint(ANumerator, ADenominator: Word): TConstraint; inline;

{ 独立 helper：调用方无需先建 TLayout 即可切分 rect。 }
function HorizontalSplit(const AArea: TRect; const ACs: array of TConstraint): TRectArray;
function VerticalSplit(const AArea: TRect; const ACs: array of TConstraint): TRectArray;

function ComputeSlotSizes(ATotal: Integer;
  const ACs: array of TConstraint): TIntArray;

implementation

function LengthConstraint(AN: Word): TConstraint;
begin
  Result.Kind := ckLength;
  Result.Value := AN;
  Result.Value2 := 0;
end;

function MinConstraint(AN: Word): TConstraint;
begin
  Result.Kind := ckMin;
  Result.Value := AN;
  Result.Value2 := 0;
end;

function MaxConstraint(AN: Word): TConstraint;
begin
  Result.Kind := ckMax;
  Result.Value := AN;
  Result.Value2 := 0;
end;

function PercentageConstraint(AN: Word): TConstraint;
begin
  Result.Kind := ckPercentage;
  Result.Value := AN;
  Result.Value2 := 0;
end;

function FillConstraint(AWeight: Word): TConstraint;
begin
  Result.Kind := ckFill;
  Result.Value := 0;
  Result.Value2 := AWeight;
  if AWeight = 0 then Result.Value2 := 1;
end;

function RatioConstraint(ANumerator, ADenominator: Word): TConstraint;
begin
  if ADenominator = 0 then ADenominator := 1;
  Result.Kind := ckPercentage;
  Result.Value := (ANumerator * 100) div ADenominator;
  Result.Value2 := 0;
end;

{ TLayout }

class function TLayout.Default: TLayout;
begin
  Result.Direction := dirVertical;
  Result.Constraints := nil;
end;

class function TLayout.Horizontal(const ACs: array of TConstraint): TLayout;
begin
  Result := Default;
  Result.Direction := dirHorizontal;
  Result := Result.WithConstraints(ACs);
end;

class function TLayout.Vertical(const ACs: array of TConstraint): TLayout;
begin
  Result := Default;
  Result.Direction := dirVertical;
  Result := Result.WithConstraints(ACs);
end;

function TLayout.WithDirection(ADirection: TDirection): TLayout;
begin
  Result := Self;
  Result.Direction := ADirection;
end;

function TLayout.WithConstraints(const ACs: array of TConstraint): TLayout;
var
  LI: Integer;
begin
  Result := Self;
  SetLength(Result.Constraints, System.Length(ACs));
  for LI := 0 to System.High(ACs) do
    Result.Constraints[LI] := ACs[LI];
end;

{ 沿选定轴计算槽尺寸。返回与 ACs 等长数组。ATotal 是可用范围
  （Area.Width 或 Area.Height）；算法见单元头。 }
function ComputeSlotSizes(ATotal: Integer;
  const ACs: array of TConstraint): TIntArray;
var
  LN, LI, LWant, LTake, LMinCount, LRemaining: Integer;
  LLastFlexIdx: Integer;
  LFillTotal, LFillWeight: Integer;
begin
  Result := nil;
  LN := System.Length(ACs);
  SetLength(Result, LN);
  if LN = 0 then Exit;

  LRemaining := ATotal;
  if LRemaining < 0 then LRemaining := 0;

  { Pass 1 — Length }
  for LI := 0 to LN - 1 do
    if ACs[LI].Kind = ckLength then
    begin
      LWant := ACs[LI].Value;
      if LWant > LRemaining then LWant := LRemaining;
      Result[LI] := LWant;
      Dec(LRemaining, LWant);
    end;

  { Pass 2 — Percentage of the original Total }
  for LI := 0 to LN - 1 do
    if ACs[LI].Kind = ckPercentage then
    begin
      LWant := (ATotal * ACs[LI].Value) div 100;
      if LWant > LRemaining then LWant := LRemaining;
      Result[LI] := LWant;
      Dec(LRemaining, LWant);
    end;

  { Pass 3 — Max：取至多 Value，不超过公平份额 }
  for LI := 0 to LN - 1 do
    if ACs[LI].Kind = ckMax then
    begin
      LWant := LRemaining;
      if LWant > Integer(ACs[LI].Value) then LWant := ACs[LI].Value;
      if LWant < 0 then LWant := 0;
      Result[LI] := LWant;
      Dec(LRemaining, LWant);
    end;

  { Pass 4 — Min：剩余在 Min 槽间分配 }
  LMinCount := 0;
  for LI := 0 to LN - 1 do
    if ACs[LI].Kind = ckMin then Inc(LMinCount);

  if LMinCount > 0 then
  begin
    if LRemaining < 0 then LRemaining := 0;
    for LI := 0 to LN - 1 do
      if ACs[LI].Kind = ckMin then
      begin
        if LMinCount > 1 then
          LTake := LRemaining div LMinCount
        else
          LTake := LRemaining;
        if LTake < ACs[LI].Value then LTake := ACs[LI].Value;
        if LTake > LRemaining then LTake := LRemaining;
        if LTake < 0 then LTake := 0;
        Result[LI] := LTake;
        Dec(LRemaining, LTake);
        Dec(LMinCount);
      end;
  end;

  { Pass 5 — Fill：剩余按权重分配 }
  LFillTotal := 0;
  for LI := 0 to LN - 1 do
    if ACs[LI].Kind = ckFill then
      Inc(LFillTotal, ACs[LI].Value2);

  if (LFillTotal > 0) and (LRemaining > 0) then
  begin
    for LI := 0 to LN - 1 do
      if ACs[LI].Kind = ckFill then
      begin
        LFillWeight := ACs[LI].Value2;
        LTake := (LRemaining * LFillWeight) div LFillTotal;
        Result[LI] := LTake;
      end;
    { 残差给最后一个 Fill 槽 }
    LWant := 0;
    for LI := 0 to LN - 1 do
      if ACs[LI].Kind = ckFill then Inc(LWant, Result[LI]);
    if LWant < LRemaining then
      for LI := LN - 1 downto 0 do
        if ACs[LI].Kind = ckFill then
        begin
          Inc(Result[LI], LRemaining - LWant);
          Break;
        end;
    LRemaining := 0;
  end;

  { Pass 6 — 残差吸收进最后一个非 Max 槽 }
  if LRemaining <> 0 then
  begin
    LLastFlexIdx := -1;
    for LI := LN - 1 downto 0 do
      if ACs[LI].Kind <> ckMax then
      begin
        LLastFlexIdx := LI;
        Break;
      end;
    if LLastFlexIdx >= 0 then
    begin
      if Result[LLastFlexIdx] + LRemaining < 0 then
        Result[LLastFlexIdx] := 0
      else
        Inc(Result[LLastFlexIdx], LRemaining);
    end;
  end;
end;

function TLayout.Split(const AArea: TRect): TRectArray;
var
  LSizes: TIntArray;
  LTotal, LI, LCursor: Integer;
begin
  Result := nil;
  if Direction = dirHorizontal then
    LTotal := AArea.Width
  else
    LTotal := AArea.Height;

  LSizes := ComputeSlotSizes(LTotal, Constraints);
  SetLength(Result, System.Length(LSizes));

  LCursor := 0;
  for LI := 0 to System.High(LSizes) do
  begin
    if Direction = dirHorizontal then
      Result[LI] := TRect.Make(AArea.X + LCursor, AArea.Y, LSizes[LI], AArea.Height)
    else
      Result[LI] := TRect.Make(AArea.X, AArea.Y + LCursor, AArea.Width, LSizes[LI]);
    Inc(LCursor, LSizes[LI]);
  end;
end;

function HorizontalSplit(const AArea: TRect; const ACs: array of TConstraint): TRectArray;
begin
  Result := TLayout.Horizontal(ACs).Split(AArea);
end;

function VerticalSplit(const AArea: TRect; const ACs: array of TConstraint): TRectArray;
begin
  Result := TLayout.Vertical(ACs).Split(AArea);
end;

end.
