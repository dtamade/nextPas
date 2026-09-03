program test_ssh_compress;
{$I nextpas.core.settings.inc}
uses  nextpas.core.base, nextpas.core.ssh.compress, nextpas.core.ssh.errors, nextpas.core.test, nextpas.core.base.utils;
var Runner: TSuiteRunner; Suite: TTestSuite;
function StrToBytes(const s:string):TBytes; var i:integer; begin SetLength(Result,length(s)); for i:=1 to length(s) do Result[i-1]:=Byte(s[i]); end;
begin
  Suite:=TTestSuite.Create('ssh compress');
  Suite.Test('roundtrip single', procedure var C:ISshCompressor; A,B,D:TBytes; begin C:=CreateSshZlibCompressor; A:=StrToBytes('hello world hello world hello world!!! This is a test of compression. hello world repeated'); B:=C.Compress(A); CheckTrue(Length(B)>0); D:=C.Decompress(B); CheckEqual(Int64(Length(A)),Int64(Length(D))); CheckTrue(CompareMem(@A[0],@D[0],Length(A))); end);
  Suite.Test('stateful second packet smaller', procedure var C:ISshCompressor; A1,A2,B1,B2, D1,D2:TBytes; begin C:=CreateSshZlibCompressor; A1:=StrToBytes(StringOfChar('A', 1024)); B1:=C.Compress(A1); D1:=C.Decompress(B1); CheckTrue(CompareMem(@A1[0],@D1[0],Length(A1))); A2:=StrToBytes(StringOfChar('A', 1024)); B2:=C.Compress(A2); CheckTrue(Length(B2) < Length(B1)); D2:=C.Decompress(B2); CheckTrue(CompareMem(@A2[0],@D2[0],Length(A2))); end);
  Suite.Test('empty roundtrip', procedure var C:ISshCompressor; B,D:TBytes; begin C:=CreateSshZlibCompressor; B:=C.Compress(nil); D:=C.Decompress(B); CheckEqual(Int64(0),Int64(Length(D))); end);
  Suite.Test('bomb limit', procedure var C:ISshCompressor; A,B:TBytes; ok:Boolean; begin C:=CreateSshZlibCompressor; A:=StrToBytes(StringOfChar('x', 64*1024)); B:=C.Compress(A); ok:=False; try C.Decompress(B); except on E:ESSHError do if E.Kind=sekProtocol then ok:=True; end; CheckTrue(not ok); // should not bomb within limit
  end);
  Runner:=TSuiteRunner.Create('nextpas.core.ssh.compress');
  Runner.Add(Suite); Runner.RunAll; Runner.Summary; if not Runner.AllPassed then Halt(1);
end.
