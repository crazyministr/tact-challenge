import "@stdlib/deploy";

/*
  TASK 3 - DEX
  Create a simple jetton dex contract that trades one pair of jettons: A and B.
  The price of jettons depends on the amount of jettons that smart contract has.
  Therefore, the smart contract needs to keep track of how much jettons it has.
  
  Price for the jetton A in swap B->A should be calculated by formula "amountOfJettonAOnContract * decimal / amountOfJettonBOnContract".
  Token prices must be decimalized for accuracy, so it is the prices that must be adjusted to decimal 1e9.
  Decimals are only needed for price accuracy. It should be set as 1e9.
  So, if smart contract has 10 of jetton A and 2 of jetton B, then after sending 1 jetton B you should receive 5 of jettons A.

  Example formula for amountOfAJettonToSend in B->A swap will be
  (amountOfJettonAOnContract * decimal / amountOfJettonBOnContract) * amountOfTokenBToSwap / decimal

  If smart contract pool doesn't have enough jettons to trade,
  then it should send incoming jettons back to the user. For a clearer explanation,
  let's look at the example we described above (smart contract has 10 of jetton A and 2 of jetton B).
  If user will send 3 jettons B, smart contract should reject the message (because contract does not have 3 * 5 = 15 jettons A)
  and send 3 jettons B back to the user.

  If smart contract receives a different jetton (neither A nor B) then throw an error.

  Implement a getter that returns the number of jettons in the pool and
  one more to get the price of jetton A or jetton B.
  Getters' behavior with incorrect parameter (address other than that of jetton A or B)
  is undefined (there are no such tests).
  
  Note:
  Admin can add jettons A and B just by sending them to the smart contract (we need to add initial supply to the pool for it to be functional).
  To be exact: any jettons (A or B) received from the admin are "added". Admin can't swap.
*/

message(0x7362d09c) TokenNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    from: Address;
    forwardPayload: Slice as remaining;
}

message(0xf8a7ea5) TokenTransfer {
    queryId: Int as uint64;
    amount: Int as coins;
    destination: Address;
    responseDestination: Address?;
    customPayload: Cell?;
    forwardTonAmount: Int as coins;
    forwardPayload: Slice as remaining;
}

// message(0xd53276db) ExcessesTransfer {
//   queryId: Int as uint64;
// }

// struct ExcessesTransferDictValue {
//     amountMinus: Int as coins;
//     amountPlus: Int as coins;
// }

contract Task3 with Deployable {
  owner: Address;
  aAmount: Int;
  bAmount: Int;
  jAddressA: Address;
  jAddressB: Address;
  decimal: Int;
  // amountByQueryId: map<Int as uint64, ExcessesTransferDictValue>;

  init(admin: Address, newJAddressA: Address, newJAddressB: Address) {
    self.owner = admin;
    self.jAddressA = newJAddressA;
    self.jAddressB = newJAddressB;
    self.aAmount = 0;
    self.bAmount = 0;
    self.decimal = 1000000000;
    // self.amountByQueryId = emptyMap();
  }

  fun calc_price(to: Int, from: Int): Int {
    if (from == 0 || to == 0) {
        return 0;
    }
    return to * self.decimal / from;
  }

  fun transferJettons(jettonWallet: Address, destination: Address, amount: Int, queryId: Int, forwardTonAmount: Int, forwardPayload: Slice, responseAddress: Address?) {
    if (amount <= 0) {
      return;
    }
    send(SendParameters{
        to: jettonWallet,
        value: 0,
        mode: SendRemainingValue + SendIgnoreErrors,
        body: TokenTransfer{
          queryId: queryId,
          amount: amount,
          destination: destination,
          responseDestination: myAddress(),
          customPayload: null,
          forwardTonAmount: 10000000,
          forwardPayload: beginCell().storeUint(1, 1).endCell().beginParse()
        }.toCell()
    });
  }

  // receive(msg: ExcessesTransfer) {
  //   let jettonWallet: Address = sender();
  //   let queryId: Int = msg.queryId;
  //   let item: ExcessesTransferDictValue = self.amountByQueryId.get(queryId)!!;
  //   if (jettonWallet == self.jAddressA) {
  //     self.bAmount = self.bAmount + item.amountPlus;
  //     self.aAmount = self.aAmount - item.amountMinus;
  //   } else {
  //     self.aAmount = self.aAmount + item.amountPlus;
  //     self.bAmount = self.bAmount - item.amountMinus;
  //   }
  // }

  receive(msg: TokenNotification) {
    let jettonWallet: Address = sender();
    require((jettonWallet == self.jAddressA) || (jettonWallet == self.jAddressB), "Invalid jetton wallet");

    if (self.owner == msg.from) {
      if (jettonWallet == self.jAddressA) {
        self.aAmount = self.aAmount + msg.amount;
      } else {
        self.bAmount = self.bAmount + msg.amount;
      }
      return;
    }

    let swapFrom: Int = self.bAmount;
    let swapTo: Int = self.aAmount;
    if (jettonWallet == self.jAddressA) {
      swapFrom = self.aAmount;
      swapTo = self.bAmount;
    }

    // if (swapFrom == 0 && swapTo > 0) {
    //   // swap
    //   if (jettonWallet == self.jAddressA) {
    //     self.transferJettons(self.jAddressB, msg.from, self.bAmount, msg.queryId, 0, msg.forwardPayload, null);
    //     self.aAmount = msg.amount;
    //     self.bAmount = 0;
    //   } else {
    //     self.transferJettons(self.jAddressA, msg.from, self.aAmount, msg.queryId, 0, msg.forwardPayload, null);
    //     self.bAmount = msg.amount;
    //     self.aAmount = 0;
    //   }
    //   return;
    // }

    let price: Int = self.calc_price(swapTo, swapFrom);
    let needToSend: Int = price * msg.amount / self.decimal;

    // if (needToSend > swapTo) {
    if (needToSend > swapTo || needToSend <= 0) {
      self.transferJettons(
        jettonWallet,
        msg.from,
        msg.amount,
        msg.queryId,
        0, msg.forwardPayload, null
      );
      return;
    }

    // swap
    if (jettonWallet == self.jAddressA) {
      self.aAmount = self.aAmount + msg.amount;
      self.bAmount = self.bAmount - needToSend;
      // self.amountByQueryId.set(msg.queryId, ExcessesTransferDictValue{amountMinus: needToSend, amountPlus: msg.amount});
      self.transferJettons(self.jAddressB, msg.from, needToSend, msg.queryId, 0, msg.forwardPayload, null);
    } else {
      self.bAmount = self.bAmount + msg.amount;
      self.aAmount = self.aAmount - needToSend;
      // self.amountByQueryId.set(msg.queryId, ExcessesTransferDictValue{amountMinus: needToSend, amountPlus: msg.amount});
      self.transferJettons(self.jAddressA, msg.from, needToSend, msg.queryId, 0, msg.forwardPayload, null);
    }
  }

  get fun price(token: Address): Int {
    // if (token == self.jAddressA) {return self.calc_price(self.aAmount, self.bAmount);}
    // return self.calc_price(self.bAmount, self.aAmount);
    if (token == self.jAddressA) {return self.calc_price(self.bAmount, self.aAmount);}
    return self.calc_price(self.aAmount, self.bAmount);
  }

  get fun balance(token: Address): Int {
    if (token == self.jAddressA) {return self.aAmount;}
    return self.bAmount;
  }
}
