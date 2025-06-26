import { expect } from 'chai';

class DividendSystemWithRetry {
  private static readonly DIVIDEND_SCALE = 1_000_000_000n;
  private static readonly FEE = 2n;
  private dividendPerToken = 0n;
  private totalSupply = 0n;
  private balances = new Map<string, bigint>();
  private dividendsCheckpointPerToken = new Map<string, bigint>();
  private lock = new Map<string, { owedAmount: bigint; dividendsCheckpoint: bigint }>();
  private tmp = new Map<string, bigint>();

  balanceOf(a: string): bigint {
    return this.balances.get(a) ?? 0n;
  }

  mint(a: string, amount: bigint) {
    this.dividendsCheckpointPerToken.set(a, this.dividendPerToken);
    this.balances.set(a, this.balanceOf(a) + amount);
    this.totalSupply += amount;
  }

  addDividends(amount: bigint) {
    if (this.totalSupply === 0n) return;
    this.dividendPerToken += amount * DividendSystemWithRetry.DIVIDEND_SCALE / this.totalSupply;
  }

  private dividendsOwing(a: string): bigint {
    const last = this.dividendsCheckpointPerToken.get(a) ?? 0n;
    const perTokenDelta = this.dividendPerToken - last;
    return this.balanceOf(a) * perTokenDelta / DividendSystemWithRetry.DIVIDEND_SCALE;
  }

  putDividendsOnTmpAccount(a: string, interrupt = false): bigint {
    let lockEntry = this.lock.get(a);
    let amount: bigint;
    if (lockEntry) {
      amount = lockEntry.owedAmount;
    } else {
      amount = this.dividendsOwing(a);
      const checkpoint = this.dividendPerToken;
      lockEntry = { owedAmount: amount, dividendsCheckpoint: checkpoint };
      this.lock.set(a, lockEntry);
    }
    if (amount <= DividendSystemWithRetry.FEE) {
      this.lock.delete(a);
      return 0n;
    }
    const existing = this.tmp.get(a) ?? 0n;
    if (existing >= DividendSystemWithRetry.FEE) {
      this.dividendsCheckpointPerToken.set(a, lockEntry!.dividendsCheckpoint);
      this.lock.delete(a);
      return existing;
    }
    this.tmp.set(a, existing + (amount - DividendSystemWithRetry.FEE));
    if (interrupt) {
      return amount;
    }
    this.dividendsCheckpointPerToken.set(a, lockEntry.dividendsCheckpoint);
    this.lock.delete(a);
    return amount;
  }

  finishWithdrawDividends(a: string): bigint {
    const amount = this.tmp.get(a) ?? 0n;
    if (amount <= DividendSystemWithRetry.FEE) return 0n;
    this.tmp.set(a, 0n);
    return amount - DividendSystemWithRetry.FEE;
  }

  withdrawDividends(a: string): bigint {
    const moved = this.putDividendsOnTmpAccount(a);
    if (moved === 0n) return 0n;
    return this.finishWithdrawDividends(a);
  }
}

describe('dividends with retry', () => {
  it('handles interrupted transfer', () => {
    const ds = new DividendSystemWithRetry();
    ds.mint('alice', 10n);
    ds.addDividends(100n);
    const owed = ds.putDividendsOnTmpAccount('alice', true);
    const expectedTmp = owed - DividendSystemWithRetry.FEE;
    expect(ds.finishWithdrawDividends('alice')).to.equal(expectedTmp - DividendSystemWithRetry.FEE);
    const retry = ds.putDividendsOnTmpAccount('alice');
    expect(retry).to.equal(owed);
    const withdrawn = ds.finishWithdrawDividends('alice');
    expect(withdrawn).to.equal(expectedTmp - DividendSystemWithRetry.FEE);
  });

  it('repeated withdraw pays once', () => {
    const ds = new DividendSystemWithRetry();
    ds.mint('bob', 10n);
    ds.addDividends(100n);
    const first = ds.withdrawDividends('bob');
    const second = ds.withdrawDividends('bob');
    expect(second).to.equal(0n);
    expect(first).to.equal(100n - 2n * DividendSystemWithRetry.FEE);
  });

  it('skips transfer when owed equals fee', () => {
    const ds = new DividendSystemWithRetry();
    ds.mint('carol', 10n);
    ds.addDividends(DividendSystemWithRetry.FEE); // owed amount equals fee
    const moved = ds.putDividendsOnTmpAccount('carol');
    expect(moved).to.equal(0n);
    expect((ds as any).lock.get('carol')).to.equal(undefined);
    expect((ds as any).tmp.get('carol')).to.equal(undefined);
  });

  it('no dividends for tokens minted after declaration', () => {
    const ds = new DividendSystemWithRetry();
    ds.mint('alice', 10n);
    ds.addDividends(100n);
    ds.mint('bob', 10n);
    expect(ds.withdrawDividends('bob')).to.equal(0n);
  });
});
