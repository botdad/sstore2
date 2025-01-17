object "CREATE07Proxy" {
  // This is the constructor code of the contract.
  code {
    datacopy(0, dataoffset("runtime"), datasize("runtime"))
    return(0, datasize("runtime"))
  }

  object "runtime" {
    code {
      mstore8(0x00, 0xd6)
      mstore8(0x01, 0x94)
      // pack address after
      mstore(0x02, shl(0x60, address()))
      // put a 0x01 at the end
      mstore8(0x16, 0x01)
      let nonce1Address := keccak256(0x00, 0x17)
      // replace the 0x01 with an 0x02
      mstore8(0x16, 0x02)
      let nonce2Address := keccak256(0x00, 0x17)

      // get calldata into memory to forward to create
      let size := calldatasize()
      calldatacopy(0x00, 0x00, size)

      switch extcodesize(nonce1Address)
      case 0 {
        // deploy data at nonce 1
        pop(create(0x00, 0x00, size))

        if extcodesize(nonce2Address) {
          // selfdestruct data contract at nonce 2
          pop(call(gas(), nonce2Address, 0x00, 0x00, 0x00, 0x00, 0x0))
        }
      }
      default {
        // deploy data at nonce 2
        pop(create(0x00, 0x00, size))

        // selfdestruct data contract at nonce 1
        pop(call(gas(), nonce1Address, 0x00, 0x00, 0x00, 0x00, 0x0))

        // selfdestruct this proxy to reset nonce to 1
        // the next data write will redeploy this proxy
        selfdestruct(caller())
      }
    }
  }
}