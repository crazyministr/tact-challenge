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

contract Task3 with Deployable {
  owner: Address;
  aAmount: Int;
  bAmount: Int;
  jAddressA: Address;
  jAddressB: Address;
  const decimal: Int = 1000000000;

  init(admin: Address, newJAddressA: Address, newJAddressB: Address) {
    self.owner = admin;
    self.jAddressA = newJAddressA;
    self.jAddressB = newJAddressB;
    self.aAmount = 0;
    self.bAmount = 0;
    // self.decimal = 1000000000;
  }

  // fun calc_price(to: Int, from: Int): Int {
  //   if (from == 0 || to == 0) {return 0;}
  //   return to * self.decimal / from;
  // }

  // fun transferJettons(jettonWallet: Address, destination: Address, amount: Int, forwardPayload: Slice) {
  //   send(SendParameters{
  //     to: jettonWallet, value: 0, mode: SendRemainingValue,
  //     body: TokenTransfer{
  //       queryId: 0, amount: amount, destination: destination, responseDestination: myAddress(), customPayload: null, forwardTonAmount: 10000000, forwardPayload: forwardPayload  // 0.01 TON
  //     }.toCell()
  //   });
  // }

  receive(msg: TokenNotification) {
    let jettonWallet: Address = sender();
    let isjettonB: Bool = jettonWallet == self.jAddressB;
    require(isjettonB || (jettonWallet == self.jAddressA), "Invalid jetton wallet");

    if (isjettonB) {
      if (self.owner == msg.from) {
        self.bAmount = self.bAmount + msg.amount;
        return;
      }

      // let price: Int = self.calc_price(self.aAmount, self.bAmount);
      if (self.aAmount == 0 || self.bAmount == 0) {
        nativeSendMessage(
          beginCell()
            .storeInt(0x18, 6)
            .storeAddress(jettonWallet) // To
            .storeInt(1, 4 + 1 + 4 + 4 + 64 + 32 + 1 + 1) // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
            .storeRef(
              beginCell().storeUint(0xf8a7ea5, 32).storeUint(0, 64).storeCoins(msg.amount).storeAddress(msg.from).storeAddress(myAddress()).storeBool(false).storeCoins(10000000).endCell()
            )
          .endCell(),
          64
        );
        // send(SendParameters{
        //   to: jettonWallet, value: 0, mode: SendRemainingValue,
        //   body: TokenTransfer{
        //     queryId: 0, amount: msg.amount, destination: msg.from, responseDestination: myAddress(), customPayload: null, forwardTonAmount: 10000000, forwardPayload: msg.forwardPayload  // 0.01 TON
        //   }.toCell()
        // });
        return;
      }
      let needToSend: Int = (self.aAmount * self.decimal / self.bAmount) * msg.amount / self.decimal;

      if (needToSend > self.aAmount) {
        nativeSendMessage(
          beginCell()
            .storeInt(0x18, 6)
            .storeAddress(jettonWallet) // To
            .storeInt(1, 4 + 1 + 4 + 4 + 64 + 32 + 1 + 1) // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
            .storeRef(
              beginCell().storeUint(0xf8a7ea5, 32).storeUint(0, 64).storeCoins(msg.amount).storeAddress(msg.from).storeAddress(myAddress()).storeBool(false).storeCoins(10000000).endCell()
            )
            // .storeRef(TokenTransfer{
            //   queryId: 0, amount: msg.amount, destination: msg.from, responseDestination: myAddress(), customPayload: null, forwardTonAmount: 10000000, forwardPayload: msg.forwardPayload  // 0.01 TON
            // }.toCell())
          .endCell(),
          64
        );
        // send(SendParameters{
        //   to: jettonWallet, value: 0, mode: SendRemainingValue,
        //   body: TokenTransfer{
        //     queryId: 0, amount: msg.amount, destination: msg.from, responseDestination: myAddress(), customPayload: null, forwardTonAmount: 10000000, forwardPayload: msg.forwardPayload  // 0.01 TON
        //   }.toCell()
        // });
        return;
      }

      // swap
      self.bAmount = self.bAmount + msg.amount;
      self.aAmount = self.aAmount - needToSend;

      nativeSendMessage(
        beginCell()
          .storeInt(0x18, 6)
          .storeAddress(self.jAddressA) // To
          .storeInt(1, 4 + 1 + 4 + 4 + 64 + 32 + 1 + 1) // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
          .storeRef(
            beginCell().storeUint(0xf8a7ea5, 32).storeUint(0, 64).storeCoins(needToSend).storeAddress(msg.from).storeAddress(myAddress()).storeBool(false).storeCoins(10000000).endCell()
          )
          // .storeRef(TokenTransfer{
          //   queryId: 0, amount: needToSend, destination: msg.from, responseDestination: myAddress(), customPayload: null, forwardTonAmount: 10000000, forwardPayload: msg.forwardPayload  // 0.01 TON
          // }.toCell())
        .endCell(),
        64
      );
      // send(SendParameters{
      //   to: self.jAddressA, value: 0, mode: SendRemainingValue,
      //   body: TokenTransfer{
      //     queryId: 0, amount: needToSend, destination: msg.from, responseDestination: myAddress(), customPayload: null, forwardTonAmount: 10000000, forwardPayload: msg.forwardPayload  // 0.01 TON
      //   }.toCell()
      // });

      return;
    }

    if (self.owner == msg.from) {
      self.aAmount = self.aAmount + msg.amount;
      return;
    }

    // let price: Int = self.calc_price(self.bAmount, self.aAmount);
    if (self.aAmount == 0 || self.bAmount == 0) {
      nativeSendMessage(
        beginCell()
          .storeInt(0x18, 6)
          .storeAddress(jettonWallet) // To
          .storeInt(1, 4 + 1 + 4 + 4 + 64 + 32 + 1 + 1) // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
          .storeRef(
            beginCell().storeUint(0xf8a7ea5, 32).storeUint(0, 64).storeCoins(msg.amount).storeAddress(msg.from).storeAddress(myAddress()).storeBool(false).storeCoins(10000000).endCell()
          )
          // .storeRef(TokenTransfer{
          //   queryId: 0, amount: msg.amount, destination: msg.from, responseDestination: myAddress(), customPayload: null, forwardTonAmount: 10000000, forwardPayload: msg.forwardPayload  // 0.01 TON
          // }.toCell())
        .endCell(),
        64
      );
      // send(SendParameters{
      //   to: jettonWallet, value: 0, mode: SendRemainingValue,
      //   body: TokenTransfer{
      //     queryId: 0, amount: msg.amount, destination: msg.from, responseDestination: myAddress(), customPayload: null, forwardTonAmount: 10000000, forwardPayload: msg.forwardPayload  // 0.01 TON
      //   }.toCell()
      // });
      return;
    }
    let needToSend: Int = (self.bAmount * self.decimal / self.aAmount) * msg.amount / self.decimal;

    if (needToSend > self.bAmount) {
      nativeSendMessage(
        beginCell()
          .storeInt(0x18, 6)
          .storeAddress(jettonWallet) // To
          .storeInt(1, 4 + 1 + 4 + 4 + 64 + 32 + 1 + 1) // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
          .storeRef(
            beginCell().storeUint(0xf8a7ea5, 32).storeUint(0, 64).storeCoins(msg.amount).storeAddress(msg.from).storeAddress(myAddress()).storeBool(false).storeCoins(10000000).endCell()
          )
          // .storeRef(TokenTransfer{
          //   queryId: 0, amount: msg.amount, destination: msg.from, responseDestination: myAddress(), customPayload: null, forwardTonAmount: 10000000, forwardPayload: msg.forwardPayload  // 0.01 TON
          // }.toCell())
        .endCell(),
        64
      );
      // send(SendParameters{
      //   to: jettonWallet, value: 0, mode: SendRemainingValue,
      //   body: TokenTransfer{
      //     queryId: 0, amount: msg.amount, destination: msg.from, responseDestination: myAddress(), customPayload: null, forwardTonAmount: 10000000, forwardPayload: msg.forwardPayload  // 0.01 TON
      //   }.toCell()
      // });
      return;
    }
    self.aAmount = self.aAmount + msg.amount;
    self.bAmount = self.bAmount - needToSend;
    // self.transferJettons(self.jAddressB, msg.from, needToSend, msg.forwardPayload);
    nativeSendMessage(
      beginCell()
        .storeInt(0x18, 6)
        .storeAddress(self.jAddressB) // To
        .storeInt(1, 4 + 1 + 4 + 4 + 64 + 32 + 1 + 1) // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
        .storeRef(
          beginCell().storeUint(0xf8a7ea5, 32).storeUint(0, 64).storeCoins(needToSend).storeAddress(msg.from).storeAddress(myAddress()).storeBool(false).storeCoins(10000000).endCell()
        )
        // .storeRef(TokenTransfer{
        //   queryId: 0, amount: needToSend, destination: msg.from, responseDestination: myAddress(), customPayload: null, forwardTonAmount: 10000000, forwardPayload: msg.forwardPayload  // 0.01 TON
        // }.toCell())
      .endCell(),
      64
    );
    // send(SendParameters{
    //   to: self.jAddressB, value: 0, mode: SendRemainingValue,
    //   body: TokenTransfer{
    //     queryId: 0, amount: needToSend, destination: msg.from, responseDestination: myAddress(), customPayload: null, forwardTonAmount: 10000000, forwardPayload: msg.forwardPayload  // 0.01 TON
    //   }.toCell()
    // });

    /*
    let swapFrom: Int = self.aAmount;
    let swapTo: Int = self.bAmount;
    if (isjettonB) {
      swapFrom = self.bAmount;
      swapTo = self.aAmount;
    }

    let price: Int = self.calc_price(swapTo, swapFrom);
    if (price == 0) {
      // self.transferJettons(jettonWallet, msg.from, msg.amount, msg.forwardPayload);
      send(SendParameters{
        to: jettonWallet, value: 0, mode: SendRemainingValue,
        body: TokenTransfer{
          queryId: 0, amount: msg.amount, destination: msg.from, responseDestination: myAddress(), customPayload: null, forwardTonAmount: 10000000, forwardPayload: msg.forwardPayload  // 0.01 TON
        }.toCell()
      });
      return;
    }
    let needToSend: Int = price * msg.amount / self.decimal;

    if (needToSend > swapTo) {
      send(SendParameters{
        to: jettonWallet, value: 0, mode: SendRemainingValue,
        body: TokenTransfer{
          queryId: 0, amount: msg.amount, destination: msg.from, responseDestination: myAddress(), customPayload: null, forwardTonAmount: 10000000, forwardPayload: msg.forwardPayload  // 0.01 TON
        }.toCell()
      });
      // self.transferJettons(jettonWallet, msg.from, msg.amount, msg.forwardPayload);
      return;
    }

    // swap
    if (isjettonB) {
      self.bAmount = self.bAmount + msg.amount;
      self.aAmount = self.aAmount - needToSend;
      // self.transferJettons(self.jAddressA, msg.from, needToSend, msg.forwardPayload);
      send(SendParameters{
        to: self.jAddressA, value: 0, mode: SendRemainingValue,
        body: TokenTransfer{
          queryId: 0, amount: needToSend, destination: msg.from, responseDestination: myAddress(), customPayload: null, forwardTonAmount: 10000000, forwardPayload: msg.forwardPayload  // 0.01 TON
        }.toCell()
      });
      return;
    }
    self.aAmount = self.aAmount + msg.amount;
    self.bAmount = self.bAmount - needToSend;
    // self.transferJettons(self.jAddressB, msg.from, needToSend, msg.forwardPayload);
    send(SendParameters{
      to: self.jAddressB, value: 0, mode: SendRemainingValue,
      body: TokenTransfer{
        queryId: 0, amount: needToSend, destination: msg.from, responseDestination: myAddress(), customPayload: null, forwardTonAmount: 10000000, forwardPayload: msg.forwardPayload  // 0.01 TON
      }.toCell()
    });
    */
  }

  get fun price(token: Address): Int {
    if (self.aAmount == 0 || self.bAmount == 0) { return 0; }
    if (token == self.jAddressA) { return self.bAmount * self.decimal / self.aAmount; }
    return self.aAmount * self.decimal / self.bAmount;
    // if (token == self.jAddressA) {return self.calc_price(self.bAmount, self.aAmount);}
    // return self.calc_price(self.aAmount, self.bAmount);
  }

  get fun balance(token: Address): Int {
    if (token == self.jAddressA) {return self.aAmount;}
    return self.bAmount;
  }
}
