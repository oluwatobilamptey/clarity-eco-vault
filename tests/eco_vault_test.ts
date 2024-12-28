import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure users can deposit funds",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('eco-vault', 'deposit', [types.uint(500)], wallet1.address)
    ]);
    
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Verify balance
    let balanceBlock = chain.mineBlock([
      Tx.contractCall('eco-vault', 'get-vault-balance', [
        types.principal(wallet1.address)
      ], wallet1.address)
    ]);
    
    assertEquals(balanceBlock.receipts[0].result, types.uint(500));
  },
});

Clarinet.test({
  name: "Test initiative registration and verification",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      // Register initiative
      Tx.contractCall('eco-vault', 'register-initiative', [
        types.ascii("Solar Panel Project")
      ], deployer.address),
      
      // Non-owner registration should fail
      Tx.contractCall('eco-vault', 'register-initiative', [
        types.ascii("Wind Farm Project")
      ], wallet1.address)
    ]);
    
    block.receipts[0].result.expectOk().expectUint(0);
    block.receipts[1].result.expectErr().expectUint(100); // err-owner-only
    
    // Verify initiative
    let verifyBlock = chain.mineBlock([
      Tx.contractCall('eco-vault', 'verify-initiative', [
        types.uint(0)
      ], deployer.address)
    ]);
    
    verifyBlock.receipts[0].result.expectOk().expectBool(true);
  },
});

Clarinet.test({
  name: "Test initiative funding flow",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // Setup: Register and verify initiative, deposit funds
    let setup = chain.mineBlock([
      Tx.contractCall('eco-vault', 'register-initiative', [
        types.ascii("Solar Panel Project")
      ], deployer.address),
      Tx.contractCall('eco-vault', 'verify-initiative', [
        types.uint(0)
      ], deployer.address),
      Tx.contractCall('eco-vault', 'deposit', [
        types.uint(1000)
      ], wallet1.address)
    ]);
    
    // Fund initiative
    let fundBlock = chain.mineBlock([
      Tx.contractCall('eco-vault', 'fund-initiative', [
        types.uint(0),
        types.uint(500)
      ], wallet1.address)
    ]);
    
    fundBlock.receipts[0].result.expectOk().expectBool(true);
    
    // Check initiative details
    let detailsBlock = chain.mineBlock([
      Tx.contractCall('eco-vault', 'get-initiative-details', [
        types.uint(0)
      ], wallet1.address)
    ]);
    
    let details = detailsBlock.receipts[0].result.expectSome();
    assertEquals(details['total-funding'], types.uint(500));
  },
});