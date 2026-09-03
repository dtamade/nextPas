unit nextpas.core.ssh.cipher.intf;

{** nextpas.core.ssh.cipher.intf - 包加密方向接口（四件套 intf）。
 *  纯接口契约，不含实现；base 仅提供常量，intf 仅暴露方向抽象。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type
  ISshPacketSender = interface
    ['{9C1E6E10-4A11-4F72-9D30-5A0000000001}']
    function PaddingBlock: Integer;
    function AadLen: Integer;
    function Protect(const ABodyPlain: TBytes; ASeq: UInt32): TBytes;
    function ProtectPayload(const APayload: TBytes; APadLen: SizeUInt; ASeq: UInt32): TBytes;
  end;

  ISshPacketReceiver = interface
    ['{9C1E6E10-4A11-4F72-9D30-5A0000000002}']
    function BodyLengthFromHeader(ASeq: UInt32; const AHeader: TBytes): UInt32;
    function TrailerSize(ABodyLen: UInt32): UInt32;
    function Unprotect(ASeq: UInt32; const AWire: TBytes): TBytes;
  end;

implementation

end.
