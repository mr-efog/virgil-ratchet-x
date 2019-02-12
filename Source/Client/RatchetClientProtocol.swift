//
// Copyright (C) 2015-2019 Virgil Security Inc.
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     (1) Redistributions of source code must retain the above copyright
//     notice, this list of conditions and the following disclaimer.
//
//     (2) Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in
//     the documentation and/or other materials provided with the
//     distribution.
//
//     (3) Neither the name of the copyright holder nor the names of its
//     contributors may be used to endorse or promote products derived from
//     this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR ''AS IS'' AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
// INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
// IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
// Lead Maintainer: Virgil Security Inc. <support@virgilsecurity.com>
//

import Foundation

/// Client used to communicate with ratchet service
public protocol RatchetClientProtocol: class {
    /// Uploads public keys
    ///
    /// Long-term public key signature should be verified.
    /// Upload priority: identity card id > long-term public key > one-time public key.
    /// Which means long-term public key can't be uploaded if identity card id is absent in the cloud
    /// and one-time public key can't be uploaded if long-term public key is absent in the cloud.
    ///
    /// - Parameters:
    ///   - identityCardId: Identity cardId that should be available on Card service.
    ///             It's public key should be ED25519
    ///   - longTermPublicKey: long-term public key + its signature created using identity private key.
    ///             Should be X25518 in PKCS#8
    ///   - oneTimePublicKeys: one-time public keys (up to 150 keys in the cloud).
    ///             Should be X25518 in PKCS#8
    ///   - token: auth token (JWT)
    /// - Throws: Depends on implementation
    func uploadPublicKeys(identityCardId: String?,
                          longTermPublicKey: SignedPublicKey?,
                          oneTimePublicKeys: [Data],
                          token: String) throws

    /// Returns number of active one-time public keys (0..<=150)
    ///
    /// - Parameter token: auth token (JWT)
    /// - Returns: Number of active one-time public keys (0..<=150)
    /// - Throws: Depends on implementation
    func getNumberOfActiveOneTimePublicKeys(token: String) throws -> Int

    /// Checks list of keys ids and returns subset of that list with already used keys ids
    ///
    /// keyId == SHA512(publicKey)[0..<8]
    ///
    /// - Parameters:
    ///   - longTermKeyId: long-term public key id to validate
    ///   - oneTimeKeysIds: list of one-time public keys ids to validate
    ///   - token: auth token (JWT)
    /// - Returns: Object with used keys ids
    /// - Throws: Depends on implementation
    func validatePublicKeys(longTermKeyId: Data?,
                            oneTimeKeysIds: [Data],
                            token: String) throws -> ValidatePublicKeysResponse

    /// Returns public keys set for given identity.
    ///
    /// - Parameters:
    ///   - identity: User's identity
    ///   - token: auth token (JWT)
    /// - Returns: Set of public keys
    /// - Throws: Depends on implementation
    func getPublicKeySet(forRecipientIdentity identity: String, token: String) throws -> PublicKeySet

    /// Deletes keys entity
    ///
    /// - Parameter token: auth token (JWT)
    /// - Throws: Depends on implementation
    func deleteKeysEntity(token: String) throws
}