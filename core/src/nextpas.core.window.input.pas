unit nextpas.core.window.input;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.input.base,
  nextpas.core.window.input.intf,
  nextpas.core.window.input.impl;

type
  TWindowInputKind = nextpas.core.window.input.base.TWindowInputKind;
  TWindowInputEvent = nextpas.core.window.input.base.TWindowInputEvent;
  TWindowInputEventView = nextpas.core.window.input.base.TWindowInputEventView;
  TWindowInputOptions = nextpas.core.window.input.base.TWindowInputOptions;
  EWindowInputError = nextpas.core.window.input.base.EWindowInputError;
  EWindowInputInvalidOptions = nextpas.core.window.input.base.EWindowInputInvalidOptions;
  IWindowInput = nextpas.core.window.input.intf.IWindowInput;
  TWindowInputHandler = nextpas.core.window.input.intf.TWindowInputHandler;
  TWindowInputMethod = nextpas.core.window.input.intf.TWindowInputMethod;
  TWindowInputProc = nextpas.core.window.input.intf.TWindowInputProc;
  TWindowInputViewHandler = nextpas.core.window.input.intf.TWindowInputViewHandler;
  TWindowInputViewMethod = nextpas.core.window.input.intf.TWindowInputViewMethod;
  TWindowInputViewProc = nextpas.core.window.input.intf.TWindowInputViewProc;

function DefaultWindowInputOptions: TWindowInputOptions; inline;
procedure CheckWindowInputOptions(const AOptions: TWindowInputOptions); inline;
function WindowInputGrowCapacity(ACurrent: Integer): Integer; inline;
function WindowInputEventToView(const AEvent: TWindowInputEvent): TWindowInputEventView; inline;
function WindowInputEventFromView(const AView: TWindowInputEventView): TWindowInputEvent; inline;
function WindowInputViewTextSpan(const AView: TWindowInputEventView): TByteSpan; inline;

implementation

function DefaultWindowInputOptions: TWindowInputOptions; inline;
begin
  Result := nextpas.core.window.input.base.DefaultWindowInputOptions;
end;

procedure CheckWindowInputOptions(const AOptions: TWindowInputOptions); inline;
begin
  nextpas.core.window.input.impl.CheckWindowInputOptions(AOptions);
end;

function WindowInputGrowCapacity(ACurrent: Integer): Integer; inline;
begin
  Result := nextpas.core.window.input.impl.WindowInputGrowCapacity(ACurrent);
end;

function WindowInputEventToView(const AEvent: TWindowInputEvent): TWindowInputEventView; inline;
begin
  Result := nextpas.core.window.input.base.WindowInputEventToView(AEvent);
end;

function WindowInputEventFromView(const AView: TWindowInputEventView): TWindowInputEvent; inline;
begin
  Result := nextpas.core.window.input.base.WindowInputEventFromView(AView);
end;

function WindowInputViewTextSpan(const AView: TWindowInputEventView): TByteSpan; inline;
begin
  Result := nextpas.core.window.input.base.WindowInputViewTextSpan(AView);
end;

end.
