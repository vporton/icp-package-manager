import { expect } from 'chai';

// FIXME@P3: The below tests a mockup, not the actual canister code, making the tests mostly meaningless.

type Currency = 'ICP' | 'cycles';

class InvestmentSystem {
  private static readonly DIVIDEND_SCALE = 1_000_000_000;
  private static readonly LIMIT_TOKENS = 33333.32;
  private dividendPerTokenICP = 0;
  private dividendPerTokenCycles = 0;
  private lastDividendsPerTokenICP = new Map<string, number>();
  private lastDividendsPerTokenCycles = new Map<string, number>();
  private balances = new Map<string, number>();
  private debtsICP = new Map<string, number>();
  private debtsCycles = new Map<string, number>();
  private totalSupply = 0;

  balanceOf(a: string): number {
    return this.balances.get(a) ?? 0;
  }

  invest(a: string, icp: number): number {
    const minted = InvestmentSystem.mintedForInvestment(this.totalSupply, icp);
    this.mint(a, minted);
    return minted;
  }

  static mintedForInvestment(prevMinted: number, invest: number): number {
    const l = InvestmentSystem.LIMIT_TOKENS;
    const newMinted = l - (l - prevMinted) * Math.exp(-4 * invest / (3 * l));
    if (newMinted > l) throw new Error('investment overflow');
    return newMinted - prevMinted;
  }

  private mint(a: string, amount: number) {
    const owedICP = this.dividendsOwing(a, 'ICP');
    if (owedICP > 0) this.indebt(a, owedICP, 'ICP');
    const owedCycles = this.dividendsOwing(a, 'cycles');
    if (owedCycles > 0) this.indebt(a, owedCycles, 'cycles');
    this.lastDividendsPerTokenICP.set(a, this.dividendPerTokenICP);
    this.lastDividendsPerTokenCycles.set(a, this.dividendPerTokenCycles);
    this.balances.set(a, this.balanceOf(a) + amount);
    this.totalSupply += amount;
  }

  addDividends(amount: number, currency: Currency) {
    if (this.totalSupply === 0) return;
    const delta = amount * InvestmentSystem.DIVIDEND_SCALE / this.totalSupply;
    if (currency === 'ICP') {
      this.dividendPerTokenICP += delta;
    } else {
      this.dividendPerTokenCycles += delta;
    }
  }

  private dividendsOwing(a: string, currency: Currency): number {
    const lastMap = currency === 'ICP'
      ? this.lastDividendsPerTokenICP
      : this.lastDividendsPerTokenCycles;
    const last = lastMap.get(a) ?? 0;
    const perToken = currency === 'ICP'
      ? this.dividendPerTokenICP
      : this.dividendPerTokenCycles;
    const perTokenDelta = perToken - last;
    return this.balanceOf(a) * perTokenDelta / InvestmentSystem.DIVIDEND_SCALE;
  }

  withdrawDividends(a: string, currency: Currency): number {
    const amount = this.dividendsOwing(a, currency);
    if (amount > 0) this.indebt(a, amount, currency);
    const lastMap = currency === 'ICP'
      ? this.lastDividendsPerTokenICP
      : this.lastDividendsPerTokenCycles;
    const perToken = currency === 'ICP'
      ? this.dividendPerTokenICP
      : this.dividendPerTokenCycles;
    lastMap.set(a, perToken);
    return amount;
  }

  indebt(a: string, amount: number, currency: Currency) {
    const map = currency === 'ICP' ? this.debtsICP : this.debtsCycles;
    const prev = map.get(a) ?? 0;
    map.set(a, prev + amount);
  }

  debtOf(a: string, currency: Currency): number {
    const map = currency === 'ICP' ? this.debtsICP : this.debtsCycles;
    return map.get(a) ?? 0;
  }
}

describe('investment and dividends', () => {
  it('user invests, profit distributed and withdrawn', () => {
    const sys = new InvestmentSystem();
    sys.invest('alice', 1);
    sys.addDividends(100, 'ICP');
    sys.invest('bob', 1);
    expect(sys.withdrawDividends('bob', 'ICP')).to.be.closeTo(0, 1e-9);
    const withdrawn = sys.withdrawDividends('alice', 'ICP');
    expect(withdrawn).to.be.closeTo(100, 1e-6);
    expect(sys.debtOf('alice', 'ICP')).to.be.closeTo(100, 1e-6);
  });

  it('tracks ICP and cycles debts separately', () => {
    const sys = new InvestmentSystem();
    sys.invest('alice', 2);
    sys.addDividends(50, 'cycles');
    const withdrawnCycles = sys.withdrawDividends('alice', 'cycles');
    expect(withdrawnCycles).to.be.closeTo(50, 1e-6);
    expect(sys.debtOf('alice', 'cycles')).to.be.closeTo(50, 1e-6);
    expect(sys.debtOf('alice', 'ICP')).to.equal(0);
  });
});
