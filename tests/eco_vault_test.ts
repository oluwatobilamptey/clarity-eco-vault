import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

// [Previous tests remain unchanged...]

Clarinet.test({
  name: "Test rate limiting functionality",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    
    // Perform multiple deposits
    for (let i = 0; i < 10; i++) {
      let block = chain.mineBlock([
        Tx.contractCall('eco-vault', 'deposit', [
          types.uint(100)
        ], wallet1.address)
      ]);
      block.receipts[0].result.expectOk().expectBool(true);
    }
    
    // This deposit should fail due to rate limiting
    let block = chain.mineBlock([
      Tx.contractCall('eco-vault', 'deposit', [
        types.uint(100)
      ], wallet1.address)
    ]);
    
    block.receipts[0].result.expectErr().expectUint(108); // err-rate-limit
  },
});

Clarinet.test({
  name: "Test emergency withdrawal functionality",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // First deposit
    let deposit = chain.mineBlock([
      Tx.contractCall('eco-vault', 'deposit', [
        types.uint(1000)
      ], wallet1.address)
    ]);
    
    deposit.receipts[0].result.expectOk().expectBool(true);
    
    // Emergency withdrawal by contract owner
    let withdrawal = chain.mineBlock([
      Tx.contractCall('eco-vault', 'emergency-withdraw', [
        types.principal(wallet1.address),
        types.uint(500)
      ], deployer.address)
    ]);
    
    withdrawal.receipts[0].result.expectOk().expectBool(true);
  },
});
