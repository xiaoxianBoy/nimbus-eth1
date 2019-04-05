import
  json_rpc/rpcserver, rpc_types, hexstrings, tables, options, sequtils,
  eth/[common, rlp, keys, p2p], eth/p2p/rlpx_protocols/whisper_protocol,
  nimcrypto/[sysrand, hmac, sha2, pbkdf2]

from byteutils import hexToSeqByte, hexToByteArray

# Whisper RPC implemented mostly as in
# https://github.com/ethereum/go-ethereum/wiki/Whisper-v6-RPC-API

# TODO: rpc calls -> check all return values and matching documentation

type
  WhisperKeys* = ref object
    asymKeys*: Table[string, KeyPair]
    symKeys*: Table[string, SymKey]

proc newWhisperKeys*(): WhisperKeys =
  new(result)
  result.asymKeys = initTable[string, KeyPair]()
  result.symKeys = initTable[string, SymKey]()

proc setupWhisperRPC*(node: EthereumNode, keys: WhisperKeys, rpcsrv: RpcServer) =

  rpcsrv.rpc("shh_version") do() -> string:
    ## Returns string of the current whisper protocol version.
    result = whisperVersionStr

  rpcsrv.rpc("shh_info") do() -> WhisperInfo:
    ## Returns diagnostic information about the whisper node.
    let config = node.protocolState(Whisper).config
    result = WhisperInfo(minPow: config.powRequirement,
                         maxMessageSize: config.maxMsgSize,
                         memory: 0,
                         messages: 0)

  # TODO: uint32 instead of uint64 is OK here, but needs to be added in json_rpc
  rpcsrv.rpc("shh_setMaxMessageSize") do(size: uint64) -> bool:
    ## Sets the maximal message size allowed by this node.
    ## Incoming and outgoing messages with a larger size will be rejected.
    ## Whisper message size can never exceed the limit imposed by the underlying
    ## P2P protocol (10 Mb).
    ##
    ## size: Message size in bytes.
    ##
    ## Returns true on success and an error on failure.
    result = node.setMaxMessageSize(size.uint32)

  rpcsrv.rpc("shh_setMinPoW") do(pow: float) -> bool:
    ## Sets the minimal PoW required by this node.
    ##
    ## pow: The new PoW requirement.
    ##
    ## Returns true on success and an error on failure.
    # TODO: is asyncCheck here OK?
    asyncCheck node.setPowRequirement(pow)
    result = true

  # TODO: change string in to ENodeStr with extra checks
  rpcsrv.rpc("shh_markTrustedPeer") do(enode: string) -> bool:
    ## Marks specific peer trusted, which will allow it to send historic
    ## (expired) messages.
    ## Note: This function is not adding new nodes, the node needs to exists as
    ## a peer.
    ##
    ## enode: Enode of the trusted peer.
    ##
    ## Returns true on success and an error on failure.
    # TODO: It will now require an enode://pubkey@ip:port uri
    # could also accept only the pubkey (like geth)?
    let peerNode = newNode(enode)
    result = node.setPeerTrusted(peerNode.id)

  rpcsrv.rpc("shh_newKeyPair") do() -> IdentifierStr:
    ## Generates a new public and private key pair for message decryption and
    ## encryption.
    ##
    ## Returns key identifier on success and an error on failure.
    result = generateRandomID().IdentifierStr
    keys.asymKeys.add(result.string, newKeyPair())

  rpcsrv.rpc("shh_addPrivateKey") do(key: PrivateKeyStr) -> IdentifierStr:
    ## Stores the key pair, and returns its ID.
    ##
    ## key: Private key as hex bytes.
    ##
    ## Returns key identifier on success and an error on failure.
    result = generateRandomID().IdentifierStr

    # No need to check if 0x prefix as the JSON Marshalling should handle this
    var privkey = initPrivateKey(key.string[2 .. ^1])
    keys.asymKeys.add(result.string, KeyPair(seckey: privkey,
                                             pubkey: privkey.getPublicKey()))

  rpcsrv.rpc("shh_deleteKeyPair") do(id: IdentifierStr) -> bool:
    ## Deletes the specifies key if it exists.
    ##
    ## id: Identifier of key pair
    ##
    ## Returns true on success and an error on failure.
    var unneeded: KeyPair
    result = keys.asymKeys.take(id.string, unneeded)

  rpcsrv.rpc("shh_hasKeyPair") do(id: IdentifierStr) -> bool:
    ## Checks if the whisper node has a private key of a key pair matching the
    ## given ID.
    ##
    ## id: Identifier of key pair
    ##
    ## Returns true on success and an error on failure.
    result = keys.asymkeys.hasKey(id.string)

  rpcsrv.rpc("shh_getPublicKey") do(id: IdentifierStr) -> PublicKey:
    ## Returns the public key for identity ID.
    ##
    ## id: Identifier of key pair
    ##
    ## Returns public key on success and an error on failure.
    # Note: key not found exception as error in case not existing
    result = keys.asymkeys[id.string].pubkey

  rpcsrv.rpc("shh_getPrivateKey") do(id: IdentifierStr) -> PrivateKey:
    ## Returns the private key for identity ID.
    ##
    ## id: Identifier of key pair
    ##
    ## Returns private key on success and an error on failure.
    # Note: key not found exception as error in case not existing
    result = keys.asymkeys[id.string].seckey

  rpcsrv.rpc("shh_newSymKey") do() -> IdentifierStr:
    ## Generates a random symmetric key and stores it under an ID, which is then
    ## returned. Can be used encrypting and decrypting messages where the key is
    ## known to both parties.
    ##
    ## Returns key identifier on success and an error on failure.
    result = generateRandomID().IdentifierStr
    var key: SymKey
    if randomBytes(key) != key.len:
      error "Generation of SymKey failed"

    keys.symKeys.add(result.string, key)


  rpcsrv.rpc("shh_addSymKey") do(key: SymKeyStr) -> IdentifierStr:
    ## Stores the key, and returns its ID.
    ##
    ## key: The raw key for symmetric encryption as hex bytes.
    ##
    ## Returns key identifier on success and an error on failure.
    result = generateRandomID().IdentifierStr

    var symKey: SymKey
    # No need to check if 0x prefix as the JSON Marshalling should handle this
    hexToByteArray(key.string[2 .. ^1], symKey)
    keys.symKeys.add(result.string, symKey)

  rpcsrv.rpc("shh_generateSymKeyFromPassword") do(password: string) -> IdentifierStr:
    ## Generates the key from password, stores it, and returns its ID.
    ##
    ## password: Password.
    ##
    ## Returns key identifier on success and an error on failure.
    ## Warning: an empty string is used as salt because the shh RPC API does not
    ## allow for passing a salt. A very good password is necessary (calculate
    ## yourself what that means :))
    var ctx: HMAC[sha256]
    var symKey: SymKey
    if pbkdf2(ctx, password, "", 65356, symKey) != sizeof(SymKey):
      raise newException(ValueError, "Failed generating key")

    result = generateRandomID().IdentifierStr
    keys.symKeys.add(result.string, symKey)

  rpcsrv.rpc("shh_hasSymKey") do(id: IdentifierStr) -> bool:
    ## Returns true if there is a key associated with the name string.
    ## Otherwise, returns false.
    ##
    ## id: Identifier of key.
    ##
    ## Returns (true or false) on success and an error on failure.
    result = keys.symkeys.hasKey(id.string)

  rpcsrv.rpc("shh_getSymKey") do(id: IdentifierStr) -> SymKey:
    ## Returns the symmetric key associated with the given ID.
    ##
    ## id: Identifier of key.
    ##
    ## Returns Raw key on success and an error on failure.
    # Note: key not found exception as error in case not existing
    result = keys.symkeys[id.string]

  rpcsrv.rpc("shh_deleteSymKey") do(id: IdentifierStr) -> bool:
    ## Deletes the key associated with the name string if it exists.
    ##
    ## id: Identifier of key.
    ##
    ## Returns (true or false) on success and an error on failure.
    var unneeded: SymKey
    result = keys.symKeys.take(id.string, unneeded)

  rpcsrv.rpc("shh_subscribe") do(id: string,
                                 options: WhisperFilterOptions) -> IdentifierStr:
    ## Creates and registers a new subscription to receive notifications for
    ## inbound whisper messages. Returns the ID of the newly created
    ## subscription.
    ##
    ## id: identifier of function call. In case of Whisper must contain the
    ## value "messages".
    ## options: WhisperFilterOptions
    ##
    ## Returns the subscription ID on success, the error on failure.

    # TODO: implement subscriptions, only for WS & IPC?
    discard

  rpcsrv.rpc("shh_unsubscribe") do(id: IdentifierStr) -> bool:
    ## Cancels and removes an existing subscription.
    ##
    ## id: Subscription identifier
    ##
    ## Returns (true or false) on success, the error on failure
    result  = node.unsubscribeFilter(id.string)

  proc validateOptions[T,U,V](asym: Option[T], sym: Option[U], topic: Option[V]) =
    if (asym.isSome() and sym.isSome()) or (asym.isNone() and sym.isNone()):
      raise newException(ValueError,
                         "Either privateKeyID/pubKey or symKeyID must be present")
    if asym.isNone() and topic.isNone():
      raise newException(ValueError, "Topic mandatory with symmetric key")

  rpcsrv.rpc("shh_newMessageFilter") do(options: WhisperFilterOptions) -> IdentifierStr:
    ## Create a new filter within the node. This filter can be used to poll for
    ## new messages that match the set of criteria.
    ##
    ## options: WhisperFilterOptions
    ##
    ## Returns filter identifier on success, error on failure

    # Check if either symKeyID or privateKeyID is present, and not both
    # Check if there are Topics when symmetric key is used
    validateOptions(options.privateKeyID, options.symKeyID, options.topics)

    var filter: Filter
    if options.privateKeyID.isSome():
      filter.privateKey = some(keys.asymKeys[options.privateKeyID.get().string].seckey)

    if options.symKeyID.isSome():
      filter.symKey= some(keys.symKeys[options.symKeyID.get().string])

    if options.sig.isSome():
      # Need to strip 0x04
      filter.src = some(initPublicKey(options.sig.get().string[4 .. ^1]))

    if options.minPow.isSome():
      filter.powReq = options.minPow.get()

    if options.topics.isSome():
      filter.topics = map(options.topics.get(),
                          proc(x: TopicStr): whisper_protocol.Topic =
                              hexToByteArray(x.string[2 .. ^1], result))

    if options.allowP2P.isSome():
      filter.allowP2P = options.allowP2P.get()

    result = node.subscribeFilter(filter).IdentifierStr

  rpcsrv.rpc("shh_deleteMessageFilter") do(id: IdentifierStr) -> bool:
    ## Uninstall a message filter in the node.
    ##
    ## id: Filter identifier as returned when the filter was created.
    ##
    ## Returns true on success, error on failure.
    result  = node.unsubscribeFilter(id.string)

  rpcsrv.rpc("shh_getFilterMessages") do(id: IdentifierStr) -> seq[WhisperFilterMessage]:
    ## Retrieve messages that match the filter criteria and are received between
    ## the last time this function was called and now.
    ##
    ## id: ID of filter that was created with `shh_newMessageFilter`.
    ##
    ## Returns array of messages on success and an error on failure.
    let messages = node.getFilterMessages(id.string)
    for msg in messages:
      var filterMsg: WhisperFilterMessage

      if msg.decoded.src.isSome():
        filterMsg.sig = some(msg.decoded.src.get())
      if msg.dst.isSome():
        filterMsg.recipientPublicKey = some(msg.dst.get())
      filterMsg.ttl = msg.ttl
      filterMsg.topic = msg.topic
      filterMsg.timestamp = msg.timestamp
      filterMsg.payload = msg.decoded.payload
      # TODO: could also remove the Option on padding in whisper_protocol?
      if msg.decoded.padding.isSome():
        filterMsg.padding = msg.decoded.padding.get()
      filterMsg.pow = msg.pow
      filterMsg.hash = msg.hash

      result.add(filterMsg)

  rpcsrv.rpc("shh_post") do(message: WhisperPostMessage) -> bool:
    ## Creates a whisper message and injects it into the network for
    ## distribution.
    ##
    ## message: Whisper message to post.
    ##
    ## Returns true on success and an error on failure.

    # Check if either symKeyID or pubKey is present, and not both
    # Check if there is a Topic when symmetric key is used
    validateOptions(message.pubKey, message.symKeyID, message.topic)

    var
      pubKey: Option[PublicKey]
      sigPrivKey: Option[PrivateKey]
      symKey: Option[SymKey]
      topic: whisper_protocol.Topic
      padding: Option[Bytes]
      targetPeer: Option[NodeId]

    if message.pubKey.isSome():
      pubKey = some(initPublicKey(message.pubKey.get().string[4 .. ^1]))

    if message.sig.isSome():
      sigPrivKey = some(keys.asymKeys[message.sig.get().string].seckey)

    if message.symKeyID.isSome():
      symKey = some(keys.symKeys[message.symKeyID.get().string])

    # Note: If no topic it will be defaulted to 0x00000000
    if message.topic.isSome():
      hexToByteArray(message.topic.get().string[2 .. ^1], topic)

    if message.padding.isSome():
      padding = some(hexToSeqByte(message.padding.get().string))

    if message.targetPeer.isSome():
      targetPeer = some(newNode(message.targetPeer.get()).id)

    result = node.postMessage(pubKey,
                              symKey,
                              sigPrivKey,
                              ttl = message.ttl.uint32,
                              topic = topic,
                              payload = hexToSeqByte(message.payload.string),
                              padding = padding,
                              powTime = message.powTime,
                              powTarget = message.powTarget,
                              targetPeer = targetPeer)
