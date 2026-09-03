unit nextpas.core.audio.bank.base;

{$I nextpas.core.settings.inc}

interface

type
  TAudioBankId = Integer;
  TBankVoiceId = Integer;

  TBankPlayParams = record
    Gain: Single;
    Pan: Single;
    Pitch: Single;
    Loop: Boolean;
    class function Default: TBankPlayParams; static;
  end;

const
  CAudioBankIdInvalid = 0;
  CAudioBankVoiceInvalid = 0;

implementation

class function TBankPlayParams.Default: TBankPlayParams;
begin
  Result.Gain := 1.0;
  Result.Pan := 0.0;
  Result.Pitch := 1.0;
  Result.Loop := False;
end;

end.
