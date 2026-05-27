unit nextpas.core.collections.bitset.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.collections.intf;

type
  {**
   * IBitSet
   *
   * @desc Efficient bit set collection for boolean flags
   * @note Uses UInt64 words for compact storage (1 bit per boolean vs 1 byte)
   *}
  IBitSet = interface(ICollection)
  ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    {**
     * SetBit
     *
     * @desc Sets a bit to 1 at the specified index
     * @param aIndex The bit index to set
     *}
    procedure SetBit(aIndex: SizeUInt);

    {**
     * ClearBit
     *
     * @desc Clears a bit to 0 at the specified index
     * @param aIndex The bit index to clear
     *}
    procedure ClearBit(aIndex: SizeUInt);

    {**
     * Test
     *
     * @desc Tests if a bit is set (1) at the specified index
     * @param aIndex The bit index to test
     * @return Boolean True if bit is set, False otherwise
     *}
    function Test(aIndex: SizeUInt): Boolean;

    {**
     * Flip
     *
     * @desc Toggles a bit at the specified index
     * @param aIndex The bit index to flip
     *}
    procedure Flip(aIndex: SizeUInt);

    {**
     * AndWith
     *
     * @desc Performs bitwise AND with another BitSet
     * @param aOther The other BitSet
     * @return IBitSet New BitSet containing the result
     *}
    function AndWith(const aOther: IBitSet): IBitSet;

    {**
     * OrWith
     *
     * @desc Performs bitwise OR with another BitSet
     * @param aOther The other BitSet
     * @return IBitSet New BitSet containing the result
     *}
    function OrWith(const aOther: IBitSet): IBitSet;

    {**
     * XorWith
     *
     * @desc Performs bitwise XOR with another BitSet
     * @param aOther The other BitSet
     * @return IBitSet New BitSet containing the result
     *}
    function XorWith(const aOther: IBitSet): IBitSet;

    {**
     * NotBits
     *
     * @desc Performs bitwise NOT (inversion)
     * @return IBitSet New BitSet containing the result
     *}
    function NotBits: IBitSet;

    {**
     * Cardinality
     *
     * @desc Counts the number of set bits (1s)
     * @return SizeUInt The count of set bits
     *}
    function Cardinality: SizeUInt;

    {**
     * SetAll
     *
     * @desc Sets all bits in the current capacity range to 1
     *}
    procedure SetAll;

    {**
     * ClearAll
     *
     * @desc Clears all bits to 0
     *}
    procedure ClearAll;

    {**
     * GetBitCapacity
     *
     * @desc Returns the total number of bits that can be stored
     * @return SizeUInt The bit capacity
     *}
    function GetBitCapacity: SizeUInt;

    property BitCapacity: SizeUInt read GetBitCapacity;
  end;

implementation

end.
