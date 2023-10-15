import "@stdlib/deploy";

/*
  TASK 5 - NFT random swap 
  The smart contract contains a bunch of different NFTs.
  A user brings his NFT (sends it to the smart contract), with 2.1 TON (2 for admin's profit, 0.1 for gas) in attachment (as fee for swap).
  The smart contract randomly chooses some NFT from the available NFTs (including the newly incoming one) and gives it to the user in exchange for the brought NFT (but occasionally just returns user's NFT in some cases).
  Admin can deposit NFTs without swap logic. Any NFT received from the admin is considered deposited. Admin can't swap.
  Admin can withdraw all NFTs at once, and also all TONs collected from users as fees.
  Implement getter that will return NFT addresses held by the smart contract.
  Implement getter that will return the amount of admin`s profit collected.

  In details, the smart contract (later: SC) should have this logic:
  Messages
  * AdminWithdrawalProfit 
   - SC should check that sender is the admin / otherwise throw "Insufficient privelegies"
   - SC should send all collected fees to admin except 0.1 TON (use AdminFetchProfit message as body)
     In other words: after each such operation, the contract's balance should be equal to 0.1 TON (which are reserved for storage) and the rest should be sent to the admin
  * AdminWithdrawalAllNFTs
   - SC should check that incoming tx TON value is enough for NFT withdrawal. Specifically, at least: (1 + totalNftsHeld * 0.08) TONs. Otherwise throw "Insufficent funds"
   - SC should check that sender is the admin, throw "Invalid sender" otherwise
   - If all checks pass, SC should send NFTs one by one to the admin 
   - SC should be able to withdraw all NFTs by a single message from admin
  * OwnershipAssigned 
   - if prevOwner is the owner's (admin) address, then add NFT to the collection
   - if value of TON attached is less then 2.1 TON then stop execution and return NFT back,
     but only in case that TON attached is enough to process refund without losing TONs on the SC's balance
   - randomly select NFT to send from all the NFTs that smart contract has
   - send the selected NFT to the sender with all remaining balance (except for admin profit = fees collected from this and other swaps)
     In other words: the contract's balance should increase by exactly 2 TON, some incoming TONs will be consumed for gas and the remainings of the incoming TONs should be refunded to the sender
  
  Getters
  * profit
   - returns how much collected fees is available to withdraw for the admin (all fees minus 0.1 TON)
  * nfts
   - returns dict of held NFTs with NFT indexes (sequential numbers from 0, 1, 2 ... and up to 'totalNftsHeld-1') as keys and NFT address as values 
     the order of NFTs in this dictionary doesn't matter
*/

message AdminWithdrawalProfit {
  queryId: Int as uint64;
}

message AdminWithdrawalAllNFTs {
  queryId: Int as uint64;
}

message(0x1313) KeepWithdrawalAllNFTs {
  queryId: Int as uint64;
}

message AdminFetchProfit {
  queryId: Int as uint64;
}

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

contract Task5 with Deployable {
  seed: Int as uint128;
  owner: Address;
  nftCollection: map<Int as uint16, Address>;
  nftCnt: Int as uint16 = 0;
  const MinTonForStorage: Int = ton("0.1");

  init(seed: Int, owner: Address) {
    self.owner = owner;
    self.seed = seed; // needed to deploy multiple smart contracts copies from one admin address
    self.nftCollection = emptyMap();
  }

  fun send_nft(nftAddress: Address, toAddress: Address, queryId: Int, amount: Int, mode: Int) {
    send(SendParameters{
      to: nftAddress,
      bounce: true,
      value: amount,
      mode: mode,
      body: Transfer{
        queryId: queryId,
        newOwner: toAddress,
        responseDestination: toAddress,
        customPayload: null,
        forwardAmount: 0,
        forwardPayload: emptySlice()
      }.toCell()
    });
  }

  receive(msg: OwnershipAssigned) {
    let nftAddress: Address = sender();
    let prevOwner: Address = msg.prevOwner;
    if (prevOwner == self.owner) {
      self.nftCollection.set(self.nftCnt, nftAddress);
      self.nftCnt = self.nftCnt + 1;
      return;
    }
    let msgValue: Int = context().value;
    if (msgValue < ton("2.1")) {
      // if (msgValue >= ton("0.1")) {
        nativeReserve(myBalance() - context().value, 0);
        self.send_nft(nftAddress, prevOwner, msg.queryId, 0, 128);
      // } else {
      //   self.nftCollection.set(self.nftCnt, nftAddress);
      //   self.nftCnt = self.nftCnt + 1;
      // }
      return;
    }

    self.nftCollection.set(self.nftCnt, nftAddress);

    let nftId: Int = random(0, self.nftCnt);
    nftAddress = self.nftCollection.get(nftId)!!;

    if (nftId < self.nftCnt) { // if its NOT the last
      self.nftCollection.set(nftId, self.nftCollection.get(self.nftCnt)!!);
      self.nftCollection.set(self.nftCnt, null);
    }

    nativeReserve(myBalance() - context().value + ton("2"), 0);
    self.send_nft(nftAddress, prevOwner, msg.queryId, 0, 128);
  }

  receive(msg: AdminWithdrawalProfit) {
    require(sender() == self.owner, "Insufficient privelegies");
    nativeReserve(self.MinTonForStorage, 0);
    send(SendParameters{
      to: self.owner,
      // bounce: true,
      // value: myBalance() - context().value - self.MinTonForStorage,
      // mode: SendRemainingValue + SendIgnoreErrors,
      value: 0,
      mode: SendRemainingBalance,
      body: AdminFetchProfit{
        queryId: msg.queryId
      }.toCell()
    });
  }

  receive(msg: AdminWithdrawalAllNFTs) {
    let n008: Int = ton("0.08");
    let n001: Int = ton("0.01");
    let minTons: Int = ton("1") + self.nftCnt * n008;
    require(context().value >= minTons, "Insufficent funds");
    require(sender() == self.owner, "Invalid sender");
    // require(self.nftCnt < 256, "cannot");

    if (self.nftCnt > 0) {
      send(SendParameters{
        to: myAddress(),
        value: 0,
        mode: SendRemainingValue,
        body: KeepWithdrawalAllNFTs{
          queryId: msg.queryId
        }.toCell()
      });
    }
    // let it: Int = 0;
    // repeat (self.nftCnt) {
    //   let nftAddress: Address = self.nftCollection.get(it)!!;
    //   let mode: Int = 0;
    //   let amount: Int = n001;
    //   self.send_nft(nftAddress, self.owner, msg.queryId, amount, mode);
    //   it = it + 1;
    // }
    // self.nftCollection = emptyMap();
    // self.nftCnt = 0;
  }

  receive(msg: KeepWithdrawalAllNFTs) {
    let n001: Int = ton("0.01");

    repeat (min(self.nftCnt, 100)) {
      let nftAddress: Address = self.nftCollection.get(self.nftCnt - 1)!!;
      let mode: Int = 0;
      let amount: Int = n001;
      self.send_nft(nftAddress, self.owner, msg.queryId, amount, mode);
      self.nftCnt = self.nftCnt - 1;
    }
    if (self.nftCnt == 0) {
      self.nftCollection = emptyMap();
    } else {
      send(SendParameters{
        to: myAddress(),
        value: 0,
        mode: SendRemainingValue,
        body: KeepWithdrawalAllNFTs{
          queryId: msg.queryId
        }.toCell()
      });
    }
  }

  get fun profit(): Int {
    return myBalance() - self.MinTonForStorage;
  }

  get fun nfts(): map<Int as uint16, Address> {
    return self.nftCollection;
  }
}
