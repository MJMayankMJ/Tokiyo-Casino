# Offline Friends Poker PRD

Last updated: 2026-05-14

## 1. Product Requirements

### Goal

Add an offline "Play With Friends" poker mode where nearby iPhone users can play together without internet or a router, with AI filling empty seats. The architecture must not lock the game to iOS-only forever; future Android apps must be able to join and eventually host using the same protocol concepts.

### V1 scope

V1 is iOS-to-iOS nearby multiplayer using Apple Multipeer Connectivity.

V1 must support:
- Create a nearby table.
- Discover nearby iPhone-hosted tables.
- Join lobby.
- Seat multiple human players.
- Fill empty seats with AI.
- Host-authoritative poker gameplay.
- Private hole cards per player.
- Reconnect or AI takeover after disconnect.
- Existing solo poker remains functional.

V1 does not support:
- Android clients.
- Android hosting.
- Internet multiplayer.
- Trustless anti-cheat/deck verification.
- Raw UDP broadcast/multicast discovery.

### Future cross-platform requirement

All gameplay messages and table snapshots must be platform-neutral and documented so a future Android app can implement the same protocol.

Future Android support will require one of these transport paths:
- Same Wi-Fi/hotspot: mDNS/Bonjour-compatible discovery plus TCP/WebSocket, or Google Nearby Connections when both platforms are on the same Wi-Fi and network conditions allow mDNS.
- Android-to-Android nearby: Google Nearby Connections.
- True no-router iOS <-> Android: not guaranteed by native OS APIs today. Treat as a future research item or use a third-party mesh SDK if this becomes a hard requirement.

Future Android hosting will require either:
- Porting the host-authoritative game engine to Android/Kotlin, or
- Extracting the poker rules into a shared engine.

Do not promise seamless Android hosting until one of those is built.

## 2. User Experience

### Entry point

Add a multiplayer option in the poker menu:
- "Play Solo"
- "Play With Friends"

When "Play With Friends" is selected:
- Show "Create Table" and "Join Nearby Table".

### Create table flow

Host:
1. Taps "Create Table".
2. Enters lobby.
3. App starts MPC advertising.
4. Host configures:
   - Buy-in / starting chips.
   - Number of seats.
   - Blinds.
   - AI fill enabled/disabled.
5. Host sees joined players in seats.
6. Host can start when at least 2 total active seats exist, counting AI if enabled.

### Join table flow

Guest:
1. Taps "Join Nearby Table".
2. App requests local network permission if needed.
3. App scans nearby MPC tables.
4. Guest selects table.
5. Host accepts guest.
6. Guest enters lobby seat.

### In-game flow

- All devices render the same table state.
- Only the local player sees their own hole cards face-up.
- Other players' hole cards remain hidden until showdown.
- Only the current player gets enabled action controls.
- Host validates every action.
- Clients send action intents, never final state mutations.
- Host broadcasts state snapshots after each accepted action.

### AI behavior

- AI runs only on the host.
- AI seats appear as normal players to all clients.
- If a human disconnects and times out, host replaces that seat with AI.

## 3. Technical Architecture

### Transport abstraction

Create a transport boundary that hides MPC from gameplay:

```swift
protocol MultiplayerTransport {
    var localPeerId: String { get }
    var onPeerEvent: ((PeerEvent) -> Void)? { get set }
    var onMessage: ((TransportMessage, String) -> Void)? { get set }

    func startAdvertising(tableInfo: LobbyAdvertisement) throws
    func stopAdvertising()
    func startBrowsing() throws
    func stopBrowsing()
    func invite(peerId: String) throws
    func accept(peerId: String) throws
    func reject(peerId: String)
    func send(_ message: TransportMessage, to peerIds: [String]) throws
    func disconnect()
}
```

V1 implementation:
- `MPCTransport`
- Uses `MCSession`, `MCNearbyServiceAdvertiser`, and `MCNearbyServiceBrowser`.
- Uses a short service type such as `tokiyo-poker`.
- Uses reliable send for poker messages because bandwidth is tiny and turn order must be exact.

Future implementations:
- `LANWebSocketTransport`
- `GoogleNearbyTransport`
- `LoopbackTransport`

### Host-authoritative game service

Add a multiplayer coordinator around `GameManager`:

- `PokerHostService`
  - Owns `GameManager`.
  - Maps peers to player seats.
  - Receives `PlayerActionIntent`.
  - Validates turn ownership.
  - Calls `GameManager.processPlayerAction`.
  - Sends `TableSnapshot` and private messages.

- `PokerClientService`
  - Owns no game rules.
  - Applies `TableSnapshot` to UI state.
  - Sends local action intents.
  - Receives private hole cards.

Existing local `GameViewController` should not directly depend on transport. Add a table-state renderer layer that can render either:
- Local `GameManager` state for solo.
- Network `TableSnapshot` state for multiplayer.

### Privacy and permissions

For MPC v1, update `Info.plist`:
- `NSLocalNetworkUsageDescription`: explain nearby poker table discovery.
- `NSBonjourServices`: include `_tokiyo-poker._tcp`.

Do not request Bluetooth permission directly for MPC unless implementation testing proves it is needed by the selected API path.

Do not request multicast entitlement for v1.

## 4. Protocol Specification

### Encoding

- Use `Codable` JSON for v1.
- UTF-8 encoded bytes.
- Assert every message is less than 16 KB.
- Reject messages over 32 KB.

### Envelope

```json
{
  "protocolVersion": 1,
  "sessionId": "UUID",
  "tableId": "UUID",
  "handNumber": 12,
  "sequence": 184,
  "senderPeerId": "peer-abc",
  "type": "tableSnapshot",
  "payload": {}
}
```

Rules:
- `sessionId` is created when a table is created.
- `tableId` identifies the lobby/table.
- `handNumber` increments and never decreases during a session.
- `sequence` is `UInt64`, host-assigned for authoritative game messages, and never resets during a session.
- Clients ignore stale authoritative messages with lower sequence numbers.

### Message types

Lobby:
- `joinRequest`
- `joinAccepted`
- `joinRejected`
- `peerLeft`
- `seatUpdate`
- `readyChanged`
- `lobbySettingsChanged`
- `startGame`

Game:
- `tableSnapshot`
- `privateCards`
- `actionRequest`
- `playerActionIntent`
- `actionAccepted`
- `actionRejected`
- `roundResult`
- `sessionResult`

Connection:
- `ping`
- `pong`
- `pause`
- `resume`
- `reconnectRequest`
- `reconnectAccepted`
- `hostEndingTable`

### Table snapshot

Snapshot must include only public information:
- Table/session ids.
- Hand number.
- Phase.
- Dealer seat.
- Current player seat.
- Blinds.
- Current bet.
- Pot.
- Community cards.
- Public player state:
  - Seat id.
  - Display name.
  - Chip count.
  - Current bet.
  - Folded/all-in/active flags.
  - Last action.
  - Dealer flag.
  - Whether cards exist, not their values unless revealed.
- Round result state when applicable.

Snapshot must not include unrevealed opponent hole-card values.

### Private cards

Send hole cards only to the peer that owns that seat.

At showdown, host may include revealed cards in public snapshot only for players whose cards should be visible according to game state.

### Action intent

Client sends:
- `seatId`
- `action`
- `raiseAmount` when applicable
- `clientKnownSequence`

Host rejects if:
- Not that player's turn.
- Seat does not match peer.
- Action is not valid.
- Amount is invalid.
- Hand/sequence is stale.

## 5. Disconnect And Reconnect

### Guest disconnect

1. Host marks seat as disconnected and pauses action if it is that player's turn.
2. Show "Waiting for Priya to reconnect..." on all devices.
3. Wait 30 seconds.
4. If peer reconnects with valid reconnect token, restore seat.
5. If timeout expires, replace seat with AI.

Rules:
- Do not reveal disconnected player's hole cards during reconnect wait.
- If disconnected player is all-in, no pause is needed; continue hand.
- If host replaces with AI, AI acts from that point forward.

### Host disconnect

V1 does not support host migration.

If host disconnects:
- Guests show "Host disconnected. Table ended."
- Guests return to multiplayer menu.
- No chip settlement occurs for guests from an untrusted incomplete session.

Future host migration is out of scope.

## 6. Security And Trust

V1 is friends-mode trusted play.

Known limitation:
- Host device owns deck and all private cards in memory.
- A malicious host could cheat.

V1 mitigations:
- Pairing/acceptance flow so strangers cannot silently join.
- Host validates actions.
- Private cards are not broadcast.
- Protocol rejects stale or invalid actions.

Future anti-cheat:
- Commit/reveal deck seed.
- Shared shuffle verification.
- Cross-device deterministic audit log.

## 7. Acceptance Criteria

Functional:
- Two iPhones can create, discover, join, and start a poker table without internet.
- Host can fill empty seats with AI.
- Guest sees only their own hole cards.
- Host validates guest actions and rejects invalid/out-of-turn actions.
- All devices converge to identical public table state after every action.
- Round result UI appears consistently on all devices.
- Session end works without corrupting coin settlement.

Transport:
- MPC advertising and browsing works on physical devices.
- Local network permission denial shows a friendly recovery message.
- Messages larger than 32 KB are rejected.
- Regular snapshots encode below 16 KB in tests.

Reliability:
- Guest disconnect pauses at most 30 seconds if action is needed.
- Guest reconnect restores the same seat.
- Timeout replaces guest with AI.
- Host disconnect ends the table cleanly for guests.

Regression:
- Solo poker still works.
- Existing AI-only/local flow still works.
- Existing poker UI remains visually unchanged except multiplayer lobby/status additions.

## 8. Implementation Phases

### Phase 1: Protocol and models

- Add transport-neutral message envelope and payload models.
- Add `TableSnapshot`, `PublicPlayerState`, `PrivateCardsPayload`, `PlayerActionIntent`.
- Add JSON encode/decode tests and golden fixtures for future Android.

### Phase 2: iOS MPC transport

- Add `MPCTransport`.
- Add Info.plist local network and Bonjour entries.
- Build create/join discovery test screen or debug lobby.
- Verify on two real devices.

### Phase 3: Host/client services

- Add `PokerHostService`.
- Add `PokerClientService`.
- Map peer IDs to seats.
- Send snapshots after actions and streets.
- Send private hole cards per peer.

### Phase 4: Multiplayer lobby UI

- Add Play With Friends entry.
- Add create/join lobby.
- Add seat list, AI fill, buy-in/blinds, ready/start controls.

### Phase 5: Multiplayer table integration

- Render network snapshots in the existing poker table UI.
- Enable actions only for local player's turn.
- Add connection status and pause/reconnect UI.

### Phase 6: Reliability and QA

- Test multi-device sessions.
- Test permission denied.
- Test guest disconnect/reconnect.
- Test host disconnect.
- Test snapshot size.
- Test golden JSON fixtures.

## 9. Open Decisions Before Build

These are product decisions, not technical blockers:
- Maximum human players in v1: recommend 6, matching current menu/player count behavior.
- Default buy-in/blinds for multiplayer: recommend reuse current poker menu defaults.
- Whether guests pay coins/buy-in in v1: recommend no real coin settlement for guests until identity/accounts exist across devices.
- Host coin settlement: recommend keep solo/local settlement only for v1 multiplayer, or use table-local chips with no global coin impact.

