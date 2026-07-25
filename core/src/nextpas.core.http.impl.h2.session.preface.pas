unit nextpas.core.http.impl.h2.session.preface;
{**
 * @desc H2 server client-preface validation free functions.
 *       Mechanical extract from impl.h2.session (behavior freeze).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.http.impl.h2.frame,
  nextpas.core.http.impl.h2.types;

type
  TH2PrefaceStatus = (
    h2psNeedMore,
    h2psOk,
    h2psConnectionError
  );

function H2ValidateServerPreface(const ABuf: PAnsiChar; const ALen: SizeUInt;
  out AConsumed: SizeUInt; out AErrorCode: UInt32): TH2PrefaceStatus;

implementation

function H2PrefaceResult(const AStatus: TH2PrefaceStatus;
  const AConsumed: SizeUInt; const AErrorCode: UInt32; out AOutConsumed: SizeUInt;
  out AOutErrorCode: UInt32): TH2PrefaceStatus;
begin
  AOutConsumed := AConsumed;
  AOutErrorCode := AErrorCode;
  Result := AStatus;
end;

function H2PrefacePrefixMatches(const ABuf: PAnsiChar;
  const ALen: SizeUInt): Boolean;
var
  LI: SizeUInt;
begin
  if ALen = 0 then
    Exit(True);

  if ABuf = nil then
    Exit(False);

  for LI := 0 to ALen - 1 do
  begin
    if ABuf[LI] <> H2_CLIENT_PREFACE[LI + 1] then
      Exit(False);
  end;

  Result := True;
end;

function H2ValidateServerPreface(const ABuf: PAnsiChar; const ALen: SizeUInt;
  out AConsumed: SizeUInt; out AErrorCode: UInt32): TH2PrefaceStatus;
var
  LFrame: TH2Frame;
  LFrameBytes: SizeUInt;
  LFrameBuf: PAnsiChar;
  LFrameError: UInt32;
  LFrameLen: SizeUInt;
begin
  if ALen < SizeUInt(Length(H2_CLIENT_PREFACE)) then
  begin
    if H2PrefacePrefixMatches(ABuf, ALen) then
      Exit(H2PrefaceResult(h2psNeedMore, 0, H2_ERR_NO_ERROR, AConsumed,
        AErrorCode));

    Exit(H2PrefaceResult(h2psConnectionError, 0, H2_ERR_PROTOCOL_ERROR,
      AConsumed, AErrorCode));
  end;

  if not H2PrefacePrefixMatches(ABuf, Length(H2_CLIENT_PREFACE)) then
    Exit(H2PrefaceResult(h2psConnectionError, 0, H2_ERR_PROTOCOL_ERROR,
      AConsumed, AErrorCode));

  LFrameLen := ALen - Length(H2_CLIENT_PREFACE);
  if LFrameLen < H2_FRAME_HEADER_SIZE then
    Exit(H2PrefaceResult(h2psNeedMore, 0, H2_ERR_NO_ERROR, AConsumed,
      AErrorCode));

  LFrameBuf := @ABuf[Length(H2_CLIENT_PREFACE)];
  if not H2DecodeFrame(LFrameBuf, LFrameLen, LFrame, LFrameBytes) then
    Exit(H2PrefaceResult(h2psNeedMore, 0, H2_ERR_NO_ERROR, AConsumed,
      AErrorCode));

  if not H2ValidateFrame(LFrame, H2_DEFAULT_MAX_FRAME_SIZE, LFrameError) then
    Exit(H2PrefaceResult(h2psConnectionError, 0, LFrameError, AConsumed,
      AErrorCode));

  if LFrame.Header.FrameType <> H2_FRAME_SETTINGS then
    Exit(H2PrefaceResult(h2psConnectionError, 0, H2_ERR_PROTOCOL_ERROR,
      AConsumed, AErrorCode));

  if (LFrame.Header.Flags and H2_FLAG_SETTINGS_ACK) <> 0 then
    Exit(H2PrefaceResult(h2psConnectionError, 0, H2_ERR_PROTOCOL_ERROR,
      AConsumed, AErrorCode));

  Result := H2PrefaceResult(h2psOk,
    Length(H2_CLIENT_PREFACE) + LFrameBytes, H2_ERR_NO_ERROR, AConsumed,
    AErrorCode);
end;

end.