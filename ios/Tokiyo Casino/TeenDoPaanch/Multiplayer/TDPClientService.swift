//
//  TDPClientService.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  Guest side. Deliberately thin: it holds no rules at all. It browses,
//  joins, renders whatever `TDPClientView` the host sends, and posts
//  intents back. Every rule decision — including whether a card is legal —
//  is made by the host.
//

import Foundation

protocol TDPClientServiceDelegate: AnyObject {
    func client(_ service: TDPClientService, didUpdateTables tables: [TDPDiscoveredTable])
    func client(_ service: TDPClientService, didJoinSeat seat: TDPSeat)
    func client(_ service: TDPClientService, didUpdateLobby snapshot: TDPLobbySnapshot)
    func client(_ service: TDPClientService, didUpdateView view: TDPClientView)
    func client(_ service: TDPClientService, didRejectIntent reason: String)
    func client(_ service: TDPClientService, didFailWith reason: String)
}

extension TDPClientServiceDelegate {
    func client(_ service: TDPClientService, didUpdateTables tables: [TDPDiscoveredTable]) {}
    func client(_ service: TDPClientService, didUpdateLobby snapshot: TDPLobbySnapshot) {}
    func client(_ service: TDPClientService, didRejectIntent reason: String) {}
}

struct TDPDiscoveredTable: Equatable {
    let peerId: String
    let advert: TDPLobbyAdvert
    let lastSeen: Date

    static func == (lhs: TDPDiscoveredTable, rhs: TDPDiscoveredTable) -> Bool {
        lhs.peerId == rhs.peerId && lhs.advert.tableId == rhs.advert.tableId
    }
}

final class TDPClientService {

    weak var delegate: TDPClientServiceDelegate?

    private(set) var seat: TDPSeat?
    private(set) var tables: [TDPDiscoveredTable] = []
    private(set) var latestView: TDPClientView?

    private let displayName: String
    private var transport: TDPTransport?
    private var hostPeerId: String?
    private var tableId: String = ""
    private var lastHostSequence: UInt64 = 0

    init(displayName: String) {
        self.displayName = displayName
    }

    // MARK: Browsing

    func startBrowsing() {
        startBrowsing(transport: TDPMPCTransport(displayName: displayName))
    }

    /// Injectable seam — see `TDPHostService.startHosting(transport:)`.
    func startBrowsing(transport: TDPTransport) {
        transport.onPeerEvent = { [weak self] event in self?.handle(event) }
        transport.onMessage = { [weak self] data, peer in self?.handle(data: data, from: peer) }
        self.transport = transport
        transport.startBrowsing()
    }

    func join(_ table: TDPDiscoveredTable) {
        hostPeerId = table.peerId
        tableId = table.advert.tableId
        lastHostSequence = 0
        transport?.invite(peerId: table.peerId, context: nil)
    }

    func leave() {
        transport?.disconnect()
        transport = nil
        hostPeerId = nil
        seat = nil
        latestView = nil
        lastHostSequence = 0
    }

    // MARK: Intents

    func send(_ intent: TDPIntent) {
        guard let transport, let host = hostPeerId else { return }
        let message = TDPMessage(tableId: tableId,
                                 senderPeerId: transport.localPeerId,
                                 type: .intent,
                                 payload: intent)
        guard let data = try? TDPWireCodec.encode(message) else { return }
        transport.send(data, to: [host])
    }

    // MARK: Incoming

    private func handle(_ event: TDPPeerEvent) {
        switch event {
        case .foundPeer(let peerId, let info):
            guard let advert = TDPLobbyAdvert(discoveryInfo: info) else { return }   // version gate
            tables.removeAll { $0.peerId == peerId }
            tables.append(TDPDiscoveredTable(peerId: peerId, advert: advert, lastSeen: Date()))
            delegate?.client(self, didUpdateTables: tables)

        case .lostPeer(let peerId):
            tables.removeAll { $0.peerId == peerId }
            delegate?.client(self, didUpdateTables: tables)

        case .peerConnected(let peerId):
            guard peerId == hostPeerId, let transport else { return }
            let message = TDPMessage(tableId: tableId,
                                     senderPeerId: transport.localPeerId,
                                     type: .joinRequest,
                                     payload: TDPJoinRequest(displayName: displayName,
                                                             clientVersion: TDPProtocol.version))
            if let data = try? TDPWireCodec.encode(message) {
                transport.send(data, to: [peerId])
            }

        case .peerDisconnected(let peerId):
            guard peerId == hostPeerId else { return }
            delegate?.client(self, didFailWith: "Lost the connection to the host.")

        case .transportError(let error):
            delegate?.client(self, didFailWith: error.localizedDescription)

        default:
            break
        }
    }

    private func handle(data: Data, from peerId: String) {
        guard peerId == hostPeerId,
              let decoded = try? TDPWireCodec.decode(data),
              decoded.header.tableId == tableId,
              decoded.header.senderPeerId == peerId else { return }
        if let sequence = decoded.header.sequence {
            guard sequence > lastHostSequence else { return }
            lastHostSequence = sequence
        }
        switch decoded.type {
        case .joinAccepted:
            guard let payload: TDPJoinAccepted = try? decoded.decode() else { return }
            seat = payload.seat
            delegate?.client(self, didJoinSeat: payload.seat)
            delegate?.client(self, didUpdateLobby: payload.lobby)

        case .joinRejected:
            guard let payload: TDPJoinRejected = try? decoded.decode() else { return }
            delegate?.client(self, didFailWith: payload.reason)

        case .lobbySnapshot:
            guard let payload: TDPLobbySnapshot = try? decoded.decode() else { return }
            delegate?.client(self, didUpdateLobby: payload)

        case .clientView:
            guard let view: TDPClientView = try? decoded.decode() else { return }
            latestView = view
            delegate?.client(self, didUpdateView: view)

        case .intentRejected:
            guard let payload: TDPIntentRejected = try? decoded.decode() else { return }
            delegate?.client(self, didRejectIntent: payload.reason)

        case .hostEndingTable:
            guard let payload: TDPHostEnding = try? decoded.decode() else { return }
            delegate?.client(self, didFailWith: payload.reason)

        default:
            break
        }
    }
}
