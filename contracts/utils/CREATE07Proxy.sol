// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

contract CREATE07Proxy {
  // solhint-disable-next-line no-complex-fallback, payable-fallback
  fallback() external {
    bytes memory creationCode = msg.data;

    address nonce1Address = address(
      uint160(
        uint256(keccak256(abi.encodePacked(hex"d6_94", address(this), hex"01")))
      )
    );
    address nonce2Address = address(
      uint160(
        uint256(keccak256(abi.encodePacked(hex"d6_94", address(this), hex"02")))
      )
    );

    address dataContract;

    if (nonce1Address.code.length == 0) {
      // deploy data at nonce 1
      // solhint-disable-next-line no-inline-assembly
      assembly {
        dataContract := create(0, add(creationCode, 32), mload(creationCode))
      }

      if (nonce2Address.code.length != 0) {
        // selfdestruct data contract at nonce 2
        // solhint-disable-next-line avoid-low-level-calls
        nonce2Address.call("");
      }
    } else {
      // deploy data at nonce 2
      // solhint-disable-next-line no-inline-assembly
      assembly {
        dataContract := create(0, add(creationCode, 32), mload(creationCode))
      }

      // selfdestruct data contract at nonce 1
      // solhint-disable-next-line avoid-low-level-calls
      nonce1Address.call("");

      // selfdestruct this proxy to reset nonce to 1
      // the next data write will redeploy this proxy
      selfdestruct(payable(msg.sender));
    }
  }
}
