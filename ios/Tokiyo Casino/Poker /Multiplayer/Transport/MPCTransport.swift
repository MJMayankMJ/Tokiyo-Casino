//
//  MPCTransport.swift
//  Tokiyo Casino — Offline Friends Poker
//
//  Apple MultipeerConnectivity implementation of `MultiplayerTransport`.
//  This file should be the *only* place that imports MultipeerConnectivity
//  — everything above the transport boundary must remain platform-neutral
//  so future LAN/WebSocket/Nearby implementations can drop in.
//

import Foundation
import MultipeerConnectivity

final class MPCTransport: NSObject, MultiplayerTransport {

    // MARK: Public API

    let localPeerId: String
    var onPeerEvent: ((TransportPeerEvent) -> Void)?
    var onMessage: ((TransportMessage, String) -> Void)?

    // MARK: MPC plumbing

    /// Local participant. The display name is shown verbatim on the other
    /// device when discovered; we use the user's chosen lobby name.
    private let localPeer: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    /// Peers found via the browser but not yet connected. Keyed by
    /// `MCPeerID.displayName` because the transport surface exposes
    /// peers as `String` ids.
    private var foundPeers: [String: MCPeerID] = [:]

    /// Connected peers, indexed similarly so `send(to:)` can resolve ids.
    private var connectedPeers: [String: MCPeerID] = [:]

    /// Pending invitation handlers. Host calls `accept`/`reject` to
    /// resolve. Indexed by peer display name.
    private var pendingInvitations: [String: (Bool, MCSession?) -> Void] = [:]

    /// Cached so the browser/advertiser can be (re)started with the
    /// latest values without rebuilding the session.
    private(set) var currentAdvert: PokerLobbyAdvert?

    /// Queue used for all delegate callbacks to keep state mutation
    /// single-threaded; consumers receive callbacks on main.
    private let workQueue = DispatchQueue(label: "tokiyo.poker.mpc")

    // MARK: Init

    /// `displayName` is the user-facing label that peers see. Empty/long
    /// names are rejected by Apple; we clamp to a safe range.
    init(displayName: String) {
        let trimmed = MPCTransport.sanitize(displayName: displayName)
        self.localPeerId = trimmed
        self.localPeer = MCPeerID(displayName: trimmed)
        self.session = MCSession(
            peer: localPeer,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        super.init()
        self.session.delegate = self
    }

    private static func sanitize(displayName: String) -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nonEmpty = trimmed.isEmpty ? "Player" : trimmed
        // MPC display name must be 1..63 UTF-8 bytes.
        if nonEmpty.utf8.count <= 63 { return nonEmpty }
        var truncated = nonEmpty
        while truncated.utf8.count > 63 {
            truncated.removeLast()
        }
        return truncated
    }

    // MARK: Host advertising

    func startAdvertising(advert: PokerLobbyAdvert) throws {
        stopAdvertising()
        currentAdvert = advert
        let ad = MCNearbyServiceAdvertiser(
            peer: localPeer,
            discoveryInfo: advert.discoveryInfo,
            serviceType: PokerProtocol.mpcServiceType
        )
        ad.delegate = self
        advertiser = ad
        ad.startAdvertisingPeer()
    }

    func updateAdvert(_ advert: PokerLobbyAdvert) throws {
        // MPC has no in-place discoveryInfo update — restart the advertiser.
        try startAdvertising(advert: advert)
    }

    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser?.delegate = nil
        advertiser = nil
    }

    // MARK: Host accept/reject

    func accept(peerId: String) throws {
        guard let handler = pendingInvitations.removeValue(forKey: peerId) else { return }
        handler(true, session)
    }

    func reject(peerId: String) {
        guard let handler = pendingInvitations.removeValue(forKey: peerId) else { return }
        handler(false, nil)
    }

    // MARK: Guest browsing

    func startBrowsing() throws {
        stopBrowsing()
        let br = MCNearbyServiceBrowser(peer: localPeer, serviceType: PokerProtocol.mpcServiceType)
        br.delegate = self
        browser = br
        br.startBrowsingForPeers()
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser?.delegate = nil
        browser = nil
    }

    func invite(peerId: String, context: Data?) throws {
        guard let peer = foundPeers[peerId] else { return }
        browser?.invitePeer(peer, to: session, withContext: context, timeout: 20)
    }

    // MARK: Send

    func send(_ message: TransportMessage, to peerIds: [String]) throws {
        let peers = peerIds.compactMap { connectedPeers[$0] }
        guard !peers.isEmpty else { return }
        try session.send(message, toPeers: peers, with: .reliable)
    }

    func broadcast(_ message: TransportMessage) throws {
        let peers = Array(connectedPeers.values)
        guard !peers.isEmpty else { return }
        try session.send(message, toPeers: peers, with: .reliable)
    }

    func disconnect() {
        stopAdvertising()
        stopBrowsing()
        session.disconnect()
        foundPeers.removeAll()
        connectedPeers.removeAll()
        pendingInvitations.removeAll()
    }

    // MARK: Helpers

    private func deliver(_ event: TransportPeerEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.onPeerEvent?(event)
        }
    }

    private func deliverMessage(_ data: Data, from peerId: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onMessage?(data, peerId)
        }
    }
}

// MARK: - MCSessionDelegate

extension MPCTransport: MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        workQueue.async { [weak self] in
            guard let self else { return }
            let id = peerID.displayName
            switch state {
            case .connecting:
                self.deliver(.peerConnecting(peerId: id, displayName: id))
            case .connected:
                self.connectedPeers[id] = peerID
                self.deliver(.peerConnected(peerId: id, displayName: id))
            case .notConnected:
                self.connectedPeers.removeValue(forKey: id)
                self.deliver(.peerDisconnected(peerId: id, displayName: id))
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        deliverMessage(data, from: peerID.displayName)
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Not used.
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not used.
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) {
        // Not used.
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MPCTransport: MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        workQueue.async { [weak self] in
            guard let self else {
                invitationHandler(false, nil)
                return
            }
            let id = peerID.displayName
            self.pendingInvitations[id] = invitationHandler
            self.deliver(.receivedInvitation(peerId: id, displayName: id, context: context))
        }
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: any Error) {
        deliver(.transportError(error))
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MPCTransport: MCNearbyServiceBrowserDelegate {

    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        workQueue.async { [weak self] in
            guard let self else { return }
            let id = peerID.displayName
            self.foundPeers[id] = peerID
            self.deliver(.foundPeer(peerId: id, displayName: id, info: info ?? [:]))
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        workQueue.async { [weak self] in
            guard let self else { return }
            let id = peerID.displayName
            self.foundPeers.removeValue(forKey: id)
            self.deliver(.lostPeer(peerId: id))
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: any Error) {
        deliver(.transportError(error))
    }
}
