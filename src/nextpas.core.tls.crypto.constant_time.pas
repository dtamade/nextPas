unit nextpas.core.tls.crypto.constant_time;

{$mode ObjFPC}{$H+}

{
  Constant-Time Cryptographic Operations
  
  Purpose: Provide timing-attack resistant operations for comparing
           sensitive data (passwords, tokens, session IDs, etc.)
  
  Security: All comparison operations take constant time regardless
            of where differences occur in the data
            
  Reference: Implements constant-time comparisons as described in:
             - "The Security Impact of a New Cryptographic Library"
             - OWASP Cryptographic Storage Cheat Sheet
}

interface

uses
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  SysUtils, Classes;

type
  { Constant-time operations for cryptographic purposes }
  TConstantTime = class
  public
    {**
     * Constant-time byte array comparison
     * 
     * Compares two byte arrays in constant time to prevent timing attacks.
     * Execution time depends only on array length, not on content or
     * where differences occur.
     * 
     * @param A First byte array
     * @param B Second byte array
     * @return 1 if arrays are equal and same length, 0 otherwise
     * 
     * Security: Resistant to timing side-channel attacks
     *}
    class function CompareBytes(const A, B: TBytes): Integer; static;
    
    {**
     * Constant-time buffer comparison
     * 
     * @param A Pointer to first buffer
     * @param B Pointer to second buffer
     * @param Len Length of buffers in bytes
     * @return 1 if buffers are equal, 0 otherwise
     * 
     * Note: Both buffers must be at least Len bytes
     * Security: Constant-time execution
     *}
    class function CompareBuffer(A, B: Pointer; Len: NativeUInt): Integer; static;
    
    {**
     * Constant-time string comparison
     * 
     * Use this for comparing passwords, tokens, and other secrets.
     * Converts strings to UTF-8 bytes and performs constant-time comparison.
     * 
     * @param A First string
     * @param B Second string
     * @return True if strings are equal, False otherwise
     * 
     * Security: Timing-attack resistant, securely zeros byte arrays
     *}
    class function CompareStrings(const A, B: string): Boolean; static;
    
    {**
     * Constant-time conditional select
     * 
     * Returns IfTrue when Condition=1, else returns IfFalse.
     * Execution time independent of Condition value.
     * 
     * @param Condition 1 to select IfTrue, 0 to select IfFalse
     * @param IfTrue Value to return if Condition=1
     * @param IfFalse Value to return if Condition=0
     * @return Selected byte array
     * 
     * Security: Reads both arrays regardless of condition
     *}
    class function Select(Condition: Integer; const IfTrue, IfFalse: TBytes): TBytes; static;
    
    {**
     * Constant-time check if byte is zero
     * 
     * @param Value Byte to check
     * @return 1 if Value=0, else 0
     * 
     * Security: Constant-time implementation
     *}
    class function IsZero(Value: Byte): Integer; static;
    
    {**
     * Constant-time check if integer is zero
     * 
     * @param Value Integer to check
     * @return 1 if Value=0, else 0
     *}
    class function IsZeroInt(Value: Integer): Integer; static;
  end;

implementation

class function TConstantTime.CompareBytes(const A, B: TBytes): Integer;
var
  I: Integer;
  Diff: Byte;
  LenDiff: Integer;
begin
  // Check if lengths differ (NOT constant-time, but necessary)
  // In practice, secrets being compared should have known equal lengths
  LenDiff := Length(A) - Length(B);
  if LenDiff <> 0 then
    Exit(0);
  
  // Constant-time comparison of contents
  Diff := 0;
  for I := 0 to Length(A) - 1 do
  begin
    // XOR finds differences, OR accumulates any difference
    Diff := Diff or (A[I] xor B[I]);
  end;
  
  // Convert Diff to 0 or 1 in constant time
  // If Diff = 0 (equal): (0 - 1) = $FF, ($FF shr 8) = 0, (0 and 1) = 0, (1 - 0) = 1
  // If Diff > 0 (diff):  (X - 1) = Y,  (Y shr 8) = Z, (Z and 1) = 1, (1 - 1) = 0
  Result := 1 - (Integer((Diff - 1) shr 8) and 1);
  
  // Alternative simpler form:
  // Result := Integer((Diff - 1) shr 8) and 1;
  // Returns 1 if equal, 0 if different
  // Actually let's use this form for clarity:
  Result := Integer(((Cardinal(Diff) - 1) shr 31) and 1);
  // If Diff=0: (0-1)=$FFFFFFFF, shr 31 = 1, and 1 = 1 (EQUAL)
  // If Diff>0: (N-1)=M<$FFFFFFFF, shr 31 = 0, and 1 = 0 (DIFFERENT)
end;

class function TConstantTime.CompareBuffer(A, B: Pointer; Len: NativeUInt): Integer;
var
  I: NativeUInt;
  PA, PB: PByte;
  Diff: Byte;
begin
  // Guard zero-length contract first to avoid NativeUInt underflow on loop bound.
  // Empty buffers are equal regardless of pointer values.
  if Len = 0 then
    Exit(1);

  if (A = nil) or (B = nil) then
    Exit(0);
  
  PA := PByte(A);
  PB := PByte(B);
  Diff := 0;
  
  // Constant-time byte-by-byte comparison
  for I := 0 to Len - 1 do
  begin
    Diff := Diff or (PA^ xor PB^);
    Inc(PA);
    Inc(PB);
  end;
  
  // Convert to 0 or 1
  Result := Integer(((Cardinal(Diff) - 1) shr 31) and 1);
end;

class function TConstantTime.CompareStrings(const A, B: string): Boolean;
var
  ABytes, BBytes: TBytes;
  CompResult: Integer;
begin
  // Convert to UTF-8 bytes
  ABytes := TEncoding.UTF8.GetBytes(UnicodeString(A));
  BBytes := TEncoding.UTF8.GetBytes(UnicodeString(B));
  
  try
    // Constant-time comparison
    CompResult := CompareBytes(ABytes, BBytes);
    Result := (CompResult = 1);
  finally
    // Securely zero the byte arrays
    if Length(ABytes) > 0 then
      FillChar(ABytes[0], Length(ABytes), 0);
    if Length(BBytes) > 0 then
      FillChar(BBytes[0], Length(BBytes), 0);
  end;
end;

class function TConstantTime.Select(Condition: Integer; const IfTrue, IfFalse: TBytes): TBytes;
var
  I: Integer;
  Mask: Byte;
begin
  // Condition should be 0 or 1
  // Create mask: if Condition=1 then Mask=$FF, else Mask=$00
  Mask := Byte(-(Condition and 1));
  
  // Select the appropriate length (assumes same length for security)
  if Length(IfTrue) <> Length(IfFalse) then
    raise ESSLException.Create('Select requires equal-length arrays');
  
  Result := nil;
  SetLength(Result, Length(IfTrue));
  
  // Constant-time selection
  for I := 0 to Length(IfTrue) - 1 do
  begin
    // Result[I] = (IfTrue[I] and Mask) or (IfFalse[I] and not Mask)
    Result[I] := (IfTrue[I] and Mask) or (IfFalse[I] and not Mask);
  end;
end;

class function TConstantTime.IsZero(Value: Byte): Integer;
begin
  // Returns 1 if Value=0, else 0
  // Constant-time implementation
  Result := Integer(((Cardinal(Value) or Cardinal(-Integer(Value))) shr 31) xor 1);
end;

class function TConstantTime.IsZeroInt(Value: Integer): Integer;
begin
  // Returns 1 if Value=0, else 0
  Result := Integer(((Cardinal(Value) or Cardinal(-Value)) shr 31) xor 1);
end;

end.
