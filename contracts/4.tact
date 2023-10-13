import "@stdlib/deploy";

/*
  TASK 4 - NFT locker contract 
  Implement smart contract that will lock NFT for a period of time to be set by the owner.
  Smart conrtact should contain logic to process following Transactions and getters: 

  Transactions: 
  * OwnershipAssigned
   - Recives nft + time (in a forwardPayload message as uint32) for which this nft will be locked + address of the sender of the nft (prevOwner).
   - If sc already hold an nft then return incoming nft back to sender
  * NftWithdrawal
   - Request to withdrawal stored nft
   - If sender not an owner (that came from OwnershipAssigned as prevOwner) address then throw "Invalid sender" 
   - If time is not passed then send tx back to sender with message "NFT is still locked" in the body 
   - If all good then send stored nft back to owner with all remaining TON balance

  Getters:
  * time
   - get how much lock time is left
  * nft
   - get address of locked nft 
  * owner
   - get owner of locked nft (that came from OwnershipAssigned as prevOwner)
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
  owner: Address;
  nft_address: Address;
  
  init(seed: Int) {
    self.seed = seed;
    self.time = 0;
    self.owner = newAddress(0, 0);
    self.nft_address = newAddress(0, 0);
  }

  receive(msg: OwnershipAssigned) {
    self.time = msg.forwardPayload.loadUint(32);
    self.owner = msg.prevOwner;
    self.nft_address = sender();
  }

  receive(msg: NftWithdrawal) {
    let sender: Address? = null;
    require(sender() == self.owner, "Invalid sender");
    if (self.time < now()) {
      self.reply("NFT is still locked".asComment());
      // send(SendParameters{
      //     to: sender(),
      //     value: 0,
      //     mode: SendRemainingValue,
      //     body: "NFT is still locked".asComment()
      // });
      return;
    }
    send(SendParameters{
      to: self.nft_address,
      value: 0,
      mode: SendRemainingBalance,
      body: Transfer{
        queryId: msg.queryId,
        newOwner: self.owner,
        responseDestination: self.owner,
        customPayload: null,
        forwardAmount: 0,
        forwardPayload: emptySlice()
      }.toCell()
    });
  }

  get fun time(): Int {
    return now() - self.time;
  }

  get fun nft(): Address? {
    return self.nft_address;
  }

  get fun owner(): Address? {
    return self.owner;
  }
}
