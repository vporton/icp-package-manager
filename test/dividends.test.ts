import { expect } from 'chai';

class DividendSystem {
  private static readonly DIVIDEND_SCALE = 1_000_000_000n;
  private dividendPerToken = 0n;
  private lastDividendsPerToken = new Map<string, bigint>();
  private balances = new Map<string, bigint>();
  private debts = new Map<string, bigint>();
  private totalSupply = 0n;

  balanceOf(a: string): bigint {
    return this.balances.get(a) ?? 0n;
  }

  mint(a: string, amount: bigint) {
    const owed = this.dividendsOwing(a);
    if (owed > 0n) {
      this.indebt(a, owed);
    }
    this.lastDividendsPerToken.set(a, this.dividendPerToken);
    this.balances.set(a, this.balanceOf(a) + amount);
    this.totalSupply += amount;
  }

  addDividends(amount: bigint) {
    if (this.totalSupply === 0n) return;
    this.dividendPerToken += amount * DividendSystem.DIVIDEND_SCALE / this.totalSupply;
  }

  private dividendsOwing(a: string): bigint {
    const last = this.lastDividendsPerToken.get(a) ?? 0n;
    const perTokenDelta = this.dividendPerToken - last;
    return this.balanceOf(a) * perTokenDelta / DividendSystem.DIVIDEND_SCALE;
  }

  withdrawDividends(a: string): bigint {
    const amount = this.dividendsOwing(a);
    this.lastDividendsPerToken.set(a, this.dividendPerToken);
    return amount;
  }

  indebt(a: string, amount: bigint) {
    const prev = this.debts.get(a) ?? 0n;
    this.debts.set(a, prev + amount);
  }

  debtOf(a: string): bigint {
    return this.debts.get(a) ?? 0n;
  }
}

describe('dividends', () => {
  it('no dividends for newly minted', () => {
    const ds = new DividendSystem();
    ds.mint('alice', 100n);
    ds.addDividends(100n); // one per token
    ds.mint('bob', 100n); // minted after dividends
    expect(ds.withdrawDividends('bob')).to.equal(0n);
  });

  it('indebt before withdraw', () => {
    const ds = new DividendSystem();
    ds.mint('alice', 100n);
    ds.addDividends(100n); // one per token
    const amount = (ds as any).dividendsOwing('alice');
    ds.indebt('alice', amount);
    const withdrawn = ds.withdrawDividends('alice');
    expect(withdrawn).to.equal(100n);
    expect(ds.debtOf('alice')).to.equal(100n);
  });

  it('indebt after withdraw', () => {
    const ds = new DividendSystem();
    ds.mint('bob', 100n);
    ds.addDividends(100n); // one per token
    const withdrawn = ds.withdrawDividends('bob');
    ds.indebt('bob', withdrawn);
    expect(withdrawn).to.equal(100n);
    expect(ds.debtOf('bob')).to.equal(100n);
  });
});
