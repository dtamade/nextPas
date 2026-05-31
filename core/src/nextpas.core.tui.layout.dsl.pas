unit nextpas.core.tui.layout.dsl;

{**
 * @desc layout 之上的便利 DSL——常用约束与切分的短名封装。
 *
 *   Fixed(N)    = LengthConstraint(N)
 *   Flex(W)     = FillConstraint(W)
 *   Pct(N)      = PercentageConstraint(N)
 *   AtLeast(N)  = MinConstraint(N)
 *   AtMost(N)   = MaxConstraint(N)
 *   V(Area, Cs) = VerticalSplit(Area, Cs)
 *   H(Area, Cs) = HorizontalSplit(Area, Cs)
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.layout;

function Fixed(AN: Word): TConstraint; inline;
function Flex(AWeight: Word = 1): TConstraint; inline;
function Pct(AN: Word): TConstraint; inline;
function AtLeast(AN: Word): TConstraint; inline;
function AtMost(AN: Word): TConstraint; inline;

function V(const AArea: TRect; const ACs: array of TConstraint): TRectArray;
function H(const AArea: TRect; const ACs: array of TConstraint): TRectArray;

implementation

function Fixed(AN: Word): TConstraint;
begin
  Result := LengthConstraint(AN);
end;

function Flex(AWeight: Word = 1): TConstraint;
begin
  Result := FillConstraint(AWeight);
end;

function Pct(AN: Word): TConstraint;
begin
  Result := PercentageConstraint(AN);
end;

function AtLeast(AN: Word): TConstraint;
begin
  Result := MinConstraint(AN);
end;

function AtMost(AN: Word): TConstraint;
begin
  Result := MaxConstraint(AN);
end;

function V(const AArea: TRect; const ACs: array of TConstraint): TRectArray;
begin
  Result := VerticalSplit(AArea, ACs);
end;

function H(const AArea: TRect; const ACs: array of TConstraint): TRectArray;
begin
  Result := HorizontalSplit(AArea, ACs);
end;

end.
