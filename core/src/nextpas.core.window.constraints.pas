unit nextpas.core.window.constraints;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.constraints.base,
  nextpas.core.window.constraints.intf,
  nextpas.core.window.constraints.impl,
  nextpas.core.window.base;

type
  TWindowConstraints = nextpas.core.window.constraints.base.TWindowConstraints;
  EWindowConstraintsError = nextpas.core.window.constraints.base.EWindowConstraintsError;
  EWindowConstraintInvalid = nextpas.core.window.constraints.base.EWindowConstraintInvalid;
  IWindowConstraints = nextpas.core.window.constraints.intf.IWindowConstraints;
  TWindowConstraintsImpl = nextpas.core.window.constraints.impl.TWindowConstraintsImpl;

function DefaultWindowConstraints: TWindowConstraints; inline;
procedure CheckWindowConstraints(const AConstraints: TWindowConstraints); inline;
procedure CheckWindowConstraintsForOptions(const AOptions: TWindowOptions); inline;
procedure ValidateWindowMinMax(AMinWidth, AMinHeight, AMaxWidth, AMaxHeight: Integer); inline;
function WindowConstraintsGrowCapacity(ACurrent: Integer): Integer; inline;
function CreateWindowConstraints: IWindowConstraints; inline; overload;
function CreateWindowConstraints(const AConstraints: TWindowConstraints): IWindowConstraints; inline; overload;

implementation

function DefaultWindowConstraints: TWindowConstraints; inline;
begin
  Result := nextpas.core.window.constraints.base.DefaultWindowConstraints;
end;

procedure CheckWindowConstraints(const AConstraints: TWindowConstraints); inline;
begin
  nextpas.core.window.constraints.impl.CheckWindowConstraints(AConstraints);
end;

procedure CheckWindowConstraintsForOptions(const AOptions: TWindowOptions); inline;
begin
  nextpas.core.window.constraints.impl.CheckWindowConstraintsForOptions(AOptions);
end;

procedure ValidateWindowMinMax(AMinWidth, AMinHeight, AMaxWidth, AMaxHeight: Integer); inline;
begin
  nextpas.core.window.constraints.impl.ValidateWindowMinMax(AMinWidth, AMinHeight, AMaxWidth, AMaxHeight);
end;

function WindowConstraintsGrowCapacity(ACurrent: Integer): Integer; inline;
begin
  Result := nextpas.core.window.constraints.impl.WindowConstraintsGrowCapacity(ACurrent);
end;

function CreateWindowConstraints: IWindowConstraints; inline; overload;
begin
  Result := nextpas.core.window.constraints.impl.CreateWindowConstraints;
end;

function CreateWindowConstraints(const AConstraints: TWindowConstraints): IWindowConstraints; inline; overload;
begin
  Result := nextpas.core.window.constraints.impl.CreateWindowConstraints(AConstraints);
end;

end.
