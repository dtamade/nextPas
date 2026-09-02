{**
 * nextpas.core.graphics.effect.graph.serialize - 滤镜图序列化
 *}
unit nextpas.core.graphics.effect.graph.serialize;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.graphics.base,
  nextpas.core.graphics.effect.graph.base;

function EffectGraphSerialize(const ANodes: TEffectNodeArray): TBytes;
function EffectGraphDeserialize(const AData: TBytes): TEffectNodeArray;

implementation

uses
  nextpas.core.graphics.errors,
  nextpas.core.bytes.binary;

function EffectGraphSerialize(const ANodes: TEffectNodeArray): TBytes;
var
  I, Need: Integer;
  P: PByte;
  U: LongWord;
begin
  Result := nil;
  Need := 4;
  for I := 0 to High(ANodes) do
    case ANodes[I].Kind of
      ekBlur: Inc(Need, 1 + 4);
      ekDropShadow: Inc(Need, 1 + 4 + 4 + 4 + 4);
      ekHue: Inc(Need, 1 + 4);
      ekLUT: Inc(Need, 1 + 4 + Length(ANodes[I].LutData));
    end;
  SetLength(Result, Need);
  if Need = 0 then Exit;
  P := @Result[0];
  WriteUInt32LE(P, LongWord(Length(ANodes))); Inc(P, 4);
  for I := 0 to High(ANodes) do
  begin
    P^ := Byte(ANodes[I].Kind); Inc(P);
    case ANodes[I].Kind of
      ekBlur:
        begin
          Move(ANodes[I].Radius, U, 4);
          WriteUInt32LE(P, U); Inc(P, 4);
        end;
      ekDropShadow:
        begin
          Move(ANodes[I].Dx, U, 4); WriteUInt32LE(P, U); Inc(P, 4);
          Move(ANodes[I].Dy, U, 4); WriteUInt32LE(P, U); Inc(P, 4);
          Move(ANodes[I].Radius, U, 4); WriteUInt32LE(P, U); Inc(P, 4);
          WriteUInt32LE(P, LongWord(ANodes[I].ShadowColor)); Inc(P, 4);
        end;
      ekHue:
        begin
          Move(ANodes[I].HueShift, U, 4);
          WriteUInt32LE(P, U); Inc(P, 4);
        end;
      ekLUT:
        begin
          WriteUInt32LE(P, LongWord(Length(ANodes[I].LutData))); Inc(P, 4);
          if Length(ANodes[I].LutData) > 0 then
          begin
            Move(ANodes[I].LutData[0], P^, Length(ANodes[I].LutData));
            Inc(P, Length(ANodes[I].LutData));
          end;
        end;
    end;
  end;
end;

function EffectGraphDeserialize(const AData: TBytes): TEffectNodeArray;
var
  P: PByte;
  N, I, Off: Integer;
  Lc: LongWord;
  Kind: Byte;
  U: LongWord;
begin
  Result := nil;
  if Length(AData) < 4 then raise EEffectError.Create('nextpas.core.graphics.effect.graph.serialize.pas: EffectGraphDeserialize: truncated header (len=' + IntToStr(Length(AData)) + ' need 4 offset=0)');
  P := @AData[0];
  N := Integer(ReadUInt32LE(P));
  Off := 4;
  if (N < 0) or (N > 1024) then raise EEffectError.Create('nextpas.core.graphics.effect.graph.serialize.pas: EffectGraphDeserialize: bad node count (count=' + IntToStr(N) + ' limit=1024 offset=' + IntToStr(Off - 4) + ')');
  SetLength(Result, N);
  for I := 0 to N - 1 do
  begin
    if Off >= Length(AData) then raise EEffectError.Create('nextpas.core.graphics.effect.graph.serialize.pas: EffectGraphDeserialize: truncated node (offset=' + IntToStr(Off) + ' index=' + IntToStr(I) + ' len=' + IntToStr(Length(AData)) + ')');
    Kind := AData[Off]; Inc(Off);
    if Kind > Ord(High(TEffectKind)) then raise EEffectError.Create('nextpas.core.graphics.effect.graph.serialize.pas: EffectGraphDeserialize: bad kind (kind=' + IntToStr(Kind) + ' offset=' + IntToStr(Off - 1) + ' index=' + IntToStr(I) + ')');
    Result[I].Kind := TEffectKind(Kind);
    Result[I].Radius := 0; Result[I].Dx := 0; Result[I].Dy := 0; Result[I].ShadowColor := 0; Result[I].HueShift := 0; Result[I].LutData := nil;
    case Result[I].Kind of
      ekBlur:
        begin
          if Off + 4 > Length(AData) then raise EEffectError.Create('nextpas.core.graphics.effect.graph.serialize.pas: EffectGraphDeserialize: truncated blur (offset=' + IntToStr(Off) + ' need 4 have ' + IntToStr(Length(AData) - Off) + ' index=' + IntToStr(I) + ')');
          P := PByte(@AData[Off]); U := ReadUInt32LE(P); Inc(Off, 4);
          Move(U, Result[I].Radius, 4);
        end;
      ekDropShadow:
        begin
          if Off + 16 > Length(AData) then raise EEffectError.Create('nextpas.core.graphics.effect.graph.serialize.pas: EffectGraphDeserialize: truncated shadow (offset=' + IntToStr(Off) + ' need 16 have ' + IntToStr(Length(AData) - Off) + ' index=' + IntToStr(I) + ')');
          P := PByte(@AData[Off]); U := ReadUInt32LE(P); Inc(Off, 4); Move(U, Result[I].Dx, 4);
          P := PByte(@AData[Off]); U := ReadUInt32LE(P); Inc(Off, 4); Move(U, Result[I].Dy, 4);
          P := PByte(@AData[Off]); U := ReadUInt32LE(P); Inc(Off, 4); Move(U, Result[I].Radius, 4);
          P := PByte(@AData[Off]); U := ReadUInt32LE(P); Inc(Off, 4); Result[I].ShadowColor := TColor32(U);
        end;
      ekHue:
        begin
          if Off + 4 > Length(AData) then raise EEffectError.Create('nextpas.core.graphics.effect.graph.serialize.pas: EffectGraphDeserialize: truncated hue (offset=' + IntToStr(Off) + ' need 4 have ' + IntToStr(Length(AData) - Off) + ' index=' + IntToStr(I) + ')');
          P := PByte(@AData[Off]); U := ReadUInt32LE(P); Inc(Off, 4);
          Move(U, Result[I].HueShift, 4);
        end;
      ekLUT:
        begin
          if Off + 4 > Length(AData) then raise EEffectError.Create('nextpas.core.graphics.effect.graph.serialize.pas: EffectGraphDeserialize: truncated lut header (offset=' + IntToStr(Off) + ' need 4 have ' + IntToStr(Length(AData) - Off) + ' index=' + IntToStr(I) + ')');
          P := PByte(@AData[Off]); Lc := ReadUInt32LE(P); Inc(Off, 4);
          if Lc <> 256 * 3 then raise EEffectError.Create('nextpas.core.graphics.effect.graph.serialize.pas: EffectGraphDeserialize: LUT size mismatch (got ' + IntToStr(Int64(Lc)) + ' expected 768 offset=' + IntToStr(Off - 4) + ' index=' + IntToStr(I) + ')');
          if Off + Integer(Lc) > Length(AData) then raise EEffectError.Create('nextpas.core.graphics.effect.graph.serialize.pas: EffectGraphDeserialize: truncated lut data (offset=' + IntToStr(Off) + ' need ' + IntToStr(Int64(Lc)) + ' have ' + IntToStr(Length(AData) - Off) + ' index=' + IntToStr(I) + ')');
          SetLength(Result[I].LutData, Lc);
          if Lc > 0 then Move(AData[Off], Result[I].LutData[0], Lc);
          Inc(Off, Integer(Lc));
        end;
    end;
  end;
end;

end.
