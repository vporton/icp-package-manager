import { useState, useEffect } from 'react';
import Button from 'react-bootstrap/Button';
import Form from 'react-bootstrap/Form';
import { useAuth } from '../../lib/use-auth-client';
import { Principal } from '@dfinity/principal';

const DECIMALS = 8;
const INITIAL_SUPPLY = 33334 * 4 * Math.pow(10, DECIMALS);
const LIMIT_ICP = 33333.32;

function investedFromMinted(mintedTokensICP: number): number {
  const b = LIMIT_ICP;
  return b - Math.sqrt(b * b - 1.5 * b * mintedTokensICP);
}

function mintedForInvestment(prevInvest: number, invest: number): number {
  const b = LIMIT_ICP;
  const newTotal = prevInvest + invest;
  return (4 / 3) * (newTotal - prevInvest) -
    (2 / (3 * b)) * (newTotal * newTotal - prevInvest * prevInvest);
}

export default function Invest() {
  const { agent, ok } = useAuth();
  const [amountICP, setAmountICP] = useState('');
  const [expected, setExpected] = useState<number | null>(null);
  const [totalInvested, setTotalInvested] = useState<number | null>(null);
  const [loading, setLoading] = useState(false);

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
        setTotalInvested(investedFromMinted(mintedICP));
      }).catch(console.error);
    })();
    return () => {
      cancelled = true;
    };
  }, [agent]);

  useEffect(() => {
    if (totalInvested === null) { setExpected(null); return; }
    const val = parseFloat(amountICP);
    if (isNaN(val) || val <= 0) { setExpected(null); return; }
    const res = mintedForInvestment(totalInvested, val);
    setExpected(res);
  }, [amountICP, totalInvested]);

  const handleBuy = async () => {
    if (!agent || !ok) return;
    setLoading(true);
    try {
      const { createActor } = await import('../../declarations/pst');
      const pst = createActor(Principal.fromText(process.env.CANISTER_ID_PST!), { agent });
      await pst.buyWithICP();
      setAmountICP('');
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
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
      <Button onClick={handleBuy} disabled={!ok || loading || !amountICP}>
        {loading ? 'Buying...' : 'Buy'}
      </Button>
    </Form>
  );
}
