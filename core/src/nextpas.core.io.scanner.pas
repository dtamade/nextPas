unit nextpas.core.io.scanner;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.io.intf;

type
  TSplitFunc = function(const AData: TBytes; const AAtEOF: Boolean;
    out AAdvance: SizeUInt; out AToken: TBytes): Boolean;

  IScanner = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000060}']
    function Scan: Boolean;
    function Text: string;
    function Bytes: TBytes;
  end;

function ScanLines(const AData: TBytes; const AAtEOF: Boolean;
  out AAdvance: SizeUInt; out AToken: TBytes): Boolean;

function CreateScanner(const AInner: IReader; const ASplit: TSplitFunc = nil): IScanner;

implementation

const
  SCANNER_BUF_SIZE = 4096;
  SCANNER_MAX_TOKEN_SIZE = 1048576;

type
  TScanner = class(TInterfacedObject, IScanner)
  private
    FInner: IReader;
    FSplit: TSplitFunc;
    FBuf: TBytes;
    FStart: SizeUInt;
    FEnd: SizeUInt;
    FToken: TBytes;
    FEOF: Boolean;
    FMaxTokenSize: SizeUInt;
  public
    constructor Create(const AInner: IReader; const ASplit: TSplitFunc);
    function Scan: Boolean;
    function Text: string;
    function Bytes: TBytes;
  end;

{ ScanLines }

function ScanLines(const AData: TBytes; const AAtEOF: Boolean;
  out AAdvance: SizeUInt; out AToken: TBytes): Boolean;
var
  LI: SizeUInt;
  LLen: SizeUInt;
begin
  LLen := Length(AData);
  if LLen = 0 then
  begin
    AAdvance := 0;
    AToken := nil;
    Result := False;
    Exit;
  end;

  for LI := 0 to LLen - 1 do
  begin
    if AData[LI] = 10 then
    begin
      if (LI > 0) and (AData[LI - 1] = 13) then
        AToken := System.Copy(AData, 0, LI - 1)
      else
        AToken := System.Copy(AData, 0, LI);
      AAdvance := LI + 1;
      Result := True;
      Exit;
    end;
  end;

  if AAtEOF then
  begin
    if (LLen > 0) and (AData[LLen - 1] = 13) then
      AToken := System.Copy(AData, 0, LLen - 1)
    else
      AToken := System.Copy(AData, 0, LLen);
    AAdvance := LLen;
    Result := True;
    Exit;
  end;

  AAdvance := 0;
  AToken := nil;
  Result := False;
end;

{ CreateScanner }

function CreateScanner(const AInner: IReader; const ASplit: TSplitFunc): IScanner;
var
  LSplit: TSplitFunc;
begin
  LSplit := ASplit;
  if LSplit = nil then
    LSplit := @ScanLines;
  Result := TScanner.Create(AInner, LSplit);
end;

{ TScanner }

constructor TScanner.Create(const AInner: IReader; const ASplit: TSplitFunc);
begin
  inherited Create;
  FInner := AInner;
  FSplit := ASplit;
  SetLength(FBuf, SCANNER_BUF_SIZE);
  FStart := 0;
  FEnd := 0;
  FToken := nil;
  FEOF := False;
  FMaxTokenSize := SCANNER_MAX_TOKEN_SIZE;
end;

function TScanner.Scan: Boolean;
var
  LData: TBytes;
  LAdvance: SizeUInt;
  LN: SizeUInt;
  LNewCap: SizeUInt;
begin
  FToken := nil;

  while True do
  begin
    if FEnd > FStart then
    begin
      LData := System.Copy(FBuf, FStart, FEnd - FStart);
      if FSplit(LData, FEOF, LAdvance, FToken) then
      begin
        if LAdvance = 0 then
          LAdvance := SizeUInt(Length(LData));
        Inc(FStart, LAdvance);
        Result := True;
        Exit;
      end;
    end
    else if FEOF then
    begin
      Result := False;
      Exit;
    end;

    if FStart > 0 then
    begin
      if FEnd > FStart then
        Move(FBuf[FStart], FBuf[0], FEnd - FStart);
      FEnd := FEnd - FStart;
      FStart := 0;
    end;

    if FEnd >= SizeUInt(Length(FBuf)) then
    begin
      LNewCap := SizeUInt(Length(FBuf)) * 2;
      if LNewCap > FMaxTokenSize then
      begin
        Result := False;
        Exit;
      end;
      SetLength(FBuf, LNewCap);
    end;

    LN := FInner.Read(FBuf[FEnd], SizeUInt(Length(FBuf)) - FEnd);
    if LN = 0 then
    begin
      FEOF := True;
      if FEnd > FStart then
      begin
        LData := System.Copy(FBuf, FStart, FEnd - FStart);
        if FSplit(LData, True, LAdvance, FToken) then
        begin
          if LAdvance = 0 then
            LAdvance := SizeUInt(Length(LData));
          Inc(FStart, LAdvance);
          Result := True;
          Exit;
        end;
      end;
      Result := False;
      Exit;
    end;
    Inc(FEnd, LN);
  end;
end;

function TScanner.Text: string;
begin
  if FToken = nil then
    Result := ''
  else
    SetString(Result, PAnsiChar(@FToken[0]), Length(FToken));
end;

function TScanner.Bytes: TBytes;
begin
  Result := FToken;
end;

end.
