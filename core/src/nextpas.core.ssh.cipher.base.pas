unit nextpas.core.ssh.cipher.base;

{** nextpas.core.ssh.cipher.base - 包加密共享常量与轻量工具（四件套 base）。
 *  单源：算法名判定与 KDF 长度表；大端读写薄转发单源 bytes.binary；边界守卫 RequireLen。
 *  Owner: crypto/hash 为实现侧，base 仅暴露纯常量与无状态判定，保持零堆分配。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.binary,
  nextpas.core.ssh.errors;

const
  CHACHA_KEY_TOTAL = 64;
  CHACHA_TAG = 16;
  GCM_TAG = 16;
  CHACHA_PAD_BLOCK = 8;
  AES_PAD_BLOCK = 16;
  GCM_SEQ_THRESHOLD = UInt64($FFFFFF00);

function IsChachaName(const AName: string): Boolean; inline;
function IsGcmName(const AName: string): Boolean; inline;
function IsCtrName(const AName: string): Boolean; inline;

function SshCipherSupported(const ACipher: string): Boolean;
function SshMacSupported(const AMac: string): Boolean;
function SshCipherKeySize(const ACipher: string): Integer;
function SshCipherIvSize(const ACipher: string): Integer;
function SshMacKeySize(const AMac: string): Integer;
function SshCipherRequiresMac(const ACipher: string): Boolean;

procedure PutU32BE(var ADst: TBytes; APos: SizeUInt; AValue: UInt32); inline;
function U32BEOf(const ASrc: TBytes; APos: SizeUInt): UInt32; inline;
procedure RequireLen(const ABuf: TBytes; ANeeded: Integer; const AWhat: string);

implementation

function IsChachaName(const AName: string): Boolean;
begin
  Result := AName = 'chacha20-poly1305@openssh.com';
end;

function IsGcmName(const AName: string): Boolean;
begin
  Result := (AName = 'aes128-gcm@openssh.com') or (AName = 'aes256-gcm@openssh.com')
    or (AName = 'aes128-gcm') or (AName = 'aes256-gcm');
end;

function IsCtrName(const AName: string): Boolean;
begin
  Result := (AName = 'aes128-ctr') or (AName = 'aes192-ctr') or (AName = 'aes256-ctr');
end;

function SshCipherSupported(const ACipher: string): Boolean;
begin
  Result := (ACipher = '') or IsChachaName(ACipher) or IsGcmName(ACipher) or IsCtrName(ACipher);
end;

function SshMacSupported(const AMac: string): Boolean;
begin
  Result := (AMac = '')
    or (AMac = 'hmac-sha2-256-etm@openssh.com')
    or (AMac = 'hmac-sha2-512-etm@openssh.com');
end;

function SshCipherKeySize(const ACipher: string): Integer;
begin
  if ACipher = '' then
    Exit(0);
  if IsChachaName(ACipher) then
    Exit(CHACHA_KEY_TOTAL);
  if IsGcmName(ACipher) then
  begin
    if (ACipher = 'aes256-gcm@openssh.com') or (ACipher = 'aes256-gcm') then
      Exit(32);
    Exit(16);
  end;
  if IsCtrName(ACipher) then
  begin
    if ACipher = 'aes128-ctr' then
      Exit(16);
    if ACipher = 'aes192-ctr' then
      Exit(24);
    Exit(32);
  end;
  raise ESSHError.Create(sekNegotiation, 'ssh cipher: unsupported cipher "' + ACipher + '"');
end;

function SshCipherIvSize(const ACipher: string): Integer;
begin
  if IsChachaName(ACipher) then
    Result := 0
  else if IsGcmName(ACipher) then
    Result := 12
  else if IsCtrName(ACipher) then
    Result := 16
  else
    Result := 0;
end;

function SshMacKeySize(const AMac: string): Integer;
begin
  if AMac = 'hmac-sha2-256-etm@openssh.com' then
    Result := 32 // SHA256_DIGEST_SIZE, avoid hash.base same-layer dep; base keeps pure constants
  else if AMac = 'hmac-sha2-512-etm@openssh.com' then
    Result := 64 // SHA512_DIGEST_SIZE
  else
    Result := 0;
end;

function SshCipherRequiresMac(const ACipher: string): Boolean;
begin
  Result := IsCtrName(ACipher);
end;

procedure PutU32BE(var ADst: TBytes; APos: SizeUInt; AValue: UInt32); inline;
begin
  WriteUInt32BE(PByte(@ADst[APos]), AValue);
end;

function U32BEOf(const ASrc: TBytes; APos: SizeUInt): UInt32; inline;
begin
  Result := ReadUInt32BE(PByte(@ASrc[APos]));
end;

procedure RequireLen(const ABuf: TBytes; ANeeded: Integer; const AWhat: string);
begin
  if Length(ABuf) < ANeeded then
    raise ESSHError.Create(sekProtocol, 'ssh cipher: ' + AWhat + ' too short');
end;

end.
