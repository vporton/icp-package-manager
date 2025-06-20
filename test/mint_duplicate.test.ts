import { expect } from 'chai';

interface TransferError {
  Duplicate?: { duplicate_of: bigint };
  GenericError?: { message: string; error_code: bigint };
}

interface TransferOk { Ok: bigint }
interface TransferErr { Err: TransferError }
type TransferResult = TransferOk | TransferErr;

class DummyLedger {
  calls = 0;
  async mint_tokens(_owner: string, _args: any): Promise<TransferResult> {
    this.calls++;
    if (this.calls === 1) {
      return { Ok: 0n };
    }
    return { Err: { Duplicate: { duplicate_of: 0n } } };
  }
}

interface MintLock {
  minted: bigint;
  invest: bigint;
  createdAtTime: bigint;
  mintedDone: boolean;
}

class BuyProcess {
  constructor(private ledger: DummyLedger) {}
  tokenToDeliver = new Map<string, MintLock>();

  async finish(user: string) {
    let lock = this.tokenToDeliver.get(user)!;
    if (!lock.mintedDone) {
      const res = await this.ledger.mint_tokens('owner', {});
      if ('Ok' in res || ('Err' in res && res.Err.Duplicate)) {
        lock = { ...lock, mintedDone: true };
        this.tokenToDeliver.set(user, lock);
      } else {
        throw new Error('mint failed');
      }
    }
  }
}

describe('finishBuyWithICP duplicate mint', () => {
  it('treats duplicate mint as success', async () => {
    const ledger = new DummyLedger();
    const buy = new BuyProcess(ledger);
    buy.tokenToDeliver.set('alice', {
      minted: 10n,
      invest: 5n,
      createdAtTime: 0n,
      mintedDone: false,
    });

    await buy.finish('alice');
    expect(buy.tokenToDeliver.get('alice')!.mintedDone).to.equal(true);

    // Simulate interrupted update
    buy.tokenToDeliver.set('alice', {
      minted: 10n,
      invest: 5n,
      createdAtTime: 0n,
      mintedDone: false,
    });

    await buy.finish('alice');
    const lock = buy.tokenToDeliver.get('alice')!;
    expect(lock.mintedDone).to.equal(true);
    expect(lock.invest).to.equal(5n);
  });
});
