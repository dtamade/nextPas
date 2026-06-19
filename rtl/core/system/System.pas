unit System;

{$mode objfpc}{$H+}

interface

type
  TObject = class
    constructor Create;
    destructor Destroy; virtual;
    procedure Free;
  end;

procedure np_process_init; cdecl;
procedure np_process_fini; cdecl;

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

procedure np_process_init; cdecl; external name 'np_process_init';
procedure np_process_fini; cdecl; external name 'np_process_fini';

end.
