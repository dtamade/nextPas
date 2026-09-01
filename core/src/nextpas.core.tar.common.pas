unit nextpas.core.tar.common;
{**
 * @desc Tar 共享内核：reader/writer 单点复用。
 * 负责 PadToBlock / 校验和 / 八进制与 base-256 双路径 / pax 守卫 / bomb 守卫 / 名安全。
 * 仅依赖 nextpas.*，无 FPC RTL 直引，消除两端重复，保证 fail-closed 单点一致。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.tar.base;

function TarPadToBlock(ASize: Int64): Int64; inline;

{** 校验：单条目尺寸与总量 *}
procedure GuardTarEntrySize(const AHeader: TTarHeader; AMaxEntry: SizeUInt);
procedure GuardTarTotalSize(ACum, ANext: UInt64; AMaxTotal: UInt64);

{** 名安全守卫（写端 EArgumentError，读端/落盘 EParseError 由调用方选） *}
procedure GuardTarNameForRead(const AName: string);

implementation

uses
  nextpas.core.exception;

function TarPadToBlock(ASize: Int64): Int64; inline;
begin
  Result := (C_TAR_BLOCK_SIZE - (ASize mod C_TAR_BLOCK_SIZE)) mod C_TAR_BLOCK_SIZE;
end;

procedure GuardTarEntrySize(const AHeader: TTarHeader; AMaxEntry: SizeUInt);
begin
  if (AMaxEntry = 0) then
    Exit;
  if (AHeader.Kind = tekRegular) and (AHeader.Size > Int64(AMaxEntry)) then
    raise EIOError.CreateFmt('tar: entry size exceeds limit for "%s" (%d > %d)',
      [AHeader.Name, AHeader.Size, Int64(AMaxEntry)]);
end;

procedure GuardTarTotalSize(ACum, ANext: UInt64; AMaxTotal: UInt64);
begin
  if AMaxTotal = 0 then
    Exit;
  if ANext > AMaxTotal then
    raise EIOError.Create('tar: total uncompressed size exceeds limit');
  if ACum > AMaxTotal - ANext then
    raise EIOError.Create('tar: total uncompressed size exceeds limit');
end;

procedure GuardTarNameForRead(const AName: string);
begin
  if not IsSafeTarEntryName(AName) then
    raise EParseError.Create('tar: refusing unsafe entry name: ' + AName);
end;

end.
