unit nextpas.core.window.queue.base;

{ window.queue base — 纯数据类型，零行为，单源 via window.base；守四件套 base←intf，L2 shard 家族内，inline 零拷贝。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base;

type
  TWindowWorkKind = (wwkRef, wwkMethod, wwkProc);
  TWindowWorkItem = record
    Kind: TWindowWorkKind;
    Ref: TWindowProcRef;
    Method: TWindowProcMethod;
    Proc: TWindowProc;
  end;
  TWindowCowCtx = record
    NewRing: array of TWindowWorkItem;
    OldRing: array of TWindowWorkItem;
    OldHead, OldCap, OldCount: Integer;
    Kind: TWindowWorkKind;
    Ref: TWindowProcRef;
    Method: TWindowProcMethod;
    Proc: TWindowProc;
    WasEmpty: Boolean;
  end;
  PWindowWorkItem = ^TWindowWorkItem;
  PWindowProcRef = ^TWindowProcRef;
  PWindowProcMethod = ^TWindowProcMethod;
  PWindowProc = ^TWindowProc;

implementation

end.
