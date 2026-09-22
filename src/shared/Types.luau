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
export type BotDifficulty = "Easy" | "Normal" | "Hard"
export type QueuePhase = "Idle" | "Queued" | "Found" | "Teleporting"
export type QueueMode = "InPlace" | "Reserved"
export type GameMode = "Hub" | "Moba" | "YarnRun" | "KoiPond" | "YarnParty" | "MemeArcade"
export type YarnRunPhase = "Idle" | "Running" | "Dead"
export type YarnRunnerId = "NyanRocket" | "Shadowpounce" | "ChairmanMeow"
export type KoiPondPhase = "Idle" | "Waiting" | "Bite" | "Reveal"
export type KoiRarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"
export type YarnPartyPhase = "Lobby" | "Intro" | "Playing" | "Recap" | "Podium"
export type YarnPartyRoundKind = "Dodge" | "Pillows"
export type ArcadePhase = "Playing" | "Settled"

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
export type StructureTier = "Outer" | "Inner" | "Core"

export type ObjectiveState = {
	id: string,
	team: TeamId,
	kind: ObjectiveKind,
	tier: StructureTier,
	lane: string,
	health: number,
	maxHealth: number,
	alive: boolean,
	vulnerable: boolean,
}

-- Match-lifetime order of structures that fell. Not a DataStore.
export type StructureFall = {
	team: TeamId,
	lane: string,
	tier: StructureTier,
	kind: ObjectiveKind,
	at: number,
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
	isBot: boolean,
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

export type PartyRole = "solo" | "leader" | "member"

export type PartyInviteCard = {
	fromUserId: number?,
	toUserId: number?,
	fromName: string?,
	toName: string?,
	expiresIn: number,
}

export type QueueStatus = {
	phase: QueuePhase,
	mode: QueueMode,
	count: number,
	needed: number,
	estimatedSeconds: number,
	waitedSeconds: number,
	maxWaitSeconds: number,
	inQueue: boolean,
	detail: string,
	party: { string },
	canCancel: boolean,
	partyRole: PartyRole?,
	partyMemberIds: { number }?,
	incomingInvite: PartyInviteCard?,
	outgoingInvite: PartyInviteCard?,
	noticeId: number?,
	notice: string?,
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
	botDifficulty: BotDifficulty?,
	players: { [string]: MatchPlayer },
	objectives: { [string]: ObjectiveState },
	structureFalls: { StructureFall }?,
	queueCount: number,
	queue: QueueStatus?,
	lobbyPlaceId: number?,
	reserved: boolean?,
}

export type MatchTeleportSeat = {
	userId: number,
	displayName: string,
	team: TeamId,
	championId: string?,
}

export type MatchTeleportData = {
	kind: string,
	matchId: string,
	lobbyPlaceId: number,
	practice: boolean,
	padWithBots: boolean,
	botDifficulty: BotDifficulty?,
	seats: { MatchTeleportSeat },
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

export type PingKind =
	"Attention"
	| "Caution"
	| "OnMyWay"
	| "Assist"
	| "EnemyMissing"
	| "AllClear"
	| "AttackHere"

export type PingPayload = {
	userId: number,
	team: TeamId,
	kind: PingKind,
	position: Vector3,
	at: number,
	text: string,
	targetName: string?,
}

export type PingRequest = {
	kind: string?,
	position: Vector3?,
	objectiveId: string?,
	targetUserId: number?,
}

export type FeedEvent = {
	kind: FeedKind,
	text: string,
	at: number,
}

export type CombatFxKind =
	"ability"
	| "aa"
	| "towerShot"
	| "structureDeath"
	| "shield"
	| "stun"
	| "heal"
	| "recall"
	| "projectile"
	| "projectileHit"

export type CombatFxEvent = {
	kind: CombatFxKind,
	origin: Vector3,
	dest: Vector3?,
	userId: number?,
	team: TeamId?,
	mode: AbilityTargeting?,
	abilityKind: AbilityKind?,
	radius: number?,
	duration: number?,
	speed: number?,
	id: number?,
	structureKind: "Tower" | "Nexus"?,
	tier: StructureTier?,
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

export type EmoteEvent = {
	userId: number,
	emoteId: string,
	at: number,
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
	-- Consumable stock cap. Nil means unique (own at most one).
	stackMax: number?,
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
	-- Packed bitset of currently visible fog cells (VisionLogic). Server-authored.
	fogBits: { number }?,
	-- Match-lifetime OR of fogBits for this viewer's team. Not DataStore.
	exploredBits: { number }?,
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

export type PersistMode = "DataStore" | "Memory"
export type CosmeticSlot = "hat" | "trail"
export type CosmeticRarity = "Common" | "Uncommon" | "Rare" | "Epic"

export type TutorialStatus = {
	done: boolean,
	persistMode: PersistMode,
}

export type ModeTileStatus = {
	id: string,
	playing: number,
}

export type HubStatus = {
	mode: GameMode,
	tiles: { ModeTileStatus },
	yarnBest: number,
	koiBest: number,
	arcadeBest: number,
}

export type CosmeticRow = {
	id: string,
	name: string,
	slot: CosmeticSlot,
	rarity: string,
	blurb: string,
	hint: string,
	owned: boolean,
	equipped: boolean,
	locked: boolean,
	cost: number,
}

export type ClosetStatus = {
	yarn: number,
	persistMode: PersistMode,
	hat: string?,
	trail: string?,
	items: { CosmeticRow },
	toast: string?,
	disclaimer: string,
}

export type CosmeticEquip = {
	id: string?,
	slot: string?,
}

export type YarnBoardPeriod = "daily" | "weekly"

export type YarnBoardEntry = {
	rank: number,
	name: string,
	score: number,
	meters: number,
	championId: string,
	isSelf: boolean?,
}

export type YarnBoard = {
	period: YarnBoardPeriod,
	dayKey: string,
	persistMode: PersistMode,
	entries: { YarnBoardEntry },
	selfRank: number?,
}

export type YarnBoards = {
	daily: YarnBoard,
	weekly: YarnBoard,
}

export type YarnBoardSubmit = {
	ok: boolean,
	improved: boolean,
	rank: number?,
	board: YarnBoard,
}

export type YarnBoardPost = {
	daily: YarnBoardSubmit,
	weekly: YarnBoardSubmit,
	boards: YarnBoards,
}

export type StallBoardEntry = {
	rank: number,
	name: string,
	score: number,
	detail: string,
	isSelf: boolean?,
}

export type StallBoard = {
	dayKey: string,
	persistMode: PersistMode,
	entries: { StallBoardEntry },
	selfRank: number?,
}

export type StallBoardPost = {
	ok: boolean,
	improved: boolean,
	rank: number?,
	board: StallBoard,
}

export type YarnRunPowers = {
	speed: boolean,
	magnet: boolean,
	shield: boolean,
	double: boolean,
}

export type YarnRunSnapshot = {
	phase: YarnRunPhase,
	championId: string,
	lane: number,
	z: number,
	y: number,
	sliding: boolean,
	jumping: boolean,
	speed: number,
	score: number,
	combo: number,
	yarn: number,
	bestScore: number,
	bestMeters: number,
	bestCombo: number,
	seed: number,
	dayKey: string,
	meters: number,
	event: string?,
	failReason: string?,
	powers: YarnRunPowers,
	ghostLane: number?,
	ghostZ: number?,
	ghostY: number?,
	ghostAlive: boolean?,
	newBest: boolean?,
	dailyRank: number?,
	weeklyRank: number?,
	podium: boolean?,
}

export type YarnRunInput = {
	lane: number?,
	jump: boolean?,
	slide: boolean?,
}

export type KoiLogRow = {
	id: string,
	name: string,
	rarity: KoiRarity,
	count: number,
}

export type KoiPondSnapshot = {
	phase: KoiPondPhase,
	score: number,
	bestCatchScore: number,
	bestCatchName: string,
	bestCatchRarity: string,
	dayKey: string,
	event: string?,
	missReason: string?,
	bar: number?,
	sweetHalf: number?,
	caught: { KoiLogRow },
	lastCatchName: string?,
	lastCatchRarity: string?,
	lastCatchScore: number,
	ticker: boolean,
	pb: number,
	dailyRank: number?,
}

export type KoiPondInput = {
	action: "cast" | "reel",
}

export type YarnPartySeat = {
	id: number,
	name: string,
	championId: string,
	isBot: boolean,
	alive: boolean,
	score: number,
	seat: number,
}

export type YarnPartySnapshot = {
	phase: YarnPartyPhase,
	roundIndex: number,
	roundKind: YarnPartyRoundKind,
	roundTitle: string,
	hint: string,
	event: string?,
	countdown: number,
	yarnX: number,
	yarnZ: number,
	safePads: { boolean },
	musicOn: boolean,
	freeze: boolean,
	seats: { YarnPartySeat },
	winnerName: string?,
	winnerId: number?,
	roundCount: number,
}

export type ArcadeTickerView = {
	id: string,
	name: string,
	ticker: string,
	price: number,
	last: number,
	change: number,
	shares: number,
	candles: { number },
	eventKind: string,
}

export type ArcadeSnapshot = {
	phase: ArcadePhase,
	round: number,
	remaining: number,
	startYarn: number,
	cash: number,
	equity: number,
	profit: number,
	bestProfit: number,
	tickers: { ArcadeTickerView },
	eventBanner: string,
	eventKind: string,
	toast: string,
	disclaimer: string,
	dayKey: string,
	dailyRank: number?,
}

export type ArcadeInput = {
	tickerId: string,
	action: "buy" | "sell",
}

export type PlayerPrefs = {
	sfxVolume: number,
	sfxMuted: boolean,
	musicVolume: number,
	musicMuted: boolean,
	muteOthersEmotes: boolean,
	hideBoardName: boolean,
	practiceDifficulty: BotDifficulty,
	persistMode: PersistMode,
}

export type MintStatus = {
	wallet: string?,
	walletVerified: boolean,
	siweBypass: boolean,
	siweMessage: string?,
	siweExpiresAt: number?,
	productId: number,
	productName: string,
	studioMock: boolean,
	persistMode: PersistMode,
	persistNote: string,
	entitlements: { Entitlement },
	disclaimer: string,
}

return {}
