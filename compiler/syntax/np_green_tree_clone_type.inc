  function CloneTypeNode(const ANode: TGreenNode): TGreenNode;
  var
    ChildClone: TGreenNode;
    ChildIndex: LongInt;
  begin
    Result := nil;
    if ANode = nil then
      Exit;
    Result := TGreenNode.Create(ANode.NodeKind, ANode.ByteOffset,
      ANode.ByteLength, ANode.Text);
    Inc(ATree.FNodeCount);
    for ChildIndex := 0 to ANode.ChildCount - 1 do
    begin
      ChildClone := CloneTypeNode(ANode.ChildAt(ChildIndex));
      if ChildClone <> nil then
        Result.AppendChild(ChildClone);
    end;
  end;
begin
  Section := TGreenNode.Create(gnkTypeSection,
    CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  AParent.AppendChild(Section);
  Inc(ATree.FNodeCount);
  Inc(ACursor);

  while True do
  begin
    { Check for {$compiler_root} or {$compiler_type_kind} directive }
    IsCompilerRoot := CheckCompilerRootDirective(ALexer, ACursor);
    IsCompilerTypeKind := CheckCompilerTypeKindDirective(ALexer, ACursor);
    SkipDirectives(ALexer, ACursor);
    if (ACursor >= ALexer.TokenCount) or
      ((CurrentToken(ALexer, ACursor).Kind <> tkIdentifier) and
       (CurrentToken(ALexer, ACursor).Kind <> tkGenericKeyword)) then
      Break;
    if (CurrentToken(ALexer, ACursor).Kind = tkGenericKeyword) and
      (ACursor + 1 < ALexer.TokenCount) and
      (ALexer.TokenAt(ACursor + 1).Kind = tkIdentifier) then
      Inc(ACursor)
    else if CurrentToken(ALexer, ACursor).Kind = tkGenericKeyword then
      Break;
    if (ACursor >= ALexer.TokenCount) or
      (CurrentToken(ALexer, ACursor).Kind <> tkIdentifier) then
      Break;
    NameToken := CurrentToken(ALexer, ACursor);
    { Store directive info in node text }
    if IsCompilerRoot then
      Decl := TGreenNode.Create(gnkTypeDecl, NameToken.ByteOffset, 0,
        'compiler_root:' + NameToken.Lexeme)
    else if IsCompilerTypeKind then
      Decl := TGreenNode.Create(gnkTypeDecl, NameToken.ByteOffset, 0,
        'compiler_type_kind:' + NameToken.Lexeme)
    else
      Decl := TGreenNode.Create(gnkTypeDecl, NameToken.ByteOffset, 0,
        NameToken.Lexeme);
    Section.AppendChild(Decl);
    Inc(ATree.FNodeCount);
    Inc(ACursor);

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkLessThan) then
    begin
      TypeParamNode := TGreenNode.Create(gnkTypeParamList,
        CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
      Inc(ACursor);
      while (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind <> tkGreaterThan) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
      begin
        if CurrentToken(ALexer, ACursor).Kind = tkIdentifier then
        begin
          SpecArgs := CurrentToken(ALexer, ACursor).Lexeme;
          Inc(ACursor);
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkColon) then
          begin
            Inc(ACursor);
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind in
                [tkIdentifier, tkClassKeyword, tkRecordKeyword]) then
            begin
              SpecArgs := SpecArgs + ':' + CurrentToken(ALexer, ACursor).Lexeme;
              Inc(ACursor);
            end;
          end;
          ElementNode := TGreenNode.Create(gnkIdentifier,
            CurrentToken(ALexer, ACursor - 1).ByteOffset, 0, SpecArgs);
          TypeParamNode.AppendChild(ElementNode);
          Inc(ATree.FNodeCount);
        end
        else
          Inc(ACursor);
      end;
      MatchTokenSilent(ALexer, ACursor, tkGreaterThan);
      Decl.AppendChild(TypeParamNode);
      Inc(ATree.FNodeCount);
    end;

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkEquals) then
      Inc(ACursor);

    { type X = type Y: 跳过 distinct type 标记
      但不跳过 type helper (type + identifier + for) }
    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkTypeKeyword) and
      not ((ACursor + 2 < ALexer.TokenCount) and
        (ALexer.TokenAt(ACursor + 1).Kind = tkIdentifier) and
        (ALexer.TokenAt(ACursor + 2).Kind = tkForKeyword)) then
      Inc(ACursor);

    if (ACursor < ALexer.TokenCount) then
    begin
      case CurrentToken(ALexer, ACursor).Kind of
        tkRecordKeyword:
          begin
            TypeNode := TGreenNode.Create(gnkRecordType,
              CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
            Decl.AppendChild(TypeNode);
            Inc(ATree.FNodeCount);
            Inc(ACursor);
            SkipDirectives(ALexer, ACursor);
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
              (CurrentToken(ALexer, ACursor).Kind <> tkImplementationKeyword) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
            begin
              if CurrentToken(ALexer, ACursor).Kind = tkIdentifier then
              begin
                IndexNode := TGreenNode.Create(gnkVarDecl,
                  CurrentToken(ALexer, ACursor).ByteOffset, 0,
                  CurrentToken(ALexer, ACursor).Lexeme);
                TypeNode.AppendChild(IndexNode);
                Inc(ATree.FNodeCount);
                Inc(ACursor);
                while (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkComma) do
                begin
                  Inc(ACursor);
                  if (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                  begin
                    IndexNode := TGreenNode.Create(gnkVarDecl,
                      CurrentToken(ALexer, ACursor).ByteOffset, 0,
                      CurrentToken(ALexer, ACursor).Lexeme);
                    TypeNode.AppendChild(IndexNode);
                    Inc(ATree.FNodeCount);
                    Inc(ACursor);
                  end;
                end;
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkColon) then
                begin
                  Inc(ACursor);
                  ElementNode := ParseTypeReference(ALexer, ACursor,
                    ADiagnostics, ARootFileId, ATree);
                  if ElementNode <> nil then
                  begin
                    IndexNode.AppendChild(ElementNode);
                    Inc(ATree.FNodeCount);
                  end;
                end;
                MatchTokenSilent(ALexer, ACursor, tkSemicolon);
              end
              else if CurrentToken(ALexer, ACursor).Kind in
                [tkPublicKeyword, tkPrivateKeyword, tkProtectedKeyword,
                 tkPublishedKeyword] then
              begin
                ElementNode := TGreenNode.Create(gnkVisibilityLabel,
                  CurrentToken(ALexer, ACursor).ByteOffset, 0,
                  CurrentToken(ALexer, ACursor).Lexeme);
                TypeNode.AppendChild(ElementNode);
                Inc(ATree.FNodeCount);
                Inc(ACursor);
              end
              else if CurrentToken(ALexer, ACursor).Kind = tkCaseKeyword then
              begin
                I := 1;
                Inc(ACursor);
                while (ACursor < ALexer.TokenCount) and (I > 0) and
                  (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                begin
                  if CurrentToken(ALexer, ACursor).Kind in
                    [tkRecordKeyword, tkCaseKeyword] then
                    Inc(I)
                  else if CurrentToken(ALexer, ACursor).Kind = tkEndKeyword then
                    Dec(I);
                  if I > 0 then
                    Inc(ACursor);
                end;
              end
              else if CurrentToken(ALexer, ACursor).Kind = tkPropertyKeyword then
              begin
                { Record properties were token-skipped here, so sema never saw
                  the declared read/write targets — `S := Rec.Prop` residual-
                  called @Type.Prop (M2 B3b). Emit the same gnkClassProperty
                  shape the class branch below produces. }
                Inc(ACursor);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                begin
                  ElementNode := TGreenNode.Create(gnkClassProperty,
                    CurrentToken(ALexer, ACursor).ByteOffset, 0,
                    CurrentToken(ALexer, ACursor).Lexeme);
                  TypeNode.AppendChild(ElementNode);
                  Inc(ATree.FNodeCount);
                  Inc(ACursor);
                  if (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind = tkColon) then
                  begin
                    Inc(ACursor);
                    if (ACursor < ALexer.TokenCount) and
                      ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) or
                       (CurrentToken(ALexer, ACursor).Kind = tkStringKeyword)) then
                    begin
                      IndexNode := TGreenNode.Create(gnkIdentifier,
                        CurrentToken(ALexer, ACursor).ByteOffset, 0,
                        CurrentToken(ALexer, ACursor).Lexeme);
                      ElementNode.AppendChild(IndexNode);
                      Inc(ATree.FNodeCount);
                      Inc(ACursor);
                    end;
                  end;
                  while (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                  begin
                    if (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
                      (LowerCase(CurrentToken(ALexer, ACursor).Lexeme) = 'read') then
                    begin
                      Inc(ACursor);
                      if (ACursor < ALexer.TokenCount) and
                        (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                      begin
                        IndexNode := TGreenNode.Create(gnkIdentifier,
                          CurrentToken(ALexer, ACursor).ByteOffset, 0,
                          'read:' + CurrentToken(ALexer, ACursor).Lexeme);
                        ElementNode.AppendChild(IndexNode);
                        Inc(ATree.FNodeCount);
                        Inc(ACursor);
                      end;
                    end
                    else if (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
                      (LowerCase(CurrentToken(ALexer, ACursor).Lexeme) = 'write') then
                    begin
                      Inc(ACursor);
                      if (ACursor < ALexer.TokenCount) and
                        (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                      begin
                        IndexNode := TGreenNode.Create(gnkIdentifier,
                          CurrentToken(ALexer, ACursor).ByteOffset, 0,
                          'write:' + CurrentToken(ALexer, ACursor).Lexeme);
                        ElementNode.AppendChild(IndexNode);
                        Inc(ATree.FNodeCount);
                        Inc(ACursor);
                      end;
                    end
                    else
                      Inc(ACursor);
                  end;
                end
                else
                begin
                  while (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                    Inc(ACursor);
                end;
                MatchTokenSilent(ALexer, ACursor, tkSemicolon);
              end
              else if CurrentToken(ALexer, ACursor).Kind in
                [tkClassKeyword, tkProcedureKeyword, tkFunctionKeyword,
                 tkConstructorKeyword, tkDestructorKeyword, tkOperatorKeyword,
                 tkStaticKeyword, tkGenericKeyword] then
              begin
                I := 0;
                while (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
                  (CurrentToken(ALexer, ACursor).Kind <> tkImplementationKeyword) and
                  (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                begin
                  if CurrentToken(ALexer, ACursor).Kind = tkLParen then Inc(I)
                  else if CurrentToken(ALexer, ACursor).Kind = tkRParen then Dec(I)
                  else if (CurrentToken(ALexer, ACursor).Kind = tkSemicolon) and (I <= 0) then
                    Break;
                  Inc(ACursor);
                end;
                MatchTokenSilent(ALexer, ACursor, tkSemicolon);
                MethodModifiers := '';
                while (ACursor < ALexer.TokenCount) and
                  (IsDirectiveToken(CurrentToken(ALexer, ACursor).Kind) or
                   ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
                    IsCallingDirective(CurrentToken(ALexer, ACursor).Lexeme))) do
                begin
                  Inc(ACursor);
                  if (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind = tkStringLiteral) then
                    Inc(ACursor);
                  MatchTokenSilent(ALexer, ACursor, tkSemicolon);
                end;
              end
              else if CurrentToken(ALexer, ACursor).Kind = tkTypeKeyword then
              begin
                { skip nested type section in record: may contain multiple decls }
                Inc(ACursor);
                Nesting := 0;
                while (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                begin
                  if (Nesting = 0) and
                    (CurrentToken(ALexer, ACursor).Kind in
                      [tkPublicKeyword, tkPrivateKeyword, tkProtectedKeyword,
                       tkPublishedKeyword, tkEndKeyword]) then
                    Break;
                  if (CurrentToken(ALexer, ACursor).Kind in
                    [tkRecordKeyword, tkObjectKeyword,
                     tkClassKeyword, tkInterfaceKeyword]) and
                    ((ACursor <= 0) or
                     (ALexer.TokenAt(ACursor - 1).Kind <> tkOfKeyword)) then
                  begin
                    if (CurrentToken(ALexer, ACursor).Kind = tkClassKeyword) and
                      (ACursor + 1 < ALexer.TokenCount) and
                      (ALexer.TokenAt(ACursor + 1).Kind in
                        [tkFunctionKeyword, tkProcedureKeyword,
                         tkConstructorKeyword, tkDestructorKeyword,
                         tkOperatorKeyword]) then
                      { class as method modifier, not type declaration }
                    else
                      Inc(Nesting);
                  end
                  else if (CurrentToken(ALexer, ACursor).Kind = tkEndKeyword) and
                    (Nesting > 0) then
                    Dec(Nesting);
                  Inc(ACursor);
                end;
              end
              else
                Inc(ACursor);
            end;
            MatchTokenSilent(ALexer, ACursor, tkEndKeyword);
          end;
        tkArrayKeyword:
          begin
            TypeNode := TGreenNode.Create(gnkArrayType,
              CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
            RangeNode := nil;
            Decl.AppendChild(TypeNode);
            Inc(ATree.FNodeCount);
            Inc(ACursor);
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkLBracket) then
            begin
              Inc(ACursor);
              RangeNode := ParseArrayBoundsRange(ALexer, ACursor,
                ADiagnostics, ARootFileId);
              while (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind <> tkRBracket) and
                (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                Inc(ACursor);
              MatchTokenSilent(ALexer, ACursor, tkRBracket);
            end;
            if MatchTokenSilent(ALexer, ACursor, tkOfKeyword) then
            begin
              if (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind = tkConstKeyword) then
              begin
                ElementNode := TGreenNode.Create(gnkIdentifier,
                  CurrentToken(ALexer, ACursor).ByteOffset,
                  Length(CurrentToken(ALexer, ACursor).Lexeme),
                  CurrentToken(ALexer, ACursor).Lexeme);
                Inc(ACursor);
              end
              else
                ElementNode := ParseTypeReference(ALexer, ACursor, ADiagnostics,
                  ARootFileId, ATree);
              if ElementNode <> nil then
              begin
                TypeNode.AppendChild(ElementNode);
                Inc(ATree.FNodeCount);
              end;
              if RangeNode <> nil then
              begin
                TypeNode.AppendChild(RangeNode);
                Inc(ATree.FNodeCount);
              end;
            end
            else
              { { RangeNode.Free; } // record, no Free needed } // owned by tree FFacades
          end;
        tkClassKeyword:
          begin
            TypeNode := TGreenNode.Create(gnkClassType,
              CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
            Decl.AppendChild(TypeNode);
            Inc(ATree.FNodeCount);
            Inc(ACursor);
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkLParen) then
            begin
              Inc(ACursor);
              ElementNode := ParseTypeReference(ALexer, ACursor, ADiagnostics,
                ARootFileId, ATree);
              if ElementNode <> nil then
              begin
                TypeNode.AppendChild(ElementNode);
                Inc(ATree.FNodeCount);
              end;
              while (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind = tkComma) do
              begin
                Inc(ACursor);
                ElementNode := ParseTypeReference(ALexer, ACursor, ADiagnostics,
                  ARootFileId, ATree);
                if ElementNode <> nil then
                begin
                  TypeNode.AppendChild(ElementNode);
                  Inc(ATree.FNodeCount);
                end;
              end;
              MatchTokenSilent(ALexer, ACursor, tkRParen);
            end;
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkSemicolon) then
            begin
              // Forward class declaration: class; or class(parent);
            end
            else if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkOfKeyword) then
            begin
              { Mark class-of so sema can distinguish from empty
                `ClassName = class(Parent);` (also ChildCount=1). }
              TypeNode.Text := 'of';
              Inc(ACursor);
              ElementNode := ParseTypeReference(ALexer, ACursor, ADiagnostics,
                ARootFileId, ATree);
              if ElementNode <> nil then
              begin
                TypeNode.AppendChild(ElementNode);
                Inc(ATree.FNodeCount);
              end;
            end
            else
            begin
            I := 0;
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEOF) and
              not ((I = 0) and (CurrentToken(ALexer, ACursor).Kind = tkEndKeyword)) do
            begin
              if (CurrentToken(ALexer, ACursor).Kind in
                [tkRecordKeyword, tkObjectKeyword]) and
                ((ACursor <= 0) or
                 (ALexer.TokenAt(ACursor - 1).Kind <> tkOfKeyword)) then
                Inc(I)
              else if (CurrentToken(ALexer, ACursor).Kind = tkEndKeyword) and (I > 0) then
              begin
                Dec(I);
                Inc(ACursor);
                MatchTokenSilent(ALexer, ACursor, tkSemicolon);
                Continue;
              end;
              if CurrentToken(ALexer, ACursor).Kind in
                [tkPublicKeyword, tkPrivateKeyword, tkProtectedKeyword,
                 tkPublishedKeyword] then
              begin
                ElementNode := TGreenNode.Create(gnkVisibilityLabel,
                  CurrentToken(ALexer, ACursor).ByteOffset, 0,
                  CurrentToken(ALexer, ACursor).Lexeme);
                TypeNode.AppendChild(ElementNode);
                Inc(ATree.FNodeCount);
                Inc(ACursor);
              end
              else if CurrentToken(ALexer, ACursor).Kind = tkTypeKeyword then
              begin
                { skip nested type section: may contain multiple decls }
                Inc(ACursor);
                Nesting := 0;
                while (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                begin
                  if (Nesting = 0) and
                    (CurrentToken(ALexer, ACursor).Kind in
                      [tkPublicKeyword, tkPrivateKeyword, tkProtectedKeyword,
                       tkPublishedKeyword, tkEndKeyword]) then
                    Break;
                  if (CurrentToken(ALexer, ACursor).Kind in
                    [tkRecordKeyword, tkObjectKeyword,
                     tkClassKeyword, tkInterfaceKeyword]) and
                    ((ACursor <= 0) or
                     (ALexer.TokenAt(ACursor - 1).Kind <> tkOfKeyword)) then
                  begin
                    if (CurrentToken(ALexer, ACursor).Kind = tkClassKeyword) and
                      (ACursor + 1 < ALexer.TokenCount) and
                      (ALexer.TokenAt(ACursor + 1).Kind in
                        [tkFunctionKeyword, tkProcedureKeyword,
                         tkConstructorKeyword, tkDestructorKeyword,
                         tkOperatorKeyword]) then
                      { class as method modifier, not type declaration }
                    else
                      Inc(Nesting);
                  end
                  else if (CurrentToken(ALexer, ACursor).Kind = tkEndKeyword) and
                    (Nesting > 0) then
                    Dec(Nesting);
                  Inc(ACursor);
                end;
              end
              else if CurrentToken(ALexer, ACursor).Kind in
                [tkProcedureKeyword, tkFunctionKeyword,
                 tkConstructorKeyword, tkDestructorKeyword,
                 tkGenericKeyword, tkClassKeyword] then
              begin
                MethodModifiers := TokenKindName(CurrentToken(ALexer, ACursor).Kind);
                ElementNode := TGreenNode.Create(gnkClassMethod,
                  CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
                Inc(ACursor);
                while (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind in
                    [tkClassKeyword, tkProcedureKeyword, tkFunctionKeyword,
                     tkConstructorKeyword, tkDestructorKeyword,
                     tkGenericKeyword, tkOperatorKeyword]) do
                  Inc(ACursor);
                if (ACursor < ALexer.TokenCount) and
                  IsDeclNameToken(CurrentToken(ALexer, ACursor).Kind) then
                begin
                  ElementNode.AppendChild(TGreenNode.Create(gnkIdentifier,
                    CurrentToken(ALexer, ACursor).ByteOffset, 0,
                    CurrentToken(ALexer, ACursor).Lexeme));
                  Inc(ATree.FNodeCount);
                  Inc(ACursor);
                end;
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkLessThan) then
                begin
                  while (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkGreaterThan) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                    Inc(ACursor);
                  if ACursor < ALexer.TokenCount then Inc(ACursor);
                end;
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkLParen) then
                  ParseParameterList(ALexer, ACursor, ElementNode, ATree,
                    ADiagnostics, ARootFileId);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkColon) then
                begin
                  Inc(ACursor);
                  if (ACursor < ALexer.TokenCount) and
                    ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) or
                     (CurrentToken(ALexer, ACursor).Kind = tkStringKeyword)) then
                  begin
                    ElementNode.AppendChild(TGreenNode.Create(gnkIdentifier,
                      CurrentToken(ALexer, ACursor).ByteOffset, 0,
                      CurrentToken(ALexer, ACursor).Lexeme));
                    Inc(ATree.FNodeCount);
                    Inc(ACursor);
                  end;
                end;
                MatchTokenSilent(ALexer, ACursor, tkSemicolon);
                while (ACursor < ALexer.TokenCount) and
                  (IsDirectiveToken(CurrentToken(ALexer, ACursor).Kind) or
                   (CurrentToken(ALexer, ACursor).Kind in
                    [tkVirtualKeyword, tkOverrideKeyword, tkAbstractKeyword,
                     tkOverloadKeyword]) or
                   ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
                    IsCallingDirective(CurrentToken(ALexer, ACursor).Lexeme))) do
                begin
                  if CurrentToken(ALexer, ACursor).Kind = tkVirtualKeyword then
                    MethodModifiers := MethodModifiers + ';virtual'
                  else if CurrentToken(ALexer, ACursor).Kind = tkOverrideKeyword then
                    MethodModifiers := MethodModifiers + ';override'
                  else if CurrentToken(ALexer, ACursor).Kind = tkAbstractKeyword then
                    MethodModifiers := MethodModifiers + ';virtual;abstract';
                  Inc(ACursor);
                  MatchTokenSilent(ALexer, ACursor, tkSemicolon);
                end;
                ElementNode.Text := MethodModifiers;
                TypeNode.AppendChild(ElementNode);
                Inc(ATree.FNodeCount);
              end
              else if CurrentToken(ALexer, ACursor).Kind = tkPropertyKeyword then
              begin
                Inc(ACursor);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                begin
                  ElementNode := TGreenNode.Create(gnkClassProperty,
                    CurrentToken(ALexer, ACursor).ByteOffset, 0,
                    CurrentToken(ALexer, ACursor).Lexeme);
                  TypeNode.AppendChild(ElementNode);
                  Inc(ATree.FNodeCount);
                  Inc(ACursor);
                  if (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind = tkColon) then
                  begin
                    Inc(ACursor);
                    if (ACursor < ALexer.TokenCount) and
                      (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                    begin
                      IndexNode := TGreenNode.Create(gnkIdentifier,
                        CurrentToken(ALexer, ACursor).ByteOffset, 0,
                        CurrentToken(ALexer, ACursor).Lexeme);
                      ElementNode.AppendChild(IndexNode);
                      Inc(ATree.FNodeCount);
                      Inc(ACursor);
                    end;
                  end;
                  while (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                  begin
                    if (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
                      (LowerCase(CurrentToken(ALexer, ACursor).Lexeme) = 'read') then
                    begin
                      Inc(ACursor);
                      if (ACursor < ALexer.TokenCount) and
                        (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                      begin
                        IndexNode := TGreenNode.Create(gnkIdentifier,
                          CurrentToken(ALexer, ACursor).ByteOffset, 0,
                          'read:' + CurrentToken(ALexer, ACursor).Lexeme);
                        ElementNode.AppendChild(IndexNode);
                        Inc(ATree.FNodeCount);
                        Inc(ACursor);
                      end;
                    end
                    else if (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
                      (LowerCase(CurrentToken(ALexer, ACursor).Lexeme) = 'write') then
                    begin
                      Inc(ACursor);
                      if (ACursor < ALexer.TokenCount) and
                        (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                      begin
                        IndexNode := TGreenNode.Create(gnkIdentifier,
                          CurrentToken(ALexer, ACursor).ByteOffset, 0,
                          'write:' + CurrentToken(ALexer, ACursor).Lexeme);
                        ElementNode.AppendChild(IndexNode);
                        Inc(ATree.FNodeCount);
                        Inc(ACursor);
                      end;
                    end
                    else
                      Inc(ACursor);
                  end;
                end
                else
                begin
                  while (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                    Inc(ACursor);
                end;
                MatchTokenSilent(ALexer, ACursor, tkSemicolon);
              end
              else if (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
                (LowerCase(CurrentToken(ALexer, ACursor).Lexeme) = 'where') then
              begin
                Inc(ACursor);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                begin
                  SpecArgs := CurrentToken(ALexer, ACursor).Lexeme;
                  Inc(ACursor);
                  if (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind = tkColon) then
                  begin
                    Inc(ACursor);
                    SpecArgs := SpecArgs + ':';
                    if (ACursor < ALexer.TokenCount) and
                      (CurrentToken(ALexer, ACursor).Kind in
                        [tkIdentifier, tkClassKeyword, tkRecordKeyword]) then
                    begin
                      SpecArgs := SpecArgs + CurrentToken(ALexer, ACursor).Lexeme;
                      Inc(ACursor);
                      while (ACursor < ALexer.TokenCount) and
                        (CurrentToken(ALexer, ACursor).Kind = tkComma) do
                      begin
                        Inc(ACursor);
                        if (ACursor < ALexer.TokenCount) and
                          (CurrentToken(ALexer, ACursor).Kind in
                            [tkIdentifier, tkClassKeyword, tkRecordKeyword]) then
                        begin
                          SpecArgs := SpecArgs + '|' +
                            CurrentToken(ALexer, ACursor).Lexeme;
                          Inc(ACursor);
                        end;
                      end;
                    end;
                  end;
                  ElementNode := TGreenNode.Create(gnkIdentifier,
                    CurrentToken(ALexer, ACursor - 1).ByteOffset, 0,
                    'where:' + SpecArgs);
                  TypeNode.AppendChild(ElementNode);
                  Inc(ATree.FNodeCount);
                end;
                MatchTokenSilent(ALexer, ACursor, tkSemicolon);
              end
              else if CurrentToken(ALexer, ACursor).Kind = tkIdentifier then
              begin
                ElementNode := TGreenNode.Create(gnkClassField,
                  CurrentToken(ALexer, ACursor).ByteOffset, 0,
                  CurrentToken(ALexer, ACursor).Lexeme);
                Inc(ACursor);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkComma) then
                begin
                  FieldGroupStart := TypeNode.ChildCount;
                  TypeNode.AppendChild(ElementNode);
                  Inc(ATree.FNodeCount);
                  while (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind = tkComma) do
                  begin
                    Inc(ACursor);
                    if (ACursor < ALexer.TokenCount) and
                      (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                    begin
                      ElementNode := TGreenNode.Create(gnkClassField,
                        CurrentToken(ALexer, ACursor).ByteOffset, 0,
                        CurrentToken(ALexer, ACursor).Lexeme);
                      TypeNode.AppendChild(ElementNode);
                      Inc(ATree.FNodeCount);
                      Inc(ACursor);
                    end;
                  end;
                  if (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind = tkColon) then
                  begin
                    Inc(ACursor);
                    FieldTypeNode := ParseTypeReference(ALexer, ACursor,
                      ADiagnostics, ARootFileId, ATree);
                    UsedOriginalTypeNode := False;
                    if FieldTypeNode <> nil then
                      for K := FieldGroupStart to TypeNode.ChildCount - 1 do
                      begin
                        FieldNode := TypeNode.ChildAt(K);
                        if (FieldNode = nil) or
                          (FieldNode.NodeKind <> gnkClassField) or
                          (FieldNode.ChildCount <> 0) then
                          Continue;
                        if not UsedOriginalTypeNode then
                        begin
                          FieldNode.AppendChild(FieldTypeNode);
                          Inc(ATree.FNodeCount);
                          UsedOriginalTypeNode := True;
                        end
                        else
                          FieldNode.AppendChild(CloneTypeNode(FieldTypeNode));
                      end;
                  end;
                  MatchTokenSilent(ALexer, ACursor, tkSemicolon);
                end
                else if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkColon) then
                begin
                  Inc(ACursor);
                  FieldTypeNode := ParseTypeReference(ALexer, ACursor,
                    ADiagnostics, ARootFileId, ATree);
                  if FieldTypeNode <> nil then
                  begin
                    ElementNode.AppendChild(FieldTypeNode);
                    Inc(ATree.FNodeCount);
                  end;
                  MatchTokenSilent(ALexer, ACursor, tkSemicolon);
                  TypeNode.AppendChild(ElementNode);
                  Inc(ATree.FNodeCount);
                end
                else
                begin
                  I := 0;
                  while (ACursor < ALexer.TokenCount) and
                    not ((I = 0) and (CurrentToken(ALexer, ACursor).Kind in
                      [tkSemicolon, tkEndKeyword, tkEOF])) do
                  begin
                    if (CurrentToken(ALexer, ACursor).Kind in
                      [tkRecordKeyword, tkObjectKeyword]) and
                      ((ACursor <= 0) or
                       (ALexer.TokenAt(ACursor - 1).Kind <> tkOfKeyword)) then
                      Inc(I)
                    else if (CurrentToken(ALexer, ACursor).Kind = tkEndKeyword) and
                      (I > 0) then
                      Dec(I);
                    Inc(ACursor);
                  end;
                  MatchTokenSilent(ALexer, ACursor, tkSemicolon);
                  TypeNode.AppendChild(ElementNode);
                  Inc(ATree.FNodeCount);
                end;
              end
              else
                Inc(ACursor);
            end;
            MatchTokenSilent(ALexer, ACursor, tkEndKeyword);
            end;
          end;
        tkInterfaceKeyword:
          begin
            TypeNode := TGreenNode.Create(gnkClassType,
              CurrentToken(ALexer, ACursor).ByteOffset, 0, 'interface');
            Decl.AppendChild(TypeNode);
            Inc(ATree.FNodeCount);
            Inc(ACursor);
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkLParen) then
            begin
              Inc(ACursor);
              ElementNode := ParseTypeReference(ALexer, ACursor, ADiagnostics,
                ARootFileId, ATree);
              if ElementNode <> nil then
              begin
                TypeNode.AppendChild(ElementNode);
                Inc(ATree.FNodeCount);
              end;
              MatchTokenSilent(ALexer, ACursor, tkRParen);
            end;
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkLBracket) then
            begin
              Inc(ACursor);
              while (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind <> tkRBracket) and
                (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                Inc(ACursor);
              MatchTokenSilent(ALexer, ACursor, tkRBracket);
            end;
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkSemicolon) then
            begin
              { Forward interface declaration: interface; — semicolon consumed by ParseTypeSection }
            end
            else
            begin
              while (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
                (CurrentToken(ALexer, ACursor).Kind <> tkImplementationKeyword) and
                (CurrentToken(ALexer, ACursor).Kind <> tkBeginKeyword) and
                (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
              begin
                if CurrentToken(ALexer, ACursor).Kind in
                  [tkProcedureKeyword, tkFunctionKeyword] then
                begin
                  ElementNode := TGreenNode.Create(gnkClassMethod,
                    CurrentToken(ALexer, ACursor).ByteOffset, 0,
                    TokenKindName(CurrentToken(ALexer, ACursor).Kind));
                  Inc(ACursor);
                  if (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                  begin
                    ElementNode.AppendChild(TGreenNode.Create(gnkIdentifier,
                      CurrentToken(ALexer, ACursor).ByteOffset, 0,
                      CurrentToken(ALexer, ACursor).Lexeme));
                    Inc(ATree.FNodeCount);
                    Inc(ACursor);
                  end;
                  if (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind = tkLParen) then
                    ParseParameterList(ALexer, ACursor, ElementNode, ATree,
                      ADiagnostics, ARootFileId);
                  if (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind = tkColon) then
                  begin
                    Inc(ACursor);
                    if (ACursor < ALexer.TokenCount) and
                      ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) or
                       (CurrentToken(ALexer, ACursor).Kind = tkStringKeyword)) then
                    begin
                      ElementNode.AppendChild(TGreenNode.Create(gnkIdentifier,
                        CurrentToken(ALexer, ACursor).ByteOffset, 0,
                        CurrentToken(ALexer, ACursor).Lexeme));
                      Inc(ATree.FNodeCount);
                      Inc(ACursor);
                    end;
                  end;
                  MatchTokenSilent(ALexer, ACursor, tkSemicolon);
                  TypeNode.AppendChild(ElementNode);
                  Inc(ATree.FNodeCount);
                end
                else if CurrentToken(ALexer, ACursor).Kind = tkPropertyKeyword then
                begin
                  Inc(ACursor);
                  if (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                  begin
                    ElementNode := TGreenNode.Create(gnkClassProperty,
                      CurrentToken(ALexer, ACursor).ByteOffset, 0,
                      CurrentToken(ALexer, ACursor).Lexeme);
                    TypeNode.AppendChild(ElementNode);
                    Inc(ATree.FNodeCount);
                    Inc(ACursor);
                    if (ACursor < ALexer.TokenCount) and
                      (CurrentToken(ALexer, ACursor).Kind = tkColon) then
                    begin
                      Inc(ACursor);
                      if (ACursor < ALexer.TokenCount) and
                        (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                      begin
                        IndexNode := TGreenNode.Create(gnkIdentifier,
                          CurrentToken(ALexer, ACursor).ByteOffset, 0,
                          CurrentToken(ALexer, ACursor).Lexeme);
                        ElementNode.AppendChild(IndexNode);
                        Inc(ATree.FNodeCount);
                        Inc(ACursor);
                      end;
                    end;
                    while (ACursor < ALexer.TokenCount) and
                      (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
                      (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
                      (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                    begin
                      if (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
                        (LowerCase(CurrentToken(ALexer, ACursor).Lexeme) = 'read') then
                      begin
                        Inc(ACursor);
                        if (ACursor < ALexer.TokenCount) and
                          (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                        begin
                          IndexNode := TGreenNode.Create(gnkIdentifier,
                            CurrentToken(ALexer, ACursor).ByteOffset, 0,
                            'read:' + CurrentToken(ALexer, ACursor).Lexeme);
                          ElementNode.AppendChild(IndexNode);
                          Inc(ATree.FNodeCount);
                          Inc(ACursor);
                        end;
                      end
                      else if (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
                        (LowerCase(CurrentToken(ALexer, ACursor).Lexeme) = 'write') then
                      begin
                        Inc(ACursor);
                        if (ACursor < ALexer.TokenCount) and
                          (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                        begin
                          IndexNode := TGreenNode.Create(gnkIdentifier,
                            CurrentToken(ALexer, ACursor).ByteOffset, 0,
                            'write:' + CurrentToken(ALexer, ACursor).Lexeme);
                          ElementNode.AppendChild(IndexNode);
                          Inc(ATree.FNodeCount);
                          Inc(ACursor);
                        end;
                      end
                      else
                        Inc(ACursor);
                    end;
                  end
                  else
                  begin
                    while (ACursor < ALexer.TokenCount) and
                      (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
                      (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
                      (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                      Inc(ACursor);
                  end;
                  MatchTokenSilent(ALexer, ACursor, tkSemicolon);
                end
                else
                  Inc(ACursor);
              end;
              MatchTokenSilent(ALexer, ACursor, tkEndKeyword);
            end;
          end;
        tkLParen:
          begin
            TypeNode := TGreenNode.Create(gnkEnumType,
              CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
            Decl.AppendChild(TypeNode);
            Inc(ATree.FNodeCount);
            Inc(ACursor);
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind <> tkRParen) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
            begin
              if CurrentToken(ALexer, ACursor).Kind = tkIdentifier then
              begin
                TypeNode.AppendChild(TGreenNode.Create(gnkIdentifier,
                  CurrentToken(ALexer, ACursor).ByteOffset,
                  Length(CurrentToken(ALexer, ACursor).Lexeme),
                  CurrentToken(ALexer, ACursor).Lexeme));
                Inc(ATree.FNodeCount);
                Inc(ACursor);
              end;
              if (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind = tkEquals) then
              begin
                Inc(ACursor);
                ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
              end;
              if (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind = tkComma) then
                Inc(ACursor);
            end;
            MatchTokenSilent(ALexer, ACursor, tkRParen);
          end;
        tkSetKeyword:
          begin
            Inc(ACursor);
            MatchTokenSilent(ALexer, ACursor, tkOfKeyword);
            TypeNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId, ATree);
            if TypeNode <> nil then
            begin
              Decl.AppendChild(TypeNode);
              Inc(ATree.FNodeCount);
            end;
          end;
        tkCaret:
          begin
            Inc(ACursor);
            { Keep '^Pointee' text — same contract as ParseTypeReference.
              Dropping the caret made `PFoo = ^TFoo` look like a value alias of
              TFoo (often a record), so locals/returns became recvar/sret. }
            TypeNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId, ATree);
            if TypeNode <> nil then
            begin
              if (Length(TypeNode.Text) = 0) or (TypeNode.Text[1] <> '^') then
              begin
                ElementNode := TypeNode;
                TypeNode := TGreenNode.Create(ElementNode.NodeKind,
                  ElementNode.ByteOffset, Length('^' + ElementNode.Text),
                  '^' + ElementNode.Text);
                Inc(ATree.FNodeCount);
              end;
              Decl.AppendChild(TypeNode);
              Inc(ATree.FNodeCount);
            end;
          end;
        tkProcedureKeyword, tkFunctionKeyword:
          begin
            Inc(ACursor);
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkLParen) then
            begin
              Inc(ACursor);
              while (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind <> tkRParen) and
                (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                Inc(ACursor);
              MatchTokenSilent(ALexer, ACursor, tkRParen);
            end;
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkColon) then
            begin
              Inc(ACursor);
              TypeNode := ParseTypeReference(
                ALexer,
                ACursor,
                ADiagnostics,
                ARootFileId, ATree
              );
              { { TypeNode.Free; } // record, no Free needed } // owned by tree FFacades
            end;
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
              Inc(ACursor);
          end;
        tkTypeKeyword:
          begin
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
              Inc(ACursor);
            MatchTokenSilent(ALexer, ACursor, tkEndKeyword);
          end;
        tkPackedKeyword:
          begin
            Inc(ACursor);
            SkipDirectives(ALexer, ACursor);
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkRecordKeyword) then
            begin
              TypeNode := TGreenNode.Create(gnkRecordType,
                CurrentToken(ALexer, ACursor).ByteOffset, 0, 'packed');
              Decl.AppendChild(TypeNode);
              Inc(ATree.FNodeCount);
              Inc(ACursor);
              SkipDirectives(ALexer, ACursor);
              while (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
                (CurrentToken(ALexer, ACursor).Kind <> tkImplementationKeyword) and
                (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                Inc(ACursor);
              MatchTokenSilent(ALexer, ACursor, tkEndKeyword);
            end
            else
            begin
              while (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
                (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                Inc(ACursor);
            end;
          end;
        tkMinus, tkPlus, tkIntegerLiteral, tkCharLiteral:
          begin
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
              Inc(ACursor);
          end;
      else
        TypeNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId, ATree);
        if TypeNode <> nil then
        begin
          Decl.AppendChild(TypeNode);
          Inc(ATree.FNodeCount);
        end;
      end;
    end;

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind in
        [tkDeprecatedKeyword, tkPlatformKeyword, tkExperimentalKeyword]) then
    begin
      Inc(ACursor);
      if (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind = tkStringLiteral) then
        Inc(ACursor);
    end;
    if not MatchTokenSilent(ALexer, ACursor, tkSemicolon) then
    begin
      while (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkImplementationKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkBeginKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
        Inc(ACursor);
      MatchTokenSilent(ALexer, ACursor, tkSemicolon);
    end;
    { Consume calling conventions after procedure type semicolons:
      e.g. "procedure; cdecl;" — after the first ; is consumed, check for cdecl }
    while (ACursor < ALexer.TokenCount) and
      (IsDirectiveToken(CurrentToken(ALexer, ACursor).Kind) or
       ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
        IsCallingDirective(CurrentToken(ALexer, ACursor).Lexeme))) do
    begin
      Inc(ACursor);
      MatchTokenSilent(ALexer, ACursor, tkSemicolon);
    end;
  end;

  Result := True;
end;

