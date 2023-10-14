import "@stdlib/deploy";

/*
  TASK 3 - DEX
  Create a simple jetton dex contract that trades one pair of jettons: A and B.
  The price of jettons depends on the amount of jettons that smart contract has.
  Therefore, the smart contract needs to keep track of how much jettons it has.
  
  Price for the jetton A in swap B->A should be calculated by formula "amountOfJettonAOnContract * decimal / amountOfJettonBOnContract".
  Decimals are only needed for price accuracy. It should be set as 1e9.
  So, if smart contract has 10 of jetton A and 2 of jetton B, then after sending 1 jetton B you should receive 5 of jettons A.

  If smart contract pool doesn't have enough jettons to trade
  (for example someone sends 99999 jettons of B, but dex pool only has 10 of jettons A),
  then sent incoming jettons (B, in our example) back to the sender.

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

fun mydiv(a: Int, b: Int, d: Int): Int {
  if (b == 0) {
    return 0;
  }
  return a * d / (b * d);
}

fun transferJettons(jettonWallet: Address, destination: Address, amount: Int, queryId: Int) {
    send(SendParameters{
        to: jettonWallet,
        value: 0,
        mode: SendRemainingValue,
        body: TokenTransfer{
          queryId: queryId,
          amount: amount,
          destination: destination,
          responseDestination: destination,
          customPayload: null,
          forwardTonAmount: ton("0.0001"),
          forwardPayload: emptySlice()
        }.toCell()
    });
}

contract Task3 with Deployable {
  owner: Address;
  aAmount: Int;
  bAmount: Int;
  jAddressA: Address;
  jAddressB: Address;
  decimal: Int;

  init(admin: Address, newJAddressA: Address, newJAddressB: Address) {
    self.owner = admin;
    self.jAddressA = newJAddressA;
    self.jAddressB = newJAddressB;
    self.aAmount = 0;
    self.bAmount = 0;
    self.decimal = 1000000000;
  }

  receive(msg: TokenNotification) {
    let jettonWallet: Address = sender();
    if (jettonWallet != self.jAddressA && jettonWallet != self.jAddressB) {
      throw(100);
    }
    if (self.owner == msg.from) {
      if (jettonWallet == self.jAddressA) {
        self.aAmount = self.aAmount + msg.amount;
      }
      if (jettonWallet == self.jAddressB) {
        self.bAmount = self.bAmount + msg.amount;
      }
      return;
    }

    let tf: Int = self.bAmount;
    let tfAddr: Address = self.jAddressB;
    let tt: Int = self.aAmount;
    let ttAddr: Address = self.jAddressA;
    if (jettonWallet == self.jAddressA) {
      tf = self.aAmount;
      tfAddr = self.jAddressA;
      tt = self.bAmount;
      ttAddr = self.jAddressB;
    }
    let price: Int = mydiv(tt, tf, self.decimal);  // tt * self.decimal / tf
    let needToSend: Int = price * msg.amount;
    if (needToSend > tt || needToSend == 0) {
      // return tokens back
      transferJettons(
        jettonWallet,
        msg.from,
        msg.amount,
        msg.queryId
      );
      return;
    }

    // swap
    if (jettonWallet == self.jAddressA) {
      self.bAmount = self.bAmount - needToSend;
      transferJettons(self.jAddressB, msg.from, needToSend, msg.queryId);
    } else {
      self.aAmount = self.aAmount - needToSend;
      transferJettons(self.jAddressA, msg.from, needToSend, msg.queryId);
    }
  } 

  get fun price(token: Address): Int {
    if (token == self.jAddressA) {
      if (self.bAmount == 0) {
        return 0;
      }
      return mydiv(self.aAmount, self.bAmount, self.decimal);
    }
    return mydiv(self.bAmount, self.aAmount, self.decimal);
  }

  get fun balance(token: Address): Int { 
    if (token == self.jAddressA) {
      return self.aAmount;
    }
    return self.bAmount;
  }
}
