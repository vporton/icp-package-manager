import { useState, useEffect, useContext } from 'react';
import Button from 'react-bootstrap/Button';
import Form from 'react-bootstrap/Form';
import { Line } from 'react-chartjs-2'
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
} from 'chart.js';
import { useAuth } from '../../lib/use-auth-client';
import { Principal } from '@dfinity/principal';
import { ErrorContext } from '../../lib/ErrorContext';
import { GlobalContext } from './state';

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
);

const DECIMALS = 8;
const INITIAL_SUPPLY = 33334 * 4 * Math.pow(10, DECIMALS);
const LIMIT_TOKENS = 33333.32;
const TOTAL_SUPPLY = 33334 * 5;

const STEPS = 100;
const GRAPH_DATA = Array.from({ length: STEPS + 1 }, (_, i) => {
  const minted = LIMIT_TOKENS * 0.99 * i / STEPS;
  const icp = investedFromMinted(minted);
  return { x: icp, y: minted };
});

const baseDataset = {
  label: 'ICPACK vs ICP',
  data: GRAPH_DATA,
  borderColor: 'rgb(75, 192, 192)',
  backgroundColor: 'rgba(75, 192, 192, 0.4)',
  showLine: true,
  fill: false,
  tension: 0.1,
  pointRadius: 0,
};

const chartOptions = {
  responsive: true,
  plugins: {
    legend: { display: false },
  },
  scales: {
    x: { type: 'linear', title: { display: true, text: 'ICP' } },
    y: { title: { display: true, text: 'ICPACK' } },
    yPercent: {
      type: 'linear',
      position: 'right',
      title: { display: true, text: '% of max ICPACK' },
      grid: { drawOnChartArea: false },
      ticks: {
        callback: (value: string | number) =>
          `${(Number(value) / TOTAL_SUPPLY * 100).toFixed(1)}%`,
      },
      min: 0,
      max: LIMIT_TOKENS,
    },
  },
};

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
  const { setError } = useContext(ErrorContext)!;
  const { agent, ok, defaultAgent, principal } = useAuth();
  const glob = useContext(GlobalContext);
  const [amountICP, setAmountICP] = useState('');
  const [expected, setExpected] = useState<number | null>(null);
  const [totalMinted, setTotalMinted] = useState<number | null>(null);
  const [loading, setLoading] = useState(false);
  const [icpackBalance, setIcpackBalance] = useState<number | null>(null);
  const [withdrawing, setWithdrawing] = useState(false);

  const chartData = {
    datasets: [
      baseDataset,
      ...(totalMinted !== null
        ? [{
            label: 'Current',
            data: [{
              x: investedFromMinted(totalMinted),
              y: totalMinted,
            }],
            borderColor: 'rgb(255, 99, 132)',
            backgroundColor: 'rgb(255, 99, 132)',
            showLine: false,
            pointRadius: 5,
          }]
        : []),
    ],
  };

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
      const res = await pst.buyWithICP();
      if (res && 'Err' in res) {
        const err = (res as any).Err;
        const msg = err.GenericError?.message ?? JSON.stringify(err);
        setError(msg);
      } else {
        setAmountICP('');
      }
      loadBalance();
    } catch (err: any) {
      console.error(err);
      setError(err?.toString() || 'Failed to buy tokens');
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
        Estimated bought by you ICPACK: {expected !== null ? `${expected.toFixed(4)} (${(expected / TOTAL_SUPPLY * 100).toFixed(4)}%)` : 'N/A'}
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
      <div className="my-4">
        <Line data={chartData} options={chartOptions} />
      </div>
      <p className="mt-3">
        We don't warrant any return of investment. Invest on your own risk.
      </p>
      <p>
        Hereby our company All World Files Corp warrants that we won't mint more
        than 20% of the profit sharing token (PST) and that all our profits on
        blockchain will be routed through this PST proportionally to holdings.
        This way we preserve validity of your investment, not to be diluted by
        minting too much PST.
      </p>
      <p>
        The investment may be more profitable if you buy the token early,
        because of a discount for early investors. At later stage the price of
        ICPACK token swiftly goes up, making the investment unprofitable. Invest
        early.
      </p>
    </Form>
  );
}
