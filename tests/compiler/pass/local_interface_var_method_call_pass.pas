program local_interface_var_method_call_pass;

{$mode objfpc}{$H+}

type
  IRequest = interface
    ['{66666666-6666-6666-6666-666666666666}']
  end;

  IClient = interface
    ['{77777777-7777-7777-7777-777777777777}']
    function Send(const AReq: IRequest): Integer;
  end;

  TRequest = class(TInterfacedObject, IRequest)
  end;

  TClient = class(TInterfacedObject, IClient)
  public
    function Send(const AReq: IRequest): Integer;
    function Post: Integer;
  end;

function NewRequest: IRequest;
begin
  Result := TRequest.Create;
end;

function TClient.Send(const AReq: IRequest): Integer;
begin
  if AReq = nil then
    Exit(0);
  Result := 13;
end;

function TClient.Post: Integer;
var
  LReq: IRequest;
begin
  LReq := NewRequest;
  Result := Send(LReq);
end;

var
  Client: TClient;
begin
  Client := TClient.Create;
  if Client.Post <> 13 then
    Halt(1);
  Client.Free;
end.
