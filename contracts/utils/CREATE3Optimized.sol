//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

/**
  @title A library for deploying contracts EIP-3171 style.
  @author zefram.eth <https://twitter.com/boredGenius>
*/
library CREATE3Optimized {
  error ErrorCreatingProxy();
  error ErrorCreatingContract();

  /**
    @notice The bytecode for a contract that proxies the creation of another contract
    @dev If this code is deployed using CREATE2 it can be used to decouple `creationCode` from the child contract address
  0x67363d3d37363d34f03d5260086018f3:
      0x00  0x67  0x67XXXXXXXXXXXXXXXX  PUSH8 bytecode  0x363d3d37363d34f0
      0x01  0x3d  0x3d                  RETURNDATASIZE  0 0x363d3d37363d34f0
      0x02  0x52  0x52                  MSTORE
      0x03  0x60  0x6008                PUSH1 08        8
      0x04  0x60  0x6018                PUSH1 18        24 8
      0x05  0xf3  0xf3                  RETURN
  0x363d3d37363d34f0:
      0x00  0x36  0x36                  CALLDATASIZE    cds
      0x01  0x3d  0x3d                  RETURNDATASIZE  0 cds
      0x02  0x3d  0x3d                  RETURNDATASIZE  0 0 cds
      0x03  0x37  0x37                  CALLDATACOPY
      0x04  0x36  0x36                  CALLDATASIZE    cds
      0x05  0x3d  0x3d                  RETURNDATASIZE  0 cds
      0x06  0x34  0x34                  CALLVALUE       val 0 cds
      0x07  0xf0  0xf0                  CREATE          addr
  */

  // this is a terrible and unoptimized proxy created from CREATE07Proxy.sol
  // I didn't want to write the bytecode manually in order to test if this stupid idea would work
  bytes internal constant PROXY_CHILD_BYTECODE =
    hex"608060405234801561001057600080fd5b506102d2806100206000396000f3fe60a06020601f369081018290049091028201604052608081815260009290918391819083828082843760009201829052506040517fd69400000000000000000000000000000000000000000000000000000000000060208201527fffffffffffffffffffffffffffffffffffffffff0000000000000000000000003060601b1660228201527f010000000000000000000000000000000000000000000000000000000000000060368201529495509360370192506100bb915050565b604080517fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe081840301815282825280516020918201207fd694000000000000000000000000000000000000000000000000000000000000828501523060601b7fffffffffffffffffffffffffffffffffffffffff0000000000000000000000001660228501527f020000000000000000000000000000000000000000000000000000000000000060368501528251601781860301815260379094019092528251920191909120909150600073ffffffffffffffffffffffffffffffffffffffff83163b61022b578351602085016000f0905073ffffffffffffffffffffffffffffffffffffffff82163b156102265760405173ffffffffffffffffffffffffffffffffffffffff831690600081818181865af19150503d806000811461021d576040519150601f19603f3d011682016040523d82523d6000602084013e610222565b606091505b5050505b610296565b8351602085016000f060405190915073ffffffffffffffffffffffffffffffffffffffff841690600081818181865af19150503d806000811461028a576040519150601f19603f3d011682016040523d82523d6000602084013e61028f565b606091505b5033915050ff5b5050505000fea2646970667358221220656b45276c8bc0577cd91a14c7fda83b3d1ee9c783b7bcad8a5a8397ba625dc664736f6c634300080b0033";
  bytes32 internal constant KECCAK256_PROXY_CHILD_BYTECODE =
    keccak256(PROXY_CHILD_BYTECODE);

  /**
    @notice Creates a new contract with given `_creationCode` and `_salt`
    @param _salt Salt of the contract creation, resulting address will be derivated from this value only
    @param _creationCode Creation code (constructor) of the contract to be deployed, this value doesn't affect the resulting address
  */
  function create3Optimized(bytes32 _salt, bytes memory _creationCode)
    internal
  {
    // Creation code
    bytes memory creationCode = PROXY_CHILD_BYTECODE;

    // Create CREATE2 proxy
    address proxy = computeProxyAddress(_salt);
    if (proxy.code.length == 0) {
      proxy = address(0);
      // solhint-disable no-inline-assembly
      assembly {
        proxy := create2(0, add(creationCode, 32), mload(creationCode), _salt)
      }
      // solhint-enable no-inline-assembly
      if (proxy == address(0)) revert ErrorCreatingProxy();
    }

    // Call proxy with final init code
    // solhint-disable avoid-low-level-calls
    (bool success, ) = proxy.call(_creationCode);
    // solhint-enable avoid-low-level-calls
    if (!success) revert ErrorCreatingContract();
  }

  /**
    @notice Computes the resulting address of a contract deployed using address(this) and the given `_salt`
    @param _salt Salt of the contract creation, resulting address will be derivated from this value only
    @return the two possible addr of the deployed data, reverts on error
    @dev The address creation formula is: keccak256(rlp([keccak256(0xff ++ address(this) ++ _salt ++ keccak256(childBytecode))[12:], 0x01]))
  */
  function possibleAddressesOf(bytes32 _salt)
    internal
    view
    returns (address, address)
  {
    address proxy = address(
      uint160(
        uint256(
          keccak256(
            abi.encodePacked(
              hex"ff",
              address(this),
              _salt,
              KECCAK256_PROXY_CHILD_BYTECODE
            )
          )
        )
      )
    );

    return (
      address(
        uint160(
          uint256(keccak256(abi.encodePacked(hex"d6_94", proxy, hex"01")))
        )
      ),
      address(
        uint160(
          uint256(keccak256(abi.encodePacked(hex"d6_94", proxy, hex"02")))
        )
      )
    );
  }

  function computeProxyAddress(bytes32 _salt) internal view returns (address) {
    bytes32 _data = keccak256(
      abi.encodePacked(
        hex"ff",
        address(this),
        _salt,
        KECCAK256_PROXY_CHILD_BYTECODE
      )
    );
    return address(uint160(uint256(_data)));
  }
}
