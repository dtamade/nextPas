unit System;

{$mode objfpc}{$H+}

interface

type
  TObject = class
    constructor Create;
    destructor Destroy; virtual;
    procedure Free;
  end;

procedure np_process_init;
procedure np_process_fini;

implementation

constructor TObject.Create;
begin
end;

destructor TObject.Destroy;
begin
end;

procedure TObject.Free;
begin
end;

procedure np_process_init;
begin
  { stub: will be filled with actual runtime initialization }
end;

procedure np_process_fini;
begin
  { stub: will be filled with actual runtime finalization }
end;

end.
