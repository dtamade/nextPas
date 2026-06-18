unit System;

{$mode objfpc}{$H+}

interface

type
  TObject = class
    constructor Create;
    destructor Destroy; virtual;
    procedure Free;
  end;

  // stage0 临时 stub：实际 refcount 由编译器 HIR intrinsic 驱动 runtime
  // 不是最终 ABI，待自举后替换为完整实现（含 QueryInterface）
  TInterfacedObject = class(TObject)
    constructor Create;
    function _AddRef: LongInt; virtual;
    function _Release: LongInt; virtual;
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

function TInterfacedObject._AddRef: LongInt;
begin
  Result := 1;
end;

function TInterfacedObject._Release: LongInt;
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
