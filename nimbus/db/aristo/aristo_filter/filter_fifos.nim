# nimbus-eth1
# Copyright (c) 2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or
#    http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or
#    http://opensource.org/licenses/MIT)
# at your option. This file may not be copied, modified, or distributed
# except according to those terms.

import
  std/tables,
  results,
  ".."/[aristo_desc, aristo_desc/desc_backend],
  "."/[filter_merge, filter_scheduler]

type
  FifoInstr* = object
    ## Database backend instructions for storing or deleting filters.
    put*: seq[(QueueID,FilterRef)]
    scd*: QidSchedRef

  FetchInstr* = object
    fil*: FilterRef
    del*: FifoInstr

# ------------------------------------------------------------------------------
# Private functions
# ------------------------------------------------------------------------------

template getFilterOrReturn(be: BackendRef; qid: QueueID): FilterRef =
  let rc = be.getFilFn qid
  if rc.isErr:
    return err(rc.error)
  rc.value

template joinFiltersOrReturn(upper, lower: FilterRef): FilterRef =
  let rc = upper.merge lower
  if rc.isErr:
    return err(rc.error[1])
  rc.value

template nextFidOrReturn(be: BackendRef): FilterID =
  ## Get next free filter ID, or exit function using this wrapper
  var fid = FilterID(1)
  block:
    let qid = be.filters[0]
    if qid.isValid:
      let rc = be.getFilFn qid
      if rc.isOK:
        fid = rc.value.fid + 1
      elif rc.error != GetFilNotFound:
        return err(rc.error)
  fid

# ------------------------------------------------------------------------------
# Public functions
# ------------------------------------------------------------------------------

proc fifosStore*(
    be: BackendRef;                              # Database backend
    filter: FilterRef;                           # Filter to save
      ): Result[FifoInstr,AristoError] =
  ## Calculate backend instructions for storing the arguent `filter` on the
  ## argument backend `be`.
  ##
  if be.filters.isNil:
    return err(FilQuSchedDisabled)

  # Calculate filter table queue update by slot addresses
  let
    qTop = be.filters[0]
    upd = be.filters.addItem

  # Update filters and calculate database update
  var
    instr = FifoInstr(scd: upd.fifo)
    hold: seq[FilterRef]
    saved = false

  # make sure that filter matches top entry (if any)
  if qTop.isValid:
    let top = be.getFilterOrReturn qTop
    if filter.trg != top.src:
      return err(FilTrgTopSrcMismatch)

  for act in upd.exec:
    case act.op:
    of Oops:
      return err(FilExecOops)

    of SaveQid:
      if saved:
        return err(FilExecDublicateSave)
      instr.put.add (act.qid, filter)
      saved = true

    of DelQid:
      instr.put.add (act.qid, FilterRef(nil))

    of HoldQid:
      # Push filter
      hold.add be.getFilterOrReturn act.qid

      # Merge additional filters into top filter
      for w in act.qid+1 .. act.xid:
        let lower = be.getFilterOrReturn w
        hold[^1] = hold[^1].joinFiltersOrReturn lower

    of DequQid:
      if hold.len == 0:
        return err(FilExecStackUnderflow)
      var lower = hold.pop
      while 0 < hold.len:
        let upper = hold.pop
        lower = upper.joinFiltersOrReturn lower
      instr.put.add (act.qid, lower)

  if not saved:
    return err(FilExecSaveMissing)

  # Set next filter ID
  filter.fid = be.nextFidOrReturn

  ok instr


proc fifosFetch*(
    be: BackendRef;                              # Database backend
    backSteps: int;                              # Backstep this many filters
      ): Result[FetchInstr,AristoError] =
  ## This function returns the single filter obtained by squash merging the
  ## topmost `backSteps` filters on the backend fifo. Also, backend instructions
  ## are calculated and returned for deleting the merged filters on the fifo.
  ##
  if be.filters.isNil:
    return err(FilQuSchedDisabled)
  if backSteps <= 0:
    return err(FilBackStepsExpected)

  # Get instructions
  let fetch = be.filters.fetchItems backSteps
  var instr = FetchInstr(del: FifoInstr(scd: fetch.fifo))

  # Follow `HoldQid` instructions and combine filters for sub-queues and
  # push intermediate results on the `hold` stack
  var hold: seq[FilterRef]
  for act in fetch.exec:
    if act.op != HoldQid:
      return err(FilExecHoldExpected)

    hold.add be.getFilterOrReturn act.qid
    instr.del.put.add (act.qid,FilterRef(nil))

    for qid in act.qid+1 .. act.xid:
      let lower = be.getFilterOrReturn qid
      instr.del.put.add (qid,FilterRef(nil))

      hold[^1] = hold[^1].joinFiltersOrReturn lower

  # Resolve `hold` stack
  if hold.len == 0:
    return err(FilExecStackUnderflow)

  var upper = hold.pop
  while 0 < hold.len:
    let lower = hold.pop

    upper = upper.joinFiltersOrReturn lower

  instr.fil = upper
  ok instr


proc fifosDelete*(
    be: BackendRef;                              # Database backend
    backSteps: int;                              # Backstep this many filters
      ): Result[FifoInstr,AristoError] =
  ## Variant of `fetch()` for calculating the deletion part only.
  if be.filters.isNil:
    return err(FilQuSchedDisabled)
  if backSteps <= 0:
    return err(FilBackStepsExpected)

  # Get instructions
  let fetch = be.filters.fetchItems backSteps
  var instr = FifoInstr(scd: fetch.fifo)

  # Follow `HoldQid` instructions for producing the list of entries that
  # need to be deleted
  for act in fetch.exec:
    if act.op != HoldQid:
      return err(FilExecHoldExpected)
    for qid in act.qid .. act.xid:
      instr.put.add (qid,FilterRef(nil))

  ok instr

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------
