unit nextpas.core.websocket.base;
{$I nextpas.core.settings.inc}

interface

uses
  SysUtils;

const
  WS_OPCODE_CONTINUATION = $0;
  WS_OPCODE_TEXT = $1;
  WS_OPCODE_BINARY = $2;
  WS_OPCODE_CLOSE = $8;
  WS_OPCODE_PING = $9;
  WS_OPCODE_PONG = $A;

  WS_CLOSE_NORMAL = 1000;
  WS_CLOSE_GOING_AWAY = 1001;
  WS_CLOSE_PROTOCOL_ERROR = 1002;
  WS_CLOSE_UNSUPPORTED = 1003;
  WS_CLOSE_ABNORMAL = 1006;
  WS_CLOSE_INVALID_PAYLOAD = 1007;
  WS_CLOSE_POLICY_VIOLATION = 1008;
  WS_CLOSE_TOO_LARGE = 1009;

  WS_GUID = '258EAFA5-E914-47DA-95CA-5AB0F964E80E';

  WS_MAX_FRAME_SIZE = 16 * 1024 * 1024;       { 16MB default max payload }
  WS_MAX_CONTROL_PAYLOAD = 125;                { RFC 6455: control frames <= 125 bytes }

type
  TWebSocketRole = (wsrClient, wsrServer);

  TWebSocketFrame = record
    Fin: Boolean;
    Opcode: Byte;
    Masked: Boolean;
    MaskKey: array[0..3] of Byte;
    Payload: TBytes;
  end;

  TWebSocketMessage = record
    IsText: Boolean;
    Payload: TBytes;
  end;

implementation

end.
