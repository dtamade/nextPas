unit nextpas.core.text.unicode.base;

{$I nextpas.core.settings.inc}

interface

type
  TUnicodeCodepoint = UInt32;

  TGeneralCategory = (
    gcuUppercaseLetter,
    gcuLowercaseLetter,
    gcuTitlecaseLetter,
    gcuModifierLetter,
    gcuOtherLetter,
    gcuNonspacingMark,
    gcuSpacingMark,
    gcuEnclosingMark,
    gcuDecimalNumber,
    gcuLetterNumber,
    gcuOtherNumber,
    gcuConnectorPunctuation,
    gcuDashPunctuation,
    gcuOpenPunctuation,
    gcuClosePunctuation,
    gcuInitialPunctuation,
    gcuFinalPunctuation,
    gcuOtherPunctuation,
    gcuMathSymbol,
    gcuCurrencySymbol,
    gcuModifierSymbol,
    gcuOtherSymbol,
    gcuSpaceSeparator,
    gcuLineSeparator,
    gcuParagraphSeparator,
    gcuControl,
    gcuFormat,
    gcuSurrogate,
    gcuPrivateUse,
    gcuUnassigned
  );

  TBinaryProperty = (
    ubpAlphabetic,
    ubpLowercase,
    ubpUppercase,
    ubpCased,
    ubpCaseIgnorable,
    ubpIdStart,
    ubpIdContinue,
    ubpXidStart,
    ubpXidContinue,
    ubpWhiteSpace,
    ubpGraphemeBase,
    ubpGraphemeExtend,
    ubpMath,
    ubpEmoji,
    ubpEmojiPresentation,
    ubpEmojiModifier,
    ubpEmojiModifierBase,
    ubpEmojiComponent,
    ubpDefaultIgnorableCodePoint,
    ubpDeprecated,
    ubpSoftDotted
  );

  TGeneralCategorySet = set of TGeneralCategory;

  TCodepointRange2 = record
    Lo: TUnicodeCodepoint;
    Hi: TUnicodeCodepoint;
    Delta: Int32;
  end;

  TCodepointRange3 = record
    Lo: TUnicodeCodepoint;
    Hi: TUnicodeCodepoint;
    Value: Byte;
  end;

  TCaseFoldMap = array[0..7] of TUnicodeCodepoint;

  TCaseFoldEntry = record
    Cp: TUnicodeCodepoint;
    Len: Byte;
    Map: TCaseFoldMap;
  end;

const
  UNICODE_MAX_CODEPOINT = TUnicodeCodepoint($10FFFF);
  UNICODE_SURROGATE_FIRST = TUnicodeCodepoint($D800);
  UNICODE_SURROGATE_LAST = TUnicodeCodepoint($DFFF);

implementation

end.
