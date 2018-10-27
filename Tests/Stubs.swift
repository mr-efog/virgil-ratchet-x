//
//  Stubs.swift
//  VirgilSDKRatchet
//
//  Created by Oleksandr Deundiak on 10/24/18.
//  Copyright © 2018 Oleksandr Deundiak. All rights reserved.
//

import Foundation
import VirgilSDK
import VirgilCryptoApiImpl
@testable import VirgilSDKRatchet

class FakeRamSessionStorage: SessionStorage {
    private var db: [String: SecureSession] = [:]
    
    func storeSession(_ session: SecureSession) throws {
        self.db[session.participantIdentity] = session
    }
    
    func retrieveSession(participantIdentity: String) -> SecureSession? {
        return self.db[participantIdentity]
    }
    
    func deleteSession(participantIdentity: String) throws {
        guard self.db.removeValue(forKey: participantIdentity) != nil else {
            throw NSError()
        }
    }
}

class FakeLongTermKeysStorage: LongTermKeysStorage {
    var db: [Data: LongTermKey] = [:]
    
    init(db: [Data: LongTermKey]) {
        self.db = db
    }

    func storeKey(_ key: Data, withId id: Data) throws -> LongTermKey {
        let longTermKey = LongTermKey(identifier: id, key: key, creationDate: Date(), outdatedFrom: nil)
        self.db[id] = longTermKey
        return longTermKey
    }
    
    func retrieveKey(withId id: Data) throws -> LongTermKey {
        guard let key = self.db[id] else {
            throw NSError()
        }
        
        return key
    }
    
    func deleteKey(withId id: Data) throws {
        guard self.db.removeValue(forKey: id) != nil else {
            throw NSError()
        }
    }
    
    func retrieveAllKeys() throws -> [LongTermKey] {
        return [LongTermKey](self.db.values)
    }
    
    func markKeyOutdated(startingFrom date: Date, keyId: Data) throws {
        guard let key = self.db[keyId] else {
            throw NSError()
        }
        
        self.db[keyId] = LongTermKey(identifier: keyId, key: key.key, creationDate: key.creationDate, outdatedFrom: date)
    }
}

class FakeOneTimeKeysStorage: OneTimeKeysStorage {
    var db: [Data: OneTimeKey] = [:]
    
    init(db: [Data: OneTimeKey]) {
        self.db = db
    }
    
    func startInteraction() throws { }
    
    func stopInteraction() throws { }
    
    func storeKey(_ key: Data, withId id: Data) throws -> OneTimeKey {
        let oneTimeKey = OneTimeKey(identifier: id, key: key, orphanedFrom: nil)
        self.db[id] = oneTimeKey
        return oneTimeKey
    }
    
    func retrieveKey(withId id: Data) throws -> OneTimeKey {
        guard let key = self.db[id] else {
            throw NSError()
        }
        
        return key
    }
    
    func deleteKey(withId id: Data) throws {
        guard self.db.removeValue(forKey: id) != nil else {
            throw NSError()
        }
    }
    
    func retrieveAllKeys() throws -> [OneTimeKey] {
        return [OneTimeKey](self.db.values)
    }
    
    func markKeyOrphaned(startingFrom date: Date, keyId: Data) throws {
        guard let key = self.db[keyId] else {
            throw NSError()
        }
        
        self.db[keyId] = OneTimeKey(identifier: keyId, key: key.key, orphanedFrom: date)
    }
}

class FakeClient: RatchetClientProtocol {
    let publicKeySet: PublicKeySet
    
    init(publicKeySet: PublicKeySet) {
        self.publicKeySet = publicKeySet
    }
    
    func uploadPublicKeys(identityCardId: String?, longTermPublicKey: SignedPublicKey?, oneTimePublicKeys: [Data], token: String) throws {
        
    }
    
    func getNumberOfActiveOneTimePublicKeys(token: String) throws -> Int {
        return 0
    }
    
    func validatePublicKeys(longTermKeyId: Data?, oneTimeKeysIds: [Data], token: String) throws -> ValidatePublicKeysResponse {
        return try JSONDecoder().decode(ValidatePublicKeysResponse.self, from: Data())
    }
    
    func getPublicKeySet(forRecipientIdentity identity: String, token: String) throws -> PublicKeySet {
        return publicKeySet
    }
}

class FakeRamClient: RatchetClientProtocol {
    struct UserStore {
        var identityPublicKey: (VirgilPublicKey, Data)?
        var longTermPublicKey: SignedPublicKey?
        var usedLongtermPublicKeys: Set<SignedPublicKey> = []
        var oneTimePublicKeys: Set<Data> = []
        var usedOnetimePublicKeys: Set<Data> = []
    }
    
    private let cardManager: CardManager
    private let crypto = VirgilCrypto()
    private var users: [String: UserStore] = [:]
    
    init(cardManager: CardManager) {
        self.cardManager = cardManager
    }
    
    func uploadPublicKeys(identityCardId: String?, longTermPublicKey: SignedPublicKey?, oneTimePublicKeys: [Data], token: String) throws {
        guard let jwt = try? Jwt(stringRepresentation: token) else {
            throw NSError()
        }
        
        var userStore = self.users[jwt.identity()] ?? UserStore()
        
        let publicKey: VirgilPublicKey
        if let identityCardId = identityCardId {
            let card = try self.cardManager.getCard(withId: identityCardId).startSync().getResult()
            publicKey = card.publicKey as! VirgilPublicKey
            userStore.identityPublicKey = (publicKey, CUtils.extractRawPublicKey(self.crypto.exportPublicKey(publicKey)))
        }
        else {
            guard let existingIdentityPublicKey = userStore.identityPublicKey else {
                throw NSError()
            }
            
            publicKey = existingIdentityPublicKey.0
        }
        
        if let longTermPublicKey = longTermPublicKey {
            guard crypto.verifySignature(longTermPublicKey.signature, of: longTermPublicKey.publicKey, with: publicKey) else {
                throw NSError()
            }

            if let usedLongTermPublicKey = userStore.longTermPublicKey {
                userStore.usedLongtermPublicKeys.insert(usedLongTermPublicKey)
            }
            
            userStore.longTermPublicKey = longTermPublicKey
        }
        else {
            guard userStore.longTermPublicKey != nil else {
                throw NSError()
            }
        }
        
        if !oneTimePublicKeys.isEmpty {
            let newKeysSet = Set<Data>(oneTimePublicKeys)
            
            guard userStore.oneTimePublicKeys.intersection(newKeysSet).isEmpty else {
                throw NSError()
            }
            
            userStore.oneTimePublicKeys.formUnion(newKeysSet)
        }
        
        self.users[jwt.identity()] = userStore
    }
    
    func getNumberOfActiveOneTimePublicKeys(token: String) throws -> Int {
        guard let jwt = try? Jwt(stringRepresentation: token) else {
            throw NSError()
        }
        
        let userStore = self.users[jwt.identity()] ?? UserStore()
        
        return userStore.oneTimePublicKeys.count
    }
    
    func validatePublicKeys(longTermKeyId: Data?, oneTimeKeysIds: [Data], token: String) throws -> ValidatePublicKeysResponse {
        guard let jwt = try? Jwt(stringRepresentation: token) else {
            throw NSError()
        }
        
        let userStore = self.users[jwt.identity()] ?? UserStore()
        
        let usedLongTermKeyId: Data?
        
        if let storedLongTermPublicKey = userStore.longTermPublicKey?.publicKey, let longTermKeyId = longTermKeyId {
            let hash = self.crypto.computeHash(for: storedLongTermPublicKey, using: .SHA512).subdata(in: 0..<8)
            
            usedLongTermKeyId = hash == longTermKeyId ? nil : longTermKeyId
        }
        else {
            usedLongTermKeyId = nil
        }
        
        let usedOneTimeKeysIds: [Data] = Array<Data>(Set<Data>(userStore.usedOnetimePublicKeys.map {
                return self.crypto.computeHash(for: $0, using: .SHA512).subdata(in: 0..<8)
            }).intersection(Set<Data>(oneTimeKeysIds)))
        
        return ValidatePublicKeysResponse(usedLongTermKeyId: usedLongTermKeyId, usedOneTimeKeysIds: usedOneTimeKeysIds)
    }
    
    func getPublicKeySet(forRecipientIdentity identity: String, token: String) throws -> PublicKeySet {
        guard let jwt = try? Jwt(stringRepresentation: token) else {
            throw NSError()
        }
        
        var userStore = self.users[identity] ?? UserStore()
        
        guard let identityPublicKey = userStore.identityPublicKey?.1,
            let longTermPublicKey = userStore.longTermPublicKey else {
                throw NSError()
        }
        
        let oneTimePublicKey: Data?
        if let randomOneTimePublicKey = userStore.oneTimePublicKeys.randomElement() {
            oneTimePublicKey = randomOneTimePublicKey
            userStore.oneTimePublicKeys.remove(randomOneTimePublicKey)
            
            self.users[identity] = userStore
        }
        else {
            oneTimePublicKey = nil
        }
        
        return PublicKeySet(identityPublicKey: identityPublicKey, longTermPublicKey: longTermPublicKey, oneTimePublicKey: oneTimePublicKey)
    }
}

class FakeKeysRotator: KeysRotatorProtocol {
    func rotateKeysOperation() -> GenericOperation<Void> {
        return CallbackOperation { _, completion in
            completion(Void(), nil)
        }
    }
}
