program fuzz_ssl;

{$mode objfpc}{$H+}

{**
 * Fuzz Testing for fafafa.ssl Security-Critical Functions
 *
 * Targets:
 * - Base64 decoding (pure Pascal)
 * - Hex decoding (pure Pascal)
 *
 * Run: ./fuzz_ssl [iterations]
 * Default: 5000 iterations per target
 *}

uses
  SysUtils, Classes,
  fuzz_framework;

{ ============================================================================ }
{ Pure Pascal Implementations for Fuzzing                                       }
{ (No OpenSSL dependency - safe to fuzz even when OpenSSL fails to load)       }
{ ============================================================================ }

const
  Base64Chars: array[0..63] of Char =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

function PureBase64Decode(const AInput: AnsiString): TBytes;
var
  I, J, Len, OutLen: Integer;
  A, B, C, D: Integer;
  DecTable: array[0..255] of ShortInt;  // Extended to handle all byte values
  ChVal: Byte;
begin
  SetLength(Result, 0);
  if AInput = '' then Exit;

  // Build decode table (all values start as invalid)
  for I := 0 to 255 do
    DecTable[I] := -1;
  for I := 0 to 63 do
    DecTable[Ord(Base64Chars[I])] := I;
  DecTable[Ord('=')] := -2;  // Special marker for padding

  // Calculate output length
  Len := Length(AInput);
  OutLen := (Len * 3) div 4;
  if (Len > 0) and (AInput[Len] = '=') then Dec(OutLen);
  if (Len > 1) and (AInput[Len - 1] = '=') then Dec(OutLen);
  if OutLen <= 0 then Exit;

  SetLength(Result, OutLen);
  J := 0;
  I := 1;

  while I <= Len do
  begin
    // Get 4 characters, handle invalid chars
    A := 0; B := 0; C := 0; D := 0;

    if I <= Len then begin
      ChVal := Ord(AInput[I]);
      if DecTable[ChVal] >= 0 then
        A := DecTable[ChVal]
      else if DecTable[ChVal] = -2 then  // Padding
        A := 0
      else
        raise Exception.Create('Invalid base64 character');
    end;
    Inc(I);

    if I <= Len then begin
      ChVal := Ord(AInput[I]);
      if DecTable[ChVal] >= 0 then
        B := DecTable[ChVal]
      else if DecTable[ChVal] = -2 then
        B := 0
      else
        raise Exception.Create('Invalid base64 character');
    end;
    Inc(I);

    if I <= Len then begin
      ChVal := Ord(AInput[I]);
      if DecTable[ChVal] >= 0 then
        C := DecTable[ChVal]
      else if DecTable[ChVal] = -2 then
        C := 0
      else
        raise Exception.Create('Invalid base64 character');
    end;
    Inc(I);

    if I <= Len then begin
      ChVal := Ord(AInput[I]);
      if DecTable[ChVal] >= 0 then
        D := DecTable[ChVal]
      else if DecTable[ChVal] = -2 then
        D := 0
      else
        raise Exception.Create('Invalid base64 character');
    end;
    Inc(I);

    // Decode
    if J < OutLen then begin
      Result[J] := Byte((A shl 2) or (B shr 4));
      Inc(J);
    end;
    if J < OutLen then begin
      Result[J] := Byte((B shl 4) or (C shr 2));
      Inc(J);
    end;
    if J < OutLen then begin
      Result[J] := Byte((C shl 6) or D);
      Inc(J);
    end;
  end;
end;

function PureHexToBytes(const AHex: AnsiString): TBytes;
var
  I, Len: Integer;
  Ch: AnsiChar;
  Hi, Lo: Byte;
begin
  SetLength(Result, 0);
  Len := Length(AHex);
  if (Len = 0) or (Len mod 2 <> 0) then
    raise Exception.Create('Invalid hex string length');

  SetLength(Result, Len div 2);
  for I := 0 to (Len div 2) - 1 do
  begin
    // High nibble
    Ch := AHex[I * 2 + 1];
    case Ch of
      '0'..'9': Hi := Ord(Ch) - Ord('0');
      'A'..'F': Hi := Ord(Ch) - Ord('A') + 10;
      'a'..'f': Hi := Ord(Ch) - Ord('a') + 10;
    else
      raise Exception.Create('Invalid hex character');
    end;

    // Low nibble
    Ch := AHex[I * 2 + 2];
    case Ch of
      '0'..'9': Lo := Ord(Ch) - Ord('0');
      'A'..'F': Lo := Ord(Ch) - Ord('A') + 10;
      'a'..'f': Lo := Ord(Ch) - Ord('a') + 10;
    else
      raise Exception.Create('Invalid hex character');
    end;

    Result[I] := (Hi shl 4) or Lo;
  end;
end;

{ ============================================================================ }
{ Fuzz Targets                                                                  }
{ ============================================================================ }

procedure FuzzBase64Decode(const AInput: TBytes);
var
  InputStr: AnsiString;
  Output: TBytes;
begin
  if Length(AInput) = 0 then Exit;
  SetLength(InputStr, Length(AInput));
  Move(AInput[0], InputStr[1], Length(AInput));

  try
    Output := PureBase64Decode(InputStr);
  except
    // Expected: invalid base64 should raise exception
  end;
end;

procedure FuzzHexDecode(const AInput: TBytes);
var
  InputStr: AnsiString;
  Output: TBytes;
begin
  if Length(AInput) = 0 then Exit;
  SetLength(InputStr, Length(AInput));
  Move(AInput[0], InputStr[1], Length(AInput));

  try
    Output := PureHexToBytes(InputStr);
  except
    // Expected for invalid hex
  end;
end;

{ ============================================================================ }
{ Main Program                                                                  }
{ ============================================================================ }

var
  Fuzzer: TFuzzer;
  Iterations: Integer;

begin
  WriteLn('================================================================');
  WriteLn('          fafafa.ssl Fuzz Testing Suite                         ');
  WriteLn('================================================================');
  WriteLn;

  // Parse iterations from command line
  if ParamCount >= 1 then
    Iterations := StrToIntDef(ParamStr(1), 5000)
  else
    Iterations := 5000;

  // Create fuzzer
  Fuzzer := TFuzzer.Create;
  try
    Fuzzer.MaxInputSize := 256;  // Reduced for faster fuzzing
    Fuzzer.MinInputSize := 0;
    Fuzzer.Verbose := False;

    // Register targets
    WriteLn('Registering fuzz targets...');
    Fuzzer.RegisterTarget('base64_decode', @FuzzBase64Decode);
    Fuzzer.RegisterTarget('hex_decode', @FuzzHexDecode);
    WriteLn;

    // Run fuzzing
    Fuzzer.Run(Iterations);

    // Save results
    Fuzzer.SaveStatsToFile('fuzz_results.txt');
    WriteLn('Results saved to: fuzz_results.txt');

  finally
    Fuzzer.Free;
  end;

  WriteLn;
  WriteLn('Fuzz testing complete.');
end.
