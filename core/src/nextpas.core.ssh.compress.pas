unit nextpas.core.ssh.compress;

{** nextpas.core.ssh - 压缩：zlib / zlib@openssh.com。
 *
 * 有状态流式封装（每方向持一个 z_stream，Z_SYNC_FLUSH 逐包刷出，保留滑动窗口），
 * 兼容 OpenSSH 的延迟/即时两种激活语义。爆炸防护在解压侧强制。
 * 仅依赖 nextpas.core.compress.base 的 Level 映射与 zlib 符号，不拉取
 * IWriter/IReader 流式外壳。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.ssh.errors;

const
  SSH_COMP_NONE = 'none';
  SSH_COMP_ZLIB = 'zlib';
  SSH_COMP_ZLIB_OPENSSH = 'zlib@openssh.com';

  SSH_COMP_MAX_DECOMPRESSED = 1024 * 1024; { 1 MiB，约 4× MAX_PACKET，防 bomb }

type
  ISshCompressor = interface
    ['{A7B2C9D1-5E4F-4A8B-9C00-000000000001}']
    function Compress(const AData: TBytes): TBytes;
    function Decompress(const AData: TBytes): TBytes;
    procedure Reset;
  end;

function CreateSshZlibCompressor: ISshCompressor;
function SshCompressionIsZlib(const AName: string): Boolean; inline;
function SshCompressionIsDelayed(const AName: string): Boolean; inline;

implementation

uses
  nextpas.core.compress.zlib.ffi,
  nextpas.core.compress.base,
  nextpas.core.text.conv;

function SshCompressionIsZlib(const AName: string): Boolean;
begin
  Result := (AName = SSH_COMP_ZLIB) or (AName = SSH_COMP_ZLIB_OPENSSH);
end;

function SshCompressionIsDelayed(const AName: string): Boolean;
begin
  Result := AName = SSH_COMP_ZLIB_OPENSSH;
end;

type
  TSshZlibCompressor = class(TInterfacedObject, ISshCompressor)
  private
    FDeflate: z_stream;
    FInflate: z_stream;
    FDeflateInited: Boolean;
    FInflateInited: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function Compress(const AData: TBytes): TBytes;
    function Decompress(const AData: TBytes): TBytes;
    procedure Reset;
  end;

constructor TSshZlibCompressor.Create;
begin
  inherited Create;
  FillChar(FDeflate, SizeOf(FDeflate), 0);
  FillChar(FInflate, SizeOf(FInflate), 0);
  if deflateInit(FDeflate, LevelToZlib(clDefault)) <> Z_OK then
    raise ESSHError.Create(sekCrypto, 'ssh compress: deflateInit failed');
  FDeflateInited := True;
  if inflateInit(FInflate) <> Z_OK then
  begin
    deflateEnd(FDeflate);
    raise ESSHError.Create(sekCrypto, 'ssh compress: inflateInit failed');
  end;
  FInflateInited := True;
end;

destructor TSshZlibCompressor.Destroy;
begin
  if FDeflateInited then
    deflateEnd(FDeflate);
  if FInflateInited then
    inflateEnd(FInflate);
  inherited;
end;

procedure TSshZlibCompressor.Reset;
begin
  if FDeflateInited then
  begin
    deflateEnd(FDeflate);
    FillChar(FDeflate, SizeOf(FDeflate), 0);
    if deflateInit(FDeflate, LevelToZlib(clDefault)) <> Z_OK then
      raise ESSHError.Create(sekCrypto, 'ssh compress: deflate reinit failed');
  end;
  if FInflateInited then
  begin
    inflateEnd(FInflate);
    FillChar(FInflate, SizeOf(FInflate), 0);
    if inflateInit(FInflate) <> Z_OK then
      raise ESSHError.Create(sekCrypto, 'ssh compress: inflate reinit failed');
  end;
end;

function TSshZlibCompressor.Compress(const AData: TBytes): TBytes;
var
  LInLen: SizeUInt;
  LCap, LOutLen: SizeUInt;
  LAvail: LongWord;
  LRet: Int32;
  LDummy: Byte;
begin
  Result := nil;
  LInLen := SizeUInt(Length(AData));
  if LInLen > 0 then
  begin
    FDeflate.next_in := pBytef(@AData[0]);
    FDeflate.avail_in := LongWord(LInLen);
  end
  else
  begin
    LDummy := 0;
    FDeflate.next_in := pBytef(@LDummy);
    FDeflate.avail_in := 0;
  end;
  LCap := LInLen + 128;
  if LCap < 128 then LCap := 128;
  SetLength(Result, LCap);
  LOutLen := 0;
  repeat
    if LOutLen >= LCap then
    begin
      if LCap > High(SizeUInt) div 2 then
        LCap := LCap + 65536
      else
        LCap := LCap * 2;
      SetLength(Result, LCap);
    end;
    FDeflate.next_out := pBytef(@Result[LOutLen]);
    FDeflate.avail_out := LongWord(LCap - LOutLen);
    LAvail := FDeflate.avail_out;
    LRet := deflate(FDeflate, Z_SYNC_FLUSH);
    if (LRet <> Z_OK) and (LRet <> Z_BUF_ERROR) then
      raise ESSHError.Create(sekCrypto, 'ssh compress: deflate failed (' + IntToStr(LRet) + ')');
    LOutLen := LOutLen + SizeUInt(LAvail - FDeflate.avail_out);
    if FDeflate.avail_in = 0 then
      Break;
  until False;
  { deflate with Z_SYNC_FLUSH should have consumed all input; if not, loop }
  while FDeflate.avail_in > 0 do
  begin
    if LOutLen >= LCap then
    begin
      if LCap > High(SizeUInt) div 2 then LCap := LCap + 65536 else LCap := LCap * 2;
      SetLength(Result, LCap);
    end;
    FDeflate.next_out := pBytef(@Result[LOutLen]);
    FDeflate.avail_out := LongWord(LCap - LOutLen);
    LAvail := FDeflate.avail_out;
    LRet := deflate(FDeflate, Z_SYNC_FLUSH);
    if (LRet <> Z_OK) and (LRet <> Z_BUF_ERROR) then
      raise ESSHError.Create(sekCrypto, 'ssh compress: deflate failed (' + IntToStr(LRet) + ')');
    LOutLen := LOutLen + SizeUInt(LAvail - FDeflate.avail_out);
  end;
  SetLength(Result, LOutLen);
end;

function TSshZlibCompressor.Decompress(const AData: TBytes): TBytes;
var
  LInLen: SizeUInt;
  LCap, LOutLen: SizeUInt;
  LAvail: LongWord;
  LRet: Int32;
begin
  Result := nil;
  LInLen := SizeUInt(Length(AData));
  if LInLen = 0 then
    Exit(nil);
  try
    FInflate.next_in := pBytef(@AData[0]);
    FInflate.avail_in := LongWord(LInLen);
    LCap := LInLen * 3;
    if LCap < 256 then LCap := 256;
    if LCap > SSH_COMP_MAX_DECOMPRESSED then LCap := SSH_COMP_MAX_DECOMPRESSED;
    SetLength(Result, LCap);
    LOutLen := 0;
    repeat
      if LOutLen >= LCap then
      begin
        if LCap >= SSH_COMP_MAX_DECOMPRESSED then
          raise ESSHError.Create(sekProtocol, 'ssh compress: decompressed size exceeds limit');
        if LCap > SSH_COMP_MAX_DECOMPRESSED div 2 then
          LCap := SSH_COMP_MAX_DECOMPRESSED
        else
          LCap := LCap * 2;
        SetLength(Result, LCap);
      end;
      FInflate.next_out := pBytef(@Result[LOutLen]);
      FInflate.avail_out := LongWord(LCap - LOutLen);
      LAvail := FInflate.avail_out;
      LRet := inflate(FInflate, Z_SYNC_FLUSH);
      if (LRet <> Z_OK) and (LRet <> Z_BUF_ERROR) and (LRet <> Z_STREAM_END) then
      begin
        if LRet = Z_DATA_ERROR then
          raise ESSHError.Create(sekProtocol, 'ssh compress: corrupt stream');
        raise ESSHError.Create(sekProtocol, 'ssh compress: inflate failed (' + IntToStr(LRet) + ')');
      end;
      LOutLen := LOutLen + SizeUInt(LAvail - FInflate.avail_out);
      if LOutLen > SSH_COMP_MAX_DECOMPRESSED then
        raise ESSHError.Create(sekProtocol, 'ssh compress: decompressed size exceeds limit');
      if (FInflate.avail_in = 0) and (FInflate.avail_out > 0) then
        Break;
      if LRet = Z_STREAM_END then
        Break;
    until False;
    if FInflate.avail_in <> 0 then
      raise ESSHError.Create(sekProtocol, 'ssh compress: trailing bytes after stream');
    SetLength(Result, LOutLen);
  except
    on E: Exception do
    begin
      try Reset; except end;
      raise;
    end;
  end;
end;

function CreateSshZlibCompressor: ISshCompressor;
begin
  Result := TSshZlibCompressor.Create;
end;

end.
