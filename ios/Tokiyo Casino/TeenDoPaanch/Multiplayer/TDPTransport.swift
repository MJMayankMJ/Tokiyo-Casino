//
//  TDPTransport.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  Transport boundary. Keeping this an abstraction rather than wiring
//  `TDPMPCTransport` in directly buys two things: a future LAN/WebSocket
//  implementation drops in without touching the services, and the tests
//  can run a real host↔client session over an in-memory loopback instead
//  of needing two physical devices.
//

import Foundation

protocol TDPTransport: AnyObject {

    /// Stable id for the local participant.
    var localPeerId: String { get }
    var connectedPeerIds: [String] { get }

    var onPeerEvent: ((TDPPeerEvent) -> Void)? { get set }
    var onMessage: ((Data, String) -> Void)? { get set }

    // Host
    func startAdvertising(advert: TDPLobbyAdvert)
    func updateAdvert(_ advert: TDPLobbyAdvert)
    func stopAdvertising()
    func accept(peerId: String)
    func reject(peerId: String)

    // Guest
    func startBrowsing()
    func stopBrowsing()
    func invite(peerId: String, context: Data?)

    // Both
    func send(_ data: Data, to peerIds: [String])
    func broadcast(_ data: Data)
    func disconnect()
}

extension TDPMPCTransport: TDPTransport {}
