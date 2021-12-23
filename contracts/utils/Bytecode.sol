// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

library Bytecode {
  error InvalidCodeAtRange(uint256 _size, uint256 _start, uint256 _end);

  /**
    @notice Generate a creation code that results on a contract with `_code` as bytecode
    @param _code The returning value of the resulting `creationCode`
    @return creationCode (constructor) for new contract
  */
  function creationCodeFor(bytes memory _code)
    internal
    pure
    returns (bytes memory)
  {
    /*
      0x00    0x63         0x63XXXXXX  PUSH4 _code.length  size
      0x01    0x80         0x80        DUP1                size size
      0x02    0x60         0x600e      PUSH1 14            14 size size
      0x03    0x60         0x6000      PUSH1 00            0 14 size size
      0x04    0x39         0x39        CODECOPY            size
      0x05    0x60         0x6000      PUSH1 00            0 size
      0x06    0xf3         0xf3        RETURN
      <CODE>
    */

    return
      abi.encodePacked(
        hex"63",
        uint32(_code.length),
        hex"80_60_0E_60_00_39_60_00_F3",
        _code
      );
  }

  /**
    @notice Returns the code of a given address
    @dev It will fail if `_end < _start`
    @param _possibleAddr1 first of two addresses that may or may not contain code
    @param _possibleAddr2 second of two addresses that may or may not contain code
    @param _start number of bytes of code to skip on read
    @param _end index before which to end extraction
    @return oCode read from `_addr` deployed bytecode

    Forked from: https://gist.github.com/KardanovIR/fe98661df9338c842b4a30306d507fbd
  */
  function codeAt(
    address _possibleAddr1,
    address _possibleAddr2,
    uint256 _start,
    uint256 _end
  ) internal view returns (bytes memory oCode) {
    address _addr = _possibleAddr1;
    uint256 csize = _addr.code.length;

    if (csize == 0) {
      _addr = _possibleAddr2;
      csize = _addr.code.length;
    }
    if (csize == 0) return bytes("");

    if (_start > csize) return bytes("");
    if (_end < _start) revert InvalidCodeAtRange(csize, _start, _end);

    unchecked {
      uint256 reqSize = _end - _start;
      uint256 maxSize = csize - _start;

      uint256 size = maxSize < reqSize ? maxSize : reqSize;

      // solhint-disable no-inline-assembly
      assembly {
        // allocate output byte array - this could also be done without assembly
        // by using o_code = new bytes(size)
        oCode := mload(0x40)
        // new "memory end" including padding
        mstore(
          0x40,
          add(oCode, and(add(add(size, add(_start, 0x20)), 0x1f), not(0x1f)))
        )
        // store length in memory
        mstore(oCode, size)
        // actually retrieve the code, this needs assembly
        extcodecopy(_addr, add(oCode, 0x20), _start, size)
      }
      // solhint-enable no-inline-assembly
    }
  }
}
