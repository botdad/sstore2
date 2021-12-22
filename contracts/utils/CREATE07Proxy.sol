// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./Bytecode.sol";

contract CREATE07Proxy {
  error ErrorDestroyingContract();
  error ErrorDeployingToDeterministicAddress();

  function deployDataContract(bytes memory creationCode) external {
    address nonce1Address = addressOf(1);
    address nonce2Address = addressOf(2);

    address dataContract;

    if (nonce1Address.code.length == 0) {
      // deploy data at nonce 1
      assembly {
        dataContract := create(0, add(creationCode, 32), mload(creationCode))
      }
      if (dataContract != nonce1Address)
        revert ErrorDeployingToDeterministicAddress();

      if (nonce2Address.code.length != 0) {
        // selfdestruct data contract at nonce 2
        (bool success, ) = nonce2Address.call("");
        if (!success) revert ErrorDestroyingContract();
      }
    } else {
      // deploy data at nonce 2
      assembly {
        dataContract := create(0, add(creationCode, 32), mload(creationCode))
      }
      if (dataContract != nonce2Address)
        revert ErrorDeployingToDeterministicAddress();

      // selfdestruct data contract at nonce 1
      (bool success, ) = nonce1Address.call("");
      if (!success) revert ErrorDestroyingContract();

      // selfdestruct this proxy to reset nonce to 1
      // the next data write will redeploy this proxy
      selfdestruct(payable(tx.origin));
    }
  }

  function addressOf(uint8 nonce) internal view returns (address) {
    return
      address(
        uint160(
          uint256(keccak256(abi.encodePacked(hex"d6_94", address(this), nonce)))
        )
      );
  }
}
