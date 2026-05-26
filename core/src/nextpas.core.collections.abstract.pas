unit nextpas.core.collections.abstract;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.collections.base,
  nextpas.core.collections.intf;

type
  ICollection = nextpas.core.collections.intf.ICollection;

  TCollection = nextpas.core.collections.base.TCollection;
  TCollectionClass = nextpas.core.collections.base.TCollectionClass;

  IGrowthStrategy = nextpas.core.collections.intf.IGrowthStrategy;

  { TGrowthStrategy 增长策略基类 }
  TGrowthStrategy = class(TInterfacedObject, IGrowthStrategy)
  protected
    function DoGetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; virtual; abstract;
  public
    function GetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; virtual;
  end;

  TGrowthStrategyClass = class of TGrowthStrategy;

  { 增长策略回调 }
  TGrowFunc    = function (aCurrentSize, aRequiredSize: SizeUInt; aData: Pointer): SizeUInt;
  TGrowMethod  = function (aCurrentSize, aRequiredSize: SizeUInt): SizeUInt of object;
  {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
  TGrowRefFunc = reference to function (aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
  {$ENDIF}
  TGrowProxyMethod = function (aCurrentSize, aRequiredSize: SizeUInt): SizeUInt of object;

  { TCustomGrowthStrategy 自定义回调增长策略 }
  TCustomGrowthStrategy = class(TGrowthStrategy)
  private
    FData:        Pointer;
    FGrowFunc:    TGrowFunc;
    FGrowMethod:  TGrowMethod;
    FGrowRefFunc: TGrowRefFunc;
    FGrowProxy:   TGrowProxyMethod;
    function GetData: Pointer; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
  protected
    function DoGetGrowSizeFunc(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    function DoGetGrowSizeMethod(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function DoGetGrowSizeRefFunc(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    {$ENDIF}
    function DoGetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; override;
  public
    constructor Create(aGrowFunc: TGrowFunc; aData: Pointer);
    constructor Create(aGrowMethod: TGrowMethod; aData: Pointer);
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    constructor Create(aGrowRefFunc: TGrowRefFunc);
    {$ENDIF}

  strict protected
    property Data: Pointer read GetData;
  end;

  { TCalcGrowStrategy 计算增长策略(这是个抽象类,不能直接使用) }
  TCalcGrowStrategy = class(TGrowthStrategy)
  protected
    function DoCalc(aCurrentSize: SizeUInt): SizeUInt; virtual; abstract;
    function DoGetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; override;
  public
  end;

  { TDoublingGrowStrategy 指数增长 }
  TDoublingGrowStrategy = class(TCalcGrowStrategy)
  protected
    function DoCalc(aCurrentSize: SizeUInt): SizeUInt; override;
  private
    class var FGlobal: TDoublingGrowStrategy;
    class destructor Destroy;
  public
    class function GetGlobal: TDoublingGrowStrategy; static; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
  end;

  { TFixedGrowStrategy 固定线性增长 }
  TFixedGrowStrategy = class(TCalcGrowStrategy)
  private
    FFixedSize: SizeUInt;
    function GetFixedSize: SizeUInt; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
  protected
    function DoCalc(aCurrentSize: SizeUInt): SizeUInt; override;
  public
    constructor Create(aFixedSize: SizeUInt);

    property FixedSize: SizeUInt read GetFixedSize;
  end;

  { TFactorGrowStrategy 因子增长 }
  TFactorGrowStrategy = class(TCalcGrowStrategy)
  private
    FFactor: Single;
    function GetFactor: Single; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
  protected
    function DoCalc(aCurrentSize: SizeUInt): SizeUInt; override;
  public
    constructor Create(aFactor: Single);

    property Factor: Single read GetFactor;
  end;

  { TPowerOfTwoGrowStrategy 最近的2次幂增长 }
  TPowerOfTwoGrowStrategy = class(TGrowthStrategy)
  private
    class var FGlobal: TPowerOfTwoGrowStrategy;
    class destructor Destroy;
  protected
    function DoGetGrowSize({%H-}aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; override;
  public
    class function GetGlobal: TPowerOfTwoGrowStrategy; static; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
  end;

  { TGoldenRatioGrowStrategy 黄金比例增长 }
  TGoldenRatioGrowStrategy = class(TCalcGrowStrategy)
  protected
    function DoCalc(aCurrentSize: SizeUInt): SizeUInt; override;
  private
    class var FGlobal: TGoldenRatioGrowStrategy;
    class destructor Destroy;
  public
    class function GetGlobal: TGoldenRatioGrowStrategy; static; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
  end;

  { TAlignedWrapperStrategy 对齐包装增长策略 }
  TAlignedWrapperStrategy = class(TGrowthStrategy)
  private
    FGrowStrategy: IGrowthStrategy;
    FAlignSize: SizeUInt;

    function GetGrowStrategy: IGrowthStrategy;
    function GetAlignSize: SizeUInt;
  public
    const
      DEFAULT_ALIGN_SIZE = 64;
  public
    constructor Create(const aGrowStrategy: IGrowthStrategy; aAlignSize: SizeUInt);
    function DoGetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; override;

    property GrowStrategy: IGrowthStrategy read GetGrowStrategy;
    property AlignSize: SizeUInt read GetAlignSize;
  end;

  { TExactGrowStrategy 精确增长策略 }
  TExactGrowStrategy = class(TGrowthStrategy)
  private
    class var FGlobal: TExactGrowStrategy;
    class destructor Destroy;
  protected
    function DoGetGrowSize({%H-}aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; override;
  public
    class function GetGlobal: TExactGrowStrategy; static; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
  end;

function FixedGrow(aStep: SizeUInt): IGrowthStrategy;
function FactorGrow(aFactor: Double): IGrowthStrategy;
function DoublingGrow: IGrowthStrategy;
function ExactGrow: IGrowthStrategy;
function GoldenRatioGrow: IGrowthStrategy;

implementation

uses
  nextpas.core.base,
  nextpas.core.math;

function FixedGrow(aStep: SizeUInt): IGrowthStrategy;
begin
  Result := TFixedGrowStrategy.Create(aStep);
end;

function FactorGrow(aFactor: Double): IGrowthStrategy;
begin
  Result := TFactorGrowStrategy.Create(aFactor);
end;

function DoublingGrow: IGrowthStrategy;
begin
  Result := TDoublingGrowStrategy.Create;
end;

function ExactGrow: IGrowthStrategy;
begin
  Result := TExactGrowStrategy.Create;
end;

function GoldenRatioGrow: IGrowthStrategy;
begin
  Result := TGoldenRatioGrowStrategy.Create;
end;

{ 设计说明：
  - GetGrowSize 统一委派到具体策略 DoGetGrowSize，即便 aCurrentSize=0 也不在这里特判，
    让自定义策略可以在“首轮扩张”时生效自己的下界/策略。
  - 基类负责做最小下界收敛：Result >= aRequiredSize，保证调用方契约。
}

function TGrowthStrategy.GetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  if aRequiredSize <= aCurrentSize then
    Exit(aCurrentSize);

  Result := DoGetGrowSize(aCurrentSize, aRequiredSize);
  if Result < aRequiredSize then
    Result := aRequiredSize;
end;

function TCustomGrowthStrategy.GetData: Pointer;
begin
  Result := FData;
end;

function TCustomGrowthStrategy.DoGetGrowSizeFunc(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  Result := FGrowFunc(aCurrentSize, aRequiredSize, FData);
end;

function TCustomGrowthStrategy.DoGetGrowSizeMethod(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  Result := FGrowMethod(aCurrentSize, aRequiredSize);
end;

function TCustomGrowthStrategy.DoGetGrowSizeRefFunc(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  Result := FGrowRefFunc(aCurrentSize, aRequiredSize);
end;

function TCustomGrowthStrategy.DoGetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  Result := FGrowProxy(aCurrentSize, aRequiredSize);
end;

constructor TCustomGrowthStrategy.Create(aGrowFunc: TGrowFunc; aData: Pointer);
begin
  inherited Create;

  if aGrowFunc = nil then
    raise EArgumentNil.Create('TCustomGrowthStrategy.Create: aGrowFunc is nil');

  FGrowFunc  := aGrowFunc;
  FData      := aData;

  FGrowProxy := @DoGetGrowSizeFunc;
end;

constructor TCustomGrowthStrategy.Create(aGrowMethod: TGrowMethod; aData: Pointer);
begin
  inherited Create;

  if aGrowMethod = nil then
    raise EArgumentNil.Create('TCustomGrowthStrategy.Create: aGrowMethod is nil');

  FGrowMethod := aGrowMethod;
  FData       := aData;

  FGrowProxy  := @DoGetGrowSizeMethod;
end;

constructor TCustomGrowthStrategy.Create(aGrowRefFunc: TGrowRefFunc);
begin
  inherited Create;

  if aGrowRefFunc = nil then
    raise EArgumentNil.Create('TCustomGrowthStrategy.Create: aGrowRefFunc is nil');

  FGrowRefFunc := aGrowRefFunc;
  FData        := nil;

  FGrowProxy   := @DoGetGrowSizeRefFunc;
end;

function TCalcGrowStrategy.DoGetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  Result := aCurrentSize;

  while Result < aRequiredSize do
    Result := DoCalc(Result);
end;

function TDoublingGrowStrategy.DoCalc(aCurrentSize: SizeUInt): SizeUInt;
begin
  if aCurrentSize = 0 then
    Result := 1
  else
  begin
    if aCurrentSize > High(SizeUInt) div 2 then
      Result := High(SizeUInt)
    else
      Result := aCurrentSize * 2;
  end;
end;

class destructor TDoublingGrowStrategy.Destroy;
begin
  if FGlobal <> nil then
  begin
    FGlobal.Free;
    FGlobal := nil;
  end;
end;

class function TDoublingGrowStrategy.GetGlobal: TDoublingGrowStrategy;
begin
  Result := TDoublingGrowStrategy.Create;
end;

function TFixedGrowStrategy.GetFixedSize: SizeUInt;
begin
  Result := FFixedSize;
end;

function TFixedGrowStrategy.DoCalc(aCurrentSize: SizeUInt): SizeUInt;
begin
  Result := aCurrentSize + FFixedSize;
end;

constructor TFixedGrowStrategy.Create(aFixedSize: SizeUInt);
begin
  inherited Create;

  if aFixedSize = 0 then
    raise EInvalidArgument.Create('TFixedGrowStrategy.Create: aFixedSize is 0');

  FFixedSize := aFixedSize;
end;

function TFactorGrowStrategy.GetFactor: Single;
begin
  Result := FFactor;
end;

function TFactorGrowStrategy.DoCalc(aCurrentSize: SizeUInt): SizeUInt;
var
  LProduct: Single;
  LCeiled: Int64;
const
  MAX_SAFE_SIZEUINT = 9223372036854775807;
begin
  if aCurrentSize = 0 then
    Result := 1
  else
  begin
    LProduct := aCurrentSize * FFactor;
    if (LProduct > MAX_SAFE_SIZEUINT) or IsInfinite(LProduct) or IsNaN(LProduct) then
      Result := MAX_SAFE_SIZEUINT
    else
    begin
      LCeiled := Ceil(LProduct);
      Result := SizeUInt(LCeiled);
    end;
  end;
end;

constructor TFactorGrowStrategy.Create(aFactor: Single);
begin
  inherited Create;

  if aFactor <= 0 then
    raise EInvalidArgument.Create('TFactorGrowStrategy.Create: aFactor is 0');

  FFactor := aFactor;
end;

class destructor TPowerOfTwoGrowStrategy.Destroy;
begin
  if FGlobal <> nil then
  begin
    FGlobal.Free;
    FGlobal := nil;
  end;
end;

class function TPowerOfTwoGrowStrategy.GetGlobal: TPowerOfTwoGrowStrategy;
begin
  Result := TPowerOfTwoGrowStrategy.Create;
end;

function TPowerOfTwoGrowStrategy.DoGetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  if aCurrentSize <> 0 then;
  if aRequiredSize = 0 then
    Exit(0);
  Result := 1;
  while Result < aRequiredSize do
    Result := Result shl 1;
end;

function TGoldenRatioGrowStrategy.DoCalc(aCurrentSize: SizeUInt): SizeUInt;
const
  GOLDEN_RATIO: Single = 1.61803398875;
  MAX_SAFE_SIZEUINT = 9223372036854775807;
var
  LProduct: Single;
  LCeiled: Int64;
begin
  if aCurrentSize = 0 then
    Result := 1
  else
  begin
    LProduct := aCurrentSize * GOLDEN_RATIO;
    if (LProduct > MAX_SAFE_SIZEUINT) or IsInfinite(LProduct) or IsNaN(LProduct) then
      Result := MAX_SAFE_SIZEUINT
    else
    begin
      LCeiled := Ceil(LProduct);
      Result := SizeUInt(LCeiled);
    end;
  end;
end;

class destructor TGoldenRatioGrowStrategy.Destroy;
begin
  if FGlobal <> nil then
  begin
    FGlobal.Free;
    FGlobal := nil;
  end;
end;

class function TGoldenRatioGrowStrategy.GetGlobal: TGoldenRatioGrowStrategy;
begin
  Result := TGoldenRatioGrowStrategy.Create;
end;

function TAlignedWrapperStrategy.GetGrowStrategy: IGrowthStrategy;
begin
  Result := FGrowStrategy;
end;

function TAlignedWrapperStrategy.GetAlignSize: SizeUInt;
begin
  Result := FAlignSize;
end;

constructor TAlignedWrapperStrategy.Create(const aGrowStrategy: IGrowthStrategy; aAlignSize: SizeUInt);
begin
  inherited Create;

  if (aGrowStrategy = nil) then
    raise EArgumentNil.Create('TAlignedWrapperStrategy.Create: aGrowStrategy is nil');

  if (aAlignSize = 0) then
    raise EInvalidArgument.Create('TAlignedWrapperStrategy.Create: aAlignSize is 0');

  if ((aAlignSize and (aAlignSize - 1)) <> 0) then
    raise EInvalidArgument.Create('TAlignedWrapperStrategy.Create: aAlignSize must be power of two');

  FGrowStrategy := aGrowStrategy;
  FAlignSize    := aAlignSize;
end;

function TAlignedWrapperStrategy.DoGetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  Result := FGrowStrategy.GetGrowSize(aCurrentSize, aRequiredSize);
  Result := ((Result + FAlignSize - 1) div FAlignSize) * FAlignSize;
end;

class destructor TExactGrowStrategy.Destroy;
begin
  if FGlobal <> nil then
  begin
    FGlobal.Free;
    FGlobal := nil;
  end;
end;

class function TExactGrowStrategy.GetGlobal: TExactGrowStrategy;
begin
  Result := TExactGrowStrategy.Create;
end;

function TExactGrowStrategy.DoGetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  if aCurrentSize <> 0 then;
  Result := aRequiredSize;
end;

end.
