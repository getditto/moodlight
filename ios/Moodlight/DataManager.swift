//
//  DataManager.swift
//  CouchBus2.0
//
//  Created by Neil Ballard on 3/26/22.
//

import Foundation
import DittoSwift
import CouchbaseLiteSwift

class ActivePeerManager: ConnectionPeerManagerProtocol {
    
    // MARK: - Private attributes
    private var replicator: Replicator?
    private var connection: MessageEndpointConnection?
    private var replicatorConnection: ReplicatorConnection?
    
    
    // MARK: - Attributes
    var target: DittoAddress
    var send: ((Data) -> Void)?
    var semaphore = DispatchSemaphore(value: 1)
    var queue = DispatchQueue(label: "ActivePeerManager Serial Queue", qos: .userInitiated)
    
    
    // MARK: - Methods
    init(database: Database, uid: String, target: DittoAddress) {
        self.target = target
        self.setupConnection(database: database, uid: uid, target: target)
    }
    
    func didReceive(message: Message) {
        self.replicatorConnection?.receive(message: message)
    }
    
    func stopReplicationSync() {
        self.connection?.close(error: nil) {}
        self.replicator?.stop()
        self.replicatorConnection?.close(error: nil)
    }
    
    
    // MARK: - Private methods
    private func setupConnection(database: Database, uid: String, target: DittoAddress) {
        let id = "AP:\(uid.dropLast(10))"
        let messageTarget = MessageEndpoint(uid: id, target: target, protocolType: .messageStream, delegate: self)
        var config = ReplicatorConfiguration(database: database, target: messageTarget)
        config.continuous = true
        config.replicatorType = .pushAndPull
        
        self.replicator?.addChangeListener({ listener in
            print("update from replicator \(listener.status.activity)")
        })
        
        self.replicator = Replicator(config: config)
        self.replicator?.start()
    }
}

extension ActivePeerManager: Equatable {
    
    static func == (lhs: ActivePeerManager, rhs: ActivePeerManager) -> Bool {
        lhs.target == rhs.target
    }
}

extension ActivePeerManager: MessageEndpointDelegate {
    
    func createConnection(endpoint: MessageEndpoint) -> MessageEndpointConnection {
        
        let connection = PeerConnection()
        self.connection = connection
        
        connection.didConnect = { [weak self] conn in
            self?.replicatorConnection = conn
        }
        connection.readyToSend = { [weak self] data in
            self?.send?(data)
        }
        return connection
    }
}

class PassivePeerManager: ConnectionPeerManagerProtocol {
    
    // MARK: - Private attributes
    var connection: MessageEndpointConnection?
    private var replicatorConnection: ReplicatorConnection?
    
    
    // MARK: - Attributes
    var target: DittoAddress
    var send: ((Data) -> Void)?
    var semaphore = DispatchSemaphore(value: 1)
    var queue = DispatchQueue(label: "PassivePeerManager Serial Queue", qos: .userInitiated)
    
    
    // MARK: - Methods
    init(database: Database, target: DittoAddress) {
        self.target = target
        self.setupConnection(database: database)
    }
    
    func didReceive(message: Message) {
        self.replicatorConnection?.receive(message: message)
    }
    
    func stopReplicationSync() {
        print("stopping replication")
        self.connection?.close(error: nil) {}
        self.replicatorConnection?.close(error: nil)
    }
    
    
    // MARK: - Private methods
    private func setupConnection(database: Database) {
        
        let connection = PeerConnection()
        self.connection = connection
        
        connection.didConnect = { [weak self] conn in
            self?.replicatorConnection = conn
        }
        connection.readyToSend = { [weak self] data in
            self?.send?(data)
        }
    }
}

extension PassivePeerManager: Equatable {
    
    static func == (lhs: PassivePeerManager, rhs: PassivePeerManager) -> Bool {
        lhs.target == rhs.target
    }
}

protocol ConnectionPeerManagerProtocol {
    
    var target: DittoAddress { get set }
    var send: ((Data) -> Void)? { get set }
    var semaphore: DispatchSemaphore { get }
    var queue: DispatchQueue { get }
    
    func didReceive(message: Message)
    func stopReplicationSync()
}

class PeerConnection: MessageEndpointConnection {
    var didConnect: ((ReplicatorConnection) -> ())?
    var readyToSend: ((Data) -> Void)?
    
    func open(connection: ReplicatorConnection, completion: @escaping (Bool, MessagingError?) -> Void) {
        didConnect?(connection)
        completion(true, nil)
    }
    
    func close(error: Error?, completion: @escaping () -> Void) {
        
    }
    
    func send(message: Message, completion: @escaping (Bool, MessagingError?) -> Void) {
        print("Active peer send method is being called")
        let data = message.toData()
        let str = String(decoding: data, as: UTF8.self)
        print(str)
        self.readyToSend?(data)
    }
    
}


class DataManger: NSObject {
    
    static let shared = DataManger()
    var ditto: Ditto
    var database: Database
    private var bus: DittoBus
    private var dittoObserver: DittoObserver?
    private var cbListener: MessageEndpointListener
    private var streams: [DittoAddress : DittoBusStream?] = [:]
    private var activePeerManagers: [DittoAddress: ActivePeerManager] = [:]
    private var passivePeerManagers: [DittoAddress: PassivePeerManager] = [:]
    
    
    override init() {
        Database.log.console.domains = .all
        database = try! Database(name: "Ditto-CB")
        cbListener = MessageEndpointListener(config: MessageEndpointListenerConfiguration(database: database, protocolType: .messageStream))
        do {
            ditto = Ditto()
            DittoLogger.minimumLogLevel = .debug
            try ditto.setOfflineOnlyLicenseToken("o2d1c2VyX2lkaXNlYXRjaGFydGZleHBpcnl0MjAyMy0wNS0wMVQwMDowMDowMFppc2lnbmF0dXJleFh2SEEvT3VBb1poOXBzZTBGcm1XajNGTXQ2YWhHVWE5UUNSblN4V3orWFlCZFZVMU5aRDQyYjlOOU9pNnkxT1Q4Q2Fzb011d1BSVWtkc3pGS0pUKzRvUT09")
            try! ditto.startSync()
            self.bus = DittoExperimental.busFor(ditto: ditto)
        } catch(let err) {
            fatalError("Failed to start ditto \(err.localizedDescription)")
        }
        super.init()
        createObserver()
    }
    
    func createObserver() {
        self.bus.delegate = self
        dittoObserver = ditto.observePeersV2 { [weak self] remotePeersJSON in
            guard let `self` = self else { return }
            
            let remotePeers = DittoPeerV2Parser.parseJson(json: remotePeersJSON) ?? []
            
            // Find streams for peers that are gone
            var streamsToRemove: [DittoAddress] = []
            self.streams.forEach({ (key, stream) in
                if !remotePeers.contains(where: { (peer) in key == peer.address }) {
                    streamsToRemove.append(key)
                }
            })
            
            // Remove and close streams
            for stream in streamsToRemove {
                if let removedStream = self.streams.removeValue(forKey: stream) {
                    removedStream?.close()
                }
            }
            
            // Now open new streams to peers who we have not tried yet
            remotePeers.forEach({ peer in
                if !self.streams.contains(where: { (key, _) in key == peer.address }) {
                    print("Opening new outgoing stream to \(peer.deviceName)")
                    //let deviceName = peer.deviceName
                    let placeholder: DittoBusStream? = nil
                    self.streams[peer.address] = placeholder
                    // Check to prevent dual bidirectional connections between peers
                    // TODO: We should use networkId but it is only available for remote peers
                    if (peer.deviceName < self.ditto.deviceName) {
                        self.bus.openStream(toAddress: peer.address, reliability: .reliable, completion: { (stream, error) in
                            if let error = error {
                                print("error opening stream to address \(peer.address) error \(error.localizedDescription)")
                                self.streams.removeValue(forKey: peer.address)
                            }
                            else if let stream = stream {
                                print("opening stream with peer")
                                self.streams[peer.address] = stream
                                stream.delegate = self
                                print("win")
                                let activePeerManager = ActivePeerManager(database: self.database, uid: "\(self.ditto.siteID)", target:peer.address)
                                self.setupConnectionManager(peerManager: activePeerManager, stream: stream)
                                self.activePeerManagers[peer.address] = activePeerManager
                            }
                        })
                    }
                }
            })
        }
    }
    
    private func setupConnectionManager(peerManager: ConnectionPeerManagerProtocol, stream: DittoBusStream) {
        
        var manager = peerManager
        manager.send = { data in
            // When we enque data, we must wait until the enqueue delegate fires.
            // We use a combination of a serial queue (CB might be on concurrent queue)
            // and a semaphore that starts at value 1.
            //
            // First we dispatch on to the serial queue to order all the enqueue
            // requests. Then inside the block, we use a semaphore to wait on delegate.
            //
            // On each wait() call it will decrement by 1, and each signal()
            // increase by 1, so:
            // 1 -> wait() -> 0 -> data enqueued -> signal() -> 1 -> ready again!
            // 1 -> wait() -> 0 -> data enqueued -> wait() -> -1 -> thread blocked!
            //
            // This pattern means that because our enqueueing of data is in a serial
            // queue, if a subsequent attempt to enqueue happens before we get a
            // signal() call, we won't enqueue the data - ensuring correct backpressure.
            manager.queue.async {
                manager.semaphore.wait()
                stream.enqueueMessage(data: data)
            }
        }
    }
    
    func sendData(id: String, red: Double, green: Double, blue: Double, isOff: Bool) {
        let count = database.count
        print(count)
        let newTask = MutableDocument(id: id)
        newTask.setString("\(ditto.siteID)", forKey: "uid")
        newTask.setDouble(red, forKey: "red")
        newTask.setDouble(green, forKey: "green")
        newTask.setDouble(blue, forKey: "blue")
        newTask.setBoolean(isOff, forKey: "isOff")
        do {
            try database.saveDocument(newTask)
        } catch {
            print("Error in sending document")
        }
    }
    
    func updateColors(id: String, red: Double, green: Double, blue: Double) {
        let count = database.count
        print(count)
        let doc = database.document(withID: id)
        let mutableDoc = doc!.toMutable()
        mutableDoc.setDouble(red, forKey: "red")
        mutableDoc.setDouble(green, forKey: "green")
        mutableDoc.setDouble(blue, forKey: "blue")
        do {
            try database.saveDocument(mutableDoc)
        } catch {
            print("Error in updating document")
        }
    }
    
    func updateIsOFF(id: String, isOff: Bool) {
        let doc = database.document(withID: id)
        let mutableDoc = doc!.toMutable()
        mutableDoc.setBoolean(isOff, forKey: "isOff")
        do {
            try database.saveDocument(mutableDoc)
        } catch {
            print("Error in updating document")
        }
    }
    
    
    
}

extension DataManger: DittoBusDelegate, DittoBusStreamDelegate {
    func dittoBus(_ bus: DittoBus, didReceiveSingleMessage message: DittoBusMessage) {
        
    }
    
    func dittoBus(_ bus: DittoBus, didReceiveIncomingStream busStream: DittoBusStream, fromPeer peer: DittoAddress) {
        print("didReceiveIncomingStream")
        busStream.delegate = self
        streams[peer] = busStream
        let passivePeerManager = PassivePeerManager(database: database, target: peer)
        cbListener.accept(connection: passivePeerManager.connection!)
        self.setupConnectionManager(peerManager: passivePeerManager, stream: busStream)
        self.passivePeerManagers[peer] = passivePeerManager
    }
    
    func dittoBusStream(_ busStream: DittoBusStream, didEnqueueDataWithMessageSequence messageSequence: UInt64, error: DittoSwiftError?) {
        guard let stream = streams.filter({ (name, stream) in
            return busStream.id == stream?.id
        }).first else { return }
        
        let activePeerManager = activePeerManagers.filter { (peer, manager) in
            return peer == stream.key
        }.first
        
        let passivePeerManager = passivePeerManagers.filter { (peer, manager) in
            return peer == stream.key
        }.first
        
        // When we enque data, we wait until this delegate callback fires
        // This is done via a semaphore that starts at value 1
        // On each wait() call it will decrement by 1, and each signal()
        // increase by 1, so:
        // 1 -> wait() -> 0 -> data enqueued -> signal() -> 1 -> ready again!
        // 1 -> wait() -> 0 -> data enqueued -> wait() -> -1 -> thread blocked!
        //
        // This pattern means that because our enqueueing of data is in a serial
        // queue, if a subsequent attempt to enqueue happens before we get a
        // signal() call, we won't enqueue the data - ensuring correct backpressure
        if let active = activePeerManager?.value {
            active.semaphore.signal()
        }
        else if let passive = passivePeerManager?.value {
            passive.semaphore.signal()
        }
    }
    
    func dittoBusStream(_ busStream: DittoBusStream, didClose error: DittoSwiftError) {
        print("dittoBusStream:didClose")
        if let _ = error.errorDescription {
            print(error.errorDescription as Any)
        }
        
        var toRemoveAddress: DittoAddress?
        for (dittoAddress, stream) in streams {
            if busStream.id == stream?.id {
                toRemoveAddress = dittoAddress
            }
        }
        guard let toRemoveAddress = toRemoveAddress else { return }
        print("Eliminating closed outgoing stream \(toRemoveAddress)")
        let _ = streams.removeValue(forKey: toRemoveAddress)
        if let peerManager = activePeerManagers.removeValue(forKey: toRemoveAddress) {
            peerManager.stopReplicationSync()
        }
        if let peerManager = passivePeerManagers.removeValue(forKey: toRemoveAddress), let connection = peerManager.connection {
            peerManager.stopReplicationSync()
            cbListener.close(connection: connection)
        }
    }
    
    func dittoBusStream(_ busStream: DittoBusStream, didReceiveMessage message: Data) {
        print("dittoBusStream:didReceiveMessage \(message.count)")
        let message = Message.fromData(message)
        guard let stream = streams.filter({ (name, stream) in
            return busStream.id == stream?.id
        }).first else { return }
        
        let activePeerManager = activePeerManagers.filter { (peer, manager) in
            return peer == stream.key
        }.first
        
        let passivePeerManager = passivePeerManagers.filter { (peer, manager) in
            return peer == stream.key
        }.first
        
        if let active = activePeerManager {
            print("received value with active")
            active.value.didReceive(message: message)
        } else if let passive = passivePeerManager {
            print("received value with passive")
            passive.value.didReceive(message: message)
        }
    }
    
    func dittoBusStream(_ busStream: DittoBusStream, didAcknowledgeReceipt messageSequence: UInt64) {
        
    }
}
