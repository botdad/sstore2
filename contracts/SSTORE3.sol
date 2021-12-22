// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./utils/CREATE3Optimized.sol";
import "./utils/Bytecode.sol";
import "hardhat/console.sol";

/**
  @title A rewritable key-value storage for storing chunks of data with a lower write & read cost.
  @author zefram.eth <https://twitter.com/boredGenius>

  Readme: https://github.com/ZeframLou/sstore3#readme
*/
library SSTORE3 {
  error ErrorDestroyingContract();

  bytes32 private constant SLOT_KEY_PREFIX =
    keccak256(bytes("zefram.eth.SSTORE3.slot"));
  uint256 private constant DATA_OFFSET = 30;

  function internalKey(bytes32 _key) internal pure returns (bytes32) {
    // Mutate the key so it doesn't collide
    // if the contract is also using CREATE3 for other things
    return keccak256(abi.encode(SLOT_KEY_PREFIX, _key));
  }

  /**
    @notice Stores `_data` and returns `pointer` as key for later retrieval
    @dev The pointer is a contract address with `_data` as code
    @param _data To be written
    @param _key unique string key for accessing the written data (can only be used once)
    @return pointer Pointer to the written `_data`
  */
  function write(string memory _key, bytes memory _data)
    internal
    returns (address pointer)
  {
    return write(keccak256(bytes(_key)), _data);
  }

  /**
    @notice Stores `_data` and returns `pointer` as key for later retrieval
    @dev The pointer is a contract address with `_data` as code
    @param _data to be written
    @param _key unique bytes32 key for accessing the written data (can only be used once)
    @return pointer Pointer to the written `_data`
  */
  function write(bytes32 _key, bytes memory _data)
    internal
    returns (address pointer)
  {
    /**
      The bytecode of the created data-contract.
      When called, the data-contract check whether the sender is equal to the preset owner address
      (in our case it's this contract), if so then the data-contract selfdestructs, allowing for
      reiniting a new contract at the same address. If the sender is not the owner, then the
      execution halts.
      The data is stored from 0x09 onwards.

      0x00  0x33  0x33                                          CALLER        sender
      0x01  0x73  0x73XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  PUSH20 owner  owner sender
      0x16  0x14  0x14                                          EQ            isOwner
      0x17  0x60  0x601B                                        PUSH1 0x06    0x06 isOwner
      0x19  0x57  0x57                                          JUMPI                       % branch based on isOwner
      0x1A  0x00  0x00                                          STOP                        % not owner, halt
      0x1B  0x5B  0x5B                                          JUMPDEST                    % is owner, selfdestruct
      0x1C  0x32  0x32                                          ORIGIN        origin        % use tx.origin for cheaper gas
      0x1D  0xFF  0xFF                                          SELFDESTRUCT
     */
    bytes32 salt = internalKey(_key);

    bytes memory code = Bytecode.creationCodeFor(
      abi.encodePacked(
        hex"33_73",
        CREATE3Optimized.computeProxyAddress(salt),
        hex"14_60_1B_57_00_5B_32_FF",
        _data
      )
    );

    // pointer = CREATE3Optimized.addressOf(salt);

    // Deploy contract using CREATE3
    CREATE3Optimized.create3Optimized(salt, code);

    // console.logBytes(pointer.code);
  }

  /**
    @notice Reads the contents for a given `_key`, it maps to a contract code as data, skips the first byte
    @dev The function is intended for reading pointers first written by `write`
    @param _key string key that constains the data
    @return data read from contract associated with `_key`
  */
  function read(string memory _key) internal view returns (bytes memory) {
    return read(keccak256(bytes(_key)));
  }

  /**
    @notice Reads the contents for a given `_key`, it maps to a contract code as data, skips the first byte
    @dev The function is intended for reading pointers first written by `write`
    @param _key string key that constains the data
    @param _start number of bytes to skip
    @return data read from contract associated with `_key`
  */
  function read(string memory _key, uint256 _start)
    internal
    view
    returns (bytes memory)
  {
    return read(keccak256(bytes(_key)), _start);
  }

  /**
    @notice Reads the contents for a given `_key`, it maps to a contract code as data, skips the first byte
    @dev The function is intended for reading pointers first written by `write`
    @param _key string key that constains the data
    @param _start number of bytes to skip
    @param _end index before which to end extraction
    @return data read from contract associated with `_key`
  */
  function read(
    string memory _key,
    uint256 _start,
    uint256 _end
  ) internal view returns (bytes memory) {
    return read(keccak256(bytes(_key)), _start, _end);
  }

  /**
    @notice Reads the contents for a given `_key`, it maps to a contract code as data, skips the first byte
    @dev The function is intended for reading pointers first written by `write`
    @param _key bytes32 key that constains the data
    @return data read from contract associated with `_key`
  */
  function read(bytes32 _key) internal view returns (bytes memory) {
    return
      Bytecode.codeAt(
        CREATE3Optimized.addressOf(internalKey(_key)),
        DATA_OFFSET,
        type(uint256).max
      );
  }

  /**
    @notice Reads the contents for a given `_key`, it maps to a contract code as data, skips the first byte
    @dev The function is intended for reading pointers first written by `write`
    @param _key bytes32 key that constains the data
    @param _start number of bytes to skip
    @return data read from contract associated with `_key`
  */
  function read(bytes32 _key, uint256 _start)
    internal
    view
    returns (bytes memory)
  {
    return
      Bytecode.codeAt(
        CREATE3Optimized.addressOf(internalKey(_key)),
        _start + DATA_OFFSET,
        type(uint256).max
      );
  }

  /**
    @notice Reads the contents for a given `_key`, it maps to a contract code as data, skips the first byte
    @dev The function is intended for reading pointers first written by `write`
    @param _key bytes32 key that constains the data
    @param _start number of bytes to skip
    @param _end index before which to end extraction
    @return data read from contract associated with `_key`
  */
  function read(
    bytes32 _key,
    uint256 _start,
    uint256 _end
  ) internal view returns (bytes memory) {
    return
      Bytecode.codeAt(
        CREATE3Optimized.addressOf(internalKey(_key)),
        _start + DATA_OFFSET,
        _end + DATA_OFFSET
      );
  }
}
