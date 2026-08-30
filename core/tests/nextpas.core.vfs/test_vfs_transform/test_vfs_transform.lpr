program test_vfs_transform;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.io.intf,
  nextpas.core.vfs,
  nextpas.core.vfs.intf,
  nextpas.core.vfs.transform;

var T: TTestSuite;

function BytesOf(const S: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S)>0 then Move(Pointer(S)^, Result[0], Length(S));
end;

function SameBytes(const A,B: TBytes): Boolean;
var I: Integer;
begin
  Result := False;
  if Length(A)<>Length(B) then Exit;
  for I:=0 to Length(A)-1 do if A[I]<>B[I] then Exit;
  Result := True;
end;

function MakeSample: IVfs;
var B: TVfsTreeBuilder;
begin
  B := TVfsTreeBuilder.Create;
  try
    B.AddFile('a.txt', BytesOf('hello'), 10);
    B.AddFile('b.bin', BytesOf('world'), 20, $12345678);
    B.AddFile('dir/c.txt', BytesOf('nested'), 30);
    Result := B.Freeze;
  finally B.Free; end;
end;

function UpperTransform(const AData: TBytes): TBytes;
var I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AData));
  for I:=0 to Length(AData)-1 do begin if (AData[I] >= Ord('a')) and (AData[I] <= Ord('z')) then Result[I] := AData[I] - 32 else Result[I] := AData[I]; end;
end;

function OnlyHello(const AData: TBytes): Boolean;
begin
  Result := (Length(AData)=5) and (AData[0]=Ord('h'));
end;

function FailTransform(const AData: TBytes): TBytes;
begin
  Result := nil;
  raise EIOError.Create('boom');
end;

procedure TestIdentityPassthrough;
var Inner, Tr: IVfs; Data: TBytes;
begin
  Inner := MakeSample;
  Tr := CreateTransformingVfs(Inner, @UpperTransform, nil);
  Data := VfsReadAllBytes(Tr, 'a.txt');
  Check(SameBytes(Data, BytesOf('HELLO')), 'upper transform a.txt');
  Check(Tr.CaseSensitive = Inner.CaseSensitive, 'caseSensitive passthrough');
  Check(Tr.Exists('a.txt'), 'exists passthrough');
end;

procedure TestPredicateSelective;
var Inner, Tr: IVfs; D1,D2: TBytes;
begin
  Inner := MakeSample;
  Tr := CreateTransformingVfs(Inner, @UpperTransform, @OnlyHello);
  D1 := VfsReadAllBytes(Tr, 'a.txt');
  Check(SameBytes(D1, BytesOf('HELLO')), 'predicate hello transformed');
  D2 := VfsReadAllBytes(Tr, 'b.bin');
  Check(SameBytes(D2, BytesOf('world')), 'predicate world not transformed');
  Check(VfsStat(Tr, 'a.txt').Info.Size=5, 'stat size unchanged for same len');
  Check(VfsStat(Tr, 'a.txt').ContentHash=0, 'stat hash cleared after transform');
  Check(VfsStat(Tr, 'b.bin').ContentHash = VfsStat(Inner, 'b.bin').ContentHash, 'stat hash kept when not transformed');
end;

procedure TestNilArgsRaise;
var Got: Boolean;
begin
  Got := False; try CreateTransformingVfs(nil, @UpperTransform); except on E: EVfsError do Got:=True; end; Check(Got, 'nil inner raises');
  Got := False; try CreateTransformingVfs(MakeSample, nil); except on E: EVfsError do Got:=True; end; Check(Got, 'nil transform raises');
end;

procedure TestETagDisabled;
var Inner, Tr: IVfs; ET: IVfsETag; Tag: string;
begin
  Inner := MakeSample;
  Tr := CreateTransformingVfs(Inner, @UpperTransform, nil);
  Check(Tr.QueryInterface(IVfsETag, ET)=0, 'exposes IVfsETag');
  Check(not ET.TryGetETag('a.txt', Tag), 'ETag disabled');
end;

procedure TestListPassthrough;
var Inner, Tr: IVfs; L1,L2: TEntryArray;
begin
  Inner := MakeSample;
  Tr := CreateTransformingVfs(Inner, @UpperTransform, nil);
  L1 := Inner.List('.');
  L2 := Tr.List('.');
  Check(Length(L1)=Length(L2), 'list count passthrough');
  Check(L1[0].Name=L2[0].Name, 'list name passthrough');
end;

procedure TestTransformErrorWrapped;
var Inner, Tr: IVfs; Got: Boolean;
begin
  Inner := MakeSample;
  Tr := CreateTransformingVfs(Inner, @FailTransform, nil);
  Got := False;
  try VfsReadAllBytes(Tr, 'a.txt'); except on E: EVfsError do Got:=(Pos('transform failed', E.Message)>0); end;
  Check(Got, 'transform error wrapped as EVfsError');
end;

begin
  T := TTestSuite.Create('nextpas.core.vfs.transform');
  T.Test('identity/upper passthrough', @TestIdentityPassthrough);
  T.Test('predicate selective', @TestPredicateSelective);
  T.Test('nil args raise', @TestNilArgsRaise);
  T.Test('ETag disabled', @TestETagDisabled);
  T.Test('list passthrough', @TestListPassthrough);
  T.Test('error wrapped', @TestTransformErrorWrapped);
  if not T.Run then Halt(1);
end.
