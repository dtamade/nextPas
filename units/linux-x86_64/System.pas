unit System;

{$mode objfpc}{$H+}

interface

type
  TObject = class
    constructor Create;
    destructor Destroy; virtual;
    procedure Free;
  end;

  TInterfacedObject = class(TObject)
    constructor Create;
    function _AddRef: Integer; virtual;
    function _Release: Integer; virtual;
  end;

  Exception = class(TObject)
    FMessage: Integer;
    constructor Create(Code: Integer);
    function GetCode: Integer; virtual;
  end;

  EAbort = class(Exception);
  ERangeError = class(Exception);
  EDivByZero = class(Exception);

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

constructor TInterfacedObject.Create;
begin
end;

function TInterfacedObject._AddRef: Integer;
begin
  Result := 1;
end;

function TInterfacedObject._Release: Integer;
begin
  Result := 0;
end;

constructor Exception.Create(Code: Integer);
begin
  FMessage := Code;
end;

function Exception.GetCode: Integer;
begin
  Result := FMessage;
end;

end.
