# Meo404 claim bridge

Roblox records a **purchase entitlement**. This hosted service is what may talk to the chain.

Do not put `MEO404_MINTER_PRIVATE_KEY` in Studio, Rojo, or `Config.luau`.

See `claim-service/handler.ts` for the request shape and checks. Wire it to `Meo404.mintFromEntitlement` after Foundry deploy (`contracts/`).
