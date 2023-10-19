import "@stdlib/deploy";

/*
  TASK 4 - NFT locker
  Implement a smart contract that will lock NFT for a period of time specified by the owner.
  Smart conrtact should contain logic to process following messages and getters: 

  Messages: 
  * OwnershipAssigned
   - Recives nft + time (in a forwardPayload message as uint32) for which this nft will be locked + address of the sender of the nft (prevOwner).
   - If the smart contract already holds an nft then return the incoming nft back to the sender
  * NftWithdrawal
   - Request withdrawal of the locked nft
   - If sender is not the owner (that came from OwnershipAssigned as prevOwner address) then throw "Invalid sender" 
   - If time has not passed then send message back to the sender with the comment "NFT is still locked" according to the TON's "message with text comment" standard 
   - Otherwise (all good) send the locked nft back to the owner with all the remaining TON balance
   Note that the order of checks is important
   (in case: "sender is not the owner" and "time has not passed" at the same time, "Invalid sender" error takes priority)

  Getters:
  * time
   - get how much lock time is left
  * nft
   - get the address of the locked nft 
  * owner
   - get the owner of the locked nft (that came from OwnershipAssigned as prevOwner)
*/

message(0x05138d91) OwnershipAssigned {
    queryId: Int as uint64;
    prevOwner: Address;
    forwardPayload: Slice as remaining; 
}

message(0x5fcc3d14) Transfer { 
    queryId: Int as uint64;            
    newOwner: Address; 
    responseDestination: Address; 
    customPayload: Cell?; 
    forwardAmount: Int as coins; 
    forwardPayload: Slice as remaining; 
}

message NftWithdrawal {
  queryId: Int as uint64;
  nftAddress: Address;
}

contract Task4 with Deployable {
  seed: Int as uint128;
  time: Int as uint32;
  owner: Address?;
  nft_address: Address?;

  init(seed: Int) {
    self.seed = seed;
    self.time = 0;
    self.owner = null;
    self.nft_address = null;
  }

  receive(msg: OwnershipAssigned) {
    if (self.nft_address == null) {
      self.time = now() + msg.forwardPayload.loadUint(32);
      self.owner = msg.prevOwner;
      self.nft_address = sender();
      return;
    }
    nativeSendMessage(beginCell().storeInt(0x18, 6).storeAddress(sender()).storeCoins(0).storeInt(0, 1 + 4 + 4 + 64 + 32 + 1).storeBool(true).storeRef(
      Transfer{
        queryId: msg.queryId,
        newOwner: msg.prevOwner,
        responseDestination: msg.prevOwner,
        customPayload: null,
        forwardAmount: 0,
        forwardPayload: emptySlice()
      }.toCell()
    ).endCell(), 64);

    // send(SendParameters{
    //   to: sender(),
    //   value: 0,
    //   mode: 64,
    //   body: Transfer{
    //     queryId: msg.queryId,
    //     newOwner: msg.prevOwner,
    //     responseDestination: msg.prevOwner,
    //     customPayload: null,
    //     forwardAmount: 0,
    //     forwardPayload: emptySlice()
    //   }.toCell()
    // });
  }

  receive(msg: NftWithdrawal) {
    require(sender() == self.owner, "Invalid sender");

    if (now() < self.time) {
      nativeSendMessage(beginCell().storeInt(0x18, 6).storeAddress(sender()).storeCoins(0).storeInt(0, 1 + 4 + 4 + 64 + 32 + 1).storeBool(true).storeRef(
        "NFT is still locked".asComment()
      ).endCell(), 64);
      // send(SendParameters{
      //     to: sender(),
      //     value: 0,
      //     mode: 64,
      //     body: "NFT is still locked".asComment()
      // });
      return;
    }

    nativeThrowUnless(100, self.nft_address == msg.nftAddress);
    // require(self.nft_address == msg.nftAddress, "Invalid nftAddress");

    nativeSendMessage(beginCell().storeInt(0x18, 6).storeAddress(msg.nftAddress).storeCoins(0).storeInt(0, 1 + 4 + 4 + 64 + 32 + 1).storeBool(true).storeRef(
      beginCell().storeUint(msg.queryId, 64).storeAddress(sender()).storeAddress(sender()).storeBool(false).storeCoins(0).endCell()
      // Transfer{
      //   queryId: msg.queryId,
      //   newOwner: sender(),
      //   responseDestination: sender(),
      //   customPayload: null,
      //   forwardAmount: 0,
      //   forwardPayload: emptySlice()
      // }.toCell()
    ).endCell(), 128);
    // send(SendParameters{
    //   to: msg.nftAddress,
    //   value: 0,
    //   mode: 128,
    //   body: Transfer{
    //     queryId: msg.queryId,
    //     newOwner: sender(),
    //     responseDestination: sender(),
    //     customPayload: null,
    //     forwardAmount: 0,
    //     forwardPayload: emptySlice()
    //   }.toCell()
    // });
    self.owner = null;
    self.nft_address = null;
  }

  get fun time(): Int {
    return self.time - now();
  }

  get fun nft(): Address? {
    return self.nft_address;
  }

  get fun owner(): Address? {
    return self.owner;
  }
}
