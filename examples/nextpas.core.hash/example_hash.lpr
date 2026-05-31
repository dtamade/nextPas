program example_hash;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.hash.base,
  nextpas.core.hash.intf,
  nextpas.core.hash,
  nextpas.core.crypto.hmac,
  nextpas.core.crypto.hkdf;

procedure DemoStreaming;
var
  H: IHasher;
  Chunk: array[0..255] of Byte;
  I: Integer;
begin
  WriteLn('--- Streaming Hash (simulating large file) ---');
  H := NewSHA256;
  for I := 0 to 9 do
  begin
    FillChar(Chunk, 256, Byte(I));
    H.Write(Chunk[0], 256);
  end;
  WriteLn('  SHA-256 of 2560 bytes: ', DigestToHex(H.SumBytes[0], 32));
end;

procedure DemoOneShot;
var
  Msg: TBytes;
  D: TSHA256Digest;
begin
  WriteLn('--- One-shot Hash ---');
  Msg := TEncoding.UTF8.GetBytes(UnicodeString('Hello, nextPas!'));
  D := SHA256Of(Msg[0], Length(Msg));
  WriteLn('  SHA-256("Hello, nextPas!"): ', DigestToHex(D, 32));
end;

procedure DemoHMAC;
var
  Key, Msg, Mac: TBytes;
begin
  WriteLn('--- HMAC-SHA-256 ---');
  Key := TEncoding.UTF8.GetBytes(UnicodeString('my-secret-key'));
  Msg := TEncoding.UTF8.GetBytes(UnicodeString('important data'));
  Mac := HMAC_SHA256(Key, Msg);
  WriteLn('  HMAC: ', DigestToHex(Mac[0], 32));

  // Verify: recompute and compare
  if CompareMem(@Mac[0], @HMAC_SHA256(Key, Msg)[0], 32) then
    WriteLn('  Verification: OK')
  else
    WriteLn('  Verification: FAILED');
end;

procedure DemoHKDF;
var
  IKM, Salt, Info, PRK, OKM: TBytes;
begin
  WriteLn('--- HKDF Key Derivation ---');
  IKM := TEncoding.UTF8.GetBytes(UnicodeString('input keying material'));
  Salt := TEncoding.UTF8.GetBytes(UnicodeString('optional salt'));
  Info := TEncoding.UTF8.GetBytes(UnicodeString('context info'));

  PRK := HKDF_Extract_SHA256(Salt, IKM);
  WriteLn('  PRK (32 bytes): ', Copy(DigestToHex(PRK[0], 32), 1, 16), '...');

  OKM := HKDF_Expand_SHA256(PRK, Info, 64);
  WriteLn('  OKM (64 bytes): ', Copy(DigestToHex(OKM[0], 32), 1, 16), '...');
  WriteLn('  Use OKM[0..31] as encryption key, OKM[32..63] as IV');
end;

procedure DemoClone;
var
  H, H2: IHasher;
  Part1: TBytes;
begin
  WriteLn('--- Clone (save intermediate state) ---');
  Part1 := TEncoding.UTF8.GetBytes(UnicodeString('common prefix | '));

  H := NewSHA256;
  H.Write(Part1[0], Length(Part1));
  H2 := H.Clone;

  Part1 := TEncoding.UTF8.GetBytes(UnicodeString('branch A'));
  H.Write(Part1[0], Length(Part1));
  WriteLn('  Branch A: ', Copy(DigestToHex(H.SumBytes[0], 32), 1, 16), '...');

  Part1 := TEncoding.UTF8.GetBytes(UnicodeString('branch B'));
  H2.Write(Part1[0], Length(Part1));
  WriteLn('  Branch B: ', Copy(DigestToHex(H2.SumBytes[0], 32), 1, 16), '...');
end;

begin
  WriteLn('=== nextpas.core.hash Examples ===');
  WriteLn;

  DemoStreaming;
  WriteLn;
  DemoOneShot;
  WriteLn;
  DemoHMAC;
  WriteLn;
  DemoHKDF;
  WriteLn;
  DemoClone;

  WriteLn;
  WriteLn('nextpas.core.hash=ready');
end.
