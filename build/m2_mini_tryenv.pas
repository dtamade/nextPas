program m2_mini_tryenv;

uses SysUtils;

type
  EEnvError = class(Exception);

procedure FailLike(const AMsg: string);
begin
  WriteLn('fail msg=', AMsg);
end;

function LoadCfg(const AName: string): string;
begin
  if AName = 'bad' then
    raise EEnvError.Create('cfg broken');
  Result := AName + '.toml';
end;

procedure RunEnvLike(const AName: string);
var
  Cfg: string;
begin
  try
    Cfg := LoadCfg(AName);
  except
    on E: EEnvError do
      FailLike(E.Message);
  end;
  WriteLn('mode=env');
  WriteLn('target=', AName, ' len=', Length(Cfg));
end;

begin
  RunEnvLike('ok');
  RunEnvLike('bad');
end.
