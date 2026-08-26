unit nextpas.core.ssh.keys;

{** nextpas.core.ssh - 私钥容器解析。
 *
 * 当前支持：OpenSSH "openssh-key-v1" 未加密容器中的 ssh-ed25519 密钥。
 * 加密容器（bcrypt_pbkdf + aes256-ctr）明确抛 sekUnsupported，
 * 属于后续 slice（见 docs/ssh/goal-tree.md）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system.sysutils,
  nextpas.core.base,
  nextpas.core.text.strings,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer;

type
  { 已解析的客户端私钥 }
  TSshPrivateKey = record
    Kind: TSshHostKeyAlg;
    Ed25519Seed: TBytes;   { 32 字节种子（Ed25519 签名输入）}
  end;

{** 解析 PEM 形式的 openssh-key-v1 容器内容。
 * 成功时返回 True 并给出私钥与其公钥 wire blob（用于 publickey 认证）。*}
function SshLoadPrivateKey(const AContent: string;
  out AKey: TSshPrivateKey; out APubBlob: TBytes): Boolean;

implementation

uses
  nextpas.core.encoding.base64;

{ 按 '#' 换行切分（替代 SysUtils 字符串助手的多分隔符 Split）}
function SplitBase64Junk(const AValue: string): TStringArray;
var
  I: Integer;
  LChunk: string;

  procedure Flush;
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := LChunk;
    LChunk := '';
  end;

begin
  Result := nil;
  LChunk := '';
  for I := 1 to Length(AValue) do
    if (AValue[I] = '#') or (AValue[I] = #10) or (AValue[I] = #13) then
      Flush
    else
      LChunk := LChunk + AValue[I];
  Flush;
end;

const
  OPENSSH_KEY_MAGIC: array[0..14] of Byte = (
    Ord('o'), Ord('p'), Ord('e'), Ord('n'), Ord('s'), Ord('s'), Ord('h'),
    Ord('-'), Ord('k'), Ord('e'), Ord('y'), Ord('-'), Ord('v'), Ord('1'), 0);

function ExtractBase64Body(const AContent: string): string;
var
  I: Integer;
  LBeginMark, LEndMark: Integer;
  LLine: string;
  LLines: TStringArray;
const
  MARK_BEGIN = '-----BEGIN OPENSSH PRIVATE KEY-----';
  MARK_END = '-----END OPENSSH PRIVATE KEY-----';
begin
  Result := '';
  LBeginMark := Pos(MARK_BEGIN, AContent);
  LEndMark := Pos(MARK_END, AContent);
  if LBeginMark <= 0 then
    raise ESSHError.Create(sekKeyFormat,
      'ssh keys: not an openssh-key-v1 container (missing BEGIN marker)');
  if LEndMark <= 0 then
    raise ESSHError.Create(sekKeyFormat, 'ssh keys: missing END marker');
  LLine := Copy(AContent, LBeginMark + Length(MARK_BEGIN),
    LEndMark - LBeginMark - Length(MARK_BEGIN));
  LLines := SplitBase64Junk(LLine);
  for I := 0 to High(LLines) do
    Result := Result + Trim(LLines[I]);
end;

function SshLoadPrivateKey(const AContent: string;
  out AKey: TSshPrivateKey; out APubBlob: TBytes): Boolean;
var
  LBlob: TBytes;
  LR: TsshReader;
  LCipher, LKdf, LKeyType, LComment: string;
  LNKeys: UInt32;
  LPrivSection: TBytes;
  LCheck1, LCheck2: UInt32;
  LPubInPriv, LPrivRaw: TBytes;
  I: Integer;
begin
  Result := False;
  AKey := Default(TSshPrivateKey);
  APubBlob := nil;

  LBlob := Base64Decode(ExtractBase64Body(AContent));
  LR := TsshReader.Create(LBlob);
  try
    if SizeUInt(Length(LBlob)) < SizeUInt(Length(OPENSSH_KEY_MAGIC)) then
      raise ESSHError.Create(sekKeyFormat, 'ssh keys: container too short');
    for I := 0 to High(OPENSSH_KEY_MAGIC) do
      if LR.ReadByte <> OPENSSH_KEY_MAGIC[I] then
        raise ESSHError.Create(sekKeyFormat, 'ssh keys: bad magic');

    LCipher := LR.ReadStringText;
    LKdf := LR.ReadStringText;
    LR.ReadStringBytes;              { kdfoptions }
    if (LCipher <> 'none') or (LKdf <> 'none') then
      raise ESSHError.Create(sekUnsupported,
        'ssh keys: encrypted openssh containers not supported yet');
    LNKeys := LR.ReadUInt32;
    if LNKeys <> 1 then
      raise ESSHError.Create(sekKeyFormat, 'ssh keys: expected exactly one key');
    APubBlob := LR.ReadStringBytes;
    LPrivSection := LR.ReadStringBytes;
  finally
    LR.Free;
  end;

  LR := TsshReader.Create(LPrivSection);
  try
    LCheck1 := LR.ReadUInt32;
    LCheck2 := LR.ReadUInt32;
    if LCheck1 <> LCheck2 then
      raise ESSHError.Create(sekKeyFormat, 'ssh keys: checkint mismatch');
    LKeyType := LR.ReadStringText;
    if LKeyType <> 'ssh-ed25519' then
      raise ESSHError.Create(sekUnsupported,
        'ssh keys: only unencrypted ed25519 supported yet, got "' + LKeyType + '"');
    AKey.Kind := hkEd25519;
    LPubInPriv := LR.ReadStringBytes;
    LPrivRaw := LR.ReadStringBytes;
    if Length(LPrivRaw) < 32 then
      raise ESSHError.Create(sekKeyFormat, 'ssh keys: ed25519 private section too short');
    SetLength(AKey.Ed25519Seed, 32);
    Move(LPrivRaw[0], AKey.Ed25519Seed[0], 32);
    { 公钥段应与 priv64 后半一致；宽松校验长度即可 }
    if Length(LPubInPriv) <> 32 then
      raise ESSHError.Create(sekKeyFormat, 'ssh keys: ed25519 embedded pubkey not 32 bytes');
    LComment := LR.ReadStringText;    { 忽略注释 }
  finally
    LR.Free;
  end;
  Result := True;
end;

end.
