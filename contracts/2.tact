import "@stdlib/deploy";

/*
  TASK 2 - Proxy 
  Create a contract that forwards all received TONs
  to the admin contract (whose address is set in init_store).
  Message from this proxy contract to the admin contract should contain:
    - Address of user who sent original message (should be stored in the outcoming body's data/bits)
    - Original message that proxy smart contract received from user (should be stored in the outcoming body's first ref)
  Also, if admin contract decides to reject message (if it sends to the proxy "Refund" message with opcode=0x44),
  proxy contract needs to forward all TONs (attached to Refund message) back to the user.
  User address will be provided in Refund message body as "sender".
*/

message(0x44) Refund {
  queryId: Int as uint64;
  sender: Address;
}

contract Task2 with Deployable {
  admin: Address;

  init(admin: Address) {
    self.admin = admin;
  }
  
  receive(msg: Refund) {
    nativeThrowUnless(100, sender() == self.admin);
    // require(sender() == self.admin, "invalid address");
    nativeSendMessage(
      beginCell()
        .storeInt(0x18, 6)
        .storeSlice(msg.sender.asSlice()) // To
        .storeInt(0, 4 + 1 + 4 + 4 + 64 + 32 + 1 + 1) // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt + No state init + no body
      .endCell(),
      64
    );

    // send(SendParameters{
    //   to: msg.sender,
    //   value: 0,
    //   mode: SendRemainingValue
    // });
  }

  receive(msg: Slice) {
    nativeSendMessage(
      beginCell()
        .storeInt(0x18, 6)
        .storeSlice(self.admin.asSlice())
        // .storeAddress(self.admin) // To
        .storeInt(1, 4 + 1 + 4 + 4 + 64 + 32 + 1 + 1) // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
        .storeRef(
          beginCell().storeSlice(sender().asSlice()).storeRef(
            beginCell().storeSlice(msg).endCell()
          ).endCell()
        )
      .endCell(),
      64
    );
    // send(SendParameters{
    //   to: self.admin,
    //   value: 0,
    //   mode: SendRemainingValue,
    //   body: beginCell().storeAddress(sender()).storeRef(
    //     beginCell().storeSlice(msg).endCell()
    //   ).endCell()
    // });
  }
}
