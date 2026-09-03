program test_vfs_mount;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.respack,
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

procedure TestMountBasic;
var
  FsA, FsB, Mounted: IVfs;
  SI: TStatInfo;
  L: TEntryArray;
  B: TBytes;
begin
  FsA := MakeMem(['a.txt', 'common.txt'], ['A', 'from A']);
  FsB := MakeMem(['b.txt', 'common.txt'], ['B', 'from B']);
  Mounted := CreateMountedVfs([
    VfsMountEntry('a', FsA),
    VfsMountEntry('b', FsB)
  ]);
  Check(Mounted.Exists('a/a.txt'), 'mount: a/a.txt exists');
  Check(Mounted.Exists('b/b.txt'), 'mount: b/b.txt exists');
  Check(not Mounted.Exists('a/b.txt'), 'mount: cross not exists');
  SI := Mounted.Stat('a/common.txt');
  Check(SI.Info.Size = 6, 'mount: a/common from A size 6');
  B := VfsReadAllBytes(Mounted, 'a/common.txt');
  Check((Length(B) = 6) and (B[0] = Ord('f')), 'mount: A content');
  B := VfsReadAllBytes(Mounted, 'b/common.txt');
  Check(B[0] = Ord('f'), 'mount: B content');
  L := Mounted.List('.');
  Check(Length(L) = 2, 'mount: root list 2');
  Check((L[0].Name = 'a') and (L[1].Name = 'b'), 'mount: root sorted');
  L := Mounted.List('a');
  Check(Length(L) = 2, 'mount: a list 2');
end;

procedure TestMountLongestPrefix;
var
  Fs1, Fs2, Mounted: IVfs;
  B: TBytes;
begin
  Fs1 := MakeMem(['x.txt'], ['root']);
  Fs2 := MakeMem(['x.txt'], ['sub']);
  Mounted := CreateMountedVfs([
    VfsMountEntry('.', Fs1),
    VfsMountEntry('sub', Fs2)
  ]);
  B := VfsReadAllBytes(Mounted, 'x.txt');
  Check(B[0] = Ord('r'), 'mount: root file');
  B := VfsReadAllBytes(Mounted, 'sub/x.txt');
  Check(B[0] = Ord('s'), 'mount: longest prefix wins');
end;

procedure TestMountDuplicateRaises;
var
  Fs: IVfs;
  OK: Boolean;
begin
  Fs := MakeMem(['x.txt'], ['v']);
  OK := False;
  try
    CreateMountedVfs([
      VfsMountEntry('a', Fs),
      VfsMountEntry('a', Fs)
    ]);
  except
    on E: Exception do OK := True;
  end;
  Check(OK, 'mount: duplicate prefix raises');
end;

procedure TestMountETag;
var
  Fs, FsEmb: IVfs;
  Mounted: IVfs;
  ETag: string;
  OK: Boolean;
  Inputs: TResPackInputArray;
  Bufs: array of TBytes;
  Blob: TResPackBlob;
begin
  // memtree 无 ETag，mount 应透传 false
  Fs := MakeMem(['a.txt'], ['hello']);
  Mounted := CreateMountedVfs([VfsMountEntry('m', Fs)]);
  OK := (Mounted as IVfsETag).TryGetETag('m/a.txt', ETag);
  Check(not OK, 'mount: memtree ETag passthrough false');
  // embedded 有 ETag，mount 应透传 true
  SetLength(Bufs, 1);
  SetLength(Inputs, 1);
  Bufs[0] := StrToBytes('hello');
  Inputs[0].Path := 'a.txt';
  Inputs[0].Data := @Bufs[0][0];
  Inputs[0].DataSize := 5;
  Inputs[0].ModTime := 0;
  Blob := ResPackBuild(Inputs, ResPackDefaultOptions);
  FsEmb := CreateEmbeddedVfsOwned(Blob.Data, Blob.Size);
  Mounted := CreateMountedVfs([VfsMountEntry('m', FsEmb)]);
  OK := (Mounted as IVfsETag).TryGetETag('m/a.txt', ETag);
  Check(OK and (ETag <> ''), 'mount: embedded ETag passthrough true');
end;

procedure TestMountCaseSensitive;
var
  Fs: IVfs;
  Mounted: IVfs;
begin
  Fs := MakeMem(['a.txt'], ['v']);
  Mounted := CreateMountedVfs([VfsMountEntry('m', Fs)]);
  Check(Mounted.CaseSensitive, 'mount: case sensitive true default');
end;

procedure TestMountNotFound;
var
  Fs, Mounted: IVfs;
  OK: Boolean;
begin
  Fs := MakeMem(['a.txt'], ['v']);
  Mounted := CreateMountedVfs([VfsMountEntry('m', Fs)]);
  OK := False;
  try
    Mounted.Stat('m/missing.txt');
  except
    on E: EVfsNotFound do OK := True;
  end;
  Check(OK, 'mount: missing raises NotFound');
end;

procedure TestMountNested;
var
  Fs1, Fs2, Mounted: IVfs;
  L: TEntryArray;
begin
  Fs1 := MakeMem(['x.txt'], ['1']);
  Fs2 := MakeMem(['y.txt'], ['2']);
  Mounted := CreateMountedVfs([
    VfsMountEntry('a/b', Fs1),
    VfsMountEntry('a/c', Fs2)
  ]);
  L := Mounted.List('a');
  Check(Length(L) = 2, 'mount: nested list a 2 children');
  Check((L[0].Name = 'b') and (L[1].Name = 'c'), 'mount: nested sorted');
  L := Mounted.List('a/b');
  Check((Length(L) = 1) and (L[0].Name = 'x.txt'), 'mount: nested leaf');
  Check(Mounted.Exists('a/b/x.txt'), 'mount: nested exists');
  Check(not Mounted.Exists('a/x.txt'), 'mount: nested parent not file');
end;

procedure TestOverlayPriority;
var
  FsBase, FsPatch, Overlay: IVfs;
  B: TBytes;
begin
  FsBase := MakeMem(['textures/hero.png', 'common.txt'], ['base-hero', 'base-common']);
  FsPatch := MakeMem(['textures/hero.png'], ['patch-hero']);
  Overlay := CreateOverlayVfs([FsPatch, FsBase]);
  B := VfsReadAllBytes(Overlay, 'textures/hero.png');
  Check((Length(B)=10) and (B[0]=Ord('p')), 'overlay: patch overrides base');
  B := VfsReadAllBytes(Overlay, 'common.txt');
  Check(B[0]=Ord('b'), 'overlay: fallback to base');
end;

procedure TestOverlayListDedup;
var
  FsA, FsB, Overlay: IVfs;
  L: TEntryArray;
begin
  FsA := MakeMem(['a.txt', 'shared.txt'], ['1','a']);
  FsB := MakeMem(['b.txt', 'shared.txt'], ['2','b']);
  Overlay := CreateOverlayVfs([FsA, FsB]);
  L := Overlay.List('.');
  Check(Length(L)=3, 'overlay: list dedup 3');
  Check((L[0].Name='a.txt') and (L[1].Name='b.txt') and (L[2].Name='shared.txt'), 'overlay: list sorted dedup');
end;

procedure TestOverlayETagPriority;
var
  FsEmb, FsMem, Overlay: IVfs;
  ETag: string;
  OK: Boolean;
  Inputs: TResPackInputArray;
  Bufs: array of TBytes;
  Blob: TResPackBlob;
begin
  FsMem := MakeMem(['a.txt'], ['mem']);
  SetLength(Bufs,1); SetLength(Inputs,1);
  Bufs[0]:=StrToBytes('emb');
  Inputs[0].Path:='a.txt'; Inputs[0].Data:=@Bufs[0][0]; Inputs[0].DataSize:=3; Inputs[0].ModTime:=0;
  Blob:=ResPackBuild(Inputs, ResPackDefaultOptions);
  FsEmb:=CreateEmbeddedVfsOwned(Blob.Data, Blob.Size);
  Overlay:=CreateOverlayVfs([FsEmb, FsMem]);
  OK:=(Overlay as IVfsETag).TryGetETag('a.txt', ETag);
  Check(OK and (ETag<>''), 'overlay: ETag from priority ETag source');
  Overlay:=CreateOverlayVfs([FsMem, FsEmb]);
  OK:=(Overlay as IVfsETag).TryGetETag('a.txt', ETag);
  Check(not OK, 'overlay: first without ETag => false even if second has it');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.vfs.mount');
  T.Test('basic', @TestMountBasic);
  T.Test('longest prefix', @TestMountLongestPrefix);
  T.Test('duplicate raises', @TestMountDuplicateRaises);
  T.Test('etag passthrough', @TestMountETag);
  T.Test('case sensitive', @TestMountCaseSensitive);
  T.Test('not found', @TestMountNotFound);
  T.Test('nested', @TestMountNested);
  T.Test('overlay priority', @TestOverlayPriority);
  T.Test('overlay list dedup', @TestOverlayListDedup);
  T.Test('overlay etag priority', @TestOverlayETagPriority);
  if not T.Run then Halt(1);
end.
