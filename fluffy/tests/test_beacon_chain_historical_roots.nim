# Nimbus
# Copyright (c) 2023 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at https://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at https://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.used.}

when (NimMajor, NimMinor) < (1, 4):
  {.push raises: [Defect].}
else:
  {.push raises: [].}

import
  unittest2,
  beacon_chain/spec/forks,
  beacon_chain/spec/datatypes/bellatrix,
  beacon_chain/../tests/testblockutil,
  # Mock helpers
  beacon_chain/../tests/mocking/mock_genesis,

  ../network/history/experimental/beacon_chain_historical_roots

suite "Beacon Chain Historical Roots":
  let
    cfg = block:
      var res = defaultRuntimeConfig
      res.ALTAIR_FORK_EPOCH = GENESIS_EPOCH
      res.BELLATRIX_FORK_EPOCH = GENESIS_EPOCH
      res
    state = newClone(initGenesisState(cfg = cfg))
  var cache = StateCache()

  var blocks: seq[bellatrix.SignedBeaconBlock]
  # Note:
  # Adding 8192 blocks. First block is genesis block and not one of these.
  # Then one extra block is needed to get the historical roots, block
  # roots and state roots processed.
  # index i = 0 is second block.
  # index i = 8190 is 8192th block and last one that is part of the first
  # historical root
  for i in 0..<SLOTS_PER_HISTORICAL_ROOT:
    blocks.add(addTestBlock(state[], cache, cfg = cfg).bellatrixData)

  test "Historical Roots Proof":
    let historical_roots = getStateField(state[], historical_roots)

    let res = buildProof(state[])
    check res.isOk()
    let proof = res.get()

    withState(state[]):
      check verifyProof(historical_roots, proof, forkyState.root)
