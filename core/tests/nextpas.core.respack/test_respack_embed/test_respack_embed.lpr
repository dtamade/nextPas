program test_respack_embed;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.respack;

{$I golden_embed_v1.inc}

{ S4 嵌入工具链门禁：glob 过滤 / prefix 映射 / .inc 生成确定性（golden 逐字节
  锁定）/ extract-to-dir roundtrip。夹具树与 dist 树在 SetupTree 构造。 }

var
  T: TTestSuite;
  G_Root: string;

function BytesOf(const S: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(Pointer(S)^, Result[0], Length(S));
end;

procedure SetupTree;
begin
  G_Root := GetTempDir + '/rp-embed-test';
  RemoveAll(G_Root);
  MkdirAll(G_Root + '/wwwroot/assets');
  MkdirAll(G_Root + '/wwwroot/docs');
  MkdirAll(G_Root + '/dist/web');
  WriteFile(G_Root + '/wwwroot/index.html', BytesOf('<html>hi</html>'));
  WriteFile(G_Root + '/wwwroot/assets/app.js', BytesOf('console.log(1);'));
  WriteFile(G_Root + '/wwwroot/assets/app.js.map', BytesOf('{"m":1}'));
  WriteFile(G_Root + '/wwwroot/docs/guide.md', BytesOf('# guide'));
  WriteFile(G_Root + '/wwwroot/logo.svg', BytesOf('<svg/>'));
  WriteFile(G_Root + '/dist/web/index.html', BytesOf('<html>dist</html>'));
  WriteFile(G_Root + '/dist/web/app.js', BytesOf('console.log(2);'));
  WriteFile(G_Root + '/dist/README.md', BytesOf('readme'));
end;

function CountPaths(const ABlob: TResPackBlob; out RP: TResPack): SizeUInt;
begin
  RP := ResPackOpen(ABlob.Data, ABlob.Size);
  Result := RP.Count;
end;

function HasPath(var RP: TResPack; const APath: string): Boolean;
var
  E: TResPackEntry;
begin
  Result := RP.Find(APath, E);
end;

function SameBytes(const AA, AB: TBytes): Boolean;
var
  I: SizeInt;
begin
  Result := Length(AA) = Length(AB);
  if not Result then
    Exit;
  for I := 0 to Length(AA) - 1 do
    if AA[I] <> AB[I] then
      Exit(False);
end;

function SameRaw(const AA, AB: PByte; const ALen: SizeUInt): Boolean;
var
  I: SizeUInt;
begin
  Result := False;
  if ALen = 0 then
    Exit(True);
  for I := 0 to ALen - 1 do
    if AA[I] <> AB[I] then
      Exit;
  Result := True;
end;

procedure CheckContent(var RP: TResPack; const APath, AWant: string);
var
  E: TResPackEntry;
  Got: TBytes;
begin
  Check(RP.Find(APath, E), 'found ' + APath);
  if not RP.Find(APath, E) then
    Exit;
  SetLength(Got, SizeInt(E.Size));
  if E.Size > 0 then
    Move(RP.ContentPtr(E)^, Got[0], SizeUInt(E.Size));
  Check(SameBytes(Got, BytesOf(AWant)), 'content of ' + APath);
end;

procedure TestBuildAllEntries;
var
  Opts: TResPackEmbedOptions;
  B: TResPackBlob;
  RP: TResPack;
begin
  SetupTree;
  try
    Opts := ResPackDefaultEmbedOptions;
    B := ResPackEmbedBuild(G_Root + '/wwwroot', Opts);
    try
      Check(CountPaths(B, RP) = 5, 'all five entries packed');
      Check(HasPath(RP, 'index.html'), 'root file present');
      Check(HasPath(RP, 'assets/app.js'), 'nested file present');
      Check(HasPath(RP, 'assets/app.js.map'), 'sourcemap present');
      Check(HasPath(RP, 'docs/guide.md'), 'deep dir present');
      Check(HasPath(RP, 'logo.svg'), 'top-level file present');
      CheckContent(RP, 'assets/app.js', 'console.log(1);');
    finally
      RP.Close;
      ResPackFreeBlob(B);
    end;
  finally
    RemoveAll(G_Root);
  end;
end;

procedure TestIncludeGlob;
var
  Opts: TResPackEmbedOptions;
  B: TResPackBlob;
  RP: TResPack;
begin
  SetupTree;
  try
    Opts := ResPackDefaultEmbedOptions;
    Opts.IncludeGlobs := TStringArray.Create('assets/*');
    B := ResPackEmbedBuild(G_Root + '/wwwroot', Opts);
    try
      Check(CountPaths(B, RP) = 2, 'include assets/* keeps two');
      Check(HasPath(RP, 'assets/app.js') and HasPath(RP, 'assets/app.js.map'),
        'kept the right pair');
    finally
      RP.Close;
      ResPackFreeBlob(B);
    end;
  finally
    RemoveAll(G_Root);
  end;
end;

procedure TestExcludeGlobCrossLevel;
var
  Opts: TResPackEmbedOptions;
  B: TResPackBlob;
  RP: TResPack;
begin
  SetupTree;
  try
    { '*.map' 不跨分隔符，跨层级排除须 '**/*.map' }
    Opts := ResPackDefaultEmbedOptions;
    Opts.ExcludeGlobs := TStringArray.Create('**/*.map');
    B := ResPackEmbedBuild(G_Root + '/wwwroot', Opts);
    try
      Check(CountPaths(B, RP) = 4, 'exclude **/*.map keeps four');
      Check(not HasPath(RP, 'assets/app.js.map'), 'sourcemap excluded');
      Check(HasPath(RP, 'assets/app.js'), 'sibling kept');
    finally
      RP.Close;
      ResPackFreeBlob(B);
    end;
  finally
    RemoveAll(G_Root);
  end;
end;

procedure TestStripPrefix;
var
  Opts: TResPackEmbedOptions;
  B: TResPackBlob;
  RP: TResPack;
begin
  SetupTree;
  try
    Opts := ResPackDefaultEmbedOptions;
    Opts.StripPrefix := 'dist/';
    B := ResPackEmbedBuild(G_Root, Opts);
    try
      Check(CountPaths(B, RP) = 3, 'strip keeps entries under prefix');
      Check(HasPath(RP, 'web/index.html') and HasPath(RP, 'web/app.js'),
        'stripped paths rebased to root');
      Check(HasPath(RP, 'README.md'), 'file directly under prefix kept');
      CheckContent(RP, 'web/index.html', '<html>dist</html>');
    finally
      RP.Close;
      ResPackFreeBlob(B);
    end;
  finally
    RemoveAll(G_Root);
  end;
end;

procedure TestAddPrefix;
var
  Opts: TResPackEmbedOptions;
  B: TResPackBlob;
  RP: TResPack;
begin
  SetupTree;
  try
    Opts := ResPackDefaultEmbedOptions;
    Opts.AddPrefix := 'static/';
    B := ResPackEmbedBuild(G_Root + '/wwwroot', Opts);
    try
      Check(CountPaths(B, RP) = 5, 'add prefix keeps all five');
      Check(HasPath(RP, 'static/index.html')
        and HasPath(RP, 'static/assets/app.js'),
        'paths carry the prefix');
    finally
      RP.Close;
      ResPackFreeBlob(B);
    end;
  finally
    RemoveAll(G_Root);
  end;
end;

procedure TestPipelineCombo;
var
  Opts: TResPackEmbedOptions;
  B: TResPackBlob;
  RP: TResPack;
begin
  SetupTree;
  try
    { strip → glob → add 全管线 }
    Opts := ResPackDefaultEmbedOptions;
    Opts.StripPrefix := 'dist/';
    Opts.IncludeGlobs := TStringArray.Create('web/*');
    Opts.AddPrefix := 'site/';
    B := ResPackEmbedBuild(G_Root, Opts);
    try
      Check(CountPaths(B, RP) = 2, 'combo pipeline keeps web pair');
      Check(HasPath(RP, 'site/web/index.html')
        and HasPath(RP, 'site/web/app.js'), 'combo mapped paths correct');
    finally
      RP.Close;
      ResPackFreeBlob(B);
    end;
  finally
    RemoveAll(G_Root);
  end;
end;

procedure TestBadOptionsRaise;
var
  Opts: TResPackEmbedOptions;
  B: TResPackBlob;
  Got: Boolean;

  procedure ExpectRaise;
  begin
    Got := False;
    try
      B := ResPackEmbedBuild(G_Root + '/wwwroot', Opts);
      ResPackFreeBlob(B);
    except
      on E: EResPackError do Got := True;
      on E: Exception do ;
    end;
    Check(Got, 'bad option raises EResPackError');
  end;

begin
  SetupTree;
  try
    Opts := ResPackDefaultEmbedOptions;
    Opts.StripPrefix := 'dist';   { 缺尾 '/' }
    ExpectRaise;
    Opts := ResPackDefaultEmbedOptions;
    Opts.AddPrefix := 'static';   { 缺尾 '/' }
    ExpectRaise;
    Opts := ResPackDefaultEmbedOptions;
    Opts.IncludeGlobs := TStringArray.Create('');   { 空 glob 模式 }
    ExpectRaise;
    Opts := ResPackDefaultEmbedOptions;
    Opts.ExcludeGlobs := TStringArray.Create('**'); { 全剔 → 空包拒绝 }
    ExpectRaise;
  finally
    RemoveAll(G_Root);
  end;
end;

procedure TestIdentValidation;
begin
  Check(ResPackValidIdent('RP_ASSETS'), 'plain ident ok');
  Check(ResPackValidIdent('_x9'), 'underscore lead ok');
  Check(not ResPackValidIdent('1bad'), 'digit lead rejected');
  Check(not ResPackValidIdent('a-b'), 'dash rejected');
  Check(not ResPackValidIdent(''), 'empty rejected');
end;

procedure TestIncGolden;
var
  Entries: array[0..2] of TResPackInputEntry;
  Opts: TResPackIncOptions;
  B: TResPackBlob;
  TextOut: TBytes;
  D1, D2: TBytes;
begin
  { 输入集必须与 golden_embed_v1.inc 头注释一致；由 core/build/rp-check 下
    gen_golden_embed.lpr 生成后提交，重生成需同步本用例字面量。
    注意内容缓冲须锚定在存活局部变量上，不能取临时 TBytes 的指针 }
  D1 := BytesOf('hello');
  D2 := BytesOf('let x=1;');
  FillChar(Entries, SizeOf(Entries), 0);
  Entries[0].Path := 'a.txt';
  Entries[0].Data := @D1[0];
  Entries[0].DataSize := SizeUInt(Length(D1));
  Entries[0].ModTime := 100;
  Entries[1].Path := 'b/c.js';
  Entries[1].Data := @D2[0];
  Entries[1].DataSize := SizeUInt(Length(D2));
  Entries[1].ModTime := 0;
  Entries[2].Path := 'empty.dat';
  Entries[2].Data := nil;
  Entries[2].DataSize := 0;
  Entries[2].ModTime := 0;
  B := ResPackBuild(Entries, ResPackDefaultOptions);
  try
    Opts := ResPackDefaultIncOptions;
    Opts.ConstName := 'RP_EMBED_GOLDEN';
    TextOut := ResPackEmbedIncSource(B, Opts);
    Check(Length(TextOut) = GOLDEN_TEXT_SIZE, 'golden text size matches');
    if Length(TextOut) = GOLDEN_TEXT_SIZE then
      Check(SameRaw(@TextOut[0], @GOLDEN_TEXT[0], SizeUInt(GOLDEN_TEXT_SIZE)),
        '.inc text matches golden byte-for-byte (determinism locked)');
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestIncBadNameRaises;
var
  Entries: array[0..0] of TResPackInputEntry;
  Opts: TResPackIncOptions;
  B: TResPackBlob;
  Got: Boolean;
  D1: TBytes;
begin
  D1 := BytesOf('x');
  FillChar(Entries, SizeOf(Entries), 0);
  Entries[0].Path := 'x';
  Entries[0].Data := @D1[0];
  Entries[0].DataSize := SizeUInt(Length(D1));
  Entries[0].ModTime := 0;
  B := ResPackBuild(Entries, ResPackDefaultOptions);
  try
    Opts := ResPackDefaultIncOptions;
    Opts.ConstName := '9lives';
    Got := False;
    try
      ResPackEmbedIncSource(B, Opts);
    except
      on E: EResPackError do Got := True;
      on E: Exception do ;
    end;
    Check(Got, 'invalid ConstName raises');
  finally
    ResPackFreeBlob(B);
  end;
end;

{ Hex payload decoder: inverse of the .inc emitter (independent path, no
  shared sizing code). Proves the shipped text is well-formed for any blob. }
function HexNibble(const C: Byte): Integer;
begin
  if (C >= Byte('0')) and (C <= Byte('9')) then
    Exit(Integer(C) - Integer(Byte('0')));
  if (C >= Byte('A')) and (C <= Byte('F')) then
    Exit(Integer(C) - Integer(Byte('A')) + 10);
  Result := -1;
end;

function DecodeIncHex(const AText: TBytes): TBytes;
var
  I, N, Hi, Lo: SizeInt;
begin
  Result := nil;
  N := 0;
  for I := 0 to Length(AText) - 1 do
    if AText[I] = Byte('$') then
      Inc(N);
  SetLength(Result, N);
  N := 0;
  I := 0;
  while I < Length(AText) do
  begin
    if AText[I] <> Byte('$') then
    begin
      Inc(I);
      Continue;
    end;
    if I + 2 >= Length(AText) then
    begin
      Check(False, 'hex pair in bounds');
      Exit;
    end;
    Hi := HexNibble(AText[I + 1]);
    Lo := HexNibble(AText[I + 2]);
    if (Hi < 0) or (Lo < 0) then
    begin
      Check(False, 'hex pair valid');
      Exit;
    end;
    Result[N] := Byte(Hi * 16 + Lo);
    Inc(N);
    Inc(I, 3);
  end;
end;

procedure CheckIncHexRoundtrip(const ALabel: string; const B: TResPackBlob);
var
  Opts: TResPackIncOptions;
  T1, T2, Back: TBytes;
begin
  Opts := ResPackDefaultIncOptions;
  Opts.ConstName := 'RP_INC_RT';
  T1 := ResPackEmbedIncSource(B, Opts);
  T2 := ResPackEmbedIncSource(B, Opts);
  Check((Length(T1) > SizeInt(B.Size)) and SameBytes(T1, T2),
    ALabel + ': deterministic hex expansion');
  Back := DecodeIncHex(T1);
  Check(Length(Back) = SizeInt(B.Size), ALabel + ': decoded length matches blob');
  if Length(Back) = SizeInt(B.Size) then
    Check(SameRaw(@Back[0], B.Data, B.Size), ALabel + ': decoded bytes identical');
end;

procedure TestIncTinyBlobHexRoundtrip;
var
  Entries: array[0..0] of TResPackInputEntry;
  B: TResPackBlob;
  D1: TBytes;
begin
  { Single 1-byte file: exercises the smallest multi-line .inc through the
    shipped IncSource entry point (rp_pack inc --const path). }
  D1 := BytesOf('x');
  FillChar(Entries, SizeOf(Entries), 0);
  Entries[0].Path := 'x';
  Entries[0].Data := @D1[0];
  Entries[0].DataSize := SizeUInt(Length(D1));
  Entries[0].ModTime := 0;
  B := ResPackBuild(Entries, ResPackDefaultOptions);
  try
    CheckIncHexRoundtrip('tiny', B);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestIncMediumBlobHexRoundtrip;
var
  Entries: array[0..3] of TResPackInputEntry;
  B: TResPackBlob;
  D1, D2, D3: TBytes;
  K: Integer;
begin
  { Empty + duplicate + text + full binary sweep: multi-line emission with
    dedup off, mirroring the rp_pack sample tree shape. }
  D1 := BytesOf('same-content');
  D2 := BytesOf('same-content');
  D3 := nil;
  SetLength(D3, 256);
  for K := 0 to 255 do
    D3[K] := Byte(K);
  FillChar(Entries, SizeOf(Entries), 0);
  Entries[0].Path := 'empty.txt';
  Entries[0].Data := nil;
  Entries[0].DataSize := 0;
  Entries[0].ModTime := 0;
  Entries[1].Path := 'a/dup1.bin';
  Entries[1].Data := @D1[0];
  Entries[1].DataSize := SizeUInt(Length(D1));
  Entries[1].ModTime := 0;
  Entries[2].Path := 'a/b/dup2.bin';
  Entries[2].Data := @D2[0];
  Entries[2].DataSize := SizeUInt(Length(D2));
  Entries[2].ModTime := 0;
  Entries[3].Path := 'bin/all256.bin';
  Entries[3].Data := @D3[0];
  Entries[3].DataSize := SizeUInt(Length(D3));
  Entries[3].ModTime := 0;
  B := ResPackBuild(Entries, ResPackDefaultOptions);
  try
    CheckIncHexRoundtrip('medium', B);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestExtractRoundtrip;var
  Opts: TResPackEmbedOptions;
  B1, B2: TResPackBlob;
  RP: TResPack;
begin
  { build → extract → rebuild 字节一致（INV-R5 确定性的端到端体现） }
  SetupTree;
  try
    Opts := ResPackDefaultEmbedOptions;
    B1 := ResPackEmbedBuild(G_Root + '/wwwroot', Opts);
    try
      ResPackExtractToDir(B1, G_Root + '/out');
      B2 := ResPackEmbedBuild(G_Root + '/out', Opts);
      try
        Check((B1.Size = B2.Size)
          and SameRaw(B1.Data, B2.Data, SizeUInt(B1.Size)),
          'extract→rebuild reproduces identical blob bytes');
      finally
        ResPackFreeBlob(B2);
      end;
    finally
      ResPackFreeBlob(B1);
    end;
  finally
    RemoveAll(G_Root);
  end;
end;

procedure TestExtractCreatesDirsAndContent;
var
  Opts: TResPackEmbedOptions;
  B: TResPackBlob;
  RP: TResPack;
  Deep: string;
begin
  SetupTree;
  try
    Opts := ResPackDefaultEmbedOptions;
    B := ResPackEmbedBuild(G_Root + '/wwwroot', Opts);
    try
      Deep := G_Root + '/fresh/a/b';
      ResPackExtractToDir(B, Deep);
      Check(IsFile(Deep + '/assets/app.js'), 'nested dirs auto-created');
      ReadFileText(Deep + '/index.html');   { 存在性烟囱：不抛即通过形态检查 }
      RP := ResPackOpen(B.Data, B.Size);
      try
        Check(ReadFileText(Deep + '/docs/guide.md') = '# guide',
          'extracted content byte-equal');
      finally
        RP.Close;
      end;
    finally
      ResPackFreeBlob(B);
    end;
  finally
    RemoveAll(G_Root);
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.respack.embed');
  T.Test('build all entries', @TestBuildAllEntries);
  T.Test('include glob', @TestIncludeGlob);
  T.Test('exclude glob cross level', @TestExcludeGlobCrossLevel);
  T.Test('strip prefix', @TestStripPrefix);
  T.Test('add prefix', @TestAddPrefix);
  T.Test('pipeline combo', @TestPipelineCombo);
  T.Test('bad options raise', @TestBadOptionsRaise);
  T.Test('identifier validation', @TestIdentValidation);
  T.Test('.inc golden snapshot', @TestIncGolden);
  T.Test('.inc bad name raises', @TestIncBadNameRaises);
  T.Test('.inc tiny blob hex roundtrip', @TestIncTinyBlobHexRoundtrip);
  T.Test('.inc medium blob hex roundtrip', @TestIncMediumBlobHexRoundtrip);
  T.Test('extract roundtrip identical blob', @TestExtractRoundtrip);
  T.Test('extract creates dirs and content', @TestExtractCreatesDirsAndContent);
  if not T.Run then Halt(1);
end.
