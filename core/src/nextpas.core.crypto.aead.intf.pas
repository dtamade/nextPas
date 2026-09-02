unit nextpas.core.crypto.aead.intf;

{$I nextpas.core.settings.inc}

{ nextpas.core.crypto.aead.intf — AEAD 域接口契约
  base ← intf. 复用 bytes.ops TByteSpan 零拷贝, SecureZero 清理. }

interface

uses
  nextpas.core.base,
  nextpas.core.crypto.aead.base;

type
  IAeadCipher = interface
    ['{D2E3F4A5-B6C7-0003-ABCD-1234567890AC}']
    function Seal(const AKey, ANonce, APlaintext, AAAD: TBytes; out ACiphertext, ATag: TBytes): Boolean;
    function Open(const AKey, ANonce, ACiphertext, AAAD, ATag: TBytes; out APlaintext: TBytes): Boolean;
    function NonceSize: Integer;
    function TagSize: Integer;
    function KeySize: Integer;
  end;

function AEADIsValidKeyNonce(const AKey: TBytes; AAlgo: TAeadAlgo; const ANonce: TBytes): Boolean; inline;
function AEADIsValidTag(const ATag: TBytes; AAlgo: TAeadAlgo): Boolean; inline;

implementation

uses
  nextpas.core.bytes.ops;

function AEADIsValidKeyNonce(const AKey: TBytes; AAlgo: TAeadAlgo; const ANonce: TBytes): Boolean; inline;
begin
  case AAlgo of
    aeadAES128GCM: Result := (Length(AKey)=AEAD_GCM_KEY_SIZE_128) and (Length(ANonce)=AEAD_GCM_NONCE_SIZE);
    aeadAES256GCM: Result := (Length(AKey)=AEAD_GCM_KEY_SIZE_256) and (Length(ANonce)=AEAD_GCM_NONCE_SIZE);
    aeadChaCha20Poly1305: Result := (Length(AKey)=AEAD_CHACHA_KEY_SIZE) and (Length(ANonce)=AEAD_CHACHA_NONCE_SIZE);
    else Result := (Length(AKey) in [AEAD_GCM_KEY_SIZE_128,AEAD_GCM_KEY_SIZE_256]) and (Length(ANonce)=AEAD_GCM_NONCE_SIZE);
  end;
end;

function AEADIsValidTag(const ATag: TBytes; AAlgo: TAeadAlgo): Boolean; inline;
begin
  case AAlgo of
    aeadChaCha20Poly1305: Result := Length(ATag)=AEAD_CHACHA_TAG_SIZE;
    else Result := Length(ATag)=AEAD_GCM_TAG_SIZE;
  end;
end;

end.
