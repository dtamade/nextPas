program NestedComments_pass;
begin
  { outer { inner } still outer }
  { level1
    { level2
      { level3 }
    }
  }
  { not nested with paren-star (* this stays raw *) just braces }
end.
