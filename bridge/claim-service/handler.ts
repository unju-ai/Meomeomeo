/**
 * Hosted Meo404 claim handler (stub).
 *
 * Run this on your own backend — never inside Roblox.
 * The Roblox server only POSTs an already-granted entitlement.
 * This process is the only place that may hold MEO404_MINTER_PRIVATE_KEY.
 *
 * Flow:
 *   1. Authenticate the request (shared secret from Roblox Config.Nft404.ClaimApiSecret).
 *   2. Re-verify the entitlement (DataStore / your DB / Open Cloud). Do not trust the body alone.
 *   3. Check wallet format and (ideally) that the player proved ownership (SIWE).
 *   4. Call Meo404.mintFromEntitlement(wallet, keccak256(purchaseId)) — idempotent on-chain.
 *   5. Return { txHash }. One purchaseId → one mint.
 *
 * This is NOT "take Robux and send ETH/tokens to the wallet".
 */

export type ClaimRequest = {
  robloxUserId: number;
  purchaseId: string;
  productId: number;
  nonce: string;
  wallet: string;
};

export type ClaimResult = {
  txHash: string;
};

export type ClaimContext = {
  expectedSecret: string;
  authorizationHeader: string | undefined;
  entitlementExists: (purchaseId: string, userId: number) => Promise<boolean>;
  alreadyMinted: (purchaseId: string) => Promise<boolean>;
  mint: (wallet: `0x${string}`, entitlementId: `0x${string}`) => Promise<string>;
  keccak256: (value: string) => `0x${string}`;
};

function isWallet(value: string): value is `0x${string}` {
  return /^0x[0-9a-fA-F]{40}$/.test(value) && !/^0x0{40}$/.test(value);
}

export async function handleClaim(
  body: ClaimRequest,
  ctx: ClaimContext
): Promise<ClaimResult> {
  if (ctx.authorizationHeader !== `Bearer ${ctx.expectedSecret}`) {
    throw new Error("unauthorized");
  }
  if (!isWallet(body.wallet)) {
    throw new Error("invalid wallet");
  }
  if (!(await ctx.entitlementExists(body.purchaseId, body.robloxUserId))) {
    throw new Error("entitlement not found");
  }
  if (await ctx.alreadyMinted(body.purchaseId)) {
    throw new Error("already minted");
  }

  const entitlementId = ctx.keccak256(body.purchaseId);
  const txHash = await ctx.mint(body.wallet, entitlementId);
  return { txHash };
}

// Example HTTP wiring (not started by this repo):
// app.post("/v1/meo404", async (req, res) => {
//   const result = await handleClaim(req.body, { ... });
//   res.json(result);
// });
