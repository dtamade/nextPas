program test_ssh_buffer;

{$I nextpas.core.settings.inc}

{ S1 gate：RFC 4251 wire 类型读写。
 * 覆盖：byte/bool/uint32/string/mpint/name-list 往返、RFC 4251 mpint 边界向量、
 * wire 精确字节、越界错误（ESSHError/sekind protocol）。}

uses
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.test, nextpas.core.base, nextpas.core.base.utils, nextpas.core.text.conv;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

procedure AssertProtocolError(AProc: TTestProc);
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    AProc;
  except
    on E: ESSHError do
    begin
      LRaised := True;
      CheckEqual(Ord(sekProtocol), Ord(E.Kind));
    end;
  end;
  CheckTrue(LRaised, 'expected ESSHError(sekProtocol)');
end;

{ RFC 4251 §5 向量：写入 magnitude，断言完整 wire 表示 }
procedure PutMPIntExpect(const AMagnitudeHex, AWireHex: string);
var
  LW: TsshWriter;
begin
  LW := TsshWriter.Create(64);
  try
    LW.PutMPInt(HexToBytes(AMagnitudeHex));
    CheckEqual(AWireHex, BytesToHex(LW.ToBytes), 'wire for ' + AMagnitudeHex);
  finally
    LW.Free;
  end;
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
  LW: TsshWriter;
  LR: TsshReader;
begin
  LSuite := TTestSuite.Create('ssh buffer');

  LSuite.Test('byte/boolean roundtrip', procedure
  begin
    LW := TsshWriter.Create(16);
    try
      LW.PutByte($00);
      LW.PutByte($FF);
      LW.PutBoolean(True);
      LW.PutBoolean(False);
      LR := TsshReader.Create(LW.ToBytes);
      try
        CheckEqual(Int64($00), Int64(LR.ReadByte));
        CheckEqual(Int64($FF), Int64(LR.ReadByte));
        CheckEqual(True, LR.ReadBoolean);
        CheckEqual(False, LR.ReadBoolean);
        CheckTrue(LR.AtEnd);
      finally
        LR.Free;
      end;
    finally
      LW.Free;
    end;
  end);

  LSuite.Test('uint32 boundaries exact wire', procedure
  var
    LWire: TBytes;
  begin
    LW := TsshWriter.Create(16);
    try
      LW.PutUInt32(0);
      LW.PutUInt32($DEADBEEF);
      LW.PutUInt32($FFFFFFFF);
      LWire := LW.ToBytes;
      CheckEqual('00000000deadbeefffffffff', BytesToHex(LWire));
      LR := TsshReader.Create(LWire);
      try
        CheckEqual(Int64(0), Int64(LR.ReadUInt32));
        CheckEqual(Int64($DEADBEEF), Int64(LR.ReadUInt32));
        CheckEqual(UInt64($FFFFFFFF), UInt64(LR.ReadUInt32));
      finally
        LR.Free;
      end;
    finally
      LW.Free;
    end;
  end);

  LSuite.Test('string bytes/text roundtrip', procedure
  var
    LPayload: TBytes;
    LBack: TBytes;
  begin
    LPayload := HexToBytes('00112233445566778899aabbccddeeff');
    LW := TsshWriter.Create(8);
    try
      LW.PutStringBytes(LPayload);
      LW.PutStringText('hello, ssh');
      LW.PutStringText('');
      LR := TsshReader.Create(LW.ToBytes);
      try
        LBack := LR.ReadStringBytes;
        CheckTrue(CompareMem(@LPayload[0], @LBack[0], Length(LPayload)),
          'payload mismatch');
        CheckEqual('hello, ssh', LR.ReadStringText);
        CheckEqual(0, Length(LR.ReadStringBytes));
        CheckTrue(LR.AtEnd);
      finally
        LR.Free;
      end;
    finally
      LW.Free;
    end;
  end);

  { RFC 4251 §5 mpint 示例表：value → 完整 wire 表示 }
  LSuite.Test('mpint RFC 4251 vectors', procedure
  begin
    { 0 → 空 mpint }
    PutMPIntExpect('', '00000000');
    { 高位为 1 的正数需要前导零字节（OpenSSH 互操作行为）}
    PutMPIntExpect('9a378f9d2ed19d7fe3068c5dd03ba11f',
      '00000011009a378f9d2ed19d7fe3068c5dd03ba11f');
    PutMPIntExpect('7f', '000000017f');
    PutMPIntExpect('80', '000000020080');
    PutMPIntExpect('7fff', '000000027fff');
    PutMPIntExpect('8000', '00000003008000');
    PutMPIntExpect('ffffffffffffffff',
      '0000000900ffffffffffffffff');
    { 输入自带前导零：剥离后按剩余 magnitude 编码 }
    PutMPIntExpect('0000000000000081', '000000020081');
  end);

  LSuite.Test('mpint read strips pad and leading zeros', procedure
  var
    LMagnitude: TBytes;
  begin
    LW := TsshWriter.Create(32);
    try
      LW.PutMPInt(HexToBytes('ffffffffffffffff'));
      LW.PutMPInt(HexToBytes(''));
      LW.PutRaw(HexToBytes('00000002' + '0081'));
      LR := TsshReader.Create(LW.ToBytes);
      try
        LMagnitude := LR.ReadMPInt;
        CheckEqual('ffffffffffffffff', BytesToHex(LMagnitude));
        CheckEqual(0, Length(LR.ReadMPInt));
        CheckEqual('81', BytesToHex(LR.ReadMPInt));
      finally
        LR.Free;
      end;
    finally
      LW.Free;
    end;
  end);

  LSuite.Test('name-list roundtrip', procedure
  var
    LNames: TStringArray;
  begin
    LW := TsshWriter.Create(64);
    try
      LW.PutNameList(['curve25519-sha256', 'ssh-ed25519']);
      LW.PutNameList([]);
      LR := TsshReader.Create(LW.ToBytes);
      try
        LNames := LR.ReadNameList;
        CheckEqual(2, Length(LNames));
        CheckEqual('curve25519-sha256', LNames[0]);
        CheckEqual('ssh-ed25519', LNames[1]);
        CheckEqual(0, Length(LR.ReadNameList));
      finally
        LR.Free;
      end;
    finally
      LW.Free;
    end;
  end);

  LSuite.Test('out of bounds reads raise sekProtocol', procedure
  begin
    LR := TsshReader.Create(HexToBytes(''));
    try
      AssertProtocolError(procedure begin LR.ReadByte; end);
    finally
      LR.Free;
    end;

    LR := TsshReader.Create(HexToBytes('0102'));
    try
      AssertProtocolError(procedure begin LR.ReadUInt32; end);
    finally
      LR.Free;
    end;

    { string 声明长度超出剩余数据 }
    LR := TsshReader.Create(HexToBytes('000000ff' + 'aa'));
    try
      AssertProtocolError(procedure begin LR.ReadStringBytes; end);
    finally
      LR.Free;
    end;

    { mpint 同样受长度校验保护 }
    LR := TsshReader.Create(HexToBytes('00000004' + '01'));
    try
      AssertProtocolError(procedure begin LR.ReadMPInt; end);
    finally
      LR.Free;
    end;
  end);

  LSuite.Test('peek/position/remaining bookkeeping', procedure
  begin
    LR := TsshReader.Create(HexToBytes('aabbccdd55'));
    try
      CheckEqual(Int64($AA), Int64(LR.PeekByte));
      CheckEqual(Int64(0), Int64(LR.Position));
      CheckEqual(Int64(5), Int64(LR.Remaining));
      CheckEqual(Int64($AA), Int64(LR.ReadByte));
      CheckEqual(Int64(1), Int64(LR.Position));
      CheckFalse(LR.AtEnd);
      LR.ReadUInt32;
      CheckTrue(LR.AtEnd);
      CheckEqual(Int64(0), Int64(LR.Remaining));
      AssertProtocolError(procedure begin LR.ReadByte; end);
    finally
      LR.Free;
    end;
  end);

  LSuite.Test('writer grows from tiny capacity and Clear resets', procedure
  begin
    LW := TsshWriter.Create(2);
    try
      LW.PutUInt32($01020304);
      LW.PutStringText('grow');
      CheckEqual(Int64(12), Int64(LW.Count));
      LW.Clear;
      CheckEqual(Int64(0), Int64(LW.Count));
      LW.PutByte($77);
      CheckEqual('77', BytesToHex(LW.ToBytes));
    finally
      LW.Free;
    end;
  end);

  LSuite.Test('text helpers roundtrip raw bytes', procedure
  var
    LBytes: TBytes;
  begin
    LBytes := SshBytesFromText('abc'#0'def');
    CheckEqual(7, Length(LBytes));
    CheckEqual('abc'#0'def', SshTextFromBytes(LBytes));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.ssh.buffer');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
