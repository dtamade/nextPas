program test_meta;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.io,
  nextpas.core.audio.base,
  nextpas.core.audio.codec.meta;

type
  T = class
    procedure TestID3v23_Iso8859;
    procedure TestID3v24_Utf16BOM;
    procedure TestID3v24_SyncSafeSize;
    procedure TestID3v24_ExtendedHeader;
    procedure TestID3_Truncated;
    procedure TestVorbis_Normal;
    procedure TestVorbis_CaseInsensitive;
    procedure TestVorbis_Truncated;
    procedure TestRiffInfo_Normal;
    procedure TestRiffInfo_Truncated;
    procedure TestMergeTags;
  end;

procedure AppendBytes(var D: TBytes; const S: string);
var L, I: Integer;
begin
  L:=Length(D);
  SetLength(D, L+Length(S));
  for I:=1 to Length(S) do D[L+I-1]:=Ord(S[I]);
end;

procedure AppendByte(var D: TBytes; B: Byte);
var L: Integer;
begin
  L:=Length(D);
  SetLength(D, L+1);
  D[L]:=B;
end;

procedure AppendDWordBE(var D: TBytes; V: DWord);
begin
  AppendByte(D, (V shr 24) and $FF);
  AppendByte(D, (V shr 16) and $FF);
  AppendByte(D, (V shr 8) and $FF);
  AppendByte(D, V and $FF);
end;

procedure AppendDWordLE(var D: TBytes; V: DWord);
begin
  AppendByte(D, V and $FF);
  AppendByte(D, (V shr 8) and $FF);
  AppendByte(D, (V shr 16) and $FF);
  AppendByte(D, (V shr 24) and $FF);
end;

procedure AppendSyncSafe(var D: TBytes; V: DWord);
begin
  AppendByte(D, (V shr 21) and $7F);
  AppendByte(D, (V shr 14) and $7F);
  AppendByte(D, (V shr 7) and $7F);
  AppendByte(D, V and $7F);
end;

function BuildID3v23(const Frames: array of string; const Payloads: array of string): TBytes;
var H: TBytes;
    I: Integer;
    FrameSize: DWord;
    Body: TBytes;
begin
  Body:=nil;
  for I:=0 to High(Frames) do
  begin
    AppendBytes(Body, Frames[I]); // 4
    FrameSize:=Length(Payloads[I])+1; // encoding + text (for T*)
    // simple: assume encoding 0, payloads already include? We'll pass full payload with encoding byte prepended
    // Actually Payloads already contain encoding+text, so use Length
    FrameSize:=Length(Payloads[I]);
    AppendDWordBE(Body, FrameSize);
    AppendByte(Body, 0); AppendByte(Body, 0); // flags
    AppendBytes(Body, Payloads[I]);
  end;
  H:=nil;
  AppendBytes(H, 'ID3');
  AppendByte(H, 3); AppendByte(H, 0);
  AppendByte(H, 0); // flags no ext
  AppendSyncSafe(H, Length(Body));
  AppendBytes(H, ''); // placeholder to get TBytes type
  // Append body bytes
  if Length(Body)>0 then
  begin
    SetLength(H, Length(H)+Length(Body));
    Move(Body[0], H[Length(H)-Length(Body)], Length(Body));
  end;
  Result:=H;
end;

function StrToBytes(const S: string): TBytes;
var I: Integer;
begin
  SetLength(Result, Length(S));
  for I:=1 to Length(S) do Result[I-1]:=Ord(S[I]);
end;

function MakeID3FrameData(const Text: string; Enc: Byte): string;
var S: string;
begin
  S:=Chr(Enc)+Text;
  Result:=S;
end;

procedure T.TestID3v23_Iso8859;
var B: TBytes;
    Tags: TAudioTags;
    Skipped: Integer;
    Ok: Boolean;
    Body1, Body2, Body3: string;
    Tmp: TBytes;
begin
  Body1:=MakeID3FrameData('Hello',0);
  Body2:=MakeID3FrameData('Artist',0);
  Body3:=MakeID3FrameData('3/12',0);
  Tmp:=nil;
  // Build manually to avoid helper confusion
  Tmp:=StrToBytes('ID3');
  AppendByte(Tmp, 3); AppendByte(Tmp, 0); AppendByte(Tmp, 0);
  // size placeholder
  AppendByte(Tmp, 0); AppendByte(Tmp, 0); AppendByte(Tmp, 0); AppendByte(Tmp, 0);
  // Frames
  AppendBytes(Tmp, 'TIT2'); AppendDWordBE(Tmp, Length(Body1)); AppendByte(Tmp,0); AppendByte(Tmp,0); AppendBytes(Tmp, Body1);
  AppendBytes(Tmp, 'TPE1'); AppendDWordBE(Tmp, Length(Body2)); AppendByte(Tmp,0); AppendByte(Tmp,0); AppendBytes(Tmp, Body2);
  AppendBytes(Tmp, 'TRCK'); AppendDWordBE(Tmp, Length(Body3)); AppendByte(Tmp,0); AppendByte(Tmp,0); AppendBytes(Tmp, Body3);
  // patch syncsafe size
  B:=Tmp;
  // patch size at offset 6
  AppendSyncSafe(B, 0); // dummy to avoid unused
  // compute size = len-10
  // rewrite header size
  B[6]:=((Length(B)-10) shr 21) and $7F;
  B[7]:=((Length(B)-10) shr 14) and $7F;
  B[8]:=((Length(B)-10) shr 7) and $7F;
  B[9]:=(Length(B)-10) and $7F;
  Ok:=TryParseID3v2(B, Tags, Skipped);
  CheckTrue(Ok, 'id3v23 parse ok');
  CheckEqual('Hello', Tags.Title, 'id3 title');
  CheckEqual('Artist', Tags.Artist, 'id3 artist');
  CheckEqual(3, Tags.TrackNo, 'id3 track');
  CheckEqual(Length(B), Skipped, 'id3 skipped');
end;

procedure T.TestID3v24_Utf16BOM;
var B: TBytes;
    Tags: TAudioTags;
    Skipped: Integer;
    Ok: Boolean;
    Payload: TBytes;
begin
  // TIT2 encoding 1 + BOM FF FE + 'H'i 00 69 00
  Payload:=nil;
  AppendByte(Payload, 1);
  AppendByte(Payload, $FF); AppendByte(Payload, $FE);
  AppendByte(Payload, Ord('H')); AppendByte(Payload, 0);
  AppendByte(Payload, Ord('i')); AppendByte(Payload, 0);
  B:=nil;
  AppendBytes(B, 'ID3');
  AppendByte(B, 4); AppendByte(B, 0); AppendByte(B, 0);
  AppendSyncSafe(B, 0); // placeholder
  AppendBytes(B, 'TIT2');
  // v2.4 frame size is syncsafe
  AppendSyncSafe(B, Length(Payload));
  AppendByte(B, 0); AppendByte(B, 0);
  AppendBytes(B, ''); // helper to convert Payload TBytes to string? Instead append bytes directly
  // Append payload bytes
  // Since AppendBytes expects string, do manual
  SetLength(B, Length(B)+Length(Payload));
  Move(Payload[0], B[Length(B)-Length(Payload)], Length(Payload));
  // patch header size
  B[6]:=((Length(B)-10) shr 21) and $7F;
  B[7]:=((Length(B)-10) shr 14) and $7F;
  B[8]:=((Length(B)-10) shr 7) and $7F;
  B[9]:=(Length(B)-10) and $7F;
  // patch frame size syncsafe already done (Length Payload =6)
  Ok:=TryParseID3v2(B, Tags, Skipped);
  CheckTrue(Ok, 'id3v24 utf16 ok');
  CheckEqual('Hi', Tags.Title, 'id3 utf16 title');
end;

procedure T.TestID3v24_SyncSafeSize;
var B: TBytes;
    Tags: TAudioTags;
    Skipped: Integer;
    Payload: TBytes;
    Ok: Boolean;
begin
  Payload:=nil;
  AppendByte(Payload, 3);
  AppendBytes(Payload, 'Sync');
  B:=nil;
  AppendBytes(B, 'ID3');
  AppendByte(B, 4); AppendByte(B, 0); AppendByte(B, 0);
  AppendSyncSafe(B, 0);
  AppendBytes(B, 'TIT2');
  AppendSyncSafe(B, Length(Payload));
  AppendByte(B, 0); AppendByte(B, 0);
  SetLength(B, Length(B)+Length(Payload));
  Move(Payload[0], B[Length(B)-Length(Payload)], Length(Payload));
  B[6]:=((Length(B)-10) shr 21) and $7F;
  B[7]:=((Length(B)-10) shr 14) and $7F;
  B[8]:=((Length(B)-10) shr 7) and $7F;
  B[9]:=(Length(B)-10) and $7F;
  Ok:=TryParseID3v2(B, Tags, Skipped);
  CheckTrue(Ok, 'syncsafe ok');
  CheckEqual('Sync', Tags.Title, 'sync title');
end;

procedure T.TestID3v24_ExtendedHeader;
var B: TBytes;
    Tags: TAudioTags;
    Skipped: Integer;
    Payload: TBytes;
    Ok: Boolean;
begin
  Payload:=nil;
  AppendByte(Payload, 0);
  AppendBytes(Payload, 'ExtTitle');
  B:=nil;
  AppendBytes(B, 'ID3');
  AppendByte(B, 4); AppendByte(B, 0); AppendByte(B, $40); // flags ext
  AppendSyncSafe(B, 0);
  // ext header size 6 (syncsafe)
  AppendSyncSafe(B, 6);
  AppendByte(B, 0); AppendByte(B, 0); // ext flags/padding? simplified 2 bytes to make 6
  // frame
  AppendBytes(B, 'TIT2');
  AppendSyncSafe(B, Length(Payload));
  AppendByte(B, 0); AppendByte(B, 0);
  SetLength(B, Length(B)+Length(Payload));
  Move(Payload[0], B[Length(B)-Length(Payload)], Length(Payload));
  // patch header size
  B[6]:=((Length(B)-10) shr 21) and $7F;
  B[7]:=((Length(B)-10) shr 14) and $7F;
  B[8]:=((Length(B)-10) shr 7) and $7F;
  B[9]:=(Length(B)-10) and $7F;
  Ok:=TryParseID3v2(B, Tags, Skipped);
  CheckTrue(Ok, 'ext header ok');
  CheckEqual('ExtTitle', Tags.Title, 'ext title');
end;

procedure T.TestID3_Truncated;
var B: TBytes;
    Tags: TAudioTags;
    Skipped: Integer;
    Ok: Boolean;
begin
  SetLength(B, 5);
  B[0]:=Ord('I'); B[1]:=Ord('D'); B[2]:=Ord('3'); B[3]:=3; B[4]:=0;
  Ok:=TryParseID3v2(B, Tags, Skipped);
  CheckFalse(Ok, 'truncated <10 false');
  // syncsafe high bit set
  SetLength(B, 10);
  B[0]:=Ord('I'); B[1]:=Ord('D'); B[2]:=Ord('3'); B[3]:=4; B[4]:=0; B[5]:=0;
  B[6]:=$FF; B[7]:=0; B[8]:=0; B[9]:=0; // $FF has high bit
  Ok:=TryParseID3v2(B, Tags, Skipped);
  CheckFalse(Ok, 'syncsafe high bit false');
end;

procedure T.TestVorbis_Normal;
var D: TBytes;
    Tags: TAudioTags;
    Ok: Boolean;
    LE: DWord;
begin
  D:=nil;
  // vendor "test" len 4
  AppendDWordLE(D, 4); AppendBytes(D, 'test');
  AppendDWordLE(D, 3);
  // TITLE=Song
  LE:=Length('TITLE=Song'); AppendDWordLE(D, LE); AppendBytes(D, 'TITLE=Song');
  LE:=Length('ARTIST=Bob'); AppendDWordLE(D, LE); AppendBytes(D, 'ARTIST=Bob');
  LE:=Length('TRACKNUMBER=5'); AppendDWordLE(D, LE); AppendBytes(D, 'TRACKNUMBER=5');
  Ok:=TryParseVorbisComment(D, Tags);
  CheckTrue(Ok, 'vorbis normal ok');
  CheckEqual('Song', Tags.Title, 'vorbis title');
  CheckEqual('Bob', Tags.Artist, 'vorbis artist');
  CheckEqual(5, Tags.TrackNo, 'vorbis track');
end;

procedure T.TestVorbis_CaseInsensitive;
var D: TBytes;
    Tags: TAudioTags;
    Ok: Boolean;
begin
  D:=nil;
  AppendDWordLE(D, 4); AppendBytes(D, 'vend');
  AppendDWordLE(D, 2);
  AppendDWordLE(D, Length('title=low')); AppendBytes(D, 'title=low');
  AppendDWordLE(D, Length('GENRE=Rock')); AppendBytes(D, 'GENRE=Rock');
  Ok:=TryParseVorbisComment(D, Tags);
  CheckTrue(Ok, 'case ok');
  CheckEqual('low', Tags.Title, 'case title');
  CheckTrue(Length(Tags.Extra)=1, 'genre extra 1');
  if Length(Tags.Extra)>0 then CheckEqual('Genre', Tags.Extra[0].Key, 'genre key');
end;

procedure T.TestVorbis_Truncated;
var D: TBytes;
    Tags: TAudioTags;
    Ok: Boolean;
begin
  D:=nil;
  AppendDWordLE(D, 100); // vendor len 100 but only 4 bytes exist
  AppendBytes(D, 'abcd');
  Ok:=TryParseVorbisComment(D, Tags);
  CheckFalse(Ok, 'vorbis truncated false');
end;

procedure T.TestRiffInfo_Normal;
var Stream: IStream;
    Limit: Int64;
    Tags: TAudioTags;
    Ok: Boolean;
    Buf: TBytes;
    procedure AppendChunk(const ID, S: string);
    var L: DWord;
        P: Integer;
    begin
      P:=Length(Buf);
      SetLength(Buf, P+8+Length(S)+ (Length(S) and 1));
      Buf[P]:=Ord(ID[1]); Buf[P+1]:=Ord(ID[2]); Buf[P+2]:=Ord(ID[3]); Buf[P+3]:=Ord(ID[4]);
      L:=Length(S);
      Buf[P+4]:=L and $FF; Buf[P+5]:=(L shr 8) and $FF; Buf[P+6]:=(L shr 16) and $FF; Buf[P+7]:=(L shr 24) and $FF;
      Move(S[1], Buf[P+8], L);
      if (L and 1)<>0 then Buf[P+8+L]:=0;
    end;
begin
  Buf:=nil;
  AppendBytes(Buf, 'INFO');
  AppendChunk('INAM','TitleX');
  AppendChunk('IART','ArtistY');
  AppendChunk('ITRK','7');
  AppendChunk('ICRD','2022-01-01');
  Stream:=BytesStream(0);
  if Length(Buf)>0 then Stream.Write(Buf[0], Length(Buf));
  Stream.Position:=0;
  Limit:=Stream.Size;
  Ok:=TryParseRiffInfo(Stream, Limit, Tags);
  CheckTrue(Ok, 'riff info ok');
  CheckEqual('TitleX', Tags.Title, 'info title');
  CheckEqual('ArtistY', Tags.Artist, 'info artist');
  CheckEqual(7, Tags.TrackNo, 'info track');
  CheckEqual('2022', Tags.Date, 'info date');
end;

procedure T.TestRiffInfo_Truncated;
var Stream: IStream;
    Limit: Int64;
    Tags: TAudioTags;
    Ok: Boolean;
    Buf: TBytes;
begin
  Buf:=nil;
  AppendBytes(Buf, 'INFO');
  AppendBytes(Buf, 'INAM');
  AppendDWordLE(Buf, 10); // declares 10 but only 3 bytes remain
  AppendBytes(Buf, 'abc');
  Stream:=BytesStream(0);
  if Length(Buf)>0 then Stream.Write(Buf[0], Length(Buf));
  Stream.Position:=0;
  Limit:=Stream.Size;
  Ok:=TryParseRiffInfo(Stream, Limit, Tags);
  CheckFalse(Ok, 'riff truncated false');
end;

procedure T.TestMergeTags;
var A,B,C: TAudioTags;
begin
  A:=Default(TAudioTags); B:=Default(TAudioTags);
  A.Title:='ATitle';
  A.Extra:=nil;
  SetLength(A.Extra,1); A.Extra[0].Key:='Genre'; A.Extra[0].Value:='Rock';
  B.Artist:='BArtist';
  SetLength(B.Extra,1); B.Extra[0].Key:='GENRE'; B.Extra[0].Value:='Pop';
  SetLength(B.Extra,2); B.Extra[1].Key:='Publisher'; B.Extra[1].Value:='Pub';
  C:=MergeTags(A,B);
  CheckEqual('ATitle', C.Title, 'merge title keep A');
  CheckEqual('BArtist', C.Artist, 'merge artist from B');
  CheckEqual(2, Length(C.Extra), 'merge extra 2');
  // Genre should be Rock (from A) not Pop
  CheckEqual('Genre', C.Extra[0].Key, 'merge genre key');
  CheckEqual('Rock', C.Extra[0].Value, 'merge genre val');
end;

var
  LSuite: TTestSuite;
  LCase: T;
begin
  LCase:=T.Create;
  LSuite:=TTestSuite.Create('nextpas.core.audio.meta');
  LSuite.Test('id3v23 iso8859', @LCase.TestID3v23_Iso8859);
  LSuite.Test('id3v24 utf16 bom', @LCase.TestID3v24_Utf16BOM);
  LSuite.Test('id3v24 syncsafe', @LCase.TestID3v24_SyncSafeSize);
  LSuite.Test('id3v24 extended header', @LCase.TestID3v24_ExtendedHeader);
  LSuite.Test('id3 truncated', @LCase.TestID3_Truncated);
  LSuite.Test('vorbis normal', @LCase.TestVorbis_Normal);
  LSuite.Test('vorbis case insensitive', @LCase.TestVorbis_CaseInsensitive);
  LSuite.Test('vorbis truncated', @LCase.TestVorbis_Truncated);
  LSuite.Test('riff info normal', @LCase.TestRiffInfo_Normal);
  LSuite.Test('riff info truncated', @LCase.TestRiffInfo_Truncated);
  LSuite.Test('merge tags', @LCase.TestMergeTags);
  LCase.Free;
  if not LSuite.Run then Halt(1);
end.
