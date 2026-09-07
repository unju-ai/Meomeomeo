import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";
import { issueChallenge, verifySiwe, isVerified } from "./siwe.ts";

async function main() {
  const account = privateKeyToAccount(generatePrivateKey());
  const challenge = issueChallenge({ robloxUserId: 7, address: account.address });
  if (!challenge.message.toLowerCase().includes(account.address.toLowerCase())) {
    throw new Error("challenge missing address");
  }
  const signature = await account.signMessage({ message: challenge.message });
  const result = await verifySiwe({ message: challenge.message, signature });
  if (result.address.toLowerCase() !== account.address.toLowerCase()) {
    throw new Error("recover mismatch");
  }
  if (!isVerified(account.address)) {
    throw new Error("not marked verified");
  }
  let reused = false;
  try {
    await verifySiwe({ message: challenge.message, signature });
  } catch {
    reused = true;
  }
  if (!reused) {
    throw new Error("nonce should be one-time");
  }
  console.log("siwe recover + one-time nonce ok", result.address);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
