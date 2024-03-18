use aiken/builtin.{blake2b_256}
use aiken/dict.{to_list}
use aiken/list
use aiken/math
use aiken/transaction.{InlineDatum, Input, Output, OutputReference, Transaction}
use aiken/transaction/credential.{Address, ScriptCredential}
use aiken/transaction/value.{
  from_minted_value, to_dict, tokens, without_lovelace,
}
use fortuna
use fortuna/parameters.{halving_number, initial_payout}
use fortuna/types.{State}
use fortuna/utils.{get_inline_datum, list_at, quantity_of}
use hardfork/hftypes.{
  FailedFork, ForkDatum, Forked, HardForkState, LockAction, LockState, MinerLock,
  MinerLockState, NftState, NotForked, UserLock,
}
use hardfork/params.{
  hardfork_block_height, miner_hardfork_threshold, tuna_count_blocks_from,
  tuna_hardfork_threshold_denominator, tuna_hardfork_threshold_numerator,
}

pub const miner_lock_state_token: ByteArray = "miner_lock_state"

pub const lock_state_token: ByteArray = "lock_state"

pub const hard_fork_state_token: ByteArray = "hfs"

/// Check for the proper initialization of the hard fork state
pub fn initialize(
  // Input
  initializer_input: OutputReference,
  // Tx
  transaction: Transaction,
  // Purpose
  own_policy: ByteArray,
) -> Bool {
  let Transaction { inputs, outputs, mint, .. } = transaction

  let own_address =
    Address {
      payment_credential: ScriptCredential(own_policy),
      stake_credential: None,
    }

  let mint = value.from_minted_value(mint)

  let hfs_output = list_at(outputs, 0)
  let miner_state_output = list_at(outputs, 1)
  let lock_state_output = list_at(outputs, 2)

  // The reason we check minted amount but not token name 
  // is because we check the token names and presence in the outputs back to this script
  // Plus this action can only be run once in the lifetime of this script
  expect [(_, 1), (_, 1), (_, 1)] = mint |> tokens(own_policy) |> dict.to_list

  let genesis_input = utils.resolve_output_reference(inputs, initializer_input)

  let Output { address: hfs_address, value: hfs_value, datum: hfs_datum, .. } =
    hfs_output

  let Output {
    address: miner_state_address,
    value: miner_state_value,
    datum: miner_state_datum,
    ..
  } = miner_state_output

  let Output {
    address: lock_state_address,
    value: lock_state_value,
    datum: lock_state_datum,
    ..
  } = lock_state_output

  // The values are chosen by the 
  expect HardForkState {
    status: NotForked,
    fork_block_height,
    fortuna_next_mint_hash,
    ..
  }: ForkDatum = get_inline_datum(hfs_datum)

  expect MinerLockState { locked_tuna: 0, block_signals: 0 }: ForkDatum =
    get_inline_datum(miner_state_datum)

  expect LockState { locked_tuna: 0 }: ForkDatum =
    get_inline_datum(lock_state_datum)

  and {
    own_address == hfs_address,
    own_address == miner_state_address,
    own_address == lock_state_address,
    quantity_of(hfs_value, own_policy, hard_fork_state_token) == 1,
    // Ensure new reigning lord tuna is properly locked away
    quantity_of(hfs_value, fortuna_next_mint_hash, fortuna.master_token_name) == 1,
    quantity_of(miner_state_value, own_policy, miner_lock_state_token) == 1,
    quantity_of(lock_state_value, own_policy, lock_state_token) == 1,
    // Needed to prevent removal of genesis input check
    genesis_input == genesis_input,
    fork_block_height == hardfork_block_height,
  }
}

/// Use some labels for the amount of parameters
pub fn lock_not_forked(
  fv1h fortuna_v1_hash: ByteArray,
  loi lock_output_index: Int,
  noi nft_output_index: Int,
  oki ownership_key_index: Option<Int>,
  la lock_action: LockAction,
  tx transaction: Transaction,
  op own_policy: ByteArray,
  fbh fork_block_height: Int,
) -> Bool {
  // Every action here should ensure that all mints and inputs are checked
  let Transaction { inputs, outputs, mint, .. } = transaction

  let own_address =
    Address {
      payment_credential: ScriptCredential(own_policy),
      stake_credential: None,
    }

  // Needed to ensure all validator spends from this script hash are accounted for
  let script_inputs =
    list.filter(inputs, fn(input) { input.output.address == own_address })

  // Handle output NFT state first
  let nft_output = list_at(outputs, nft_output_index)

  let Output { address, value: out_nft_value, datum: out_nft_datum, .. } =
    nft_output

  expect NftState { nft_key: out_nft_key }: ForkDatum =
    get_inline_datum(out_nft_datum)

  // Checks lock state and returns a callback for accessing the input 
  // and user locked tuna
  let callback =
    when ownership_key_index is {
      None -> {
        // Use blake hash since it's faster and this is unrelated to Proof of Work
        let own_token_name =
          builtin.head_list(inputs).output_reference
            |> builtin.serialise_data
            |> blake2b_256

        // validate mint
        // Expect only 1 minted token
        expect [(minted_token, 1)] =
          mint
            |> value.from_minted_value
            |> value.tokens(own_policy)
            |> dict.to_list

        // Handle getting input state
        expect [Input { output: lock_input, .. }] = script_inputs

        let user_locked_tuna =
          quantity_of(out_nft_value, fortuna_v1_hash, fortuna.token_name)

        if minted_token == own_token_name {
          fn(g) { g(own_token_name, lock_input, user_locked_tuna) }
        } else {
          fail @"Minted wrong token name"
        }
      }

      Some(ownership_key_index) -> {
        // validate mint
        expect [] =
          mint
            |> value.from_minted_value
            |> value.tokens(own_policy)
            |> dict.to_list

        // Handle getting input state
        expect [script_input1, script_input2] = script_inputs

        let (lock_input, nft_input) =
          if script_input1.output.datum == out_nft_datum {
            (script_input2.output, script_input1.output)
          } else {
            (script_input1.output, script_input2.output)
          }

        let Output { value: nft_value, datum: nft_datum, .. } = nft_input

        expect NftState { nft_key }: ForkDatum = get_inline_datum(nft_datum)

        let proof_of_ownership = list_at(outputs, ownership_key_index)

        let Output { value: proof_of_ownership_value, .. } = proof_of_ownership

        let user_locked_tuna =
          quantity_of(out_nft_value, fortuna_v1_hash, fortuna.token_name) - quantity_of(
            nft_value,
            fortuna_v1_hash,
            fortuna.token_name,
          )

        if quantity_of(proof_of_ownership_value, own_policy, nft_key) == 1 {
          fn(g) { g(nft_key, lock_input, user_locked_tuna) }
        } else {
          fail @"Ownership proof does not match NFT input state"
        }
      }
    }

  let own_token_name, lock_state_input, user_locked_tuna <- callback

  when lock_action is {
    // TODO: refactor some the shared parts in code
    MinerLock { fortuna_v1_output } -> and {
        // Proves that the user owns the nft key
        out_nft_key == own_token_name,
        address == own_address,
        is_a_valid_miner(
          fbh: fork_block_height,
          fv1h: fortuna_v1_hash,
          oa: own_address,
          op: own_policy,
          mli: lock_state_input,
          os: outputs,
          loi: lock_output_index,
          fvoi: fortuna_v1_output,
          ult: user_locked_tuna,
        ),
      }

    UserLock -> and {
        // Proves that the user owns the nft key
        out_nft_key == own_token_name,
        address == own_address,
        is_a_valid_locker(
          oa: own_address,
          op: own_policy,
          li: lock_state_input,
          os: outputs,
          loi: lock_output_index,
          ult: user_locked_tuna,
        ),
      }
  }
}

fn is_a_valid_miner(
  fbh fork_block_height: Int,
  fv1h fortuna_v1_hash: ByteArray,
  oa own_address: Address,
  op own_policy: ByteArray,
  mli miner_lock_input: Output,
  os outputs: List<Output>,
  loi lock_output_index: Int,
  fvoi fortuna_v1_output_index: Int,
  ult user_locked_tuna: Int,
) -> Bool {
  let Output { value: miner_lock_value, datum: miner_lock_datum, .. } =
    miner_lock_input

  expect MinerLockState { locked_tuna, block_signals }: ForkDatum =
    get_inline_datum(miner_lock_datum)

  // Handle getting output states
  let fortuna_v1_output = list_at(outputs, fortuna_v1_output_index)

  let Output { value: fortuna_v1_value, datum: fortuna_v1_datum, .. } =
    fortuna_v1_output

  expect State { block_number, .. }: State = get_inline_datum(fortuna_v1_datum)

  let miner_lock_output = list_at(outputs, lock_output_index)

  let Output {
    address,
    value: out_miner_lock_value,
    datum: out_miner_lock_datum,
    ..
  } = miner_lock_output

  expect MinerLockState {
    locked_tuna: out_locked_tuna,
    block_signals: out_block_signals,
  }: ForkDatum = get_inline_datum(out_miner_lock_datum)

  and {
    // Miner mined a valid fortuna v1 block
    quantity_of(fortuna_v1_value, fortuna_v1_hash, fortuna.master_token_name) == 1,
    // Miner locked at least some tuna
    user_locked_tuna > 0,
    // Miner lock state is updated correctly
    out_locked_tuna == user_locked_tuna + locked_tuna,
    check_block_signal(
      block_number,
      fork_block_height,
      block_signals,
      out_block_signals,
    ),
    address == own_address,
    // Miner lock value is correct
    value.without_lovelace(out_miner_lock_value) == value.without_lovelace(
      miner_lock_value,
    ),
    quantity_of(out_miner_lock_value, own_policy, miner_lock_state_token) == 1,
  }
}

fn is_a_valid_locker(
  oa own_address: Address,
  op own_policy: ByteArray,
  li lock_input: Output,
  os outputs: List<Output>,
  loi lock_output_index: Int,
  ult user_locked_tuna: Int,
) -> Bool {
  let Output { value: lock_value, datum: lock_datum, .. } = lock_input

  expect LockState { locked_tuna }: ForkDatum = get_inline_datum(lock_datum)

  // Handle getting output states
  let lock_output = list_at(outputs, lock_output_index)

  let Output { address, value: out_lock_value, datum: out_lock_datum, .. } =
    lock_output

  expect LockState { locked_tuna: out_locked_tuna }: ForkDatum =
    get_inline_datum(out_lock_datum)

  and {
    // Locked at least some tuna
    user_locked_tuna > 0,
    // Lock state is updated correctly
    out_locked_tuna == user_locked_tuna + locked_tuna,
    address == own_address,
    // Lock value is correct
    value.without_lovelace(out_lock_value) == value.without_lovelace(lock_value),
    quantity_of(out_lock_value, own_policy, lock_state_token) == 1,
  }
}

pub fn lock_after_fork(
  fv1h fortuna_v1_hash: ByteArray,
  loi lock_output_index: Int,
  noi nft_output_index: Int,
  oki ownership_key_index: Option<Int>,
  la lock_action: LockAction,
  tx transaction: Transaction,
  op own_policy: ByteArray,
  teaf total_emission_at_fork: Int,
  mlt miner_locked_tuna: Int,
) -> Bool {
  let Transaction { inputs, outputs, mint, .. } = transaction

  let own_address =
    Address {
      payment_credential: ScriptCredential(own_policy),
      stake_credential: None,
    }

  let script_inputs =
    list.filter(inputs, fn(input) { input.output.address == own_address })

  // Handle output NFT state first
  let nft_output = list_at(outputs, nft_output_index)

  let Output { address, value: out_nft_value, datum: out_nft_datum, .. } =
    nft_output

  expect NftState { nft_key: out_nft_key }: ForkDatum =
    get_inline_datum(out_nft_datum)

  let callback =
    when ownership_key_index is {
      None -> {
        // Use blake hash since it's faster and this is unrelated to Proof of Work
        let own_token_name =
          builtin.head_list(inputs).output_reference
            |> builtin.serialise_data
            |> blake2b_256

        // validate mint
        // Expect only 1 minted token
        expect [(minted_token, 1)] =
          mint
            |> value.from_minted_value
            |> value.tokens(own_policy)
            |> dict.to_list

        // Handle getting input state
        expect [Input { output: lock_input, .. }] = script_inputs

        let user_locked_tuna =
          quantity_of(out_nft_value, fortuna_v1_hash, fortuna.token_name)

        if minted_token == own_token_name {
          fn(g) { g(own_token_name, lock_input, user_locked_tuna) }
        } else {
          fail @"Minted wrong token name"
        }
      }

      Some(ownership_key_index) -> {
        // validate mint
        expect [] =
          mint
            |> value.from_minted_value
            |> value.tokens(own_policy)
            |> dict.to_list

        // Handle getting input state
        expect [script_input1, script_input2] = script_inputs

        let (lock_input, nft_input) =
          if script_input1.output.datum == out_nft_datum {
            (script_input2.output, script_input1.output)
          } else {
            (script_input1.output, script_input2.output)
          }

        let Output { value: nft_value, datum: nft_datum, .. } = nft_input

        expect NftState { nft_key }: ForkDatum = get_inline_datum(nft_datum)

        let proof_of_ownership = list_at(outputs, ownership_key_index)

        let Output { value: proof_of_ownership_value, .. } = proof_of_ownership

        let user_locked_tuna =
          quantity_of(out_nft_value, fortuna_v1_hash, fortuna.token_name) - quantity_of(
            nft_value,
            fortuna_v1_hash,
            fortuna.token_name,
          )

        if quantity_of(proof_of_ownership_value, own_policy, nft_key) == 1 {
          fn(g) { g(nft_key, lock_input, user_locked_tuna) }
        } else {
          fail @"Ownership proof does not match NFT input state"
        }
      }
    }

  let own_token_name, lock_input, user_locked_tuna <- callback

  and {
    lock_action == UserLock,
    // Proves that the user owns the nft key
    out_nft_key == own_token_name,
    address == own_address,
    is_a_valid_locker_after_fork(
      own_address,
      own_policy,
      lock_input,
      outputs,
      lock_output_index,
      user_locked_tuna,
      miner_locked_tuna,
      total_emission_at_fork,
    ),
  }
}

fn is_a_valid_locker_after_fork(
  own_address: Address,
  own_policy: ByteArray,
  lock_input: Output,
  outputs: List<Output>,
  lock_output_index: Int,
  user_locked_tuna: Int,
  miner_locked_tuna: Int,
  total_emission_at_fork: Int,
) -> Bool {
  let Output { value: lock_value, datum: lock_datum, .. } = lock_input

  expect LockState { locked_tuna }: ForkDatum = get_inline_datum(lock_datum)

  // Handle getting output states
  let lock_output = list_at(outputs, lock_output_index)

  let Output { address, value: out_lock_value, datum: out_lock_datum, .. } =
    lock_output

  expect LockState { locked_tuna: out_locked_tuna }: ForkDatum =
    get_inline_datum(out_lock_datum)

  and {
    // User locked at least some tuna
    user_locked_tuna > 0,
    // User lock state is updated correctly
    out_locked_tuna == user_locked_tuna + locked_tuna,
    out_locked_tuna + miner_locked_tuna <= total_emission_at_fork,
    address == own_address,
    // User lock value is correct
    value.without_lovelace(out_lock_value) == value.without_lovelace(lock_value),
    quantity_of(out_lock_value, own_policy, lock_state_token) == 1,
  }
}

pub fn unlock_failed_fork(
  transaction: Transaction,
  own_policy: ByteArray,
  hard_fork_state_ref: OutputReference,
) -> Bool {
  let Transaction { inputs, reference_inputs, mint, .. } = transaction

  let own_address =
    Address {
      payment_credential: ScriptCredential(own_policy),
      stake_credential: None,
    }

  let script_inputs =
    list.filter(inputs, fn(input) { input.output.address == own_address })

  let mint = value.from_minted_value(mint)

  let hfs_input =
    utils.resolve_output_reference(reference_inputs, hard_fork_state_ref)

  // Can only unlock one input at a time 
  expect [Input { output: locked_v1_input, .. }] = script_inputs

  let Output { datum: hfs_datum, value: hfs_value, .. } = hfs_input

  expect HardForkState { status: FailedFork, .. }: ForkDatum =
    get_inline_datum(hfs_datum)

  let Output { datum: nft_state, .. } = locked_v1_input

  expect NftState { nft_key }: ForkDatum = get_inline_datum(nft_state)

  expect [(token_name, -1)] = mint |> tokens(own_policy) |> dict.to_list

  and {
    quantity_of(hfs_value, own_policy, hard_fork_state_token) == 1,
    token_name == nft_key,
  }
}

pub fn burn_forked(
  transaction: Transaction,
  own_policy: ByteArray,
  hard_fork_state_ref: OutputReference,
  locked_tokens_ref: OutputReference,
) -> Bool {
  let Transaction { inputs, reference_inputs, mint, .. } = transaction

  let own_address =
    Address {
      payment_credential: ScriptCredential(own_policy),
      stake_credential: None,
    }

  let script_inputs =
    list.filter(inputs, fn(input) { input.output.address == own_address })

  let mint = value.from_minted_value(mint)

  let hfs_input =
    utils.resolve_output_reference(reference_inputs, hard_fork_state_ref)

  // Can not unlock any inputs
  expect [] = script_inputs

  let locked_v1_input =
    utils.resolve_output_reference(reference_inputs, locked_tokens_ref)

  let Output { datum: hfs_datum, value: hfs_value, .. } = hfs_input

  expect HardForkState { status: Forked, .. }: ForkDatum =
    get_inline_datum(hfs_datum)

  let Output { datum: nft_state, .. } = locked_v1_input

  expect NftState { nft_key }: ForkDatum = get_inline_datum(nft_state)

  expect [(token_name, -1)] = mint |> tokens(own_policy) |> dict.to_list

  and {
    quantity_of(hfs_value, own_policy, hard_fork_state_token) == 1,
    token_name == nft_key,
  }
}

pub fn hard_fork(
  fv1h fortuna_v1_hash: ByteArray,
  hfsi hard_fork_state_input: OutputReference,
  hoi hardfork_output_index: Int,
  loi lock_output_index: Int,
  noi nft_output_index: Int,
  oki ownership_key_index: Option<Int>,
  vmo v2_miner_output: Int,
  la lock_action: LockAction,
  tx transaction: Transaction,
  op own_policy: ByteArray,
  rlt ref_locked_tuna: Int,
) -> Bool {
  let Transaction { inputs, outputs, mint, .. } = transaction

  let own_address =
    Address {
      payment_credential: ScriptCredential(own_policy),
      stake_credential: None,
    }

  let script_inputs =
    list.filter(inputs, fn(input) { input.output.address == own_address })

  // Handle output NFT state first
  let nft_output = list_at(outputs, nft_output_index)

  let Output { address, value: out_nft_value, datum: out_nft_datum, .. } =
    nft_output

  expect address == own_address

  expect NftState { nft_key: out_nft_key }: ForkDatum =
    get_inline_datum(out_nft_datum)

  let callback =
    when ownership_key_index is {
      None -> {
        // Use blake hash since it's faster and this is unrelated to Proof of Work
        let own_token_name =
          builtin.head_list(inputs).output_reference
            |> builtin.serialise_data
            |> blake2b_256

        // validate mint
        // Expect only 1 minted token
        expect [(minted_token, 1)] =
          mint
            |> value.from_minted_value
            |> value.tokens(own_policy)
            |> dict.to_list

        // Handle getting input state
        expect [script_input1, script_input2] = script_inputs
        let (Input { output: hardfork_input, .. }, miner_lock_input) =
          if hard_fork_state_input == script_input1.output_reference {
            (script_input1, script_input2)
          } else {
            (script_input2, script_input1)
          }

        let miner_locked_tuna =
          quantity_of(out_nft_value, fortuna_v1_hash, fortuna.token_name)

        expect
          quantity_of(hardfork_input.value, own_policy, hard_fork_state_token) == 1

        if minted_token == own_token_name {
          fn(g) {
            g(
              own_token_name,
              miner_lock_input.output,
              miner_locked_tuna,
              get_inline_datum(hardfork_input.datum),
            )
          }
        } else {
          fail @"Minted wrong token name"
        }
      }

      Some(ownership_key_index) -> {
        // validate mint
        expect [] =
          mint
            |> value.from_minted_value
            |> value.tokens(own_policy)
            |> dict.to_list

        // Handle getting input state
        expect [script_input1, script_input2, script_input3] = script_inputs

        let (Input { output: hardfork_input, .. }, miner_lock_input, nft_input) =
          if hard_fork_state_input == script_input1.output_reference {
            if script_input3.output.datum == out_nft_datum {
              (script_input1, script_input2, script_input3)
            } else {
              (script_input1, script_input3, script_input2)
            }
          } else if hard_fork_state_input == script_input2.output_reference {
            if script_input3.output.datum == out_nft_datum {
              (script_input2, script_input1, script_input3)
            } else {
              (script_input2, script_input3, script_input1)
            }
          } else {
            if script_input2.output.datum == out_nft_datum {
              (script_input3, script_input1, script_input2)
            } else {
              (script_input3, script_input2, script_input1)
            }
          }

        let Output { value: nft_value, datum: nft_datum, .. } = nft_input.output

        expect NftState { nft_key }: ForkDatum = get_inline_datum(nft_datum)

        let proof_of_ownership = list_at(outputs, ownership_key_index)

        let Output { value: proof_of_ownership_value, .. } = proof_of_ownership

        let miner_locked_tuna =
          quantity_of(out_nft_value, fortuna_v1_hash, fortuna.token_name) - quantity_of(
            nft_value,
            fortuna_v1_hash,
            fortuna.token_name,
          )

        expect
          quantity_of(hardfork_input.value, own_policy, hard_fork_state_token) == 1

        if quantity_of(proof_of_ownership_value, own_policy, nft_key) == 1 {
          fn(g) {
            g(
              nft_key,
              miner_lock_input.output,
              miner_locked_tuna,
              get_inline_datum(hardfork_input.datum),
            )
          }
        } else {
          fail @"Ownership proof does not match NFT input state"
        }
      }
    }

  let nft_key, miner_lock_input, miner_locked_tuna, hardfork_datum <- callback

  expect MinerLock { fortuna_v1_output } = lock_action

  let Output { value: miner_lock_value, datum: miner_lock_datum, .. } =
    miner_lock_input

  expect MinerLockState { locked_tuna, block_signals }: ForkDatum =
    get_inline_datum(miner_lock_datum)

  expect HardForkState {
    status: NotForked,
    fork_block_height,
    fortuna_next_spend_hash,
    fortuna_next_mint_hash,
  }: ForkDatum = hardfork_datum

  let total_emitted = calculate_emission(fork_block_height)

  // Handle getting output states
  let fortuna_v1_output = list_at(outputs, fortuna_v1_output)

  let Output { value: fortuna_v1_value, datum: fortuna_v1_datum, .. } =
    fortuna_v1_output

  expect State { block_number, .. }: State = get_inline_datum(fortuna_v1_datum)

  let miner_lock_output = list_at(outputs, lock_output_index)

  let Output {
    address,
    value: out_miner_lock_value,
    datum: out_miner_lock_datum,
    ..
  } = miner_lock_output

  expect address == own_address

  expect MinerLockState {
    locked_tuna: out_locked_tuna,
    block_signals: out_block_signals,
  }: ForkDatum = get_inline_datum(out_miner_lock_datum)

  let hfs_output = list_at(outputs, hardfork_output_index)

  let Output { address, value: out_hfs_value, datum: out_hfs_datum, .. } =
    hfs_output

  expect address == own_address

  expect HardForkState {
    status: Forked,
    fork_block_height: out_fork_block_height,
    fortuna_next_spend_hash: out_fortuna_next_spend_hash,
    fortuna_next_mint_hash: out_fortuna_next_mint_hash,
  }: ForkDatum = get_inline_datum(out_hfs_datum)

  let fortuna_v2 = list_at(outputs, v2_miner_output)

  let Output { address, value: fortuna_v2_value, datum: fortuna_v2_datum, .. } =
    fortuna_v2

  expect
    address == Address {
      payment_credential: ScriptCredential(fortuna_next_spend_hash),
      stake_credential: None,
    }

  and {
    // Miner mined a valid fortuna v1 block
    quantity_of(fortuna_v1_value, fortuna_v1_hash, fortuna.master_token_name) == 1,
    // Hard fork state is run at correct block number
    fork_block_height == block_number,
    // Fortuna v2 Output state is correct
    fortuna_v2_datum == fortuna_v1_datum,
    // Fortuna v2 Output value is correct
    utils.value_has_nft_and_lovelace(
      fortuna_v2_value,
      fortuna_next_mint_hash,
      fortuna.master_token_name,
    ),
    // nft key at output datum has same token name as nft key
    nft_key == out_nft_key,
    // Miner locked at least some tuna
    miner_locked_tuna > 0,
    // Miner lock state is updated correctly
    out_locked_tuna == miner_locked_tuna + locked_tuna,
    out_block_signals == block_signals + 1,
    // Thresholds are met
    out_block_signals >= miner_hardfork_threshold,
    out_locked_tuna + ref_locked_tuna >= total_emitted * tuna_hardfork_threshold_numerator / tuna_hardfork_threshold_denominator,
    // Miner lock value is correct
    value.without_lovelace(out_miner_lock_value) == value.without_lovelace(
      miner_lock_value,
    ),
    quantity_of(out_miner_lock_value, own_policy, miner_lock_state_token) == 1,
    // Hard fork state is updated correctly
    out_fork_block_height == fork_block_height,
    out_fortuna_next_spend_hash == fortuna_next_spend_hash,
    out_fortuna_next_mint_hash == fortuna_next_mint_hash,
    utils.value_has_nft_and_lovelace(
      out_hfs_value,
      own_policy,
      hard_fork_state_token,
    ),
  }
}

pub fn failed_fork(
  fortuna_v1_hash: ByteArray,
  fortuna_v1_output: Int,
  transaction: Transaction,
  own_policy: ByteArray,
) -> Bool {
  // Every action here should ensure that all mints and inputs are checked
  let Transaction { inputs, outputs, mint, .. } = transaction

  let own_address =
    Address {
      payment_credential: ScriptCredential(own_policy),
      stake_credential: None,
    }

  // Needed to ensure all validator spends from this script hash are accounted for
  let script_inputs =
    list.filter(inputs, fn(input) { input.output.address == own_address })

  expect [Input { output: hfs_input, .. }] = script_inputs

  expect [] = mint |> from_minted_value |> to_dict |> to_list

  expect quantity_of(hfs_input.value, own_policy, hard_fork_state_token) == 1

  expect HardForkState {
    status: NotForked,
    fork_block_height,
    fortuna_next_spend_hash,
    fortuna_next_mint_hash,
  }: ForkDatum = get_inline_datum(hfs_input.datum)

  expect [hfs_output, ..] = outputs

  expect without_lovelace(hfs_input.value) == without_lovelace(hfs_output.value)

  let output_datum =
    InlineDatum(
      HardForkState {
        status: FailedFork,
        fork_block_height,
        fortuna_next_spend_hash,
        fortuna_next_mint_hash,
      },
    )

  expect hfs_output.datum == output_datum

  // Handle getting output states
  let fortuna_v1_output = list_at(outputs, fortuna_v1_output)

  let Output { value: fortuna_v1_value, datum: fortuna_v1_datum, .. } =
    fortuna_v1_output

  expect State { block_number, .. }: State = get_inline_datum(fortuna_v1_datum)

  and {
    fork_block_height < block_number,
    quantity_of(fortuna_v1_value, fortuna_v1_hash, fortuna.master_token_name) == 1,
  }
}

pub fn calculate_emission(block_height: Int) -> Int {
  if block_height < halving_number {
    block_height * initial_payout
  } else {
    halving_number * initial_payout + do_calculate_emission(
      block_height - halving_number,
      1,
    )
  }
}

fn do_calculate_emission(block_height: Int, halving_epoch: Int) -> Int {
  if block_height < halving_number {
    block_height * initial_payout / math.pow2(halving_epoch)
  } else {
    halving_number * initial_payout / math.pow2(halving_epoch) + do_calculate_emission(
      block_height - halving_number,
      halving_epoch + 1,
    )
  }
}

pub fn validate_hardfork_state(
  inputs: List<Input>,
  output_ref: OutputReference,
  own_policy: ByteArray,
) -> ForkDatum {
  let hard_fork_state_input = utils.resolve_output_reference(inputs, output_ref)

  expect
    quantity_of(hard_fork_state_input.value, own_policy, hard_fork_state_token) == 1

  expect HardForkState { .. } as datum: ForkDatum =
    get_inline_datum(hard_fork_state_input.datum)
  datum
}

pub fn check_block_signal(
  block_height,
  fork_block_height,
  block_signals,
  out_block_signals,
) -> Bool {
  if block_height >= fork_block_height - tuna_count_blocks_from {
    out_block_signals == block_signals + 1
  } else {
    out_block_signals == block_signals
  }
}
