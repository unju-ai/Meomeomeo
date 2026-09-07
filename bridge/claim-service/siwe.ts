/**
 * SIWE-shaped (EIP-4361) challenge + verify stub.
 *
 * Production must:
 *   - Serve this host over HTTPS
 *   - Bind SIWE_DOMAIN / SIWE_URI to the real site players see
 *   - Persist nonces + verified wallets (this Map is process-local)
 *   - Never store MEO404_MINTER_PRIVATE_KEY in Roblox
 *
 * Stretch: nonces expire after 10 minutes and are one-time after a successful verify.
 */

import { randomBytes } from "node:crypto";
import { recoverMessageAddress, type Hex } from "viem";

const TTL_MS = 10 * 60 * 1000;

export type SiweChallengeRequest = {
  robloxUserId: number;
  address: string;
};

export type SiweChallengeResult = {
  nonce: string;
  message: string;
  expiresAt: number;
  domain: string;
  uri: string;
};

export type SiweVerifyRequest = {
  message: string;
  signature: string;
};

export type SiweVerifyResult = {
  ok: true;
  address: `0x${string}`;
};

type NonceRow = {
  expiresAtMs: number;
  used: boolean;
  userId: number;
  address: string;
};

const nonces = new Map<string, NonceRow>();
const verifiedWallets = new Set<string>();

function envDomain(): string {
  return process.env.SIWE_DOMAIN || "meo404.local";
}

function envUri(): string {
  return process.env.SIWE_URI || "https://meo404.local/siwe";
}

function envChainId(): number {
  const raw = Number(process.env.SIWE_CHAIN_ID || "1");
  return Number.isFinite(raw) && raw > 0 ? raw : 1;
}

function prune() {
  const now = Date.now();
  for (const [nonce, row] of nonces) {
    if (row.used || row.expiresAtMs <= now) {
      nonces.delete(nonce);
    }
  }
}

function isWallet(value: string): value is `0x${string}` {
  return /^0x[0-9a-fA-F]{40}$/.test(value) && !/^0x0{40}$/i.test(value);
}

function normalizeWallet(value: string): `0x${string}` {
  return `0x${value.slice(2).toLowerCase()}` as `0x${string}`;
}

function field(message: string, label: string): string | undefined {
  const match = message.match(new RegExp(`^${label}:\\s*(.+)$`, "m"));
  return match?.[1]?.trim();
}

function parseSiwe(message: string): {
  domain: string;
  address: `0x${string}`;
  uri: string;
  nonce: string;
  expirationTime?: string;
} {
  const lines = message.split(/\r?\n/);
  const header = lines[0] || "";
  const domainMatch = header.match(/^(.+) wants you to sign in with your Ethereum account:$/);
  if (!domainMatch) {
    throw new Error("invalid SIWE header");
  }
  const addressLine = (lines[1] || "").trim();
  if (!isWallet(addressLine)) {
    throw new Error("invalid SIWE address");
  }
  const nonce = field(message, "Nonce");
  const uri = field(message, "URI");
  if (!nonce || !uri) {
    throw new Error("SIWE message missing nonce or URI");
  }
  return {
    domain: domainMatch[1],
    address: normalizeWallet(addressLine),
    uri,
    nonce,
    expirationTime: field(message, "Expiration Time"),
  };
}

export function buildSiweMessage(input: {
  domain: string;
  address: string;
  statement: string;
  uri: string;
  chainId: number;
  nonce: string;
  issuedAt: string;
  expirationTime: string;
}): string {
  return [
    `${input.domain} wants you to sign in with your Ethereum account:`,
    input.address,
    "",
    input.statement,
    "",
    `URI: ${input.uri}`,
    "Version: 1",
    `Chain ID: ${input.chainId}`,
    `Nonce: ${input.nonce}`,
    `Issued At: ${input.issuedAt}`,
    `Expiration Time: ${input.expirationTime}`,
  ].join("\n");
}

export function issueChallenge(body: SiweChallengeRequest): SiweChallengeResult {
  if (typeof body.robloxUserId !== "number" || !Number.isFinite(body.robloxUserId)) {
    throw new Error("robloxUserId required");
  }
  if (!isWallet(body.address)) {
    throw new Error("invalid wallet");
  }
  prune();
  const domain = envDomain();
  const uri = envUri();
  const address = normalizeWallet(body.address);
  const nonce = randomBytes(8).toString("hex");
  const issued = new Date();
  const expires = new Date(issued.getTime() + TTL_MS);
  const message = buildSiweMessage({
    domain,
    address,
    statement: `Link this wallet to Roblox user ${body.robloxUserId} for Meo 404. This is not a transaction.`,
    uri,
    chainId: envChainId(),
    nonce,
    issuedAt: issued.toISOString(),
    expirationTime: expires.toISOString(),
  });
  nonces.set(nonce, {
    expiresAtMs: expires.getTime(),
    used: false,
    userId: body.robloxUserId,
    address,
  });
  return {
    nonce,
    message,
    expiresAt: Math.floor(expires.getTime() / 1000),
    domain,
    uri,
  };
}

export function markVerified(address: string) {
  if (isWallet(address)) {
    verifiedWallets.add(normalizeWallet(address));
  }
}

export function isVerified(address: string): boolean {
  return isWallet(address) && verifiedWallets.has(normalizeWallet(address));
}

export async function verifySiwe(body: SiweVerifyRequest): Promise<SiweVerifyResult> {
  if (typeof body.message !== "string" || typeof body.signature !== "string") {
    throw new Error("message and signature required");
  }
  const parsed = parseSiwe(body.message);
  if (parsed.domain !== envDomain()) {
    throw new Error("SIWE domain does not match this host");
  }
  if (parsed.uri !== envUri()) {
    throw new Error("SIWE URI does not match this host");
  }
  if (parsed.expirationTime) {
    const exp = Date.parse(parsed.expirationTime);
    if (!Number.isNaN(exp) && exp <= Date.now()) {
      throw new Error("SIWE message expired");
    }
  }

  const row = nonces.get(parsed.nonce);
  if (!row) {
    throw new Error("unknown or expired SIWE nonce");
  }
  if (row.used) {
    throw new Error("SIWE nonce already used");
  }
  if (row.expiresAtMs <= Date.now()) {
    nonces.delete(parsed.nonce);
    throw new Error("SIWE nonce expired");
  }
  if (row.address !== parsed.address) {
    throw new Error("SIWE address does not match the challenge");
  }

  if (!/^0x[0-9a-fA-F]{130}$/.test(body.signature)) {
    throw new Error("invalid signature");
  }

  const recovered = normalizeWallet(
    await recoverMessageAddress({
      message: body.message,
      signature: body.signature as Hex,
    })
  );
  if (recovered !== parsed.address) {
    throw new Error("signature does not recover the SIWE address");
  }

  row.used = true;
  nonces.delete(parsed.nonce);
  markVerified(recovered);
  return { ok: true, address: recovered };
}

// Example HTTP wiring (not started by this repo):
// app.post("/v1/siwe/challenge", (req, res) => {
//   res.json(issueChallenge(req.body));
// });
// app.post("/v1/siwe/verify", async (req, res) => {
//   res.json(await verifySiwe(req.body));
// });
