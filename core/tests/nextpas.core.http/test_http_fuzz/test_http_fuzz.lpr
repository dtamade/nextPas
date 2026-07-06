program test_http_fuzz;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.http.fuzz;

var
  T: TTestSuite;

{ Test HTTP request parser fuzz }
procedure TestHttpRequestFuzz;
var
  LSeeds: array[0..2] of TBytes;
  LCrashes: Int32;
begin
  { HTTP request seeds }
  LSeeds[0] := TBytes.Create($47, $45, $54, $20, $2F, $20, $48, $54, $54, $50, $2F, $31, $2E, $31, $0D, $0A); { "GET / HTTP/1.1\r\n" }
  LSeeds[1] := TBytes.Create($50, $4F, $53, $54, $20, $2F, $64, $61, $74, $61, $20, $48, $54, $54, $50, $2F, $31, $2E, $31, $0D, $0A); { "POST /data HTTP/1.1\r\n" }
  LSeeds[2] := TBytes.Create($48, $54, $54, $50, $2F, $31, $2E, $31, $20, $32, $30, $30, $20, $4F, $4B, $0D, $0A); { "HTTP/1.1 200 OK\r\n" }

  LCrashes := TFuzzRunner.RunHttpRequestFuzz(LSeeds, 1000);
  CheckEqual(0, LCrashes, 'no HTTP request parser crashes');
end;

{ Test HTTP response parser fuzz }
procedure TestHttpResponseFuzz;
var
  LSeeds: array[0..2] of TBytes;
  LCrashes: Int32;
begin
  { HTTP response seeds }
  LSeeds[0] := TBytes.Create($48, $54, $54, $50, $2F, $31, $2E, $31, $20, $32, $30, $30, $20, $4F, $4B, $0D, $0A); { "HTTP/1.1 200 OK\r\n" }
  LSeeds[1] := TBytes.Create($48, $54, $54, $50, $2F, $31, $2E, $31, $20, $34, $30, $34, $20, $4E, $6F, $74, $20, $46, $6F, $75, $6E, $64, $0D, $0A); { "HTTP/1.1 404 Not Found\r\n" }
  LSeeds[2] := TBytes.Create($48, $54, $54, $50, $2F, $31, $2E, $31, $20, $33, $30, $31, $20, $4D, $6F, $76, $65, $64, $0D, $0A); { "HTTP/1.1 301 Moved\r\n" }

  LCrashes := TFuzzRunner.RunHttpResponseFuzz(LSeeds, 1000);
  CheckEqual(0, LCrashes, 'no HTTP response parser crashes');
end;

{ Test WebSocket frame parser fuzz }
procedure TestWebSocketFrameFuzz;
var
  LSeeds: array[0..2] of TBytes;
  LCrashes: Int32;
begin
  { WebSocket frame seeds }
  LSeeds[0] := TBytes.Create($81, $05, $48, $65, $6C, $6C, $6F); { Text "Hello" }
  LSeeds[1] := TBytes.Create($82, $04, $01, $02, $03, $04); { Binary }
  LSeeds[2] := TBytes.Create($89, $05, $50, $69, $6E, $67, $31); { Ping "Ping1" }

  LCrashes := TFuzzRunner.RunWebSocketFrameFuzz(LSeeds, 1000);
  CheckEqual(0, LCrashes, 'no WebSocket frame parser crashes');
end;

{ Test mutator functions }
procedure TestMutatorFlipBits;
var
  LData, LMutated: TBytes;
begin
  LData := TBytes.Create($48, $65, $6C, $6C, $6F); { "Hello" }
  LMutated := TFuzzMutator.FlipBits(LData);
  CheckEqual(Length(LData), Length(LMutated), 'same length after flip');
  { At least one bit should be different }
  Check(LData <> LMutated, 'data changed after flip');
end;

procedure TestMutatorInsertBytes;
var
  LData, LMutated: TBytes;
begin
  LData := TBytes.Create($48, $65, $6C, $6C, $6F); { "Hello" }
  LMutated := TFuzzMutator.InsertBytes(LData);
  Check(Length(LMutated) > Length(LData), 'longer after insert');
end;

procedure TestMutatorDeleteBytes;
var
  LData, LMutated: TBytes;
begin
  LData := TBytes.Create($48, $65, $6C, $6C, $6F); { "Hello" }
  LMutated := TFuzzMutator.DeleteBytes(LData);
  Check(Length(LMutated) < Length(LData), 'shorter after delete');
end;

procedure TestMutatorReplaceBytes;
var
  LData, LMutated: TBytes;
begin
  LData := TBytes.Create($48, $65, $6C, $6C, $6F); { "Hello" }
  LMutated := TFuzzMutator.ReplaceBytes(LData);
  CheckEqual(Length(LData), Length(LMutated), 'same length after replace');
end;

procedure TestMutatorBoundaryValues;
var
  LData, LMutated: TBytes;
begin
  LData := TBytes.Create($48, $65, $6C, $6C, $6F); { "Hello" }
  LMutated := TFuzzMutator.BoundaryValues(LData);
  CheckEqual(Length(LData), Length(LMutated), 'same length after boundary');
end;

begin
  T := TTestSuite.Create('nextpas.core.http.fuzz');

  { Mutator tests }
  T.Test('Mutator: flip bits', @TestMutatorFlipBits);
  T.Test('Mutator: insert bytes', @TestMutatorInsertBytes);
  T.Test('Mutator: delete bytes', @TestMutatorDeleteBytes);
  T.Test('Mutator: replace bytes', @TestMutatorReplaceBytes);
  T.Test('Mutator: boundary values', @TestMutatorBoundaryValues);

  { Fuzz tests }
  T.Test('HTTP request parser fuzz - 1000 iterations', @TestHttpRequestFuzz);
  T.Test('HTTP response parser fuzz - 1000 iterations', @TestHttpResponseFuzz);
  T.Test('WebSocket frame parser fuzz - 1000 iterations', @TestWebSocketFrameFuzz);

  if not T.Run then Halt(1);
end.
