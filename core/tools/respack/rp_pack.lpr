program rp_pack;
{$I nextpas.core.settings.inc}
{** @desc respack 嵌入工具链 CLI（S4）。薄壳：全部格式逻辑在
    nextpas.core.respack.embed / dirsource / writer，本程序只做参数解析、
    IO 编排与错误出口。

  用法:
    rp_pack build   --src DIR --out FILE.pack [--include GLOB]... [--exclude GLOB]...
                    [--strip-prefix P/] [--add-prefix P/]
                    [--dedup] [--no-hash] [--digest sha256]
    rp_pack inc     --src DIR (--const NAME | --unit NAME) --out FILE.pas
                    [同 build 的过滤/映射/digest 选项]
    rp_pack extract --pack FILE.pack --out DIR
    rp_pack list    --pack FILE.pack }
uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.hash.intf,
  nextpas.core.hash.sha256,
  nextpas.core.respack,
  nextpas.core.respack.base;

const
  HEXD: array[0..15] of AnsiChar = '0123456789ABCDEF';

procedure Usage;
begin
  WriteLn('usage: see header comment of rp_pack.lpr');
end;

type
  { 解析后的公共选项面 }
  TOpts = record
    SrcDir: string;
    OutFile: string;
    PackFile: string;
    ConstName: string;
    UnitName: string;
    IncludeGlobs: TStringArray;
    ExcludeGlobs: TStringArray;
    StripPrefix: string;
    AddPrefix: string;
    Dedup: Boolean;
    Hashes: Boolean;
    Digest: string;   { '' | 'sha256' }
  end;

procedure AddGlob(var AList: TStringArray; const AValue: string);
begin
  SetLength(AList, Length(AList) + 1);
  AList[Length(AList) - 1] := AValue;
end;

function ParseArgs(out O: TOpts): Boolean;
var
  I: Integer;
  Key: string;
  Fail: Boolean;

  { 取当前值并前移；I 由调用方先指向 key 再统一 Inc }
  function TakeVal: string;
  begin
    if Fail or (I > ParamCount) then
    begin
      WriteLn('missing value for ', Key);
      Fail := True;
      Result := '';
      Exit;
    end;
    Result := ParamStr(I);
    Inc(I);
  end;

begin
  O.SrcDir := ''; O.OutFile := ''; O.PackFile := '';
  O.ConstName := ''; O.UnitName := '';
  O.IncludeGlobs := nil; O.ExcludeGlobs := nil;
  O.StripPrefix := ''; O.AddPrefix := '';
  O.Dedup := False; O.Hashes := True; O.Digest := '';
  Result := False;
  Fail := False;
  I := 2;   { ParamStr(1) = 子命令 }
  while (I <= ParamCount) and (not Fail) do
  begin
    Key := ParamStr(I);
    Inc(I);
    if Key = '--include' then
      AddGlob(O.IncludeGlobs, TakeVal)
    else if Key = '--exclude' then
      AddGlob(O.ExcludeGlobs, TakeVal)
    else if Key = '--strip-prefix' then
      O.StripPrefix := TakeVal
    else if Key = '--add-prefix' then
      O.AddPrefix := TakeVal
    else if Key = '--dedup' then
      O.Dedup := True
    else if Key = '--no-hash' then
      O.Hashes := False
    else if Key = '--digest' then
      O.Digest := TakeVal
    else if Key = '--src' then
      O.SrcDir := TakeVal
    else if Key = '--out' then
      O.OutFile := TakeVal
    else if Key = '--pack' then
      O.PackFile := TakeVal
    else if Key = '--const' then
      O.ConstName := TakeVal
    else if Key = '--unit' then
      O.UnitName := TakeVal
    else
    begin
      WriteLn('unknown option: ', Key);
      Exit;
    end;
  end;
  Result := not Fail;
end;

function MakeEmbedOpts(const O: TOpts): TResPackEmbedOptions;
begin
  Result := ResPackDefaultEmbedOptions;
  Result.IncludeGlobs := O.IncludeGlobs;
  Result.ExcludeGlobs := O.ExcludeGlobs;
  Result.StripPrefix := O.StripPrefix;
  Result.AddPrefix := O.AddPrefix;
  Result.Build.Deduplicate := O.Dedup;
  Result.Build.Hashes := O.Hashes;
  { digest 算法注入：SHA-256 属 hash 域，CLI 侧组装（格式层保持零加密依赖）。
    无状态闭包，无捕获生命期问题。 }
  if O.Digest = 'sha256' then
    Result.Build.DigestFunc :=
      procedure(const AData: PByte; const ASize: SizeUInt;
        const ADigestOut: PByte)
      var
        H: IHasher;
      begin
        H := NewSHA256;
        if ASize > 0 then
          H.Write(AData^, ASize);
        H.Sum(ADigestOut^, RESPACK_DIGEST_SIZE);
      end
  else if O.Digest <> '' then
    raise EResPackError.Create('rp_pack: unsupported digest algorithm "' +
      O.Digest + '" (only sha256)');
end;

procedure CmdBuild(const O: TOpts);
var
  Blob: TResPackBlob;
  RP: TResPack;
  OutBytes: TBytes;
begin
  Blob := ResPackEmbedBuild(O.SrcDir, MakeEmbedOpts(O));
  try
    RP := ResPackOpen(Blob.Data, Blob.Size);
    try
      WriteLn('entries: ', RP.Count, '  blob bytes: ', Blob.Size,
        '  -> ', O.OutFile);
    finally
      RP.Close;
    end;
    SetLength(OutBytes, SizeInt(Blob.Size));
    Move(Blob.Data^, OutBytes[0], Blob.Size);
    WriteFile(O.OutFile, OutBytes);
  finally
    ResPackFreeBlob(Blob);
  end;
end;

procedure CmdInc(const O: TOpts);
var
  Blob: TResPackBlob;
  TextOut: TBytes;
  IOpts: TResPackIncOptions;
  L: TOpts;
begin
  if (O.ConstName = '') and (O.UnitName = '') then
    raise EResPackError.Create('rp_pack inc: need --const NAME or --unit NAME');
  L := O;
  if L.UnitName <> '' then
    L.ConstName := L.UnitName + '_BYTES';
  Blob := ResPackEmbedBuild(L.SrcDir, MakeEmbedOpts(L));
  try
    IOpts := ResPackDefaultIncOptions;
    IOpts.ConstName := L.ConstName;
    if L.UnitName <> '' then
      TextOut := ResPackEmbedIncUnitSource(Blob, IOpts, L.UnitName)
    else
      TextOut := ResPackEmbedIncSource(Blob, IOpts);
    WriteFile(L.OutFile, TextOut);
    WriteLn('wrote ', Length(TextOut), ' bytes of Pascal source -> ',
      L.OutFile);
  finally
    ResPackFreeBlob(Blob);
  end;
end;

procedure CmdExtract(const O: TOpts);
var
  PackedBytes: TBytes;
  Blob: TResPackBlob;
begin
  PackedBytes := ReadFile(O.PackFile);
  Blob.Data := @PackedBytes[0];
  Blob.Size := SizeUInt(Length(PackedBytes));
  Blob.Owned := False;
  ResPackExtractToDir(Blob, O.OutFile);
  WriteLn('extracted ', O.PackFile, ' -> ', O.OutFile);
end;

procedure CmdList(const O: TOpts);
var
  PackedBytes: TBytes;
  RP: TResPack;
  I: SizeUInt;
  E: TResPackEntry;
  PathP: PChar;
  PathPB: PByte;
  PathLen: SizeUInt;
  P: string;
  S: TByteSpan;
begin
  PackedBytes := ReadFile(O.PackFile);
  RP := ResPackOpen(@PackedBytes[0], SizeUInt(Length(PackedBytes)));
  try
    WriteLn('entries: ', RP.Count, '  total: ', Length(PackedBytes),
      '  digests: ', RP.HasDigests);
    if RP.Count > 0 then
      for I := 0 to RP.Count - 1 do
      begin
        E := RP.EntryAt(I);
        S := RP.StoredPathSpanOf(E);
        PathPB := S.Data;
        PathLen := S.Len;
        PathP := PChar(PathPB);
        SetLength(P, SizeInt(PathLen));
        if PathLen > 0 then
          Move(PathP^, Pointer(P)^, PathLen);
        Write('  ', P, '  size=', E.Size, ' mod=', E.ModTime);
        if (E.Flags and RESPACK_EFLAG_HASHED) <> 0 then
        begin
          Write(' fnv=');
          Write(HEXD[E.Hash shr 28], HEXD[(E.Hash shr 24) and 15],
            HEXD[(E.Hash shr 20) and 15], HEXD[(E.Hash shr 16) and 15],
            HEXD[(E.Hash shr 12) and 15], HEXD[(E.Hash shr 8) and 15],
            HEXD[(E.Hash shr 4) and 15], HEXD[E.Hash and 15]);
        end;
        WriteLn('');
      end;
  finally
    RP.Close;
  end;
end;

var
  Opts: TOpts;
begin
  try
    if ParamCount < 1 then
    begin
      Usage;
      Halt(2);
    end;
    if not ParseArgs(Opts) then
      Halt(2);
    if ParamStr(1) = 'build' then
    begin
      if (Opts.SrcDir = '') or (Opts.OutFile = '') then
      begin
        WriteLn('build requires --src DIR and --out FILE');
        Halt(2);
      end;
      CmdBuild(Opts);
    end
    else if ParamStr(1) = 'inc' then
    begin
      if (Opts.SrcDir = '') or (Opts.OutFile = '') then
      begin
        WriteLn('inc requires --src DIR and --out FILE');
        Halt(2);
      end;
      CmdInc(Opts);
    end
    else if ParamStr(1) = 'extract' then
    begin
      if (Opts.PackFile = '') or (Opts.OutFile = '') then
      begin
        WriteLn('extract requires --pack FILE and --out DIR');
        Halt(2);
      end;
      CmdExtract(Opts);
    end
    else if ParamStr(1) = 'list' then
    begin
      if Opts.PackFile = '' then
      begin
        WriteLn('list requires --pack FILE');
        Halt(2);
      end;
      CmdList(Opts);
    end
    else
    begin
      Usage;
      Halt(2);
    end;
  except
    on E: Exception do
    begin
      WriteLn('rp_pack: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
