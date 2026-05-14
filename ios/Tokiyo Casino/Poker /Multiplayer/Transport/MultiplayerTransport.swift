//
//  MultiplayerTransport.swift
//  Tokiyo Casino — Offline Friends Poker
//
//  Transport boundary that hides the concrete networking layer (MPC for
//  v1) from gameplay code. Future implementations like
//  `LANWebSocketTransport` or `GoogleNearbyTransport` swap in here
//  without touching `PokerHostService`/`PokerClientService`.
//

import Foundation

/// Information published on the wire so browsers can render a sensible
/// lobby list before requesting to join. Kept small enough to fit in
/// MPC's `discoveryInfo` dictionary (no recursive structures).
struct PokerLobbyAdvert {
    let tableId: String
    let displayName: String
    let hostName: String
    let smallBlind: Int
    let bigBlind: Int
    let totalSeats: Int
    let humansJoined: Int
    let aiFillEnabled: Bool
    let isStarted: Bool

    /// Encoded as `[String: String]` because MPC's discoveryInfo cannot
    /// carry arbitrary types. Numerics become their string form.
    var discoveryInfo: [String: String] {
        [
            "v": "\(PokerProtocol.version)",
            "tableId": tableId,
            "name": displayName,
            "host": hostName,
            "sb": "\(smallBlind)",
            "bb": "\(bigBlind)",
            "seats": "\(totalSeats)",
            "humans": "\(humansJoined)",
            "ai": aiFillEnabled ? "1" : "0",
            "started": isStarted ? "1" : "0"
        ]
    }

    init(
        tableId: String,
        displayName: String,
        hostName: String,
        smallBlind: Int,
        bigBlind: Int,
        totalSeats: Int,
        humansJoined: Int,
        aiFillEnabled: Bool,
        isStarted: Bool
    ) {
        self.tableId = tableId
        self.displayName = displayName
        self.hostName = hostName
        self.smallBlind = smallBlind
        self.bigBlind = bigBlind
        self.totalSeats = totalSeats
        self.humansJoined = humansJoined
        self.aiFillEnabled = aiFillEnabled
        self.isStarted = isStarted
    }

    init?(discoveryInfo: [String: String], tableId: String, displayName: String) {
        // Reject anything from a different major protocol version.
        if let v = discoveryInfo["v"], Int(v) != PokerProtocol.version { return nil }
        self.tableId = discoveryInfo["tableId"] ?? tableId
        self.displayName = discoveryInfo["name"] ?? displayName
        self.hostName = discoveryInfo["host"] ?? displayName
        self.smallBlind = Int(discoveryInfo["sb"] ?? "10") ?? 10
        self.bigBlind = Int(discoveryInfo["bb"] ?? "20") ?? 20
        self.totalSeats = Int(discoveryInfo["seats"] ?? "6") ?? 6
        self.humansJoined = Int(discoveryInfo["humans"] ?? "1") ?? 1
        self.aiFillEnabled = (discoveryInfo["ai"] ?? "1") == "1"
        self.isStarted = (discoveryInfo["started"] ?? "0") == "1"
    }
}

/// Discovered peer surfaced to the lobby UI (a "row" in the join list).
struct DiscoveredTable {
    let peerId: String
    let displayName: String
    let advert: PokerLobbyAdvert
    /// Wall-clock seen-at time so the UI can prune stale entries.
    let lastSeen: Date
}

/// Peer-lifecycle event from the transport. The host uses these to
/// admit/reject joiners and track disconnects.
enum TransportPeerEvent {
    /// A new peer was found in the browser. `displayName` is whatever the
    /// peer set as its `MCPeerID`, *not* a Tokiyo player display name.
    case foundPeer(peerId: String, displayName: String, info: [String: String])
    case lostPeer(peerId: String)
    /// A peer sent an invitation acceptance request. Host should call
    /// `accept(peerId:)` or `reject(peerId:)`.
    case receivedInvitation(peerId: String, displayName: String, context: Data?)
    case peerConnecting(peerId: String, displayName: String)
    case peerConnected(peerId: String, displayName: String)
    case peerDisconnected(peerId: String, displayName: String)
    case transportError(Error)
}

/// One transport-level message (always already-encoded JSON bytes). The
/// transport itself does not interpret these.
typealias TransportMessage = Data

protocol MultiplayerTransport: AnyObject {

    /// Stable id for the local participant (peerDisplayName for MPC).
    var localPeerId: String { get }

    /// Set by the consumer to receive lifecycle events.
    var onPeerEvent: ((TransportPeerEvent) -> Void)? { get set }

    /// Set by the consumer to receive messages from peers.
    /// `(message, fromPeerId)`
    var onMessage: ((TransportMessage, String) -> Void)? { get set }

    // MARK: Host

    func startAdvertising(advert: PokerLobbyAdvert) throws
    func updateAdvert(_ advert: PokerLobbyAdvert) throws
    func stopAdvertising()
    func accept(peerId: String) throws
    func reject(peerId: String)

    // MARK: Guest

    func startBrowsing() throws
    func stopBrowsing()
    func invite(peerId: String, context: Data?) throws

    // MARK: Both

    /// Reliable, ordered send to one or more peers. v1 uses reliable
    /// because poker bandwidth is tiny and turn order is critical.
    func send(_ message: TransportMessage, to peerIds: [String]) throws
    /// Broadcast to every currently-connected peer.
    func broadcast(_ message: TransportMessage) throws
    func disconnect()
}
