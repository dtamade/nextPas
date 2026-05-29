unit nextpas.core.tls.openssl.x509.chain;

{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.stack;

{ Find issuer certificate for a leaf certificate from a chain.

  This avoids relying on fixed indices like chain[1], which is not robust across
  different OpenSSL chain shapes (e.g. server-side peer chains may omit the leaf).

  Returns a BORROWED PX509 pointer (do not free). If the returned certificate
  must outlive the chain/store context, the caller should X509_up_ref it.
}
function FindIssuerX509InChain(ALeaf: PX509; AChain: PSTACK_OF_X509): PX509;

implementation

function FindIssuerX509InChain(ALeaf: PX509; AChain: PSTACK_OF_X509): PX509;
var
  LeafIssuer: PX509_NAME;
  Cand: PX509;
  CandSubject: PX509_NAME;
  I, Count: Integer;

  function ChainCount(const AStack: PSTACK_OF_X509): Integer;
  begin
    Result := 0;

    if Assigned(sk_X509_num) then
      Result := sk_X509_num(AStack)
    else if Assigned(OPENSSL_sk_num) then
      Result := OPENSSL_sk_num(POPENSSL_STACK(AStack));
  end;

  function ChainValue(const AStack: PSTACK_OF_X509; AIndex: Integer): PX509;
  begin
    Result := nil;

    if Assigned(sk_X509_value) then
      Result := sk_X509_value(AStack, AIndex)
    else if Assigned(OPENSSL_sk_value) then
      Result := PX509(OPENSSL_sk_value(POPENSSL_STACK(AStack), AIndex));
  end;

begin
  Result := nil;

  if (ALeaf = nil) or (AChain = nil) then
    Exit;

  if (not Assigned(X509_get_issuer_name)) or
    (not Assigned(X509_get_subject_name)) or
    (not Assigned(X509_NAME_cmp)) then
    Exit;

  // Ensure we have at least generic stack helpers.
  if (not Assigned(sk_X509_num)) and (not Assigned(OPENSSL_sk_num)) then
    LoadStackFunctions;

  if (not Assigned(sk_X509_num)) and (not Assigned(OPENSSL_sk_num)) then
    Exit;

  if (not Assigned(sk_X509_value)) and (not Assigned(OPENSSL_sk_value)) then
    Exit;

  LeafIssuer := X509_get_issuer_name(ALeaf);
  if LeafIssuer = nil then
    Exit;

  Count := ChainCount(AChain);
  for I := 0 to Count - 1 do
  begin
    Cand := ChainValue(AChain, I);
    if (Cand = nil) or (Cand = ALeaf) then
      Continue;

    CandSubject := X509_get_subject_name(Cand);
    if CandSubject = nil then
      Continue;

    if X509_NAME_cmp(LeafIssuer, CandSubject) = 0 then
    begin
      Result := Cand;
      Exit;
    end;
  end;
end;

end.
