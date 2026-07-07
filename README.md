# NovaCoin Exchange

A working buy/sell crypto app built on a real smart contract:

- **NovaCoin.sol** — a standard ERC-20 token (NOVA)
- **NovaExchange.sol** — a bonding-curve exchange: price rises as people buy,
  falls as they sell, entirely on-chain
- **frontend/index.html** — a single-page app to connect a wallet, see the
  live price, and buy/sell NOVA

No real money is involved if you deploy to a testnet (recommended below) — you
get a fully functional, live, on-chain trading app for free.

---

## 1. Deploy the contracts (using Remix — no install needed)

1. Go to https://remix.ethereum.org
2. Create two files and paste in the contents of `contracts/NovaCoin.sol`
   and `contracts/NovaExchange.sol`.
3. In the **Solidity Compiler** tab, compile both files (compiler version
   `0.8.20` or higher). Remix will auto-fetch the OpenZeppelin imports.
4. Get free Sepolia testnet ETH from a faucet, e.g.
   https://sepoliafaucet.com (you'll need a small amount to deploy and to
   seed the exchange's ETH reserve).
5. In the **Deploy & Run Transactions** tab:
   - Set environment to **Injected Provider - MetaMask**, and make sure
     MetaMask is on the **Sepolia** network.
   - Deploy `NovaCoin` with a constructor argument, e.g. `1000000`
     (this mints 1,000,000 NOVA to you).
   - Deploy `NovaExchange`, passing the NovaCoin contract address as the
     constructor argument.
6. **Fund the exchange:**
   - Call `transfer` on NovaCoin: send e.g. `500000000000000000000000`
     (500,000 NOVA, 18 decimals) to the NovaExchange address. This is the
     token reserve it will sell from.
   - Send some ETH directly to the NovaExchange address (e.g. from
     MetaMask) so it has ETH on hand to pay people who sell back. Its
     `receive()` function accepts plain transfers.
7. Copy both deployed contract addresses — you'll need them next.

## 2. Configure the frontend

Open `frontend/index.html` and edit the `CONFIG` block near the top of the
`<script>` section:

```js
const CONFIG = {
  TOKEN_ADDRESS: "0xYOUR_NOVACOIN_ADDRESS",
  EXCHANGE_ADDRESS: "0xYOUR_NOVAEXCHANGE_ADDRESS",
  CHAIN_ID: 11155111 // Sepolia
};
```

## 3. Run it

Just open `https://ayushxhyphen.github.io/NovaCoin-Exchange/` in a browser that has the MetaMask
extension installed (double-clicking the file works, or serve it with any
static file server). Click **Connect Wallet**, make sure MetaMask is on
Sepolia, and you can buy and sell NOVA immediately — the price updates
live from the contract.

---

## How the pricing works

The exchange uses a **linear bonding curve**:

```
price(tokensSold) = BASE_PRICE + SLOPE * tokensSold
```

- `BASE_PRICE = 0.0001 ETH` — the starting price of the first token
- `SLOPE = 0.00000001 ETH` — how much the price rises per token sold

Buying moves the curve forward (price goes up); selling moves it back
(price goes down). All trades are priced by integrating this curve, so
larger trades naturally get a slightly worse average price than smaller
ones — just like a real market.

You can tune `BASE_PRICE` and `SLOPE` in `NovaExchange.sol` before
deploying if you want a steeper or flatter curve.

## Notes / next steps

- This is a **testnet demo app** — do not deploy to mainnet with real ETH
  without a professional security audit of the contracts first.
- The exchange currently has no owner-only controls beyond deployment;
  if you want fee collection, pausability, or an admin panel, that's a
  natural next step.
- Want a mobile-friendly version, dark/light theme toggle, or a price
  chart over time? Happy to add any of these next.
