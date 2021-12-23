// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../utils/CREATE3Optimized.sol";
import "../../SSTORE3.sol";

contract TestSSTORE3 {
  function write1(bytes32 _key, bytes calldata _data)
    external
    returns (address pointer)
  {
    return SSTORE3.write(_key, _data);
  }

  function write2(string calldata _key, bytes calldata _data)
    external
    returns (address pointer)
  {
    return SSTORE3.write(_key, _data);
  }

  function read1(bytes32 _key) external view returns (bytes memory) {
    return SSTORE3.read(_key);
  }

  function read2(bytes32 _key, uint256 _start)
    external
    view
    returns (bytes memory)
  {
    return SSTORE3.read(_key, _start);
  }

  function read3(
    bytes32 _key,
    uint256 _start,
    uint256 _end
  ) external view returns (bytes memory) {
    return SSTORE3.read(_key, _start, _end);
  }

  function read4(string calldata _key) external view returns (bytes memory) {
    return SSTORE3.read(_key);
  }

  function read5(string calldata _key, uint256 _start)
    external
    view
    returns (bytes memory)
  {
    return SSTORE3.read(_key, _start);
  }

  function read6(
    string calldata _key,
    uint256 _start,
    uint256 _end
  ) external view returns (bytes memory) {
    return SSTORE3.read(_key, _start, _end);
  }

  function addressOf1(bytes32 _key) external view returns (address _addr) {
    (_addr, ) = CREATE3Optimized.possibleAddressesOf(SSTORE3.internalKey(_key));
  }

  function addressOf2(string calldata _key)
    external
    view
    returns (address _addr)
  {
    (_addr, ) = CREATE3Optimized.possibleAddressesOf(
      SSTORE3.internalKey(keccak256(bytes(_key)))
    );
  }
}
