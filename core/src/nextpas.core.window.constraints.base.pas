unit nextpas.core.window.constraints.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.window.base;

type
  { 约束强类型：4 字段封装 Min/Max，单源于 window.base（constraints.base 薄复用 alias 至 window.base，业务以 CONTRACT 为准），inline 零拷贝值语义；守 L0-L3 window.base 仅依赖 L0-L1。 }
  TWindowConstraints = nextpas.core.window.base.TWindowConstraints;

function DefaultWindowConstraints: TWindowConstraints; inline;
procedure CheckWindowConstraintsCore(const AConstraints: TWindowConstraints); // not inline: cold path 4-branch single source via constraints.base, avoid I-Cache bloat, zero-copy O(1), no heap

type
  EWindowConstraintsError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWindowConstraintInvalid = class(EWindowConstraintsError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

implementation

function DefaultWindowConstraints: TWindowConstraints; inline;
begin
  Result := TWindowConstraints.Default;
end;

procedure CheckWindowConstraintsCore(const AConstraints: TWindowConstraints);
begin
  // not inline cold path single source 4-branch Min/Max via constraints.base, zero-copy O(1) thin branch, no heap, shared by window.impl + window.constraints.impl
  if (AConstraints.MinWidth < 0) or (AConstraints.MinHeight < 0) then
    raise EWindowConstraintInvalid.CreateFmt('MinWidth/MinHeight must be >= 0 (got %d, %d)', [AConstraints.MinWidth, AConstraints.MinHeight]);
  if (AConstraints.MaxWidth < 0) or (AConstraints.MaxHeight < 0) then
    raise EWindowConstraintInvalid.CreateFmt('MaxWidth/MaxHeight must be >= 0 (got %d, %d)', [AConstraints.MaxWidth, AConstraints.MaxHeight]);
  if (AConstraints.MinWidth > 0) and (AConstraints.MaxWidth > 0)
    and (AConstraints.MaxWidth < AConstraints.MinWidth) then
    raise EWindowConstraintInvalid.CreateFmt('MaxWidth (%d) must be >= MinWidth (%d)', [AConstraints.MaxWidth, AConstraints.MinWidth]);
  if (AConstraints.MinHeight > 0) and (AConstraints.MaxHeight > 0)
    and (AConstraints.MaxHeight < AConstraints.MinHeight) then
    raise EWindowConstraintInvalid.CreateFmt('MaxHeight (%d) must be >= MinHeight (%d)', [AConstraints.MaxHeight, AConstraints.MinHeight]);
end;

class function EWindowConstraintsError.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EWindowConstraintInvalid.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

end.
