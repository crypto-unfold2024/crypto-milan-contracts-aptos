import { Aptos, AptosConfig, Network, Account, InputGenerateTransactionPayloadData } from "@aptos-labs/ts-sdk";
import { assert } from "chai";


const MODULE_ADDRESS = "0x0167bbd306ac7b642caa33afba08778fb2690327ab7533f84c388b4657e99a73";
const MODULE_NAME = "cryptomilan";

describe("NFT Coupon Tests", () => {
  let aptos: Aptos;
  let admin: Account;
  let user1: Account;
  let user2: Account;

  before(async () => {
    const config = new AptosConfig({ network: Network.DEVNET });
    aptos = new Aptos(config);
    
    // Create test accounts
    admin = Account.generate();
    user1 = Account.generate();
    user2 = Account.generate();

    // Fund accounts
    await aptos.fundAccount({ accountAddress: admin.accountAddress, amount: 100_000_000 });
    await aptos.fundAccount({ accountAddress: user1.accountAddress, amount: 100_000_000 });
    await aptos.fundAccount({ accountAddress: user2.accountAddress, amount: 100_000_000 });
  });

  it("should mint and transfer NFT", async () => {
    const payload: InputGenerateTransactionPayloadData = {
      function: `${MODULE_ADDRESS}::${MODULE_NAME}::mint_token_transfer`,
      typeArguments: [],
      functionArguments: [
        "Test Token",
        "Test Description",
        "45.4642",
        "9.1900",
        "Test Sponsor",
        "ipfs://test",
        user1.accountAddress.toString(),
      ],
    };
    console.log(user1.accountAddress.toString());

    const txn = await aptos.transaction.build.simple({
      sender: admin.accountAddress,
      data: payload
    });
    const senderAuthenticator = aptos.transaction.sign({ signer: admin, transaction: txn });
    const pendingTxn = await aptos.transaction.submit.simple({
      transaction: txn,
      senderAuthenticator
    });
    await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });
    console.log("Transaction hash: ", pendingTxn.hash);

    // Verify token exists at user1
    const tokenResource = await aptos.getAccountOwnedObjects({
      accountAddress: user1.accountAddress,
    });
   console.log(tokenResource);
  });

  it("should transfer NFT between users", async () => {
    // First mint token to user1
    const mintPayload: InputGenerateTransactionPayloadData = {
      function: `${MODULE_ADDRESS}::${MODULE_NAME}::mint_token_transfer`,
      typeArguments: [],
      functionArguments: [
        "Transfer Token",
        "Transfer Description",
        "45.4642",
        "9.1900",
        "Transfer Sponsor",
        "ipfs://transfer",
        user1.accountAddress.toString(),
      ],
    };

    const mintTxn = await aptos.transaction.build.simple({
      sender: admin.accountAddress,
      data: mintPayload
    });
    const mintAuthenticator = aptos.transaction.sign({ signer: admin, transaction: mintTxn });
    await aptos.transaction.submit.simple({
      transaction: mintTxn,
      senderAuthenticator: mintAuthenticator
    });

    // Transfer to user2
    const transferPayload: InputGenerateTransactionPayloadData = {
      function: `${MODULE_ADDRESS}::${MODULE_NAME}::transfer_token`,
      typeArguments: [],
      functionArguments: [
        user1.accountAddress.toString(),
        user2.accountAddress.toString(),
        "0x1", // Object address
      ],
    };

    const transferTxn = await aptos.transaction.build.simple({
      sender: user1.accountAddress,
      data: transferPayload
    });
    const transferAuthenticator = aptos.transaction.sign({ signer: user1, transaction: transferTxn });
    const pendingTxn = await aptos.transaction.submit.simple({
      transaction: transferTxn,
      senderAuthenticator: transferAuthenticator
    });
    await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });

    // Verify token exists at user2
    const tokenResource = await aptos.getAccountResource({
      accountAddress: user2.accountAddress,
      resourceType: `${MODULE_ADDRESS}::${MODULE_NAME}::CouponToken`
    });
    assert.exists(tokenResource);
  });

  it("should redeem NFT", async () => {
    // First mint token to user1
    const mintPayload: InputGenerateTransactionPayloadData = {
      function: `${MODULE_ADDRESS}::${MODULE_NAME}::mint_token_transfer`,
      typeArguments: [],
      functionArguments: [
        "Redeem Token",
        "Redeem Description",
        "45.4642",
        "9.1900",
        "Redeem Sponsor",
        "ipfs://redeem",
        user1.accountAddress.toString(),
      ],
    };

    const mintTxn = await aptos.transaction.build.simple({
      sender: admin.accountAddress,
      data: mintPayload
    });
    const mintAuthenticator = aptos.transaction.sign({ signer: admin, transaction: mintTxn });
    await aptos.transaction.submit.simple({
      transaction: mintTxn,
      senderAuthenticator: mintAuthenticator
    });

    // Redeem token
    const redeemPayload: InputGenerateTransactionPayloadData = {
      function: `${MODULE_ADDRESS}::${MODULE_NAME}::redeem_token`,
      typeArguments: [],
      functionArguments: [
        user1.accountAddress.toString(),
        "0x2", // Object address
      ],
    };

    const redeemTxn = await aptos.transaction.build.simple({
      sender: user1.accountAddress,
      data: redeemPayload
    });
    const redeemAuthenticator = aptos.transaction.sign({ signer: user1, transaction: redeemTxn });
    const pendingTxn = await aptos.transaction.submit.simple({
      transaction: redeemTxn,
      senderAuthenticator: redeemAuthenticator
    });
    await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });

    // Verify token is deleted
    try {
      await aptos.getAccountResource({
        accountAddress: user1.accountAddress,
        resourceType: `${MODULE_ADDRESS}::${MODULE_NAME}::CouponToken`
      });
      assert.fail("Token should not exist after redemption");
    } catch (e) {
      assert.include((e as Error).message, "Resource not found");
    }
  });
});


