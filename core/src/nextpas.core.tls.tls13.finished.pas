{**
 * Unit: nextpas.core.tls.tls13.finished
 * Purpose: TLS 1.3 Finished verify_data 计算/校验（SHA-256 / SHA-384）
 *}

unit nextpas.core.tls.tls13.finished;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils;

function TLS13FinishedKeySHA256(const ATrafficSecret: TBytes): TBytes;
function TLS13FinishedKeySHA384(const ATrafficSecret: TBytes): TBytes;
function TLS13ComputeFinishedVerifyDataSHA256(const AFinishedKey, ATranscriptHash: TBytes): TBytes;
function TLS13ComputeFinishedVerifyDataSHA384(const AFinishedKey, ATranscriptHash: TBytes): TBytes;
function TLS13ComputeFinishedVerifyDataFromTrafficSecretSHA256(
  const ATrafficSecret, ATranscriptHash: TBytes
): TBytes;
function TLS13ComputeFinishedVerifyDataFromTrafficSecretSHA384(
  const ATrafficSecret, ATranscriptHash: TBytes
): TBytes;
function TLS13VerifyFinishedSHA256(
  const ATrafficSecret, ATranscriptHash, APeerVerifyData: TBytes
): Boolean;
function TLS13VerifyFinishedSHA384(
  const ATrafficSecret, ATranscriptHash, APeerVerifyData: TBytes
): Boolean;

function TLS13FinishedKeyForCipherSuite(
  ACipherSuite: Word;
  const ATrafficSecret: TBytes
): TBytes;
function TLS13ComputeFinishedVerifyDataForCipherSuite(
  ACipherSuite: Word;
  const AFinishedKey, ATranscriptHash: TBytes
): TBytes;
function TLS13ComputeFinishedVerifyDataFromTrafficSecretForCipherSuite(
  ACipherSuite: Word;
  const ATrafficSecret, ATranscriptHash: TBytes
): TBytes;
function TLS13VerifyFinishedForCipherSuite(
  ACipherSuite: Word;
  const ATrafficSecret, ATranscriptHash, APeerVerifyData: TBytes
): Boolean;

implementation

uses
  nextpas.core.tls.errors,
  nextpas.core.crypto.constant_time,
  nextpas.core.crypto.hmac, nextpas.core.tls.keyschedule.labels,
  nextpas.core.tls.tls13.keyschedule;

const
  TLS13_SHA256_HASH_SIZE = 32;
  TLS13_SHA384_HASH_SIZE = 48;

function TLS13FinishedKeySHA256(const ATrafficSecret: TBytes): TBytes;
var
  LEmpty: TBytes;
begin
  if Length(ATrafficSecret) <> TLS13_SHA256_HASH_SIZE then
    RaiseInvalidParameter('TLS13TrafficSecret');

  SetLength(LEmpty, 0);
  Result := TLS13_HKDF_Expand_Label_SHA256(
    ATrafficSecret,
    'finished',
    LEmpty,
    TLS13_SHA256_HASH_SIZE
  );
end;

function TLS13FinishedKeySHA384(const ATrafficSecret: TBytes): TBytes;
var
  LEmpty: TBytes;
begin
  if Length(ATrafficSecret) <> TLS13_SHA384_HASH_SIZE then
    RaiseInvalidParameter('TLS13TrafficSecret');

  SetLength(LEmpty, 0);
  Result := TLS13_HKDF_Expand_Label_SHA384(
    ATrafficSecret,
    'finished',
    LEmpty,
    TLS13_SHA384_HASH_SIZE
  );
end;

function TLS13ComputeFinishedVerifyDataSHA256(const AFinishedKey, ATranscriptHash: TBytes): TBytes;
begin
  if Length(AFinishedKey) <> TLS13_SHA256_HASH_SIZE then
    RaiseInvalidParameter('TLS13FinishedKey');
  if Length(ATranscriptHash) <> TLS13_SHA256_HASH_SIZE then
    RaiseInvalidParameter('TLS13TranscriptHash');

  Result := HMAC_SHA256(AFinishedKey, ATranscriptHash);
end;

function TLS13ComputeFinishedVerifyDataSHA384(const AFinishedKey, ATranscriptHash: TBytes): TBytes;
begin
  if Length(AFinishedKey) <> TLS13_SHA384_HASH_SIZE then
    RaiseInvalidParameter('TLS13FinishedKey');
  if Length(ATranscriptHash) <> TLS13_SHA384_HASH_SIZE then
    RaiseInvalidParameter('TLS13TranscriptHash');

  Result := HMAC_SHA384(AFinishedKey, ATranscriptHash);
end;

function TLS13ComputeFinishedVerifyDataFromTrafficSecretSHA256(
  const ATrafficSecret, ATranscriptHash: TBytes
): TBytes;
var
  LFinishedKey: TBytes;
begin
  LFinishedKey := TLS13FinishedKeySHA256(ATrafficSecret);
  Result := TLS13ComputeFinishedVerifyDataSHA256(LFinishedKey, ATranscriptHash);
end;

function TLS13ComputeFinishedVerifyDataFromTrafficSecretSHA384(
  const ATrafficSecret, ATranscriptHash: TBytes
): TBytes;
var
  LFinishedKey: TBytes;
begin
  LFinishedKey := TLS13FinishedKeySHA384(ATrafficSecret);
  Result := TLS13ComputeFinishedVerifyDataSHA384(LFinishedKey, ATranscriptHash);
end;

function TLS13VerifyFinishedSHA256(
  const ATrafficSecret, ATranscriptHash, APeerVerifyData: TBytes
): Boolean;
var
  LExpected: TBytes;
begin
  LExpected := TLS13ComputeFinishedVerifyDataFromTrafficSecretSHA256(
    ATrafficSecret,
    ATranscriptHash
  );

  Result := TConstantTime.CompareBytes(LExpected, APeerVerifyData) = 1;
end;

function TLS13VerifyFinishedSHA384(
  const ATrafficSecret, ATranscriptHash, APeerVerifyData: TBytes
): Boolean;
var
  LExpected: TBytes;
begin
  LExpected := TLS13ComputeFinishedVerifyDataFromTrafficSecretSHA384(
    ATrafficSecret,
    ATranscriptHash
  );

  Result := TConstantTime.CompareBytes(LExpected, APeerVerifyData) = 1;
end;

function TLS13FinishedKeyForCipherSuite(
  ACipherSuite: Word;
  const ATrafficSecret: TBytes
): TBytes;
begin
  if TLS13CipherSuiteIsSHA256(ACipherSuite) then
    Exit(TLS13FinishedKeySHA256(ATrafficSecret));

  if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    Exit(TLS13FinishedKeySHA384(ATrafficSecret));

  RaiseInvalidParameter('TLS13CipherSuite');
end;

function TLS13ComputeFinishedVerifyDataForCipherSuite(
  ACipherSuite: Word;
  const AFinishedKey, ATranscriptHash: TBytes
): TBytes;
begin
  if TLS13CipherSuiteIsSHA256(ACipherSuite) then
    Exit(TLS13ComputeFinishedVerifyDataSHA256(AFinishedKey, ATranscriptHash));

  if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    Exit(TLS13ComputeFinishedVerifyDataSHA384(AFinishedKey, ATranscriptHash));

  RaiseInvalidParameter('TLS13CipherSuite');
end;

function TLS13ComputeFinishedVerifyDataFromTrafficSecretForCipherSuite(
  ACipherSuite: Word;
  const ATrafficSecret, ATranscriptHash: TBytes
): TBytes;
begin
  if TLS13CipherSuiteIsSHA256(ACipherSuite) then
    Exit(TLS13ComputeFinishedVerifyDataFromTrafficSecretSHA256(ATrafficSecret, ATranscriptHash));

  if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    Exit(TLS13ComputeFinishedVerifyDataFromTrafficSecretSHA384(ATrafficSecret, ATranscriptHash));

  RaiseInvalidParameter('TLS13CipherSuite');
end;

function TLS13VerifyFinishedForCipherSuite(
  ACipherSuite: Word;
  const ATrafficSecret, ATranscriptHash, APeerVerifyData: TBytes
): Boolean;
begin
  if TLS13CipherSuiteIsSHA256(ACipherSuite) then
    Exit(TLS13VerifyFinishedSHA256(ATrafficSecret, ATranscriptHash, APeerVerifyData));

  if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    Exit(TLS13VerifyFinishedSHA384(ATrafficSecret, ATranscriptHash, APeerVerifyData));

  RaiseInvalidParameter('TLS13CipherSuite');
end;

end.
