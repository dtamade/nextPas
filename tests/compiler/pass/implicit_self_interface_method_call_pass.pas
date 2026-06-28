program implicit_self_interface_method_call_pass;

{$mode objfpc}{$H+}

type
  IRequest = interface
    ['{44444444-4444-4444-4444-444444444444}']
  end;

  IClient = interface
    ['{55555555-5555-5555-5555-555555555555}']
    function Send(const AReq: IRequest): Integer;
  end;

  TRequest = class(TInterfacedObject, IRequest)
  end;

  TClient = class(TInterfacedObject, IClient)
  public
    function Send(const AReq: IRequest): Integer;
    function Post(const AReq: IRequest): Integer;
  end;

function TClient.Send(const AReq: IRequest): Integer;
begin
  if AReq = nil then
    Exit(0);
  Result := 11;
end;

function TClient.Post(const AReq: IRequest): Integer;
begin
  Result := Send(AReq);
end;

var
  Client: TClient;
  Request: IRequest;
begin
  Client := TClient.Create;
  Request := TRequest.Create;
  if Client.Post(Request) <> 11 then
    Halt(1);
  Client.Free;
end.
