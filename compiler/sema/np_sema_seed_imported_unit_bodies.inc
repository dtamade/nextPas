procedure TSemanticAnalyzer.SeedImportedUnitBodies;

  procedure SeedImportedCallableSymbol(
    const ANode: TGreenNode;
    const AOwnerUnitId: string;
    const AUnitScopeId: LongInt
  );
  var
    Child: TGreenNode;
    ChildIndex: LongInt;
    KindName: string;
    ParamCount: LongInt;
    ParamSignature: string;
    ScopeId: LongInt;
    Symbol: TSemanticSymbol;
    SymbolId: LongInt;
    SymbolIndex: LongInt;
    TypeId: LongInt;
  begin
    if (ANode = nil) or (Trim(AOwnerUnitId) = '') or
      (Trim(ANode.Text) = '') or (Pos('.', ANode.Text) > 0) then
      Exit;

    if ANode.NodeKind = gnkFunctionDecl then
      KindName := 'function'
    else if ANode.NodeKind = gnkProcedureDecl then
      KindName := 'procedure'
    else
      Exit;

    ParamCount := CountDeclParams(ANode);
    ParamSignature := GetParamSignature(ANode);
    for SymbolIndex := 0 to FModel.SymbolCount - 1 do
    begin
      Symbol := FModel.SymbolAt(SymbolIndex);
      if SameText(Symbol.OwnerUnitId, AOwnerUnitId) and
        SameText(Symbol.Name, ANode.Text) and
        SameText(Symbol.Kind, KindName) and
        (Symbol.ByteOffset = ANode.ByteOffset) then
        Exit;
    end;

    TypeId := 0;
    if ANode.NodeKind = gnkFunctionDecl then
      for ChildIndex := 0 to ANode.ChildCount - 1 do
      begin
        Child := ANode.ChildAt(ChildIndex);
        if (Child <> nil) and (Child.NodeKind = gnkIdentifier) then
        begin
          TypeId := ResolveTypeIdForOwner(Child.Text, AOwnerUnitId);
          Break;
        end;
      end;

    SymbolId := FModel.AddSymbol(
      ANode.Text,
      KindName,
      AOwnerUnitId,
      TypeId,
      ANode.ByteOffset
    );
    FModel.SetSymbolParamCount(SymbolId, ParamCount);
    FModel.SetSymbolMinParamCount(SymbolId, CountRequiredDeclParams(ANode));
    FModel.SetSymbolParamSignature(SymbolId, ParamSignature);

    if AUnitScopeId > 0 then
      ScopeId := AUnitScopeId
    else
      ScopeId := EnsureUnitScope(AOwnerUnitId);
    if ScopeId > 0 then
      FModel.SetSymbolScope(SymbolId, ScopeId);
  end;

  procedure RegisterBodiesInNode(
    const ANode: TGreenNode;
    const AOwnerUnitId: string
  );
  var
    ChildIdx, BodyIdx: LongInt;
    Child, BodyChild: TGreenNode;
    SavedScopeId: LongInt;
    UnitScopeId: LongInt;
  begin
    if ANode = nil then
      Exit;
    for ChildIdx := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(ChildIdx);
      if Child = nil then
        Continue;
      if Child.NodeKind = gnkTypeSection then
      begin
        UnitScopeId := EnsureUnitScope(AOwnerUnitId);
        SavedScopeId := FCurrentScopeId;
        if UnitScopeId > 0 then
          FCurrentScopeId := UnitScopeId;
        try
          ProcessTypeSection(Child, AOwnerUnitId);
        finally
          FCurrentScopeId := SavedScopeId;
        end;
      end
      else if Child.NodeKind = gnkConstSection then
      begin
        UnitScopeId := EnsureUnitScope(AOwnerUnitId);
        SavedScopeId := FCurrentScopeId;
        if UnitScopeId > 0 then
          FCurrentScopeId := UnitScopeId;
        try
          ProcessConstSection(Child, AOwnerUnitId);
        finally
          FCurrentScopeId := SavedScopeId;
        end;
      end
      else if (Child.NodeKind = gnkProcedureDecl) or
        (Child.NodeKind = gnkFunctionDecl) then
      begin
        UnitScopeId := EnsureUnitScope(AOwnerUnitId);
        SavedScopeId := FCurrentScopeId;
        if UnitScopeId > 0 then
          FCurrentScopeId := UnitScopeId;
        try
          SeedImportedCallableSymbol(Child, AOwnerUnitId, UnitScopeId);
          BodyChild := nil;
          for BodyIdx := 0 to Child.ChildCount - 1 do
            if (Child.ChildAt(BodyIdx) <> nil) and
              ((Child.ChildAt(BodyIdx).NodeKind = gnkBeginBlock) or
               (Child.ChildAt(BodyIdx).NodeKind = gnkAsmBlock)) then
            begin
              BodyChild := Child.ChildAt(BodyIdx);
              Break;
            end;
          RegisterProcedureBody(Child.Text, BodyChild, Child, AOwnerUnitId);
        finally
          FCurrentScopeId := SavedScopeId;
        end;
      end
      else if Child.NodeKind = gnkInterfaceSection then
        RegisterBodiesInNode(Child, AOwnerUnitId);
      { gnkImplementationSection 跳过: 实现段声明对外部单元不可见 }
    end;
  end;

var
  OwnerUnitId: string;
  Index: LongInt;
  ResolvedUnit: TResolvedUnit;
  SourceText, Line: string;
  UnitLexer: TLexerResult;
  UnitTree: TGreenTree;
  F: Text;
  SourcePath: string;
  TmpDiag: TDiagnosticsSink;
  PP: TPreprocessor;
  PPDefines: TDefineTable;
  IncResolver: TFileIncludeResolver;
  CacheIdx: LongInt;
  DiskUnit: TDiskCachedUnit;
  Fingerprint: UInt32;
  DiskHit: Boolean;
  ResolvedTypeId: LongInt;
  Age: Int64;
  SymBefore, SymAfter, J, NextCache: LongInt;
  Sym: TSemanticSymbol;
begin
  if FUnitGraph = nil then
    Exit;
  if GDiskCache = nil then
    GDiskCache := TDiskSymbolCache.Create('.nextpas/cache');
  TmpDiag := TDiagnosticsSink.Create;
  try
    for Index := FUnitGraph.ResolvedUnitCount - 1 downto 0 do
    begin
      ResolvedUnit := FUnitGraph.ResolvedUnitAt(Index);
      if SameText(ResolvedUnit.CanonicalName, FUnitGraph.RootName) then
        Continue;
      SourcePath := ResolvedUnit.SourcePath;
      if Trim(SourcePath) = '' then
        Continue;
      if not FsExists(SourcePath) then
        Continue;

      OwnerUnitId := ResolvedUnit.UnitId;
      if OwnerUnitId = '' then
        OwnerUnitId := NormalizeUnitIdentity(ResolvedUnit.CanonicalName);

      Age := FsStat(SourcePath).ModTime;
      CacheIdx := -1;
      if SameText(ResolvedUnit.OriginClass, 'installed-source') then
        CacheIdx := FindCachedUnit(SourcePath, Age);
      if CacheIdx >= 0 then
      begin
        for J := 0 to GImportedUnitCache[CacheIdx].SymbolCount - 1 do
          with GImportedUnitCache[CacheIdx].Symbols[J] do
          begin
            { Skip cached type symbols if a type with this name already
              exists in the model (e.g. seeded in SeedBuiltinTypes). }
            if SameText(Kind, 'type') and
              (FModel.FindTypeByName(Name) > 0) then
              Continue;
            FModel.AddSymbol(Name, Kind, OwnerUnitId, TypeId, ByteOffset);
            FModel.SetSymbolParamCount(FModel.SymbolCount, ParamCount);
            FModel.SetSymbolMinParamCount(FModel.SymbolCount, MinParamCount);
            FModel.SetSymbolParamSignature(FModel.SymbolCount, ParamSignature);
            FModel.SetSymbolScope(FModel.SymbolCount, EnsureUnitScope(OwnerUnitId));
          end;
        Continue;
      end;

      { In-memory cache miss — try persistent disk cache }
      Fingerprint := ComputeSourceFingerprintFromFile(SourcePath);
      DiskHit := GDiskCache.TryLoad(OwnerUnitId, Fingerprint, DiskUnit);
      if DiskHit then
      begin
        SymBefore := FModel.SymbolCount;
        for J := 0 to DiskUnit.SymbolCount - 1 do
        begin
          if SameText(DiskUnit.Symbols[J].Kind, 'type') and
            (FModel.FindTypeByName(DiskUnit.Symbols[J].Name) > 0) then
            Continue;
          ResolvedTypeId := 0;
          if DiskUnit.Symbols[J].TypeRefName <> '' then
            ResolvedTypeId := ResolveTypeIdForOwner(
              DiskUnit.Symbols[J].TypeRefName, OwnerUnitId);
          FModel.AddSymbol(
            DiskUnit.Symbols[J].Name,
            DiskUnit.Symbols[J].Kind,
            OwnerUnitId,
            ResolvedTypeId,
            DiskUnit.Symbols[J].ByteOffset
          );
          FModel.SetSymbolParamCount(FModel.SymbolCount,
            DiskUnit.Symbols[J].ParamCount);
          FModel.SetSymbolMinParamCount(FModel.SymbolCount,
            DiskUnit.Symbols[J].MinParamCount);
          FModel.SetSymbolParamSignature(FModel.SymbolCount,
            DiskUnit.Symbols[J].ParamSignature);
          FModel.SetSymbolScope(FModel.SymbolCount, EnsureUnitScope(OwnerUnitId));
        end;
        SymAfter := FModel.SymbolCount;
        { Promote disk cache entry to in-memory cache }
        if SymAfter > SymBefore then
        begin
          if GImportedUnitCacheCount >= Length(GImportedUnitCache) then
            SetLength(GImportedUnitCache, GImportedUnitCacheCount + 16);
          NextCache := GImportedUnitCacheCount;
          Inc(GImportedUnitCacheCount);
          GImportedUnitCache[NextCache].SourcePath := SourcePath;
          GImportedUnitCache[NextCache].FileAge := Age;
          GImportedUnitCache[NextCache].SymbolCount := SymAfter - SymBefore;
          SetLength(GImportedUnitCache[NextCache].Symbols, SymAfter - SymBefore);
          for J := SymBefore to SymAfter - 1 do
          begin
            Sym := FModel.SymbolAt(J);
            with GImportedUnitCache[NextCache].Symbols[J - SymBefore] do
            begin
              Name := Sym.Name;
              Kind := Sym.Kind;
              OwnerUnitId := Sym.OwnerUnitId;
              ParamCount := Sym.ParamCount;
              MinParamCount := Sym.MinParamCount;
              ParamSignature := Sym.ParamSignature;
              TypeId := Sym.TypeId;
              TypeRefName := '';
              ByteOffset := Sym.ByteOffset;
            end;
          end;
        end;
        Continue;
      end;

      Assign(F, SourcePath);
      {$I-}
      Reset(F);
      {$I+}
      if IOResult <> 0 then
        Continue;
      SourceText := '';
      while not Eof(F) do
      begin
        ReadLn(F, Line);
        if SourceText <> '' then
          SourceText := SourceText + #10;
        SourceText := SourceText + Line;
      end;
      Close(F);
      UnitLexer := TLexerResult.Create(SourceText);
      PPDefines := TDefineTable.Create;
      PPDefines.SeedFPCDefines;
      IncResolver := TFileIncludeResolver.Create(ExtractFileDir(SourcePath));
      IncResolver.AddSearchPath(ExtractFileDir(SourcePath));
      IncResolver.AddSearchPath(
        ExtractFileDir(ExtractFileDir(SourcePath)) + DirectorySeparator + 'objpas');
      IncResolver.AddSearchPath(
        ExtractFileDir(ExtractFileDir(SourcePath)) + DirectorySeparator + 'objpas' +
        DirectorySeparator + 'sysutils');
      IncResolver.AddSearchPath(
        ExtractFileDir(ExtractFileDir(SourcePath)) + DirectorySeparator + 'inc');
      PP := TPreprocessor.Create(PPDefines, True, IncResolver);
      try
        PP.Process(UnitLexer);
        UnitLexer.Free;
        UnitLexer := PP.ToLexerResult;
      finally
        PP.Free;
      end;

      SymBefore := FModel.SymbolCount;
      UnitTree := ParseGreenTree(UnitLexer, TmpDiag, 0);
      if (UnitTree <> nil) and (UnitTree.RootNode <> nil) then
      begin
        RegisterImportedUnitTree(UnitTree, OwnerUnitId);
        RegisterBodiesInNode(UnitTree.RootNode, OwnerUnitId);
      end
      else if UnitTree <> nil then
        UnitTree.Free;
      UnitLexer.Free;
      SymAfter := FModel.SymbolCount;

      if (SymAfter > SymBefore) and
        SameText(ResolvedUnit.OriginClass, 'installed-source') then
      begin
        if GImportedUnitCacheCount >= Length(GImportedUnitCache) then
          SetLength(GImportedUnitCache, GImportedUnitCacheCount + 16);
        NextCache := GImportedUnitCacheCount;
        Inc(GImportedUnitCacheCount);
        GImportedUnitCache[NextCache].SourcePath := SourcePath;
        GImportedUnitCache[NextCache].FileAge := Age;
        GImportedUnitCache[NextCache].SymbolCount := SymAfter - SymBefore;
        SetLength(GImportedUnitCache[NextCache].Symbols, SymAfter - SymBefore);
        { Also build disk cache entry }
        DiskUnit.UnitId := OwnerUnitId;
        DiskUnit.SourcePath := SourcePath;
        DiskUnit.Fingerprint := ComputeSourceFingerprintFromFile(SourcePath);
        DiskUnit.SymbolCount := SymAfter - SymBefore;
        SetLength(DiskUnit.Symbols, SymAfter - SymBefore);
        for J := SymBefore to SymAfter - 1 do
        begin
          Sym := FModel.SymbolAt(J);
          with GImportedUnitCache[NextCache].Symbols[J - SymBefore] do
          begin
            Name := Sym.Name;
            Kind := Sym.Kind;
            OwnerUnitId := Sym.OwnerUnitId;
            ParamCount := Sym.ParamCount;
            MinParamCount := Sym.MinParamCount;
            ParamSignature := Sym.ParamSignature;
            TypeId := Sym.TypeId;
            if Sym.TypeId > 0 then
              TypeRefName := FModel.TypeAt(Sym.TypeId - 1).Name
            else
              TypeRefName := '';
            ByteOffset := Sym.ByteOffset;
          end;
          DiskUnit.Symbols[J - SymBefore].Name := Sym.Name;
          DiskUnit.Symbols[J - SymBefore].Kind := Sym.Kind;
          DiskUnit.Symbols[J - SymBefore].OwnerUnitId := OwnerUnitId;
          DiskUnit.Symbols[J - SymBefore].ParamCount := Sym.ParamCount;
          DiskUnit.Symbols[J - SymBefore].MinParamCount := Sym.MinParamCount;
          DiskUnit.Symbols[J - SymBefore].ParamSignature := Sym.ParamSignature;
          if Sym.TypeId > 0 then
            DiskUnit.Symbols[J - SymBefore].TypeRefName := FModel.TypeAt(Sym.TypeId - 1).Name
          else
            DiskUnit.Symbols[J - SymBefore].TypeRefName := '';
          DiskUnit.Symbols[J - SymBefore].ByteOffset := Sym.ByteOffset;
        end;
        GDiskCache.Save(DiskUnit);
      end;
    end;
  finally
    TmpDiag.Free;
  end;
end;

end.
