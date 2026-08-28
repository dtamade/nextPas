unit nextpas.core.registry.factory;
{$I nextpas.core.settings.inc}
{$J-}
interface
uses nextpas.core.base, nextpas.core.exception, nextpas.core.text.conv;
type ERegistryError = class(Exception);
generic TFactoryRegistry<T> = record private type TEntry = record Id: string; Value: T; end; var FEntries: array of TEntry; function IndexOf(const AId: string): Integer; function Normalize(const AId: string): string; inline; public procedure Clear; procedure Register(const AId: string; const AValue: T); function IsRegistered(const AId: string): Boolean; function TryFind(const AId: string; out AValue: T): Boolean; function Find(const AId: string): T; function List: TStringArray; function Count: Integer; inline; end;
implementation
function LowerNorm(const AId: string): string; inline; begin Result := LowerCase(AId); end;
generic function TFactoryRegistry<T>.Normalize(const AId: string): string; begin Result := LowerNorm(AId); end;
generic function TFactoryRegistry<T>.IndexOf(const AId: string): Integer; var Norm: string; I: Integer; begin Norm := Normalize(AId); for I := 0 to High(FEntries) do if FEntries[I].Id = Norm then Exit(I); Result := -1; end;
generic procedure TFactoryRegistry<T>.Clear; begin SetLength(FEntries, 0); end;
generic procedure TFactoryRegistry<T>.Register(const AId: string; const AValue: T); var Norm: string; begin Norm := Normalize(AId); if Norm = '' then raise ERegistryError.Create('registry id must be non-empty'); if IndexOf(Norm) >= 0 then raise ERegistryError.Create('registry id already registered: ' + AId); SetLength(FEntries, Length(FEntries) + 1); FEntries[High(FEntries)].Id := Norm; FEntries[High(FEntries)].Value := AValue; end;
generic function TFactoryRegistry<T>.IsRegistered(const AId: string): Boolean; begin Result := IndexOf(AId) >= 0; end;
generic function TFactoryRegistry<T>.TryFind(const AId: string; out AValue: T): Boolean; var Idx: Integer; begin Idx := IndexOf(AId); if Idx >= 0 then begin AValue := FEntries[Idx].Value; Exit(True); end; Result := False; end;
generic function TFactoryRegistry<T>.Find(const AId: string): T; begin if not TryFind(AId, Result) then raise ERegistryError.Create('unknown registry id: ' + AId); end;
generic function TFactoryRegistry<T>.List: TStringArray; var I, J: Integer; Tmp: string; begin SetLength(Result, Length(FEntries)); for I := 0 to High(FEntries) do Result[I] := FEntries[I].Id; for I := 0 to High(Result) - 1 do for J := I + 1 to High(Result) do if Result[I] > Result[J] then begin Tmp := Result[I]; Result[I] := Result[J]; Result[J] := Tmp; end; end;
generic function TFactoryRegistry<T>.Count: Integer; begin Result := Length(FEntries); end;
end.
