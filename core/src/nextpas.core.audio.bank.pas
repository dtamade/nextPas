unit nextpas.core.audio.bank;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base,
  nextpas.core.audio.bank.base,
  nextpas.core.audio.bank.intf,
  nextpas.core.audio.bank.impl,
  nextpas.core.audio.intf;

type
  TAudioBankId = nextpas.core.audio.bank.base.TAudioBankId;
  TBankVoiceId = nextpas.core.audio.bank.base.TBankVoiceId;
  TBankPlayParams = nextpas.core.audio.bank.base.TBankPlayParams;
  IAudioBank = nextpas.core.audio.bank.intf.IAudioBank;

function CreateAudioBank(const AFormat: TAudioFormat): IAudioBank; inline;

implementation

function CreateAudioBank(const AFormat: TAudioFormat): IAudioBank; inline;
begin
  Result := nextpas.core.audio.bank.impl.CreateAudioBank(AFormat);
end;

end.
