// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../SSTORE3.sol";

contract Benchmark {
  event Written(address _addr);
  event Cost(uint256 _gas);

  mapping(bytes32 => bytes) private stored;

  function write1(bytes32 _key, bytes calldata _data) external {
    uint256 ig = gasleft();
    stored[_key] = _data;
    emit Cost(ig - gasleft());
  }

  function read1(bytes32 _key) external returns (bytes memory r) {
    uint256 ig = gasleft();
    r = stored[_key];
    emit Cost(ig - gasleft());
  }

  function write2(bytes32 _key, bytes calldata _data) external {
    uint256 ig = gasleft();
    SSTORE3.write(_key, _data);
    emit Cost(ig - gasleft());
  }

  function read2(bytes32 _key) external returns (bytes memory r) {
    uint256 ig = gasleft();
    r = SSTORE3.read(_key);
    emit Cost(ig - gasleft());
  }
}
