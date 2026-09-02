program demo_game_pack;
{$I nextpas.core.settings.inc}
{** @desc 游戏资源包示例：base + dlc + patch 三层叠加。

  场景：单机游戏发版后热更
    base  — 出厂包（textures/hero.png 1.0, levels/forest.json）
    dlc   — 扩展包（textures/hero.png 2.0 skin, levels/desert.json）
    patch — 热更（textures/hero.png 2.1 fix）

  期望：
    textures/hero.png → patch 胜出 (2.1)
    levels/desert.json → dlc
    levels/forest.json → base fallback
    List('.') 去重 3 个顶层语义正确

  对比 demo_asset_embed 的 mount（异前缀聚合），本例是同根叠加（overlay），
  两者正交，游戏侧一行 `CreateOverlayVfs([Patch,Dlc,Base])` 即得热更视图。 }
uses
  nextpas.core.base,
  nextpas.core.vfs;

function StrToBytes(const S: string): TBytes;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do Result[I - 1] := Byte(S[I]);
end;

function MakeMem(const AFiles: array of string; const AContents: array of string): IVfs;
var
  B: TVfsTreeBuilder;
  I: Integer;
begin
  B := TVfsTreeBuilder.Create;
  try
    for I := 0 to High(AFiles) do
      B.AddFile(AFiles[I], StrToBytes(AContents[I]), 0);
    Result := B.Freeze;
  finally
    B.Free;
  end;
end;

procedure AssertText(const AFs: IVfs; const APath, AExpect: string);
var
  Got: string;
begin
  Got := VfsReadAllText(AFs, APath);
  if Got <> AExpect then
  begin
    WriteLn('FAIL ', APath, ': expect "', AExpect, '" got "', Got, '"');
    Halt(1);
  end;
  WriteLn('  OK ', APath, ' = "', Got, '"');
end;

var
  FsBase, FsDlc, FsPatch, FsGame: IVfs;
  L: TEntryArray;
  I: Integer;
begin
  FsBase := MakeMem(
    ['textures/hero.png', 'levels/forest.json', 'common.txt'],
    ['hero-1.0', 'forest', 'base']);
  FsDlc := MakeMem(
    ['textures/hero.png', 'levels/desert.json'],
    ['hero-2.0-skin', 'desert']);
  FsPatch := MakeMem(
    ['textures/hero.png'],
    ['hero-2.1-fix']);

  FsGame := CreateOverlayVfs([FsPatch, FsDlc, FsBase]);

  WriteLn('backend: overlay [patch, dlc, base]  (priority first wins)');
  WriteLn('case-sensitive: ', FsGame.CaseSensitive);

  WriteLn('walk:');
  VfsWalk(FsGame, '.',
    procedure(const APath: string; const AInfo: TEntryInfo; var AStop: Boolean)
    begin
      WriteLn('  /', APath, '  isDir=', AInfo.IsDir, ' size=', AInfo.Size);
    end);

  WriteLn('reads:');
  AssertText(FsGame, 'textures/hero.png', 'hero-2.1-fix');
  AssertText(FsGame, 'levels/desert.json', 'desert');
  AssertText(FsGame, 'levels/forest.json', 'forest');
  AssertText(FsGame, 'common.txt', 'base');

  WriteLn('list . :');
  L := FsGame.List('.');
  for I := 0 to High(L) do
    WriteLn('  ', L[I].Name, ' isDir=', L[I].IsDir);
  // 期望 textures, levels, common.txt（textures/levels 为推导目录）
  if Length(L) <> 3 then begin WriteLn('FAIL list . length ', Length(L)); Halt(1); end;

  WriteLn('demo_game_pack: all OK (mount 聚合 + overlay 叠加双视图演示)');
end.
