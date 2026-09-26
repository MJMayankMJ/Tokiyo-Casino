//
//  TDPMPCTransport.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  MultipeerConnectivity transport. Deliberately a sibling of Poker's
//  `MPCTransport` rather than a refactor of it: the poker transport is
//  shipping, and generalising it would mean touching `PokerHostService`
//  and `PokerClientService` for no gameplay benefit. If a third game
//  arrives, fold both into one generic transport then.
//
//  This must remain the ONLY file in Teen Do Paanch that imports
//  MultipeerConnectivity.
//

import Foundation
import MultipeerConnectivity

enum TDPPeerEvent {
    case foundPeer(peerId: String, info: [String: String])
    case lostPeer(peerId: String)
    case receivedInvitation(peerId: String, context: Data?)
    case peerConnected(peerId: String)
    case peerDisconnected(peerId: String)
    case transportError(Error)
}

final class TDPMPCTransport: NSObject {

    let localPeerId: String
    var onPeerEvent: ((TDPPeerEvent) -> Void)?
    var onMessage: ((Data, String) -> Void)?

    private let localPeer: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    private var foundPeers: [String: MCPeerID] = [:]
    private var connectedPeers: [String: MCPeerID] = [:]
    private var pendingInvitations: [String: (Bool, MCSession?) -> Void] = [:]

    private let workQueue = DispatchQueue(label: "tokiyo.tdp.mpc")

    init(displayName: String) {
        let name = TDPMPCTransport.sanitize(displayName)
        self.localPeerId = name
        self.localPeer = MCPeerID(displayName: name)
        self.session = MCSession(peer: localPeer,
                                 securityIdentity: nil,
                                 encryptionPreference: .required)
        super.init()
        session.delegate = self
    }

    /// MPC display names must be 1…63 UTF-8 bytes.
    private static func sanitize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var name = trimmed.isEmpty ? "Player" : trimmed
        while name.utf8.count > 63 { name.removeLast() }
        return name
    }

    var connectedPeerIds: [String] { Array(connectedPeers.keys) }

    // MARK: Host

    func startAdvertising(advert: TDPLobbyAdvert) {
        stopAdvertising()
        let ad = MCNearbyServiceAdvertiser(peer: localPeer,
                                           discoveryInfo: advert.discoveryInfo,
                                           serviceType: TDPProtocol.mpcServiceType)
        ad.delegate = self
        advertiser = ad
        ad.startAdvertisingPeer()
    }

    /// MPC cannot update `discoveryInfo` in place — restart the advertiser.
    func updateAdvert(_ advert: TDPLobbyAdvert) { startAdvertising(advert: advert) }

    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser?.delegate = nil
        advertiser = nil
    }

    func accept(peerId: String) {
        guard let handler = pendingInvitations.removeValue(forKey: peerId) else { return }
        handler(true, session)
    }

    func reject(peerId: String) {
        guard let handler = pendingInvitations.removeValue(forKey: peerId) else { return }
        handler(false, nil)
    }

    // MARK: Guest

    func startBrowsing() {
        stopBrowsing()
        let br = MCNearbyServiceBrowser(peer: localPeer, serviceType: TDPProtocol.mpcServiceType)
        br.delegate = self
        browser = br
        br.startBrowsingForPeers()
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser?.delegate = nil
        browser = nil
    }

    func invite(peerId: String, context: Data?) {
        guard let peer = foundPeers[peerId] else { return }
        browser?.invitePeer(peer, to: session, withContext: context, timeout: 20)
    }

    // MARK: Send

    func send(_ data: Data, to peerIds: [String]) {
        let peers = peerIds.compactMap { connectedPeers[$0] }
        guard !peers.isEmpty else { return }
        try? session.send(data, toPeers: peers, with: .reliable)
    }

    func broadcast(_ data: Data) {
        let peers = Array(connectedPeers.values)
        guard !peers.isEmpty else { return }
        try? session.send(data, toPeers: peers, with: .reliable)
    }

    func disconnect() {
        stopAdvertising()
        stopBrowsing()
        session.disconnect()
        foundPeers.removeAll()
        connectedPeers.removeAll()
        pendingInvitations.removeAll()
    }

    // MARK: Delivery

    private func deliver(_ event: TDPPeerEvent) {
        DispatchQueue.main.async { [weak self] in self?.onPeerEvent?(event) }
    }
}

// MARK: - MCSessionDelegate

extension TDPMPCTransport: MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        workQueue.async { [weak self] in
            guard let self else { return }
            let id = peerID.displayName
            switch state {
            case .connected:
                self.connectedPeers[id] = peerID
                self.deliver(.peerConnected(peerId: id))
            case .notConnected:
                self.connectedPeers.removeValue(forKey: id)
                self.deliver(.peerDisconnected(peerId: id))
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let id = peerID.displayName
        DispatchQueue.main.async { [weak self] in self?.onMessage?(data, id) }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) {}
}

// MARK: - Advertiser

extension TDPMPCTransport: MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        workQueue.async { [weak self] in
            guard let self else { return invitationHandler(false, nil) }
            let id = peerID.displayName
            self.pendingInvitations[id] = invitationHandler
            self.deliver(.receivedInvitation(peerId: id, context: context))
        }
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: any Error) {
        deliver(.transportError(error))
    }
}

// MARK: - Browser

extension TDPMPCTransport: MCNearbyServiceBrowserDelegate {

    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        workQueue.async { [weak self] in
            guard let self else { return }
            let id = peerID.displayName
            self.foundPeers[id] = peerID
            self.deliver(.foundPeer(peerId: id, info: info ?? [:]))
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
