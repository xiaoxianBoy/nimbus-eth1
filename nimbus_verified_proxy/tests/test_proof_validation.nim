# nimbus_verified_proxy
# Copyright (c) 2022-2024 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at https://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at https://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.used.}

{.push raises: [].}

import unittest2, stint, stew/byteutils, web3, ../validate_proof

suite "Merkle proof of inclusion validation":
  test "Validate account proof":
    # Valid inclusion proof for account 0xf36f155486299ecaff2d4f5160ed5114c1f66000
    # at execution block 7533830 of goerli network
    let
      stateRoot = FixedBytes[32].fromHex(
        "0x4cc43abefcb010e4176e82e44eadaa49a249d258867ba31f5c14d6099790a614"
      )
      codeHash = FixedBytes[32].fromHex(
        "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
      )
      storageRoot = FixedBytes[32].fromHex(
        "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421"
      )
      nonce = Quantity(uint64(71518))
      balance = UInt256.fromHex("3d25780abb5f0a89b7da")
      address =
        Address(hexToByteArray[20]("0xf36f155486299ecaff2d4f5160ed5114c1f66000"))
      rlpNodes =
        @[
          RlpEncodedBytes(
            hexToSeqByte(
              "0xf90211a00314821db27eb679525687656632f7fc3cd4e196dd8740a4fbf3c484d33cc87da0b32d41dd34b46eb2ed19133871e1c927a2b922662d512b0281965f9b44eae8dca0967240ead870312be02e54d36e91305ab81a92f9623ed1aa99505be9d05d8336a07324a33b901419dd8ae772a7ecf8a634dfbca267c1d7a8ae330800e997428db3a006dfd8d1aa5e9ceb38f3942d127a341f2b223ae2c52ec8d30528676d464c3936a04e0251f3bc74fe3a136d5de07adf754bdbf50046c1c07ef2575a8375fa780a25a0b58b1c4d2cb7cb0d5d03799ea1b9590054ac1ca12b9751a36a97bd6e5928e2d4a098af6c3153e28c974884a15b1559f27496d56d2b7cdc4dfa02ad7787adcfedbda05ab08ebefdda99feb3cb89f5d70b612de898fb387ac21d8334beb7d763748c63a0ba15badc1bb92fc1170d87b36ca1b600355312376b14802f9bc1028c6a1046e0a0bb89f3c908e5681b12b35795850ca555c41957ba680d5f88e5f4002ac092025ea0577014557fe78cca16ba9d98b7c2d1a4f1f5deb467ac24f4481cc733ff28088ca0a34409628aa8722d2977aeeb1a06a8b6220afdd20d7df376ae19d1c87fdddbeda06c59547c3b6eaec3330be1a224be6df0df62ab7d48a8b9d3dd7faf4bcef18725a087328e8cd421248ab4d6a9652e02bd27affed5ce0c4c1b7813bf9e6603b951b2a0e83ecf40ab16b2c1499c0a4431dbd507078268e31eab9f4d8747b7bfaf74b6e880"
            )
          ),
          RlpEncodedBytes(
            hexToSeqByte(
              "0xf90211a0f8c7d5888d57dbc7c05198b347d48ccabae419b0240aa322b9ebc7eac04d6977a0b6190df5827a8de954713e947e6670f8424e3693ba43f514dbbc0e884b4a28a6a0708628ad543a7941dba0ddb1f1d4bf7844bba626a3a3aafd89b0385e72e57c56a08232da95725e034b1f3d9e9602765ad5e7598e7658ecad4db7c80993ca8cd82ea01ef4066c878575e664385f39ef77db1fb7a57a0a58e3b3c9b6cde5e310ddf399a02e845663f630667e0a3942b721a8dec00f01869afafcf668b0a7418cf4c89cc9a05f354987aac1183adabc4719a7b9c2607925f01d59d7334f391615b2bcbab59ea0090667b1bcf668a02a7e52c3abd65701f12ac6cebd8e2baafec3d5738c4f78bea07caa986367ce30ef3671ae12dbb31e273cdb8607bf4b4dca027eec19d68e1180a0b654499330b745fe687ff27aea175fc5ec1a170802de3422913b76742c46d29aa0f33e264f528eb4b18e558a81c5c44c8f626ed7da7a97db0f7f1f9dafc33d1793a030aa24216649d527b72e5d6e537ec39834828be1718d2454a83bbee7a4ff03e0a0b36d7321d4651737f7bf94e5a6c8e26f160a07d2c7dc572e64e2f3a332b34b9ea0c96767291f5bf5aa8849c96c9da108b2168f9268165916eb5e1fe25195a91afda011970351d8b437572eeda47c501b33c36601a2bc4f3f81aa6fc314300b8fb0f4a054558250264df1b4f7598c46ff847ee3cf880029377548d2f5dbe7ae9ea5ae6180"
            )
          ),
          RlpEncodedBytes(
            hexToSeqByte(
              "0xf90211a0645e0adf3fc44f24e122018134c8f3b354a9daf05489f9edea8421995af83d54a0f3aee49dabe2ee334de612dba0b5860b35373217f70860f1966fbf5ed87bd465a0959edf01ef89590429a1b024fd0f03c44a172725db0fbc2b06d3b48898756171a0b46320bd901a7c10859bb4855a558180fe03442d8f0ed5818aa0959ffac1cd52a0a137a658d13cc5cc1278f0e8f94d1c807183b81c248dd1d2d7d810d3888a84b5a0f472cc3565832a83d8f7196ecb582cb37ba5acce4e6d920854381101c6821dcfa0104bca973f514d8c49ea9ec29bd8e810f0126a8ee224a1d8dd38e841d9dffa64a0ade759bd4b3d4aee6afd2c6cc208d06cf61f18a3e368af4946d75270119b4417a065963fce379969fb0486089cae75302d029a5db1e11015e3ad74f0226f4e527ba0a3ee0d4db6e0a5c654ab98d3a52b06b1d5f91f481376ecbb1cb6be98221a8586a061426d1ccd902e701a6caaea223795d5f3e236aa55dce0460d2f045c6006fe3ca01619e291402e63179d5a0900bbce5604b32a1c0387611de2ddcb54ddee59f1aba0099661197942347bbe819915e9a5571ca39f0da8140f7bbf47a219a2914582ada0a7bcfa122de1249a971c58a59851a9a17d3818f4d8b6849c555ba822c5807b07a0e9d6d70a74952aaa417dac7af7ba0a730e296def339062a20e280f8149841d3aa0c5802c02299ecefe4d5881960cf7b18a1a7fa019c7a01d0ffa60ec22c68a96ec80"
            )
          ),
          RlpEncodedBytes(
            hexToSeqByte(
              "0xf90211a0b33390ffe04f59199aa089264474955e382577538040fc9f772ad6b5c4c06e27a0a5fd2d2fbdd68b6117370131fcf2c721d0da0cf2d8f01a3ddf4ad5420cf92446a008f32325d4430b4a920fbe9501fb3a62f9b39519505b69de14e182d9e9c28fdaa049b6c110a5f95b039130fbe7c369e5c76b56d66c11b3cb49d15676b832c71ef9a018119a73e40c92fc80133e021351b5633dccee7c2e2d242cd621d43b7ec806a5a083d32aebce2b54863f4440dd80ef970ab5866a4fee9ce50336b51d6d6c6c514ca01432f1eb3e4afc6fa493fd75823455a86dd921c67ca7e0f81518ab35e5696ebda027ac89ec60eac73922fef5e0ff3d53e3a04a4dce200a9f9db673b595f94cd63fa060cac64c1ac701ab6ebc752f9678c5543b856ac1755a9fa497d036d59a761d43a012f241474b3c69e648a58f2decb402e5613b38119f052bc76841860919dfbf02a0fe6141f40b1e2106b560f85c69e533c9f8474be39c74adbfb27352c39b606c29a0a826e7c1ea4203742b201b9c87244042bb07acf7c75d5e171d548c4675748d79a010b898bbcbab926031138c96b851ab6ece680d0a0ee4ed9f0d3630505aefed00a0207ca951540621936ecb946527d630e987e1dae1f6b299615d5163cbae74c229a0680537757d58834489d865435cb3947988a361bba8ee446304d6dfe665581a75a0613b58f9069a610ebffaa7b8086a97ea3991587790eb1f096b90b9526ccf9d5280"
            )
          ),
          RlpEncodedBytes(
            hexToSeqByte(
              "0xf90211a0f1b4b40950e332e3c246f6f6337bd559851b016d6b8eb7f40e31f01d63d5d003a02a77269847cfebd549834d7dac417f01b0f50d860e405305ec5988929b6c3339a0903f28b7912939efa6a807a4624702e28a6479583837b4e492aeae6a5d983a18a0638921e1fcf9bf9be37e6a648fa0ac7e1cc967abf4b975bb508515f9239260b2a015be428e82a9832418df65893858bb752f0aff3a380dd725854f64f5872b256ba09ea32765a32962713ba16c05bada54f7e4ac0e5da9fdc065f9c0deccecae61aba0a0c332c40ec2008c1d7e2176de631677317036c958991fa6a3773c9dabbd95fba06eaf67569e289f4f4c12486569b60325745a603d70fe836e28ed79abe608dd5fa0d09de843dd1de76e046a5de951db5330f03bc0b9df21d0a3ddb6a368f860cd09a063f9de11d14818fdfe6225306dbec74194c56a0f7b4c0cbb7c2200986d76d039a0a50fe5a0fac3e83bdaac397c0c4a32152e4ae756614961f2172492b42a576401a07119c9011c9eba49d196a878c6af0fe8204befccf6fb45ddce5ec0ebbe5d4c6da01d2ccefea315ac12691ce505e9bb828b731ce130b4108703f8ed7eedb2bcf1eba0e2fe8df21c00c13507e2b2870a213692ae455d4a6208f44e9bbd7d0a55b7cecba0ee91cbfa9b14ee3d2e958f0f6a383fa5da7dc667c0b93f6787b79861994d6f5fa089307ff3f6d958b9e5ef2e13ba5ceebaadcff82e99e92b6563acd0deef148e5c80"
            )
          ),
          RlpEncodedBytes(
            hexToSeqByte(
              "0xf90111a09725a5bda59d158e12856fd110eed37c2b2377833b01bbb730db1111658cb302a0acacf1fba3ed03da1672f5e12b06cc59a4e85eb8573bc64b30e598979963823f80808080808080a070555db94f94d4046ab94a7f99db7dc6caf8c1ddb9e083a8c807c99f96e0bf0ca0196f92289153376127494f86154dd26abf8273e443c4dc64d9d35ec974e63838a0969ef252c7141504f76fbb187f24e526035b3c649b18aa9d219ba9954c3312dda0bcb2b97af79709852e0f50edc795193938b18307e76f7dc87244c9dff11d5fe8a0bc7dcabe984dc42cef99f04a5c730b3c7e54f19014e6b18e5ee17add59c29b49a0d635c1be1b1ee4355531ffebdadd3cf470a0065c3a951063ef00fc60c5dece1d8080"
            )
          ),
          RlpEncodedBytes(
            hexToSeqByte(
              "0xf8749e2070b0cf62febcfb17abd5e2189b6e0029e0f9b9a1aabf0e670469d6ab74b853f8518301175e8a3d25780abb5f0a89b7daa056e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421a0c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
            )
          )
        ]

    check:
      getAccountFromProof(
        stateRoot, address, balance, nonce, codeHash, storageRoot, rlpNodes
      )
      .isOk()

  test "Validate storage proof":
    let slotValue = UInt256.fromHex("0x25a92a5853702f199bb2d805bba05d67025214a8")
    let stateRoot = FixedBytes[32].fromHex(
      "0x99b31961b56190853d6f20b17298c8e3aed0a88860f80d4662fb41712f93491d"
    )
    let proof = ProofResponse(
      address: Address(hexToByteArray[20]("0x805fe47d1fe7d86496753bb4b36206953c1ae660")),
      accountProof:
        @[
          RlpEncodedBytes(
            hexToSeqByte(
              "0xf90211a07399cef9c0d815f0ea8c485255564f7f749d3352f4cd13590b6354d521243433a0786151335ec66b81e6a5f8b0750d40a1440894febfae9021a246af0011dddc39a0d8be7a536ea6f5a70b6684a6bc5a954a3d87b424fe9c8d31e48b7697c2a439d6a0f270896eacce7a14d5f73c30c8d9864e18a7499a8c941872d0f543a583eed8d7a03d19b1d9c3294de123bab76b580db62e847b007ad24d7627c39513ad63ce7edea0cae2f92408fda1e856f7acb53c8f26984cc783dbb9ac8c4e93af362f458c2f0ca0fb6e6b3e8878fcd181be3b09eab73334d8ef6d89e26babf8072ba32e1ae5ce4aa016d11cb1bac71884c5057ec8afe714aa9b72125fb9ec6e2d9481869641a8e026a00d9828dddc21d4c4b5457a233ac518f508c88b3cd4e814eac2e28a2e2a632a08a00d396f8c462121f2e06a4288d668e98aafd2821d99b6dd1887aa660775318875a045c2a82a655fff0f7ab212635fff00ebf40e6918423f32c8abfeeb588a23c7c7a08be08722cc8bbd898101ce8a5299145d0964fd50eaf923f3feeb7df414c35fe5a0697c454102347fbd17fce54dc165220abac4ee992f1e19791c55ac17e14518e6a09502fa4ea94b14920ad984e6ab4d837068c5f00cfaefd1787a454a4705b4e2d5a08b9b53e865cd8910964ddfc3a0f1d87d8ea665ee9c0813d564de3744ffb147d7a0ae674b410e770b9fd691c72252a67ae461c82b91b88a9b42f1bbcc4a8733585780"
            )
          ),
          RlpEncodedBytes(
            hexToSeqByte(
              "0xf90211a09412f363cb562e21fccd9b4bb47a3b61215421eb9770b4a5730cb2cb6ea5bbc9a0ec0c28e23f6a9310c216965c08e1ec9c9fc9ec6112f12100263003be31d76e34a0378e652ba0a437830411206a126853271d599951a45d94a267ad5e31516563cca09b3a79cc886fd7dce88c60d39d8280ee625725b21e066358b8ca8c768911490ba088abe98c021c60a356abab43474f3fd9a3a852161b7933b0c8c932ba47e900cda052a527e30350d47b10cf22f43cf1ab288d8ffb723e6de54bc8f83b6189db2266a0bd5d883c317ab84c75785444ff61feae3ed9c2d4aab2017637ca8e974806e3c7a006c3451ace02de15b65cfd7c19c02c5c1040335f995dd957d3e07e8dc3079485a015af1df6ff5da1c38d32cf7a788c9764556e149c09bcfa92f020f77b155a03b4a0e0a5c318b7881c9e9a56d7f652a3532d5003565d5bd94337a180ce4ff1db8467a030d718ee799736a89d72b69189f1e27b0563d500ace86729685d056b09c6701ca0e2d4a13abc46bbe7b34290ca6ebd94dbbe228460fb6bb10413f6144459aa8463a0a7af172aa05889771cea29cdebdcd6bb7d4a6ec09b96629bbb64a99f4856fab8a07ece8ac878f91890f51a66f9ab6a145e1a6734cd2505ce8f2be7548617b065fda0c8819fca92b6ff1e3ea5624c0b4b582554ef7696a0e96fe696858739a8a5af9da0314d236293a35e001b071f1682bdc1e20c79af444b115fd0f8e697803b727d9180"
            )
          ),
          RlpEncodedBytes(
            hexToSeqByte(
              "0xf90211a0e8dd0264185a25c11978679ef7f80c8e50804286b5f3f15ac26d11f8f4fe8612a0398a219de5df7abe3f16eb8571583d262196726e74575ad86b88e2e27a14c529a0aafdffb23bdb02384873ed6d5df2beaf8ba1a3d7eb89a7a9cf145861ef3fd18fa09f7299d9c05587feee543d34f49c59401997d6a9d44e78d7a144b002e838be7ea0bc385eca8be25dcdf3b6b58a230ef917da28e568dbff4ad05b054feec92bd53da0bea9a90577955f6fa5a60150f37b9e77a6b233e0b75168cfb3aec7d8eb098163a0ca0114d558ad84b5afd4f5a0bd5f7469758a446cffbed94c996e4c57302d9b0aa0158a3d1058957bc5cd41d816bdb42a066132cde9439b7c1925af42256cfcfc07a0ec12e2d93e3f7862e5c86de6131caae8ac623ddbc9109b74ebc62a5ed919f60aa0fd900e1d33be45abd3e1ddda1447739c2eb90e3b53604a16c65b44bd96b2a999a019693693106b6a90707e1c9bdad704dc128c8a5690c126d573daaf007f2aedcba0ce308e3364196afb1988196382015c90e8d65f349b72e60ced504870c7f307d3a0677e417e01c738c8818f647984dbfb7683820dd8a50dba02eeb79f4314f6d81ba0ecd210d3a979b55b6d33ebc53434441d3cade0e96d6a101a082bda6cd4ca88baa055d90842c7606222257aa1e98d949a23f7d676512bb21395bfacebc9d718e1bda027e473f101976ee9201de7f867158e165eedf3fe472567a9178d96ca6856c01c80"
            )
          ),
          RlpEncodedBytes(
            hexToSeqByte(
              "0xf90211a09044017f2c2743fb2a70885262ce105c4d63095cc85e998b844ca5a08e2a6e14a020f6c529f0fcd791436640ba14ec77555cf06ac65cb75bd15a70270c940ad900a0c8f51f52d62882314e3b004ca0c3afdca1cb374582e484b10c371f553ff951c4a0975183fc3697fe81104fd4acc5e3a6167614786efcc52c940187cd517dc5f88fa00bf7e6698b3f1ba0963ced4ecd5f3fce6b7ae9346ee331ddfe54323a9027f944a06405c7db333d93ebad9e660b513373c974c5492012401a8ae14b5f2953c80e90a0bf9bad639ffcc1a8e047e03aace972039aa25c463c5880d1fd8907f684f82440a02cca4a3426ceabb8da2f06fe3491147a01eb0134128ec174d6836902f76ca9f2a070a886a555112f301b1545f883ed686519ae56cae46fb512e93986c37c63ec29a07df58e619bfcb18dc3ac5b49cf9eaa2817616e81e59204ccc66fd063b35aa4c6a09185c8c8e02e8a5dcfe642e776cf691208d0c79f8886585fc1bad1deebdf1dc8a0b660d946ab0ccca5467484c88789bc0baefcbb8f36b091f5758da2aa8f46a5e8a0127150d53d1b8d5aa81eeb898af87dbc55a2d0c2c6f1ef4d575e2dc1138dffa4a0a50a7266499bd407a2e60475df45b14cea1673957aca1a03740a5606117aa2bfa0434e10c0ff2e6b5ac8713a40b29bf8995e302c7d0b821c55c9f0cfc6d81fce87a0ed37d722b70122d0a5c96cd52810781b8b1a88277064d691a282d896fd301f0a80"
            )
          ),
          RlpEncodedBytes(
            hexToSeqByte(
              "0xf90211a05febd97d485ae84c4aa444320eddf9361b45ac0cd966eca4e86acadbbb9b1919a06b014b81f4328a4c92bd6639a0b7f06e55a875b5891b958e3f32aed237a60128a0878844a864828586bad11cc05427f942475e040da74a17affa41284c7c2b8a5ca0afa3cf559f694ca29166fd02462f8dc4263b25f5a6bcd012b5ea7792adf2aebba02ce34320a3ade650b5d6951fe0c6628a03ce227f06e46e2646f0dc85cb227348a01b4b6baed79a52ed6737deffe81b0f2fc55f2888639470266222946b9c85d47fa014b15187e49585497a789fa11b3499603a250f0f48f8f12313b453937239af72a0a304eac356264043417a7c9ca624d92ff08d32d3390d229a3ed96c089ac0a602a0f723b00e76886ba3206a92fa098996c87990e4231d4f08667201cc0891b778a7a0d67ede626d7500ad5d4f11bd9b9de562209627c50f3cfd967a03b41a17009a1aa04f46efe2492e2905d02802a7ff1f5d1718edfe36fcae46dd45954ee9861f13e1a042d8c5e5834755e7183313443996885b561b1ba6daa0e484b60d0becc245460da07302dec93846a62ecb50892edbc5a485775700aebf816badfa42af6e3853d16aa04b2b25079c39ad8d517a61e47141519b4b497b36c4edb81e6f34c7917823d414a01aac7bb66afad0b0e7f8ffeb928d34ab59fe428e4a77b30689956fabb94e9f56a01accc5cd467129ec35675c04625ae805dc974fef16119f49e44f27853aee58f480"
            )
          ),
          RlpEncodedBytes(
            hexToSeqByte(
              "0xf90111a0d7559f6dc085b66ea2cf7928f3aff9ca07e9518113f44678a662b8fd5c91ab60a0b584675ea78138a4fd465b08895f3e791e717c2e259bff313d922994ad1085da80a0901123278214a37f6cd1d18d67c9ad8c51a64f8cf18c7de342d59a6b072d2f25a097533fa6c344fb668de71a3aa0c30da9190d2b6ce2974b05ba6caa9c8a9c495aa0344b048b149b2c08d1aa92ba1741009c6a8a4726bf5e7db12c78f4ad521122ae80808080a092677d6f81cdcafb80add68e79d7322af8771830d7d444a7587e8296203b16a88080a0930e22b8279f903ce0046cabc3cd24f2659dcb9c08980509ee0d12cc0ddecbee80a0156aa8328726c06af81bc6219dfada3e7826f1337da178258886015e94b0501c80"
            )
          ),
          RlpEncodedBytes(
            hexToSeqByte(
              "0xf8679e20da5951bceaed385c03546f45f276b83d86bc0755e045f92f1d9071f431b846f8440180a07bb85da974b0ee4efcb379f528bcf7e947a55901d5a2c0d38bc9cc16c851e785a03b45ab254ec24f2bcb75a922f15031796bc433ea5a4514783705d185321e5f82"
            )
          )
        ],
      balance: UInt256.fromHex("0x0"),
      codeHash: FixedBytes[32].fromHex(
        "0x3b45ab254ec24f2bcb75a922f15031796bc433ea5a4514783705d185321e5f82"
      ),
      nonce: Quantity(uint64(1)),
      storageHash: FixedBytes[32].fromHex(
        "0x7bb85da974b0ee4efcb379f528bcf7e947a55901d5a2c0d38bc9cc16c851e785"
      ),
      storageProof:
        @[
          StorageProof(
            key: u256(0),
            value: slotValue,
            proof:
              @[
                RlpEncodedBytes(
                  hexToSeqByte(
                    "0xf8b18080a0a24d07e12c3fedf892f5325b16f489fc7f14d267cef99aa6b7b74da7eab7a47a80a078a183d317824c686d46f3cf0a344cd5e1f8f73e095ea29864d3f8ef599dc643808080a0925cf9d2d4b35a02377f6ef9c51f1bbab4842dff4befd4ee5d85bbc15bb8554a808080a020db4b8930daa709db04119c07ee39896da3ac30b961b7901a7bea81a5329a8680a024f50ff7b56d6a9de8a2fcfe21e1710377dddb106c39c834362bd41a9bce22518080"
                  )
                ),
                RlpEncodedBytes(
                  hexToSeqByte(
                    "0xf7a0390decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563959425a92a5853702f199bb2d805bba05d67025214a8"
                  )
                )
              ],
          )
        ],
    )

    let validationResult = getStorageData(stateRoot, u256(0), proof)

    check:
      validationResult.isOk()
      validationResult.get == slotValue
