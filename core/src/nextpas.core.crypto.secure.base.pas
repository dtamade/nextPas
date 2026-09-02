unit nextpas.core.crypto.secure.base;

{$I nextpas.core.settings.inc}

{ nextpas.core.crypto.secure.base — 随机/常量时间域公共载体 (L2 crypto)
  Owner: crypto 依赖 platform.random (owner 反哺). 纯常量, L0-L1+hash. }

interface

const
  SECURE_RANDOM_MAX_CHUNK = 65536;
  SECURE_CT_SELECT_MASK = $FF;
  SECURE_ZERO_FILL = 0;

type
  TSecureRandomPolicy = record
    MaxChunk: Integer;
    ZeroOnFail: Boolean;
    class function Default: TSecureRandomPolicy; static; inline;
  end;

implementation

class function TSecureRandomPolicy.Default: TSecureRandomPolicy; static; inline;
begin
  Result.MaxChunk := SECURE_RANDOM_MAX_CHUNK;
  Result.ZeroOnFail := True;
end;

end.
