unit nextpas.core.crypto.aesctr;

{** nextpas.core.crypto.aesctr - AES-CTR keystream stream, single source for ssh cipher + key containers.
 *
 *  Owner: nextpas.core.crypto (L2). Provides TAesCtrStream record with cross-packet
 *  keystream state (FKSOff residual) and AesCtrCrypt helper. Single allocation,
 *  cross-packet persist via value semantics, Done zeroizes keystream + expanded keys.
 *
 *  Backends: AES-NI (128/256) -> ct64 -> naive (192 fallback). XorInplace via bytes.ops.
 *  L2 discipline: no ssh dependency, raises ECryptoError on contract violation.
 *}

{$mode ObjFPC}{$H+}{$J-}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.base,
  nextpas.core.crypto.aesgcm,
  nextpas.core.crypto.aesni,
  nextpas.core.crypto.aes.ct64,
  nextpas.core.crypto.errors;

type
  TAesCtrKind = (akNi128, akNi256, akCt64, akNaive);
  TAesCtrStream = record
    FKind: TAesCtrKind;
    FNiKey128: TAESNIExpandedKey128;
    FNiKey256: TAESNIExpandedKey256;
    FCt64Key: TAESCt64Key;
    FExpanded: TAESExpandedKey;
    FNr: Integer;
    FCtr: TAESBlock;
    FKS: TAESBlock;
    FKSOff: Integer;
    FKSValid: Boolean;
    procedure RefreshKS; inline;
    procedure IncCounter; inline;
    procedure Init(const AKey, AIV: TBytes);
    procedure Done; inline;
    procedure XorInto(var AData: TBytes; AOffset, ACount: SizeUInt);
  end;

function AesCtrCrypt(const AKey, AIV, AInput: TBytes): TBytes;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.mem.secure;

procedure TAesCtrStream.Init(const AKey, AIV: TBytes);
var
  LKey16: TAESNIBlock;
begin
  SecureZeroMemory(@FCtr[0], SizeOf(FCtr));
  SecureZeroMemory(@FKS[0], SizeOf(FKS));
  SecureZeroMemory(@FNiKey128[0], SizeOf(FNiKey128));
  SecureZeroMemory(@FNiKey256[0], SizeOf(FNiKey256));
  SecureZeroMemory(@FCt64Key, SizeOf(FCt64Key));
  SecureZeroMemory(@FExpanded[0], SizeOf(FExpanded));
  if Length(AIV) <> 16 then
    RaiseCryptoError(cecInvalidArgument, 'aesctr: invalid iv length');
  FKSValid := False;
  FKSOff := 0;
  FNr := 0;
  Move(AIV[0], FCtr[0], 16);
  case Length(AKey) of
    16:
      if IsAESNIAvailable then
      begin
        FKind := akNi128;
        Move(AKey[0], LKey16[0], 16);
        AESNIExpandKey128(LKey16, FNiKey128);
      end
      else
      begin
        FKind := akCt64;
        AESCt64KeyExpand(Copy(AKey, 0, Length(AKey)), FCt64Key);
      end;
    32:
      if IsAESNIAvailable then
      begin
        FKind := akNi256;
        AESNIExpandKey256(AKey, FNiKey256);
      end
      else
      begin
        FKind := akCt64;
        AESCt64KeyExpand(Copy(AKey, 0, Length(AKey)), FCt64Key);
      end;
  else
    begin
      if not (Length(AKey) in [16, 24, 32]) then
        RaiseCryptoError(cecInvalidArgument, 'aesctr: invalid key length');
      FKind := akNaive;
      AESKeyExpand(Copy(AKey, 0, Length(AKey)), FExpanded, FNr);
    end;
  end;
end;

procedure TAesCtrStream.Done;
begin
  SecureZeroMemory(@FCtr[0], SizeOf(FCtr));
  SecureZeroMemory(@FKS[0], SizeOf(FKS));
  SecureZeroMemory(@FNiKey128[0], SizeOf(FNiKey128));
  SecureZeroMemory(@FNiKey256[0], SizeOf(FNiKey256));
  SecureZeroMemory(@FCt64Key, SizeOf(FCt64Key));
  SecureZeroMemory(@FExpanded[0], SizeOf(FExpanded));
  FKSOff := 0;
  FKSValid := False;
  FNr := 0;
end;

procedure TAesCtrStream.RefreshKS;
begin
  case FKind of
    akNi128:
      AESNIEncryptBlock128(TAESNIBlock(FCtr), TAESNIBlock(FKS), FNiKey128);
    akNi256:
      AESNIEncryptBlock256(TAESNIBlock(FCtr), TAESNIBlock(FKS), FNiKey256);
    akCt64:
      AESCt64EncryptBlock(@FCtr[0], @FKS[0], FCt64Key);
  else
    AESEncryptBlock(FCtr, FKS, FExpanded, FNr);
  end;
  FKSValid := True;
end;

procedure TAesCtrStream.IncCounter;
var
  I: Integer;
begin
  I := 15;
  while I >= 0 do
  begin
    Inc(FCtr[I]);
    if FCtr[I] <> 0 then
      Break;
    Dec(I);
  end;
end;

procedure TAesCtrStream.XorInto(var AData: TBytes; AOffset, ACount: SizeUInt);
var
  LDst: PByte;
  LRem, LChunk: SizeUInt;
begin
  if ACount = 0 then Exit;
  LDst := @AData[AOffset];
  LRem := ACount;
  if FKSValid and (FKSOff > 0) and (FKSOff < 16) then
  begin
    LChunk := SizeUInt(16 - FKSOff);
    if LChunk > LRem then LChunk := LRem;
    XorInplace(LDst, @FKS[FKSOff], LChunk);
    Inc(LDst, LChunk);
    Inc(FKSOff, Integer(LChunk));
    Dec(LRem, LChunk);
    if LRem = 0 then Exit;
  end;
  while LRem > 0 do
  begin
    if (not FKSValid) or (FKSOff >= 16) then
    begin
      if FKSOff >= 16 then IncCounter;
      RefreshKS;
      FKSOff := 0;
    end;
    if (LRem >= 16) and (FKSOff = 0) then
    begin
      XorInplace(LDst, @FKS[0], 16);
      Inc(LDst, 16);
      Dec(LRem, 16);
      FKSOff := 16;
    end else
    begin
      LChunk := SizeUInt(16 - FKSOff);
      if LChunk > LRem then LChunk := LRem;
      XorInplace(LDst, @FKS[FKSOff], LChunk);
      Inc(LDst, LChunk);
      Inc(FKSOff, Integer(LChunk));
      Dec(LRem, LChunk);
    end;
  end;
end;

function AesCtrCrypt(const AKey, AIV, AInput: TBytes): TBytes;
var
  LStream: TAesCtrStream;
begin
  if Length(AInput) = 0 then
    Exit(nil);
  if (Length(AKey) <> 16) and (Length(AKey) <> 24) and (Length(AKey) <> 32) then
    RaiseCryptoError(cecInvalidArgument, 'aesctr: invalid aes key length');
  if Length(AIV) <> 16 then
    RaiseCryptoError(cecInvalidArgument, 'aesctr: invalid aes iv length');
  Result := Copy(AInput, 0, Length(AInput));
  LStream.Init(AKey, AIV);
  try
    LStream.XorInto(Result, 0, SizeUInt(Length(Result)));
  finally
    LStream.Done;
  end;
end;

end.
