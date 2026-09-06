--!strict

export type TeamId = "Blue" | "Red"
export type MatchPhase = "Lobby" | "ChampionSelect" | "InProgress" | "Ended"
export type AbilitySlot = "Q" | "W" | "E" | "R"
export type AbilityKind = "damage" | "heal" | "buff" | "dash"
export type VoiceMode = "Team" | "Proximity"
export type VoiceAvailability = "Ready" | "PlayerIneligible" | "StudioBlocked" | "Unavailable"

export type AbilityDef = {
	slot: AbilitySlot,
	name: string,
	description: string,
	cooldown: number,
	manaCost: number,
	range: number,
	radius: number,
	damage: number,
	heal: number,
	kind: AbilityKind,
}

export type ChampionDef = {
	id: string,
	name: string,
	title: string,
	role: string,
	blurb: string,
	color: Color3,
	maxHealth: number,
	maxMana: number,
	abilities: { [AbilitySlot]: AbilityDef },
}

export type ObjectiveKind = "Tower" | "Nexus"

export type ObjectiveState = {
	id: string,
	team: TeamId,
	kind: ObjectiveKind,
	lane: string,
	health: number,
	maxHealth: number,
	alive: boolean,
}

export type MatchPlayer = {
	userId: number,
	displayName: string,
	team: TeamId,
	championId: string?,
	ready: boolean,
	kills: number,
	deaths: number,
	assists: number,
	gold: number,
	connected: boolean,
}

export type CombatState = {
	health: number,
	maxHealth: number,
	mana: number,
	maxMana: number,
	cooldowns: { [AbilitySlot]: number },
	alive: boolean,
}

export type MatchSnapshot = {
	id: string,
	phase: MatchPhase,
	practice: boolean,
	phaseEndsAt: number?,
	startedAt: number?,
	endedAt: number?,
	winner: TeamId?,
	players: { [string]: MatchPlayer },
	objectives: { [string]: ObjectiveState },
	queueCount: number,
}

export type VoiceStatus = {
	mode: VoiceMode,
	availability: VoiceAvailability,
	detail: string,
	localEnabled: boolean?,
}

export type AbilityRequest = {
	slot: AbilitySlot,
	aimPosition: Vector3,
	targetUserId: number?,
}

export type AbilityResult = {
	ok: boolean,
	error: string?,
	combat: CombatState?,
}

export type TradeResult = {
	ok: boolean,
	error: string?,
}

export type ChatResult = {
	ok: boolean,
	error: string?,
	reply: string?,
	speaker: string?,
}

export type NpcDef = {
	id: string,
	name: string,
	role: string,
	personality: string,
	team: TeamId?,
}

export type TickerState = {
	symbol: string,
	name: string,
	price: number,
	change: number,
}

export type EntitlementStatus = "Granted" | "Claimed" | "Failed"

export type Entitlement = {
	purchaseId: string,
	userId: number,
	productId: number,
	nonce: string,
	createdAt: number,
	status: EntitlementStatus,
	wallet: string?,
	txHash: string?,
	claimError: string?,
}

export type MintStatus = {
	wallet: string?,
	productId: number,
	productName: string,
	studioMock: boolean,
	entitlements: { Entitlement },
	disclaimer: string,
}

return {}
