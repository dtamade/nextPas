unit nextpas.core.window.input.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.text.view;

type
  TWindowInputKind = (wikKeyDown, wikKeyUp, wikMouseDown, wikMouseUp, wikMouseMove, wikWheel, wikTouch, wikImeCommit);

  TWindowInputEventView = record
    Kind: TWindowInputKind;
    KeyCode: Integer;
    X: Integer;
    Y: Integer;
    DeltaX: Integer;
    DeltaY: Integer;
    Text: TStringView;
  end;

  TWindowInputEvent = record
    Kind: TWindowInputKind;
    KeyCode: Integer;
    X: Integer;
    Y: Integer;
    DeltaX: Integer;
    DeltaY: Integer;
    Text: string;
  end;

  TWindowInputOptions = record
    EnableKey: Boolean;
    EnableMouse: Boolean;
    EnableTouch: Boolean;
    EnableIme: Boolean;
  end;

function DefaultWindowInputOptions: TWindowInputOptions; inline;

// view/managed layered helpers — inline O(1) zero-copy via TStringView.FromStr/ToString/ToSpan (bytes.ops TByteSpan single source), no alloc for view, single Move for managed copy; resource not lost: managed string auto-finalized, view non-owning
function WindowInputEventToView(const AEvent: TWindowInputEvent): TWindowInputEventView; inline;
function WindowInputEventFromView(const AView: TWindowInputEventView): TWindowInputEvent; inline;
function WindowInputViewTextSpan(const AView: TWindowInputEventView): TByteSpan; inline;

type
  EWindowInputError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWindowInputInvalidOptions = class(EWindowInputError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

implementation

function DefaultWindowInputOptions: TWindowInputOptions; inline;
begin
  Result.EnableKey := True;
  Result.EnableMouse := True;
  Result.EnableTouch := False;
  Result.EnableIme := False;
end;

function WindowInputEventToView(const AEvent: TWindowInputEvent): TWindowInputEventView; inline;
begin
  Result.Kind := AEvent.Kind;
  Result.KeyCode := AEvent.KeyCode;
  Result.X := AEvent.X;
  Result.Y := AEvent.Y;
  Result.DeltaX := AEvent.DeltaX;
  Result.DeltaY := AEvent.DeltaY;
  Result.Text := TStringView.FromStr(AEvent.Text);
end;

function WindowInputEventFromView(const AView: TWindowInputEventView): TWindowInputEvent; inline;
begin
  Result.Kind := AView.Kind;
  Result.KeyCode := AView.KeyCode;
  Result.X := AView.X;
  Result.Y := AView.Y;
  Result.DeltaX := AView.DeltaX;
  Result.DeltaY := AView.DeltaY;
  Result.Text := AView.Text.ToString;
end;

function WindowInputViewTextSpan(const AView: TWindowInputEventView): TByteSpan; inline;
begin
  Result := AView.Text.ToSpan;
end;

class function EWindowInputError.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EWindowInputInvalidOptions.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

end.
