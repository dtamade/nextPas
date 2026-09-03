unit nextpas.core.crypto.secure.intf;

{$I nextpas.core.settings.inc}

{ nextpas.core.crypto.secure.intf — 随机/常量时间域接口契约
  base ← intf. platform.random 单源 CSPRNG, inline 常量时间 compare/select, 0 长度零分配. }

interface

uses
  nextpas.core.base,
  nextpas.core.crypto.secure.base;

type
  ISecureRandom = interface
    ['{B6C7D8E9-F0A1-000A-ABCD-1234567890B3}']
    function Fill(var ABuf: TBytes; ACount: Integer): Boolean;
    function Generate(ACount: Integer): TBytes;
  end;

  IConstantTime = interface
    ['{B6C7D8E9-F0A1-000B-ABCD-1234567890B4}']
    function Equal(const A, B: TBytes): Boolean;
    function Select(ACond: Integer; const ATrue, AFalse: TBytes): TBytes;
  end;

function SecureIsValidLength(ALen: Integer): Boolean; inline;
function SecureCTEqual(const A, B: TBytes): Boolean; inline;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.crypto.constant_time;

function SecureIsValidLength(ALen: Integer): Boolean; inline;
begin
  Result := ALen >= 0;
end;

function SecureCTEqual(const A, B: TBytes): Boolean; inline;
begin
  { perf: inline 常量时间比较 single source TConstantTime.CompareBytes, 零拷贝 TByteSpan, 不泄露时序 }
  Result := TConstantTime.CompareBytes(A, B) = 1;
end;

end.
