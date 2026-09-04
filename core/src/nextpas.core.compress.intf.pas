unit nextpas.core.compress.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.base,
  nextpas.core.io.intf;

type
  ICompressWriter = interface(IWriter)
    ['{D1E2F3A4-B5C6-7890-ABCD-400000000001}']
    procedure Flush;
    procedure Close;
  end;

  IDecompressReader = interface(IReader)
    ['{D1E2F3A4-B5C6-7890-ABCD-400000000002}']
    procedure Close;
  end;

{ L2→L2解耦门面：sevenz等容器经此单一owner访问Deflate/BZip2能力，避免直连具体实现；
  单源复用 bytes.ops零拷贝哲学，异常判别单源避免Pos漂移 }
function CompressIsLimitExceededMsg(const AMsg: string): Boolean; inline;
function CompressIsLimitExceeded(const E: Exception): Boolean; inline;
function CompressBZip2IsAvailable: Boolean; inline;
function CompressBZip2DecompressWithMax(const AData: TBytes;
  const AMax: SizeUInt): TBytes; inline;
function CompressDeflateDecompressWithMax(const AData: TBytes;
  const AMax: SizeUInt): TBytes; inline;
function CompressRawDeflateMessageDecompressWithMax(const AData: TBytes;
  const AMax: SizeUInt): TBytes; inline;

implementation

uses
  nextpas.core.compress.deflate,
  nextpas.core.compress.bzip2;

function CompressIsLimitExceededMsg(const AMsg: string): Boolean; inline;
begin
  // perf: inline single Pos scan; single source for limit detection, avoids duplication in callers
  Result := Pos('exceeds limit', LowerCase(AMsg)) > 0;
end;

function CompressIsLimitExceeded(const E: Exception): Boolean; inline;
begin
  if E = nil then Exit(False);
  Result := Pos('exceeds limit', LowerCase(E.Message)) > 0;
end;

function CompressBZip2IsAvailable: Boolean; inline;
begin
  // thin inline forward, zero overhead, owner boundary via intf
  Result := BZip2FfiIsAvailable;
end;

function CompressBZip2DecompressWithMax(const AData: TBytes;
  const AMax: SizeUInt): TBytes; inline;
begin
  // perf: inline forward, single allocation inside impl, zero-copy view reused
  Result := BZip2DecompressWithMaxOutputSize(AData, AMax);
end;

function CompressDeflateDecompressWithMax(const AData: TBytes;
  const AMax: SizeUInt): TBytes; inline;
begin
  Result := DeflateDecompressWithMaxOutputSize(AData, AMax);
end;

function CompressRawDeflateMessageDecompressWithMax(const AData: TBytes;
  const AMax: SizeUInt): TBytes; inline;
begin
  Result := RawDeflateMessageDecompress(AData, AMax);
end;

end.
