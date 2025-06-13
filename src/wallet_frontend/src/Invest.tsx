import { useState, useEffect, useContext } from 'react';
import Button from 'react-bootstrap/Button';
import Form from 'react-bootstrap/Form';
import { useAuth } from '../../lib/use-auth-client';
import { Principal } from '@dfinity/principal';
import { GlobalContext } from './state';

const DECIMALS = 8;
const INITIAL_SUPPLY = 33334 * 4 * Math.pow(10, DECIMALS);
const LIMIT_TOKENS = 33333.32;

function investedFromMinted(mintedTokensICP: number): number {
  const l = LIMIT_TOKENS;
  if (mintedTokensICP >= l) return Infinity;
  return 0.75 * l * Math.log(1 / (1 - mintedTokensICP / l));
}

function mintedForInvestment(prevMinted: number, invest: number): number {
  const l = LIMIT_TOKENS;
  const newMinted = l - (l - prevMinted) * Math.exp(-4 * invest / (3 * l));
  return newMinted - prevMinted;
}

export default function Invest() {
  const { agent, ok, defaultAgent, principal } = useAuth();
  const glob = useContext(GlobalContext);
  const [amountICP, setAmountICP] = useState('');
  const [expected, setExpected] = useState<number | null>(null);
  const [totalMinted, setTotalMinted] = useState<number | null>(null);
  const [loading, setLoading] = useState(false);
  const [icpackBalance, setIcpackBalance] = useState<number | null>(null);
  const [withdrawing, setWithdrawing] = useState(false);

  useEffect(() => {
    if (!agent) return;
    let cancelled = false;
    (async () => {
      const { createActor } = await import('../../declarations/pst');
      const pst = createActor(Principal.fromText(process.env.CANISTER_ID_PST!), { agent });
      pst.icrc1_total_supply().then((s: bigint) => {
        if (cancelled) return;
        const minted = Number(s.toString()) - INITIAL_SUPPLY;
        const mintedICP = minted / Math.pow(10, DECIMALS);
        setTotalMinted(mintedICP);
      }).catch(console.error);
    })();
    return () => {
      cancelled = true;
    };
  }, [agent]);

  const loadBalance = async () => {
    if (!glob.walletBackend || !principal || !defaultAgent) return;
    const { createActor } = await import('../../declarations/pst');
    const pst = createActor(Principal.fromText(process.env.CANISTER_ID_PST!), { agent: defaultAgent });
    try {
      const account = await glob.walletBackend.getUserWallet(principal);
      const bal = await pst.icrc1_balance_of(account);
      setIcpackBalance(Number(bal.toString()) / Math.pow(10, DECIMALS));
    } catch (e) {
      console.error(e);
    }
  };

  useEffect(() => { loadBalance(); }, [glob.walletBackend, principal, defaultAgent]);

  useEffect(() => {
    if (totalMinted === null) { setExpected(null); return; }
    const val = parseFloat(amountICP);
    if (isNaN(val) || val <= 0) { setExpected(null); return; }
    const res = mintedForInvestment(totalMinted, val);
    setExpected(res);
  }, [amountICP, totalMinted]);

  const handleBuy = async () => {
    if (!agent || !ok) return;
    setLoading(true);
    try {
      const { createActor } = await import('../../declarations/pst');
      const pst = createActor(Principal.fromText(process.env.CANISTER_ID_PST!), { agent });
      await pst.buyWithICP();
      setAmountICP('');
      loadBalance();
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleWithdraw = async () => {
    if (!agent || !ok || !glob.walletBackend) return;
    setWithdrawing(true);
    try {
      await glob.walletBackend.withdrawDividends();
    } catch (err) {
      console.error(err);
    } finally {
      setWithdrawing(false);
      loadBalance();
    }
  };

  return (
    <Form>
      <Form.Group className="mb-3">
        <Form.Label>ICP to invest</Form.Label>
        <Form.Control
          type="number"
          min="0"
          step="any"
          value={amountICP}
          onChange={e => setAmountICP(e.target.value)}
        />
      </Form.Group>
      <div className="mb-3">
        Estimated ICPACK: {expected !== null ? expected.toFixed(4) : 'N/A'}
      </div>
      <div className="mb-3">
        Your ICPACK balance: {icpackBalance !== null ? icpackBalance.toFixed(4) : 'N/A'}
      </div>
      <Button onClick={handleBuy} disabled={!ok || loading || !amountICP} className="me-2">
        {loading ? 'Buying...' : 'Buy'}
      </Button>
      <Button onClick={handleWithdraw} disabled={!ok || withdrawing}>
        {withdrawing ? 'Withdrawing...' : 'Withdraw Dividends'}
      </Button>
    </Form>
  );
}
