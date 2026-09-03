unit nextpas.core.window.constraints.impl;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.window.base,
  nextpas.core.window.constraints.base,
  nextpas.core.window.constraints.intf,
  nextpas.core.bytes.ops;

function WindowConstraintsGrowCapacity(ACurrent: Integer): Integer; inline; // bench single-call BenchConstraintsGrow/1 inline zero-copy O(1) via bytes.ops BytesGrowCapacity 0→32→2× single source L2→L1 direct, BenchBlackBoxInt64 防 DCE, 无内循环, 8× identical 已收口至 bytes.ops 单源 direct

procedure CheckWindowConstraints(const AConstraints: TWindowConstraints); inline; // bench single-call BenchConstraintsCheck/1 inline 薄分支零拷贝 O(1)
procedure CheckWindowConstraintsForOptions(const AOptions: TWindowOptions); inline;
procedure ValidateWindowMinMax(AMinWidth, AMinHeight, AMaxWidth, AMaxHeight: Integer); inline;

type
  { TWindowConstraintsImpl — INV-13 运行期 SetMin/Max 最小闭包
    单源复用 bytes.ops BytesGrowCapacity 0→32→2× direct L2→L1 (single source bytes.ops direct, 8× identical 已收口, no window.impl cross-Owner), CheckWindowConstraintsCore via constraints.base 单源 4-branch 统一校验 Min/Max 零漂移；
    性能: Apply/GetConstraints/SetMin/Max 均为 inline O(1) zero-copy (record 单次 Move/单字段写, 零堆分配);
    稳定性: 无句柄/堆分配, 仅值类型 FConstraints, COM 引用计数自动释放, heaptrc 0, 析构继承不丢资源 }
  TWindowConstraintsImpl = class(TInterfacedObject, IWindowConstraints)
  strict private
    FConstraints: TWindowConstraints;
  public
    constructor Create; overload;
    constructor Create(const AConstraints: TWindowConstraints); overload;
    function GetConstraints: TWindowConstraints; inline;
    procedure SetConstraints(const AConstraints: TWindowConstraints); inline;
    procedure SetMinSize(AWidth, AHeight: Integer); inline;
    procedure SetMaxSize(AWidth, AHeight: Integer); inline;
    procedure Apply(const AConstraints: TWindowConstraints); inline;
  end;

function CreateWindowConstraints: IWindowConstraints; overload; inline;
function CreateWindowConstraints(const AConstraints: TWindowConstraints): IWindowConstraints; overload; inline;

implementation

function WindowConstraintsGrowCapacity(ACurrent: Integer): Integer; inline;
begin
  // single source 0→32→2× via bytes.ops BytesGrowCapacity inline 零拷贝 O(1)均摊 L2→L1 direct, 8× identical inline 已收口至 bytes.ops 单源 direct, no window.impl cross-Owner
  Result := BytesGrowCapacity(ACurrent);
end;

procedure CheckWindowConstraints(const AConstraints: TWindowConstraints); inline;
begin
  // inline thin forward single source via constraints.base CheckWindowConstraintsCore, zero-copy O(1) thin branch, 4-branch logic single source via base, no duplicate, exception EWindowConstraintInvalid
  CheckWindowConstraintsCore(AConstraints);
end;

procedure CheckWindowConstraintsForOptions(const AOptions: TWindowOptions); inline;
begin
  // single source via CheckWindowConstraints O(1) inline zero-copy thin branch, reuse constraints validation for TWindowOptions.Constraints projection
  CheckWindowConstraints(AOptions.Constraints);
end;

procedure ValidateWindowMinMax(AMinWidth, AMinHeight, AMaxWidth, AMaxHeight: Integer); inline;
var
  L: TWindowConstraints;
begin
  // scalar overload via CheckWindowConstraints single source inline zero-copy O(1) thin branch
  L.MinWidth := AMinWidth;
  L.MinHeight := AMinHeight;
  L.MaxWidth := AMaxWidth;
  L.MaxHeight := AMaxHeight;
  CheckWindowConstraints(L);
end;

constructor TWindowConstraintsImpl.Create;
begin
  inherited Create;
  FConstraints := DefaultWindowConstraints;
end;

constructor TWindowConstraintsImpl.Create(const AConstraints: TWindowConstraints);
begin
  inherited Create;
  CheckWindowConstraints(AConstraints);
  FConstraints := AConstraints;
end;

function TWindowConstraintsImpl.GetConstraints: TWindowConstraints; inline;
begin
  Result := FConstraints;
end;

procedure TWindowConstraintsImpl.SetConstraints(const AConstraints: TWindowConstraints); inline;
begin
  CheckWindowConstraints(AConstraints);
  FConstraints := AConstraints;
end;

procedure TWindowConstraintsImpl.SetMinSize(AWidth, AHeight: Integer); inline;
var
  L: TWindowConstraints;
begin
  L := FConstraints;
  L.MinWidth := AWidth;
  L.MinHeight := AHeight;
  CheckWindowConstraints(L);
  FConstraints := L;
end;

procedure TWindowConstraintsImpl.SetMaxSize(AWidth, AHeight: Integer); inline;
var
  L: TWindowConstraints;
begin
  L := FConstraints;
  L.MaxWidth := AWidth;
  L.MaxHeight := AHeight;
  CheckWindowConstraints(L);
  FConstraints := L;
end;

procedure TWindowConstraintsImpl.Apply(const AConstraints: TWindowConstraints); inline;
begin
  CheckWindowConstraints(AConstraints);
  FConstraints := AConstraints;
end;

function CreateWindowConstraints: IWindowConstraints; inline;
begin
  Result := TWindowConstraintsImpl.Create;
end;

function CreateWindowConstraints(const AConstraints: TWindowConstraints): IWindowConstraints; inline;
begin
  Result := TWindowConstraintsImpl.Create(AConstraints);
end;

end.
