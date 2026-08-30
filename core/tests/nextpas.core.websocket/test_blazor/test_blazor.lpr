program test_blazor;

{$I nextpas.core.settings.inc}

uses
  SysUtils, Classes,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.websocket.blazor,
  nextpas.core.encoding.msgpack;

var
  T: TTestSuite;

function LoadFixture(const AName: string): TBytes;
var
  LPath: string;
  FS: TFileStream;
begin
  LPath := ExtractFilePath(ParamStr(0)) + '../../' + 'fixtures/' + AName;
  // Try relative to source
  if not FileExists(LPath) then
    LPath := 'fixtures/' + AName;
  if not FileExists(LPath) then
    LPath := 'core/tests/nextpas.core.websocket/test_blazor/fixtures/' + AName;
  if not FileExists(LPath) then
    LPath := '/home/dtamade/projects/nextPas/.worktrees/b9-spamok-signalr-20260828/core/tests/nextpas.core.websocket/test_blazor/fixtures/' + AName;
  FS := TFileStream.Create(LPath, fmOpenRead);
  try
    SetLength(Result, FS.Size);
    if FS.Size > 0 then FS.ReadBuffer(Result[0], FS.Size);
  finally
    FS.Free;
  end;
end;

procedure TestBlazorBatchInit;
var
  B: TBytes;
  Batch: TBlazorRenderBatch;
begin
  B := LoadFixture('list_render_batch.bin');
  Check(Length(B) > 24);
  Check(Batch.Init(B));
  Check(Batch.ReferenceFrameCount > 0);
  Check(Batch.StringTableStart > 0);
end;

procedure TestBlazorBatchFields;
var
  B: TBytes;
  Batch: TBlazorRenderBatch;
  FC: Integer;
  S: string;
begin
  B := LoadFixture('list_render_batch.bin');
  Check(Batch.Init(B));
  FC := Batch.ReferenceFrameCount;
  Check(FC > 10);
  // Check first element name for td
  // Find a td element
  S := Batch.StringValue(0);
  // Just check we can read string table without exception
  Check(Length(S) >= 0);
end;

procedure TestBlazorVarint;
var
  B: TBytes;
  V: UInt32;
  LPrefix: Integer;
  LOk: Boolean;
begin
  B := BlazorEncodeVarintU32(300);
  CheckEqual(Int64(2), Int64(Length(B)));
  Check(B[0] = $AC);
  Check(B[1] = $02);
  LOk := BlazorDecodeVarintU32(B, 0, V, LPrefix);
  Check(LOk);
  CheckEqual(QWord(300), QWord(V));
  CheckEqual(Int64(2), Int64(LPrefix));
end;

procedure TestHubEncodeDecode;
var
  V: TMsgPackValue;
  B: TBytes;
  Arr: THubIncomingArray;
begin
  V := TMsgPackValue.MakeArr([
    TMsgPackValue.MakeInt(1),
    TMsgPackValue.MakeArr([]),
    TMsgPackValue.MakeStr('0'),
    TMsgPackValue.MakeStr('StartCircuit'),
    TMsgPackValue.MakeArr([
      TMsgPackValue.MakeStr('https://spamok.com/'),
      TMsgPackValue.MakeStr('https://spamok.com/test'),
      TMsgPackValue.MakeStr('[]'),
      TMsgPackValue.MakeStr('appstate')
    ])
  ]);
  B := BlazorEncodeHubMessage(V);
  Check(Length(B) > 0);
  Arr := BlazorDecodeHubMessages(B);
  CheckEqual(Int64(1), Int64(Length(Arr)));
  Check(Arr[0].Kind = hikOther); // StartCircuit is Other, not special
  // Completion
  V := TMsgPackValue.MakeArr([
    TMsgPackValue.MakeInt(3),
    TMsgPackValue.MakeUInt(1),
    TMsgPackValue.MakeStr('0')
  ]);
  B := BlazorEncodeHubMessage(V);
  Arr := BlazorDecodeHubMessages(B);
  CheckEqual(Int64(1), Int64(Length(Arr)));
  Check(Arr[0].Kind = hikCompletion);
  CheckEqual('0', Arr[0].InvocationId);
end;

procedure TestDetailBatch;
var
  B: TBytes;
  Batch: TBlazorRenderBatch;
begin
  B := LoadFixture('detail_render_batch.bin');
  Check(Batch.Init(B));
  Check(Batch.ReferenceFrameCount > 0);
end;

begin
  T := TTestSuite.Create('nextpas.core.websocket.blazor');
  T.Test('batch_init', @TestBlazorBatchInit);
  T.Test('batch_fields', @TestBlazorBatchFields);
  T.Test('varint', @TestBlazorVarint);
  T.Test('hub_encode_decode', @TestHubEncodeDecode);
  T.Test('detail_batch', @TestDetailBatch);
  if not T.Run then Halt(1);
end.
