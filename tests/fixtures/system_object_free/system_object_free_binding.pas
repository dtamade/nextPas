program SystemObjectFreeBinding;

uses
  System;

type
  TWorker = class
  end;

var
  Worker: TWorker;

begin
  Worker.Free;
end.
