unit nextpas.core.math.mat;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math.vec;

type
  TMat3f = packed record
  public
    type
      TIndex = 0..2;
      TColumn = array[TIndex] of Single;
  strict private
    function GetItems(const AColumn, ARow: TIndex): Single; inline;
    procedure SetItems(const AColumn, ARow: TIndex; const AValue: Single); inline;
    function GetRows(const ARow: TIndex): TVec3f; inline;
    procedure SetRows(const ARow: TIndex; const AValue: TVec3f); inline;
    function GetColumns(const AColumn: TIndex): TVec3f; inline;
    procedure SetColumns(const AColumn: TIndex; const AValue: TVec3f); inline;
  public
    var
      Data: array[TIndex] of TColumn;
    class function Create(const AColumn0, AColumn1, AColumn2: TVec3f): TMat3f; static; inline;
    class function Zero: TMat3f; static; inline;
    class function Identity: TMat3f; static; inline;
    class operator + (const AA, AB: TMat3f): TMat3f; inline;
    class operator - (const AA, AB: TMat3f): TMat3f; inline;
    class operator - (const AValue: TMat3f): TMat3f; inline;
    class operator * (const AValue: TMat3f; const AScalar: Single): TMat3f; inline;
    class operator * (const AScalar: Single; const AValue: TMat3f): TMat3f; inline;
    class operator * (const AMatrix: TMat3f; const AVector: TVec3f): TVec3f; inline;
    class operator * (const AA, AB: TMat3f): TMat3f;
    class function Equals(const AA, AB: TMat3f; const AEpsilon: Single): Boolean; static; inline;
    class function Lerp(const AA, AB: TMat3f; const AT: Single): TMat3f; static; inline;
    function Transpose: TMat3f; inline;
    function Determinant: Single; inline;
    function TryInverse(out AInverse: TMat3f): Boolean;
    function Inverse: TMat3f;
    function PerfectlyEquals(const AOther: TMat3f): Boolean; inline;
    property Items[const AColumn, ARow: TIndex]: Single read GetItems write SetItems; default;
    property Rows[const ARow: TIndex]: TVec3f read GetRows write SetRows;
    property Columns[const AColumn: TIndex]: TVec3f read GetColumns write SetColumns;
  end;

  TMat4f = packed record
  public
    type
      TIndex = 0..3;
      TColumn = array[TIndex] of Single;
  strict private
    function GetItems(const AColumn, ARow: TIndex): Single; inline;
    procedure SetItems(const AColumn, ARow: TIndex; const AValue: Single); inline;
    function GetRows(const ARow: TIndex): TVec4f; inline;
    procedure SetRows(const ARow: TIndex; const AValue: TVec4f); inline;
    function GetColumns(const AColumn: TIndex): TVec4f; inline;
    procedure SetColumns(const AColumn: TIndex; const AValue: TVec4f); inline;
  public
    var
      Data: array[TIndex] of TColumn;
    class function Create(const AColumn0, AColumn1, AColumn2, AColumn3: TVec4f): TMat4f; static; inline;
    class function Zero: TMat4f; static; inline;
    class function Identity: TMat4f; static; inline;
    class operator + (const AA, AB: TMat4f): TMat4f; inline;
    class operator - (const AA, AB: TMat4f): TMat4f; inline;
    class operator - (const AValue: TMat4f): TMat4f; inline;
    class operator * (const AValue: TMat4f; const AScalar: Single): TMat4f; inline;
    class operator * (const AScalar: Single; const AValue: TMat4f): TMat4f; inline;
    class operator * (const AMatrix: TMat4f; const AVector: TVec4f): TVec4f; inline;
    class operator * (const AA, AB: TMat4f): TMat4f;
    class function Equals(const AA, AB: TMat4f; const AEpsilon: Single): Boolean; static; inline;
    class function Lerp(const AA, AB: TMat4f; const AT: Single): TMat4f; static; inline;
    function Transpose: TMat4f; inline;
    function Determinant: Single;
    function TryInverse(out AInverse: TMat4f): Boolean;
    function Inverse: TMat4f;
    function MultPoint(const AVec: TVec3f): TVec3f; inline;
    function MultDirection(const AVec: TVec3f): TVec3f; inline;
    function PerfectlyEquals(const AOther: TMat4f): Boolean; inline;
    property Items[const AColumn, ARow: TIndex]: Single read GetItems write SetItems; default;
    property Rows[const ARow: TIndex]: TVec4f read GetRows write SetRows;
    property Columns[const AColumn: TIndex]: TVec4f read GetColumns write SetColumns;
  end;

  TMat3d = packed record
  public
    type
      TIndex = 0..2;
      TColumn = array[TIndex] of Double;
  strict private
    function GetItems(const AColumn, ARow: TIndex): Double; inline;
    procedure SetItems(const AColumn, ARow: TIndex; const AValue: Double); inline;
    function GetRows(const ARow: TIndex): TVec3d; inline;
    procedure SetRows(const ARow: TIndex; const AValue: TVec3d); inline;
    function GetColumns(const AColumn: TIndex): TVec3d; inline;
    procedure SetColumns(const AColumn: TIndex; const AValue: TVec3d); inline;
  public
    var
      Data: array[TIndex] of TColumn;
    class function Create(const AColumn0, AColumn1, AColumn2: TVec3d): TMat3d; static; inline;
    class function Zero: TMat3d; static; inline;
    class function Identity: TMat3d; static; inline;
    class operator + (const AA, AB: TMat3d): TMat3d; inline;
    class operator - (const AA, AB: TMat3d): TMat3d; inline;
    class operator - (const AValue: TMat3d): TMat3d; inline;
    class operator * (const AValue: TMat3d; const AScalar: Double): TMat3d; inline;
    class operator * (const AScalar: Double; const AValue: TMat3d): TMat3d; inline;
    class operator * (const AMatrix: TMat3d; const AVector: TVec3d): TVec3d; inline;
    class operator * (const AA, AB: TMat3d): TMat3d;
    class function Equals(const AA, AB: TMat3d; const AEpsilon: Double): Boolean; static; inline;
    class function Lerp(const AA, AB: TMat3d; const AT: Double): TMat3d; static; inline;
    function Transpose: TMat3d; inline;
    function Determinant: Double; inline;
    function TryInverse(out AInverse: TMat3d): Boolean;
    function Inverse: TMat3d;
    function PerfectlyEquals(const AOther: TMat3d): Boolean; inline;
    property Items[const AColumn, ARow: TIndex]: Double read GetItems write SetItems; default;
    property Rows[const ARow: TIndex]: TVec3d read GetRows write SetRows;
    property Columns[const AColumn: TIndex]: TVec3d read GetColumns write SetColumns;
  end;

  TMat4d = packed record
  public
    type
      TIndex = 0..3;
      TColumn = array[TIndex] of Double;
  strict private
    function GetItems(const AColumn, ARow: TIndex): Double; inline;
    procedure SetItems(const AColumn, ARow: TIndex; const AValue: Double); inline;
    function GetRows(const ARow: TIndex): TVec4d; inline;
    procedure SetRows(const ARow: TIndex; const AValue: TVec4d); inline;
    function GetColumns(const AColumn: TIndex): TVec4d; inline;
    procedure SetColumns(const AColumn: TIndex; const AValue: TVec4d); inline;
  public
    var
      Data: array[TIndex] of TColumn;
    class function Create(const AColumn0, AColumn1, AColumn2, AColumn3: TVec4d): TMat4d; static; inline;
    class function Zero: TMat4d; static; inline;
    class function Identity: TMat4d; static; inline;
    class operator + (const AA, AB: TMat4d): TMat4d; inline;
    class operator - (const AA, AB: TMat4d): TMat4d; inline;
    class operator - (const AValue: TMat4d): TMat4d; inline;
    class operator * (const AValue: TMat4d; const AScalar: Double): TMat4d; inline;
    class operator * (const AScalar: Double; const AValue: TMat4d): TMat4d; inline;
    class operator * (const AMatrix: TMat4d; const AVector: TVec4d): TVec4d; inline;
    class operator * (const AA, AB: TMat4d): TMat4d;
    class function Equals(const AA, AB: TMat4d; const AEpsilon: Double): Boolean; static; inline;
    class function Lerp(const AA, AB: TMat4d; const AT: Double): TMat4d; static; inline;
    function Transpose: TMat4d; inline;
    function Determinant: Double;
    function TryInverse(out AInverse: TMat4d): Boolean;
    function Inverse: TMat4d;
    function MultPoint(const AVec: TVec3d): TVec3d; inline;
    function MultDirection(const AVec: TVec3d): TVec3d; inline;
    function PerfectlyEquals(const AOther: TMat4d): Boolean; inline;
    property Items[const AColumn, ARow: TIndex]: Double read GetItems write SetItems; default;
    property Rows[const ARow: TIndex]: TVec4d read GetRows write SetRows;
    property Columns[const AColumn: TIndex]: TVec4d read GetColumns write SetColumns;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.math.scalar;

const
  SINGLE_INVERSE_EPSILON: Double = 0.000001;
  DOUBLE_INVERSE_EPSILON: Double = 0.000000000001;

type
  TWork3 = array[0..2, 0..5] of Double;
  TWork4 = array[0..3, 0..7] of Double;
  TWork4Determinant = array[0..3, 0..3] of Double;

function AbsDouble(const AValue: Double): Double; inline;
begin
  if AValue < 0.0 then
    Result := -AValue
  else
    Result := AValue;
end;

function IsFiniteDouble(const AValue: Double): Boolean; inline;
begin
  Result := (not nextpas.core.math.scalar.IsNaN(AValue)) and
    (not nextpas.core.math.scalar.IsInfinite(AValue));
end;

function IsFiniteSingle(const AValue: Single): Boolean; inline;
begin
  Result := (not nextpas.core.math.scalar.IsNaN(AValue)) and
    (not nextpas.core.math.scalar.IsInfinite(AValue));
end;

function MatrixWork3IsFinite(const AWork: TWork3): Boolean;
var
  C: Integer;
  R: Integer;
begin
  for R := 0 to 2 do
    for C := 0 to 2 do
      if not IsFiniteDouble(AWork[R, C]) then
        Exit(False);
  Result := True;
end;

function MatrixWork4IsFinite(const AWork: TWork4): Boolean;
var
  C: Integer;
  R: Integer;
begin
  for R := 0 to 3 do
    for C := 0 to 3 do
      if not IsFiniteDouble(AWork[R, C]) then
        Exit(False);
  Result := True;
end;

function InvertWork3(var AWork: TWork3; const AEpsilon: Double): Boolean;
var
  I: Integer;
  J: Integer;
  PivotRow: Integer;
  Best: Double;
  Candidate: Double;
  Pivot: Double;
  Factor: Double;
  Temp: Double;
begin
  for I := 0 to 2 do
  begin
    PivotRow := I;
    Best := AbsDouble(AWork[I, I]);
    for J := I + 1 to 2 do
    begin
      Candidate := AbsDouble(AWork[J, I]);
      if Candidate > Best then
      begin
        Best := Candidate;
        PivotRow := J;
      end;
    end;

    if Best <= AEpsilon then
      Exit(False);

    if PivotRow <> I then
      for J := 0 to 5 do
      begin
        Temp := AWork[I, J];
        AWork[I, J] := AWork[PivotRow, J];
        AWork[PivotRow, J] := Temp;
      end;

    Pivot := AWork[I, I];
    for J := 0 to 5 do
      AWork[I, J] := AWork[I, J] / Pivot;

    for PivotRow := 0 to 2 do
    begin
      if PivotRow = I then
        Continue;
      Factor := AWork[PivotRow, I];
      if Factor = 0.0 then
        Continue;
      for J := 0 to 5 do
        AWork[PivotRow, J] := AWork[PivotRow, J] - Factor * AWork[I, J];
    end;
  end;

  Result := True;
end;

function InvertWork4(var AWork: TWork4; const AEpsilon: Double): Boolean;
var
  I: Integer;
  J: Integer;
  PivotRow: Integer;
  Best: Double;
  Candidate: Double;
  Pivot: Double;
  Factor: Double;
  Temp: Double;
begin
  for I := 0 to 3 do
  begin
    PivotRow := I;
    Best := AbsDouble(AWork[I, I]);
    for J := I + 1 to 3 do
    begin
      Candidate := AbsDouble(AWork[J, I]);
      if Candidate > Best then
      begin
        Best := Candidate;
        PivotRow := J;
      end;
    end;

    if Best <= AEpsilon then
      Exit(False);

    if PivotRow <> I then
      for J := 0 to 7 do
      begin
        Temp := AWork[I, J];
        AWork[I, J] := AWork[PivotRow, J];
        AWork[PivotRow, J] := Temp;
      end;

    Pivot := AWork[I, I];
    for J := 0 to 7 do
      AWork[I, J] := AWork[I, J] / Pivot;

    for PivotRow := 0 to 3 do
    begin
      if PivotRow = I then
        Continue;
      Factor := AWork[PivotRow, I];
      if Factor = 0.0 then
        Continue;
      for J := 0 to 7 do
        AWork[PivotRow, J] := AWork[PivotRow, J] - Factor * AWork[I, J];
    end;
  end;

  Result := True;
end;

function DeterminantWork4(var AWork: TWork4Determinant): Double;
var
  I: Integer;
  J: Integer;
  K: Integer;
  PivotRow: Integer;
  Best: Double;
  Candidate: Double;
  Pivot: Double;
  Factor: Double;
  Temp: Double;
  Sign: Double;
begin
  Result := 1.0;
  Sign := 1.0;
  for I := 0 to 3 do
  begin
    PivotRow := I;
    Best := AbsDouble(AWork[I, I]);
    for J := I + 1 to 3 do
    begin
      Candidate := AbsDouble(AWork[J, I]);
      if Candidate > Best then
      begin
        Best := Candidate;
        PivotRow := J;
      end;
    end;

    if Best = 0.0 then
      Exit(0.0);

    if PivotRow <> I then
    begin
      Sign := -Sign;
      for J := 0 to 3 do
      begin
        Temp := AWork[I, J];
        AWork[I, J] := AWork[PivotRow, J];
        AWork[PivotRow, J] := Temp;
      end;
    end;

    Pivot := AWork[I, I];
    Result := Result * Pivot;
    for J := I + 1 to 3 do
    begin
      Factor := AWork[J, I] / Pivot;
      for K := I + 1 to 3 do
        AWork[J, K] := AWork[J, K] - Factor * AWork[I, K];
    end;
  end;

  Result := Result * Sign;
end;

function Det3(
  const A00, A01, A02,
        A10, A11, A12,
        A20, A21, A22: Double): Double; inline;
begin
  Result :=
    A00 * (A11 * A22 - A12 * A21) -
    A01 * (A10 * A22 - A12 * A20) +
    A02 * (A10 * A21 - A11 * A20);
end;

function FloatEqualsSingle(const AA, AB, AEpsilon: Single): Boolean; inline;
begin
  Result := nextpas.core.math.scalar.FloatEquals(AA, AB, AEpsilon);
end;

function FloatEqualsDouble(const AA, AB, AEpsilon: Double): Boolean; inline;
begin
  Result := nextpas.core.math.scalar.FloatEquals(AA, AB, AEpsilon);
end;

{ TMat3f }

function TMat3f.GetItems(const AColumn, ARow: TIndex): Single;
begin
  Result := Data[AColumn, ARow];
end;

procedure TMat3f.SetItems(const AColumn, ARow: TIndex; const AValue: Single);
begin
  Data[AColumn, ARow] := AValue;
end;

function TMat3f.GetRows(const ARow: TIndex): TVec3f;
begin
  Result := TVec3f.Create(Data[0, ARow], Data[1, ARow], Data[2, ARow]);
end;

procedure TMat3f.SetRows(const ARow: TIndex; const AValue: TVec3f);
begin
  Data[0, ARow] := AValue.X;
  Data[1, ARow] := AValue.Y;
  Data[2, ARow] := AValue.Z;
end;

function TMat3f.GetColumns(const AColumn: TIndex): TVec3f;
begin
  Result := TVec3f.Create(Data[AColumn, 0], Data[AColumn, 1], Data[AColumn, 2]);
end;

procedure TMat3f.SetColumns(const AColumn: TIndex; const AValue: TVec3f);
begin
  Data[AColumn, 0] := AValue.X;
  Data[AColumn, 1] := AValue.Y;
  Data[AColumn, 2] := AValue.Z;
end;

class function TMat3f.Create(const AColumn0, AColumn1, AColumn2: TVec3f): TMat3f;
begin
  Result.Columns[0] := AColumn0;
  Result.Columns[1] := AColumn1;
  Result.Columns[2] := AColumn2;
end;

class function TMat3f.Zero: TMat3f;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

class function TMat3f.Identity: TMat3f;
begin
  Result := Zero;
  Result[0, 0] := 1.0;
  Result[1, 1] := 1.0;
  Result[2, 2] := 1.0;
end;

class operator TMat3f.+ (const AA, AB: TMat3f): TMat3f;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 2 do
    for R := 0 to 2 do
      Result.Data[C, R] := AA.Data[C, R] + AB.Data[C, R];
end;

class operator TMat3f.- (const AA, AB: TMat3f): TMat3f;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 2 do
    for R := 0 to 2 do
      Result.Data[C, R] := AA.Data[C, R] - AB.Data[C, R];
end;

class operator TMat3f.- (const AValue: TMat3f): TMat3f;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 2 do
    for R := 0 to 2 do
      Result.Data[C, R] := -AValue.Data[C, R];
end;

class operator TMat3f.* (const AValue: TMat3f; const AScalar: Single): TMat3f;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 2 do
    for R := 0 to 2 do
      Result.Data[C, R] := AValue.Data[C, R] * AScalar;
end;

class operator TMat3f.* (const AScalar: Single; const AValue: TMat3f): TMat3f;
begin
  Result := AValue * AScalar;
end;

class operator TMat3f.* (const AMatrix: TMat3f; const AVector: TVec3f): TVec3f;
begin
  Result := TVec3f.Create(
    AMatrix.Data[0, 0] * AVector.X + AMatrix.Data[1, 0] * AVector.Y + AMatrix.Data[2, 0] * AVector.Z,
    AMatrix.Data[0, 1] * AVector.X + AMatrix.Data[1, 1] * AVector.Y + AMatrix.Data[2, 1] * AVector.Z,
    AMatrix.Data[0, 2] * AVector.X + AMatrix.Data[1, 2] * AVector.Y + AMatrix.Data[2, 2] * AVector.Z);
end;

class operator TMat3f.* (const AA, AB: TMat3f): TMat3f;
var
  C: TIndex;
  R: TIndex;
  K: TIndex;
begin
  for C := 0 to 2 do
    for R := 0 to 2 do
    begin
      Result.Data[C, R] := 0.0;
      for K := 0 to 2 do
        Result.Data[C, R] := Result.Data[C, R] + AA.Data[K, R] * AB.Data[C, K];
    end;
end;

class function TMat3f.Equals(const AA, AB: TMat3f; const AEpsilon: Single): Boolean;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 2 do
    for R := 0 to 2 do
      if not FloatEqualsSingle(AA.Data[C, R], AB.Data[C, R], AEpsilon) then
        Exit(False);
  Result := True;
end;

function TMat3f.Transpose: TMat3f;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 2 do
    for R := 0 to 2 do
      Result.Data[C, R] := Data[R, C];
end;

function TMat3f.Determinant: Single;
begin
  Result := Single(Det3(
    Data[0, 0], Data[1, 0], Data[2, 0],
    Data[0, 1], Data[1, 1], Data[2, 1],
    Data[0, 2], Data[1, 2], Data[2, 2]));
end;

function TMat3f.TryInverse(out AInverse: TMat3f): Boolean;
var
  Work: TWork3;
  C: TIndex;
  R: TIndex;
begin
  for R := 0 to 2 do
    for C := 0 to 2 do
    begin
      if not IsFiniteSingle(Data[C, R]) then
      begin
        AInverse := Zero;
        Exit(False);
      end;
      Work[R, C] := Data[C, R];
      Work[R, C + 3] := 0.0;
    end;
  Work[0, 3] := 1.0;
  Work[1, 4] := 1.0;
  Work[2, 5] := 1.0;

  Result := InvertWork3(Work, SINGLE_INVERSE_EPSILON);
  if not Result then
  begin
    AInverse := Zero;
    Exit;
  end;

  for R := 0 to 2 do
    for C := 0 to 2 do
      AInverse.Data[C, R] := Single(Work[R, C + 3]);
end;

function TMat3f.Inverse: TMat3f;
begin
  if not TryInverse(Result) then
    raise EArgumentError.Create('TMat3f.Inverse: matrix is singular');
end;

class function TMat3f.Lerp(const AA, AB: TMat3f; const AT: Single): TMat3f;
var
  LC, LR: TIndex;
begin
  for LC := Low(TIndex) to High(TIndex) do
    for LR := Low(TIndex) to High(TIndex) do
      Result.Data[LC, LR] := nextpas.core.math.scalar.Lerp(AA.Data[LC, LR], AB.Data[LC, LR], AT);
end;

function TMat3f.PerfectlyEquals(const AOther: TMat3f): Boolean;
var
  LC, LR: TIndex;
begin
  Result := True;
  for LC := Low(TIndex) to High(TIndex) do
    for LR := Low(TIndex) to High(TIndex) do
      if Data[LC, LR] <> AOther.Data[LC, LR] then
        Exit(False);
end;

{ TMat4f }

function TMat4f.GetItems(const AColumn, ARow: TIndex): Single;
begin
  Result := Data[AColumn, ARow];
end;

procedure TMat4f.SetItems(const AColumn, ARow: TIndex; const AValue: Single);
begin
  Data[AColumn, ARow] := AValue;
end;

function TMat4f.GetRows(const ARow: TIndex): TVec4f;
begin
  Result := TVec4f.Create(Data[0, ARow], Data[1, ARow], Data[2, ARow], Data[3, ARow]);
end;

procedure TMat4f.SetRows(const ARow: TIndex; const AValue: TVec4f);
begin
  Data[0, ARow] := AValue.X;
  Data[1, ARow] := AValue.Y;
  Data[2, ARow] := AValue.Z;
  Data[3, ARow] := AValue.W;
end;

function TMat4f.GetColumns(const AColumn: TIndex): TVec4f;
begin
  Result := TVec4f.Create(Data[AColumn, 0], Data[AColumn, 1], Data[AColumn, 2], Data[AColumn, 3]);
end;

procedure TMat4f.SetColumns(const AColumn: TIndex; const AValue: TVec4f);
begin
  Data[AColumn, 0] := AValue.X;
  Data[AColumn, 1] := AValue.Y;
  Data[AColumn, 2] := AValue.Z;
  Data[AColumn, 3] := AValue.W;
end;

class function TMat4f.Create(const AColumn0, AColumn1, AColumn2, AColumn3: TVec4f): TMat4f;
begin
  Result.Columns[0] := AColumn0;
  Result.Columns[1] := AColumn1;
  Result.Columns[2] := AColumn2;
  Result.Columns[3] := AColumn3;
end;

class function TMat4f.Zero: TMat4f;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

class function TMat4f.Identity: TMat4f;
begin
  Result := Zero;
  Result[0, 0] := 1.0;
  Result[1, 1] := 1.0;
  Result[2, 2] := 1.0;
  Result[3, 3] := 1.0;
end;

class operator TMat4f.+ (const AA, AB: TMat4f): TMat4f;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 3 do
    for R := 0 to 3 do
      Result.Data[C, R] := AA.Data[C, R] + AB.Data[C, R];
end;

class operator TMat4f.- (const AA, AB: TMat4f): TMat4f;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 3 do
    for R := 0 to 3 do
      Result.Data[C, R] := AA.Data[C, R] - AB.Data[C, R];
end;

class operator TMat4f.- (const AValue: TMat4f): TMat4f;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 3 do
    for R := 0 to 3 do
      Result.Data[C, R] := -AValue.Data[C, R];
end;

class operator TMat4f.* (const AValue: TMat4f; const AScalar: Single): TMat4f;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 3 do
    for R := 0 to 3 do
      Result.Data[C, R] := AValue.Data[C, R] * AScalar;
end;

class operator TMat4f.* (const AScalar: Single; const AValue: TMat4f): TMat4f;
begin
  Result := AValue * AScalar;
end;

class operator TMat4f.* (const AMatrix: TMat4f; const AVector: TVec4f): TVec4f;
begin
  Result := TVec4f.Create(
    AMatrix.Data[0, 0] * AVector.X + AMatrix.Data[1, 0] * AVector.Y +
      AMatrix.Data[2, 0] * AVector.Z + AMatrix.Data[3, 0] * AVector.W,
    AMatrix.Data[0, 1] * AVector.X + AMatrix.Data[1, 1] * AVector.Y +
      AMatrix.Data[2, 1] * AVector.Z + AMatrix.Data[3, 1] * AVector.W,
    AMatrix.Data[0, 2] * AVector.X + AMatrix.Data[1, 2] * AVector.Y +
      AMatrix.Data[2, 2] * AVector.Z + AMatrix.Data[3, 2] * AVector.W,
    AMatrix.Data[0, 3] * AVector.X + AMatrix.Data[1, 3] * AVector.Y +
      AMatrix.Data[2, 3] * AVector.Z + AMatrix.Data[3, 3] * AVector.W);
end;

class operator TMat4f.* (const AA, AB: TMat4f): TMat4f;
var
  C: TIndex;
  R: TIndex;
  K: TIndex;
begin
  for C := 0 to 3 do
    for R := 0 to 3 do
    begin
      Result.Data[C, R] := 0.0;
      for K := 0 to 3 do
        Result.Data[C, R] := Result.Data[C, R] + AA.Data[K, R] * AB.Data[C, K];
    end;
end;

class function TMat4f.Equals(const AA, AB: TMat4f; const AEpsilon: Single): Boolean;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 3 do
    for R := 0 to 3 do
      if not FloatEqualsSingle(AA.Data[C, R], AB.Data[C, R], AEpsilon) then
        Exit(False);
  Result := True;
end;

function TMat4f.Transpose: TMat4f;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 3 do
    for R := 0 to 3 do
      Result.Data[C, R] := Data[R, C];
end;

function TMat4f.Determinant: Single;
var
  Work: TWork4Determinant;
  C: TIndex;
  R: TIndex;
begin
  for R := 0 to 3 do
    for C := 0 to 3 do
      Work[R, C] := Data[C, R];
  Result := Single(DeterminantWork4(Work));
end;

function TMat4f.TryInverse(out AInverse: TMat4f): Boolean;
var
  Work: TWork4;
  C: TIndex;
  R: TIndex;
begin
  for R := 0 to 3 do
    for C := 0 to 3 do
    begin
      if not IsFiniteSingle(Data[C, R]) then
      begin
        AInverse := Zero;
        Exit(False);
      end;
      Work[R, C] := Data[C, R];
      Work[R, C + 4] := 0.0;
    end;
  Work[0, 4] := 1.0;
  Work[1, 5] := 1.0;
  Work[2, 6] := 1.0;
  Work[3, 7] := 1.0;

  Result := InvertWork4(Work, SINGLE_INVERSE_EPSILON);
  if not Result then
  begin
    AInverse := Zero;
    Exit;
  end;

  for R := 0 to 3 do
    for C := 0 to 3 do
      AInverse.Data[C, R] := Single(Work[R, C + 4]);
end;

function TMat4f.Inverse: TMat4f;
begin
  if not TryInverse(Result) then
    raise EArgumentError.Create('TMat4f.Inverse: matrix is singular');
end;

class function TMat4f.Lerp(const AA, AB: TMat4f; const AT: Single): TMat4f;
var
  LC, LR: TIndex;
begin
  for LC := Low(TIndex) to High(TIndex) do
    for LR := Low(TIndex) to High(TIndex) do
      Result.Data[LC, LR] := nextpas.core.math.scalar.Lerp(AA.Data[LC, LR], AB.Data[LC, LR], AT);
end;

function TMat4f.MultPoint(const AVec: TVec3f): TVec3f;
begin
  Result := TVec3f.Create(
    Data[0, 0] * AVec.X + Data[1, 0] * AVec.Y + Data[2, 0] * AVec.Z + Data[3, 0],
    Data[0, 1] * AVec.X + Data[1, 1] * AVec.Y + Data[2, 1] * AVec.Z + Data[3, 1],
    Data[0, 2] * AVec.X + Data[1, 2] * AVec.Y + Data[2, 2] * AVec.Z + Data[3, 2]);
end;

function TMat4f.MultDirection(const AVec: TVec3f): TVec3f;
begin
  Result := TVec3f.Create(
    Data[0, 0] * AVec.X + Data[1, 0] * AVec.Y + Data[2, 0] * AVec.Z,
    Data[0, 1] * AVec.X + Data[1, 1] * AVec.Y + Data[2, 1] * AVec.Z,
    Data[0, 2] * AVec.X + Data[1, 2] * AVec.Y + Data[2, 2] * AVec.Z);
end;

function TMat4f.PerfectlyEquals(const AOther: TMat4f): Boolean;
var
  LC, LR: TIndex;
begin
  Result := True;
  for LC := Low(TIndex) to High(TIndex) do
    for LR := Low(TIndex) to High(TIndex) do
      if Data[LC, LR] <> AOther.Data[LC, LR] then
        Exit(False);
end;

{ TMat3d }

function TMat3d.GetItems(const AColumn, ARow: TIndex): Double;
begin
  Result := Data[AColumn, ARow];
end;

procedure TMat3d.SetItems(const AColumn, ARow: TIndex; const AValue: Double);
begin
  Data[AColumn, ARow] := AValue;
end;

function TMat3d.GetRows(const ARow: TIndex): TVec3d;
begin
  Result := TVec3d.Create(Data[0, ARow], Data[1, ARow], Data[2, ARow]);
end;

procedure TMat3d.SetRows(const ARow: TIndex; const AValue: TVec3d);
begin
  Data[0, ARow] := AValue.X;
  Data[1, ARow] := AValue.Y;
  Data[2, ARow] := AValue.Z;
end;

function TMat3d.GetColumns(const AColumn: TIndex): TVec3d;
begin
  Result := TVec3d.Create(Data[AColumn, 0], Data[AColumn, 1], Data[AColumn, 2]);
end;

procedure TMat3d.SetColumns(const AColumn: TIndex; const AValue: TVec3d);
begin
  Data[AColumn, 0] := AValue.X;
  Data[AColumn, 1] := AValue.Y;
  Data[AColumn, 2] := AValue.Z;
end;

class function TMat3d.Create(const AColumn0, AColumn1, AColumn2: TVec3d): TMat3d;
begin
  Result.Columns[0] := AColumn0;
  Result.Columns[1] := AColumn1;
  Result.Columns[2] := AColumn2;
end;

class function TMat3d.Zero: TMat3d;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

class function TMat3d.Identity: TMat3d;
begin
  Result := Zero;
  Result[0, 0] := 1.0;
  Result[1, 1] := 1.0;
  Result[2, 2] := 1.0;
end;

class operator TMat3d.+ (const AA, AB: TMat3d): TMat3d;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 2 do
    for R := 0 to 2 do
      Result.Data[C, R] := AA.Data[C, R] + AB.Data[C, R];
end;

class operator TMat3d.- (const AA, AB: TMat3d): TMat3d;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 2 do
    for R := 0 to 2 do
      Result.Data[C, R] := AA.Data[C, R] - AB.Data[C, R];
end;

class operator TMat3d.- (const AValue: TMat3d): TMat3d;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 2 do
    for R := 0 to 2 do
      Result.Data[C, R] := -AValue.Data[C, R];
end;

class operator TMat3d.* (const AValue: TMat3d; const AScalar: Double): TMat3d;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 2 do
    for R := 0 to 2 do
      Result.Data[C, R] := AValue.Data[C, R] * AScalar;
end;

class operator TMat3d.* (const AScalar: Double; const AValue: TMat3d): TMat3d;
begin
  Result := AValue * AScalar;
end;

class operator TMat3d.* (const AMatrix: TMat3d; const AVector: TVec3d): TVec3d;
begin
  Result := TVec3d.Create(
    AMatrix.Data[0, 0] * AVector.X + AMatrix.Data[1, 0] * AVector.Y + AMatrix.Data[2, 0] * AVector.Z,
    AMatrix.Data[0, 1] * AVector.X + AMatrix.Data[1, 1] * AVector.Y + AMatrix.Data[2, 1] * AVector.Z,
    AMatrix.Data[0, 2] * AVector.X + AMatrix.Data[1, 2] * AVector.Y + AMatrix.Data[2, 2] * AVector.Z);
end;

class operator TMat3d.* (const AA, AB: TMat3d): TMat3d;
var
  C: TIndex;
  R: TIndex;
  K: TIndex;
begin
  for C := 0 to 2 do
    for R := 0 to 2 do
    begin
      Result.Data[C, R] := 0.0;
      for K := 0 to 2 do
        Result.Data[C, R] := Result.Data[C, R] + AA.Data[K, R] * AB.Data[C, K];
    end;
end;

class function TMat3d.Equals(const AA, AB: TMat3d; const AEpsilon: Double): Boolean;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 2 do
    for R := 0 to 2 do
      if not FloatEqualsDouble(AA.Data[C, R], AB.Data[C, R], AEpsilon) then
        Exit(False);
  Result := True;
end;

function TMat3d.Transpose: TMat3d;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 2 do
    for R := 0 to 2 do
      Result.Data[C, R] := Data[R, C];
end;

function TMat3d.Determinant: Double;
begin
  Result := Det3(
    Data[0, 0], Data[1, 0], Data[2, 0],
    Data[0, 1], Data[1, 1], Data[2, 1],
    Data[0, 2], Data[1, 2], Data[2, 2]);
end;

function TMat3d.TryInverse(out AInverse: TMat3d): Boolean;
var
  Work: TWork3;
  C: TIndex;
  R: TIndex;
begin
  for R := 0 to 2 do
    for C := 0 to 2 do
    begin
      Work[R, C] := Data[C, R];
      Work[R, C + 3] := 0.0;
    end;
  Work[0, 3] := 1.0;
  Work[1, 4] := 1.0;
  Work[2, 5] := 1.0;
  if not MatrixWork3IsFinite(Work) then
  begin
    AInverse := Zero;
    Exit(False);
  end;

  Result := InvertWork3(Work, DOUBLE_INVERSE_EPSILON);
  if not Result then
  begin
    AInverse := Zero;
    Exit;
  end;

  for R := 0 to 2 do
    for C := 0 to 2 do
      AInverse.Data[C, R] := Work[R, C + 3];
end;

function TMat3d.Inverse: TMat3d;
begin
  if not TryInverse(Result) then
    raise EArgumentError.Create('TMat3d.Inverse: matrix is singular');
end;

class function TMat3d.Lerp(const AA, AB: TMat3d; const AT: Double): TMat3d;
var
  LC, LR: TIndex;
begin
  for LC := Low(TIndex) to High(TIndex) do
    for LR := Low(TIndex) to High(TIndex) do
      Result.Data[LC, LR] := nextpas.core.math.scalar.Lerp(AA.Data[LC, LR], AB.Data[LC, LR], AT);
end;

function TMat3d.PerfectlyEquals(const AOther: TMat3d): Boolean;
var
  LC, LR: TIndex;
begin
  Result := True;
  for LC := Low(TIndex) to High(TIndex) do
    for LR := Low(TIndex) to High(TIndex) do
      if Data[LC, LR] <> AOther.Data[LC, LR] then
        Exit(False);
end;

{ TMat4d }

function TMat4d.GetItems(const AColumn, ARow: TIndex): Double;
begin
  Result := Data[AColumn, ARow];
end;

procedure TMat4d.SetItems(const AColumn, ARow: TIndex; const AValue: Double);
begin
  Data[AColumn, ARow] := AValue;
end;

function TMat4d.GetRows(const ARow: TIndex): TVec4d;
begin
  Result := TVec4d.Create(Data[0, ARow], Data[1, ARow], Data[2, ARow], Data[3, ARow]);
end;

procedure TMat4d.SetRows(const ARow: TIndex; const AValue: TVec4d);
begin
  Data[0, ARow] := AValue.X;
  Data[1, ARow] := AValue.Y;
  Data[2, ARow] := AValue.Z;
  Data[3, ARow] := AValue.W;
end;

function TMat4d.GetColumns(const AColumn: TIndex): TVec4d;
begin
  Result := TVec4d.Create(Data[AColumn, 0], Data[AColumn, 1], Data[AColumn, 2], Data[AColumn, 3]);
end;

procedure TMat4d.SetColumns(const AColumn: TIndex; const AValue: TVec4d);
begin
  Data[AColumn, 0] := AValue.X;
  Data[AColumn, 1] := AValue.Y;
  Data[AColumn, 2] := AValue.Z;
  Data[AColumn, 3] := AValue.W;
end;

class function TMat4d.Create(const AColumn0, AColumn1, AColumn2, AColumn3: TVec4d): TMat4d;
begin
  Result.Columns[0] := AColumn0;
  Result.Columns[1] := AColumn1;
  Result.Columns[2] := AColumn2;
  Result.Columns[3] := AColumn3;
end;

class function TMat4d.Zero: TMat4d;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

class function TMat4d.Identity: TMat4d;
begin
  Result := Zero;
  Result[0, 0] := 1.0;
  Result[1, 1] := 1.0;
  Result[2, 2] := 1.0;
  Result[3, 3] := 1.0;
end;

class operator TMat4d.+ (const AA, AB: TMat4d): TMat4d;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 3 do
    for R := 0 to 3 do
      Result.Data[C, R] := AA.Data[C, R] + AB.Data[C, R];
end;

class operator TMat4d.- (const AA, AB: TMat4d): TMat4d;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 3 do
    for R := 0 to 3 do
      Result.Data[C, R] := AA.Data[C, R] - AB.Data[C, R];
end;

class operator TMat4d.- (const AValue: TMat4d): TMat4d;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 3 do
    for R := 0 to 3 do
      Result.Data[C, R] := -AValue.Data[C, R];
end;

class operator TMat4d.* (const AValue: TMat4d; const AScalar: Double): TMat4d;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 3 do
    for R := 0 to 3 do
      Result.Data[C, R] := AValue.Data[C, R] * AScalar;
end;

class operator TMat4d.* (const AScalar: Double; const AValue: TMat4d): TMat4d;
begin
  Result := AValue * AScalar;
end;

class operator TMat4d.* (const AMatrix: TMat4d; const AVector: TVec4d): TVec4d;
begin
  Result := TVec4d.Create(
    AMatrix.Data[0, 0] * AVector.X + AMatrix.Data[1, 0] * AVector.Y +
      AMatrix.Data[2, 0] * AVector.Z + AMatrix.Data[3, 0] * AVector.W,
    AMatrix.Data[0, 1] * AVector.X + AMatrix.Data[1, 1] * AVector.Y +
      AMatrix.Data[2, 1] * AVector.Z + AMatrix.Data[3, 1] * AVector.W,
    AMatrix.Data[0, 2] * AVector.X + AMatrix.Data[1, 2] * AVector.Y +
      AMatrix.Data[2, 2] * AVector.Z + AMatrix.Data[3, 2] * AVector.W,
    AMatrix.Data[0, 3] * AVector.X + AMatrix.Data[1, 3] * AVector.Y +
      AMatrix.Data[2, 3] * AVector.Z + AMatrix.Data[3, 3] * AVector.W);
end;

class operator TMat4d.* (const AA, AB: TMat4d): TMat4d;
var
  C: TIndex;
  R: TIndex;
  K: TIndex;
begin
  for C := 0 to 3 do
    for R := 0 to 3 do
    begin
      Result.Data[C, R] := 0.0;
      for K := 0 to 3 do
        Result.Data[C, R] := Result.Data[C, R] + AA.Data[K, R] * AB.Data[C, K];
    end;
end;

class function TMat4d.Equals(const AA, AB: TMat4d; const AEpsilon: Double): Boolean;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 3 do
    for R := 0 to 3 do
      if not FloatEqualsDouble(AA.Data[C, R], AB.Data[C, R], AEpsilon) then
        Exit(False);
  Result := True;
end;

function TMat4d.Transpose: TMat4d;
var
  C: TIndex;
  R: TIndex;
begin
  for C := 0 to 3 do
    for R := 0 to 3 do
      Result.Data[C, R] := Data[R, C];
end;

function TMat4d.Determinant: Double;
var
  Work: TWork4Determinant;
  C: TIndex;
  R: TIndex;
begin
  for R := 0 to 3 do
    for C := 0 to 3 do
      Work[R, C] := Data[C, R];
  Result := DeterminantWork4(Work);
end;

function TMat4d.TryInverse(out AInverse: TMat4d): Boolean;
var
  Work: TWork4;
  C: TIndex;
  R: TIndex;
begin
  for R := 0 to 3 do
    for C := 0 to 3 do
    begin
      Work[R, C] := Data[C, R];
      Work[R, C + 4] := 0.0;
    end;
  Work[0, 4] := 1.0;
  Work[1, 5] := 1.0;
  Work[2, 6] := 1.0;
  Work[3, 7] := 1.0;
  if not MatrixWork4IsFinite(Work) then
  begin
    AInverse := Zero;
    Exit(False);
  end;

  Result := InvertWork4(Work, DOUBLE_INVERSE_EPSILON);
  if not Result then
  begin
    AInverse := Zero;
    Exit;
  end;

  for R := 0 to 3 do
    for C := 0 to 3 do
      AInverse.Data[C, R] := Work[R, C + 4];
end;

function TMat4d.Inverse: TMat4d;
begin
  if not TryInverse(Result) then
    raise EArgumentError.Create('TMat4d.Inverse: matrix is singular');
end;

class function TMat4d.Lerp(const AA, AB: TMat4d; const AT: Double): TMat4d;
var
  LC, LR: TIndex;
begin
  for LC := Low(TIndex) to High(TIndex) do
    for LR := Low(TIndex) to High(TIndex) do
      Result.Data[LC, LR] := nextpas.core.math.scalar.Lerp(AA.Data[LC, LR], AB.Data[LC, LR], AT);
end;

function TMat4d.MultPoint(const AVec: TVec3d): TVec3d;
begin
  Result := TVec3d.Create(
    Data[0, 0] * AVec.X + Data[1, 0] * AVec.Y + Data[2, 0] * AVec.Z + Data[3, 0],
    Data[0, 1] * AVec.X + Data[1, 1] * AVec.Y + Data[2, 1] * AVec.Z + Data[3, 1],
    Data[0, 2] * AVec.X + Data[1, 2] * AVec.Y + Data[2, 2] * AVec.Z + Data[3, 2]);
end;

function TMat4d.MultDirection(const AVec: TVec3d): TVec3d;
begin
  Result := TVec3d.Create(
    Data[0, 0] * AVec.X + Data[1, 0] * AVec.Y + Data[2, 0] * AVec.Z,
    Data[0, 1] * AVec.X + Data[1, 1] * AVec.Y + Data[2, 1] * AVec.Z,
    Data[0, 2] * AVec.X + Data[1, 2] * AVec.Y + Data[2, 2] * AVec.Z);
end;

function TMat4d.PerfectlyEquals(const AOther: TMat4d): Boolean;
var
  LC, LR: TIndex;
begin
  Result := True;
  for LC := Low(TIndex) to High(TIndex) do
    for LR := Low(TIndex) to High(TIndex) do
      if Data[LC, LR] <> AOther.Data[LC, LR] then
        Exit(False);
end;

end.
