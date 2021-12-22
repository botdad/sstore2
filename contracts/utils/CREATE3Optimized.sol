//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

interface CREATE07Like {
  function deployDataContract(bytes memory data) external;
}

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
    hex"608060405234801561001057600080fd5b506104b0806100206000396000f3fe608060405234801561001057600080fd5b506004361061002b5760003560e01c80635f2eff6214610030575b600080fd5b61004361003e3660046103ab565b610045565b005b604080517fd69400000000000000000000000000000000000000000000000000000000000060208083018290527fffffffffffffffffffffffffffffffffffffffff0000000000000000000000003060601b16602284018190527f0100000000000000000000000000000000000000000000000000000000000000603685015284518085036017018152603785018652805190830120605785019390935260598401527f0200000000000000000000000000000000000000000000000000000000000000606d8401528351604e818503018152606e90930190935281519190920120600073ffffffffffffffffffffffffffffffffffffffff83163b61026e578351602085016000f090508273ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff16146101b5576040517f4b1a372600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b73ffffffffffffffffffffffffffffffffffffffff82163b156102695760405160009073ffffffffffffffffffffffffffffffffffffffff8416908281818181865af19150503d8060008114610227576040519150601f19603f3d011682016040523d82523d6000602084013e61022c565b606091505b5050905080610267576040517f06c5dd0c00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b505b610376565b8351602085016000f090508173ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff16146102de576040517f4b1a372600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60405160009073ffffffffffffffffffffffffffffffffffffffff8516908281818181865af19150503d8060008114610333576040519150601f19603f3d011682016040523d82523d6000602084013e610338565b606091505b5050905080610373576040517f06c5dd0c00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b32ff5b50505050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b6000602082840312156103bd57600080fd5b813567ffffffffffffffff808211156103d557600080fd5b818401915084601f8301126103e957600080fd5b8135818111156103fb576103fb61037c565b604051601f82017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0908116603f011681019083821181831017156104415761044161037c565b8160405282815287602084870101111561045a57600080fd5b82602086016020830137600092810160200192909252509594505050505056fea264697066735822122037f7ce8c01d8cb24000c897c2514baaf9fc96f4330434d610fdb54542e9dddf864736f6c634300080b0033";
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
    // (bool success, ) = proxy.call(_creationCode);
    CREATE07Like(proxy).deployDataContract(_creationCode);
    // solhint-enable avoid-low-level-calls
    // if (!success) revert ErrorCreatingContract();
  }

  /**
    @notice Computes the resulting address of a contract deployed using address(this) and the given `_salt`
    @param _salt Salt of the contract creation, resulting address will be derivated from this value only
    @return calculatedAddress addr of the deployed contract, reverts on error
    @dev The address creation formula is: keccak256(rlp([keccak256(0xff ++ address(this) ++ _salt ++ keccak256(childBytecode))[12:], 0x01]))
  */
  function addressOf(bytes32 _salt)
    internal
    view
    returns (address calculatedAddress)
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

    calculatedAddress = address(
      uint160(uint256(keccak256(abi.encodePacked(hex"d6_94", proxy, hex"01"))))
    );

    if (calculatedAddress.code.length == 0) {
      calculatedAddress = address(
        uint160(
          uint256(keccak256(abi.encodePacked(hex"d6_94", proxy, hex"02")))
        )
      );
    }
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
