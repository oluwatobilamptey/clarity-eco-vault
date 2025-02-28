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
  name: "Test contract pause functionality",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('eco-vault', 'set-paused', [
        types.bool(true)
      ], deployer.address)
    ]);
    
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Attempt deposit while paused
    let depositBlock = chain.mineBlock([
      Tx.contractCall('eco-vault', 'deposit', [
        types.uint(500)
      ], wallet1.address)
    ]);
    
    depositBlock.receipts[0].result.expectErr().expectUint(105); // err-paused
  },
});

// [Additional tests...]
