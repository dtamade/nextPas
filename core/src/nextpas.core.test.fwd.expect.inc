{ ── Forward to test.expect ────────────────────────────────────────────────── }

function Expect(const AValue: string): IExpectation;
begin Result := nextpas.core.test.expect.Expect(AValue); end;

function ExpectStr(const AValue: string): IExpectation;
begin Result := nextpas.core.test.expect.ExpectStr(AValue); end;

function ExpectInt(const AValue: Int64): IExpectation;
begin Result := nextpas.core.test.expect.ExpectInt(AValue); end;

function ExpectBool(AValue: Boolean): IExpectation;
begin Result := nextpas.core.test.expect.ExpectBool(AValue); end;

function ExpectDouble(const AValue: Double): IExpectation;
begin Result := nextpas.core.test.expect.ExpectDouble(AValue); end;

function ExpectPtr(const AValue: Pointer): IExpectation;
begin Result := nextpas.core.test.expect.ExpectPtr(AValue); end;

function ExpectProc(AProc: TTestProc): IExpectation;
begin Result := nextpas.core.test.expect.ExpectProc(AProc); end;

function ExpectBytes(const AValue: TBytes): IExpectation;
begin Result := nextpas.core.test.expect.ExpectBytes(AValue); end;
