--!strict

export type TeamId = "Blue" | "Red"
export type MatchPhase = "Lobby" | "ChampionSelect" | "InProgress" | "Ended"
export type AbilitySlot = "Q" | "W" | "E" | "R"
export type AbilityKind = "damage" | "heal" | "buff" | "dash" | "shield" | "stun"
export type AbilityTargeting = "instant" | "ground" | "line" | "dash"
export type AbilityRanks = { Q: number, W: number, E: number, R: number }
export type FeedKind = "kill" | "tower" | "nexus" | "level" | "announce"
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
	shield: number,
	stunSeconds: number,
	kind: AbilityKind,
	targeting: AbilityTargeting?,
}

export type ChampionDef = {
	id: string,
	name: string,
	title: string,
	role: string,
	blurb: string,
	ticker: string?,
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
	vulnerable: boolean,
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
	xp: number,
	level: number,
	ranks: AbilityRanks,
	respawnAt: number?,
	cs: number,
	connected: boolean,
	items: { string },
	damageDealt: number,
}

export type CombatState = {
	health: number,
	maxHealth: number,
	mana: number,
	maxMana: number,
	shield: number,
	bonusDamage: number,
	abilityPower: number,
	armor: number,
	cooldowns: { [AbilitySlot]: number },
	alive: boolean,
	nextAutoAttack: number,
	attackTarget: string?,
	level: number,
	ranks: AbilityRanks,
	respawnAt: number?,
	recalling: boolean,
	recallEndsAt: number?,
	recallStartedAt: number?,
	trinketReadyAt: number,
	lensReadyAt: number,
}

export type MatchSnapshot = {
	id: string,
	phase: MatchPhase,
	practice: boolean,
	phaseEndsAt: number?,
	startedAt: number?,
	endedAt: number?,
	winner: TeamId?,
	mvpUserId: number?,
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

export type AttackKind = "player" | "minion" | "objective" | "jungle" | "ward" | "stop"

export type AttackRequest = {
	kind: AttackKind,
	userId: number?,
	minionId: string?,
	objectiveId: string?,
	jungleId: string?,
	wardId: string?,
	position: Vector3?,
}

export type PingPayload = {
	userId: number,
	team: TeamId,
	position: Vector3,
	at: number,
}

export type FeedEvent = {
	kind: FeedKind,
	text: string,
	at: number,
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

export type ItemDef = {
	id: string,
	name: string,
	blurb: string,
	cost: number,
	bonusDamage: number,
	armor: number,
	maxHealth: number,
	maxMana: number,
	walkSpeed: number,
}

export type ShopStatus = {
	gold: number,
	atFountain: boolean,
	owned: { string },
	items: { ItemDef },
}

export type ItemBonuses = {
	bonusDamage: number,
	armor: number,
	maxHealth: number,
	maxMana: number,
	walkSpeed: number,
}

export type VisionFrame = {
	players: { number },
	minions: { string },
	jungle: { string },
	wards: { string },
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
