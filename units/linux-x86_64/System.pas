unit System;

{$mode objfpc}{$H+}

interface

type
  TObject = class
    constructor Create;
    destructor Destroy; virtual;
    procedure Free;
  end;

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

end.
