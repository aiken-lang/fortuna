use aiken/dict
use aiken/list
use aiken/transaction.{InlineDatum,
  OutputReference, ScriptContext, Transaction} as tx
use aiken/transaction/credential.{Inline, ScriptCredential}
use fortuna/utils.{get_inline_datum, quantity_of}
use hardfork/hftypes.{
  ForkDatum, Forked, HardForkState, LockAction, LockState, MinerLockState,
  NotForked,
}
use hardfork as hf

type NftForkAction {
  /// Only run once to initialize the nft tokens
  Initialize

  /// Allows locking of v1 tuna tokens in the hopes that the hard fork succeeds 
  /// they would then be able to claim an equal amount of v2 tokens 
  /// if the fork fails you get the v1 tuna back =)
  /// Mints an ownership NFT or uses an existing one to prove ownership over who locked the funds
  Lock {
    hard_fork_state_ref: OutputReference,
    lock_output_index: Int,
    nft_output_index: Int,
    ownership_key_index: Option<Int>,
    lock_action: LockAction,
  }

  /// This action is only run once and it permanently alters the state of 
  /// the control token to Forked
  HardFork {
    hardfork_state_input: OutputReference,
    v2_miner_output: Int,
    lock_output_index: Int,
    nft_output_index: Int,
    ownership_key_index: Option<Int>,
    hardfork_output_index: Int,
    lock_action: LockAction,
  }

  /// Fork Failed so come get your tokens back
  Unlock { hard_fork_state_ref: OutputReference }

  /// Congrats the forked succeeded, so burn your ownership NFT to get an 
  /// amount of tuna v2 equal to your locked tuna
  Burn {
    hard_fork_state_ref: OutputReference,
    locked_tokens_ref: OutputReference,
  }

  /// This action is only run once and if HardFork was not run.
  /// It permanently alters the state of the control token to FailedFork
  FailForkAttempt { fortuna_v1_output: Int }
}

// maybe we should do time instead of block height?
validator(init_utxo_ref: OutputReference, fortuna_v1_hash: ByteArray) {
  fn nft_fork(redeemer: Data, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction, purpose } = ctx

    when purpose is {
      tx.Mint(own_policy) -> {
        let Transaction { withdrawals, .. } = transaction

        let own_withdrawal = Inline(ScriptCredential(own_policy))

        // Fork Mint(0) requirement: Withdrawal script is present
        dict.has_key(withdrawals, own_withdrawal)
      }

      tx.WithdrawFrom(stake_cred) -> {
        expect action: NftForkAction = redeemer

        expect Inline(ScriptCredential(own_policy)) = stake_cred

        when action is {
          // Check if the input is spent and proper initial state is made
          // No need to check spends from own script hash in intialize
          // The reason being is no meaningful locks can happen before initialize
          Initialize -> hf.initialize(init_utxo_ref, transaction, own_policy)

          Lock {
            hard_fork_state_ref,
            lock_output_index,
            nft_output_index,
            ownership_key_index,
            lock_action,
          } -> {
            expect HardForkState { status, fork_block_height, .. } =
              hf.validate_hardfork_state(
                transaction.reference_inputs,
                hard_fork_state_ref,
                own_policy,
              )

            when status is {
              NotForked ->
                // Since this function is only used once
                // the compiler will optimize it out so all the function param
                // passing is free. Same with the others below
                hf.lock_not_forked(
                  fv1h: fortuna_v1_hash,
                  loi: lock_output_index,
                  noi: nft_output_index,
                  oki: ownership_key_index,
                  la: lock_action,
                  tx: transaction,
                  op: own_policy,
                  fbh: fork_block_height,
                )
              Forked -> {
                let total_emission_at_fork =
                  hf.calculate_emission(fork_block_height)

                expect Some(miner_locked_state_output) =
                  list.find(
                    transaction.reference_inputs,
                    fn(input) {
                      quantity_of(
                        input.output.value,
                        own_policy,
                        hf.miner_lock_state_token,
                      ) == 1
                    },
                  )

                expect InlineDatum(miner_locked_state_datum) =
                  miner_locked_state_output.output.datum

                expect MinerLockState { locked_tuna: miner_locked_tuna, .. }: ForkDatum =
                  miner_locked_state_datum

                hf.lock_after_fork(
                  fv1h: fortuna_v1_hash,
                  loi: lock_output_index,
                  noi: nft_output_index,
                  oki: ownership_key_index,
                  la: lock_action,
                  tx: transaction,
                  op: own_policy,
                  teaf: total_emission_at_fork,
                  mlt: miner_locked_tuna,
                )
              }
              _ -> False
            }
          }

          // We allow unlocking of fortuna v1 tokens in the case of a failed fork
          // We only allow an input to be spent under the hard fork failed condition and when burning the nft key
          Unlock { hard_fork_state_ref } ->
            hf.unlock_failed_fork(transaction, own_policy, hard_fork_state_ref)

          Burn { hard_fork_state_ref, locked_tokens_ref } ->
            hf.burn_forked(
              transaction,
              own_policy,
              hard_fork_state_ref,
              locked_tokens_ref,
            )

          HardFork {
            hardfork_state_input,
            hardfork_output_index,
            nft_output_index,
            lock_output_index,
            ownership_key_index,
            v2_miner_output,
            lock_action,
          } -> {
            expect Some(locked_state_input) =
              list.find(
                transaction.reference_inputs,
                fn(input) {
                  quantity_of(
                    input.output.value,
                    own_policy,
                    hf.lock_state_token,
                  ) == 1
                },
              )

            expect LockState { locked_tuna: user_locked_tuna }: ForkDatum =
              get_inline_datum(locked_state_input.output.datum)

            hf.hard_fork(
              fv1h: fortuna_v1_hash,
              hfsi: hardfork_state_input,
              hoi: hardfork_output_index,
              noi: nft_output_index,
              loi: lock_output_index,
              oki: ownership_key_index,
              vmo: v2_miner_output,
              la: lock_action,
              tx: transaction,
              op: own_policy,
              rlt: user_locked_tuna,
            )
          }

          FailForkAttempt { fortuna_v1_output } ->
            hf.failed_fork(
              fortuna_v1_hash,
              fortuna_v1_output,
              transaction,
              own_policy,
            )
        }
      }

      _ -> False
    }
  }

  fn fork(_datum, _redeemer, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction, purpose } = ctx

    expect tx.Spend(own_ref) = purpose

    let Transaction { inputs, withdrawals, .. } = transaction

    let own_input = utils.resolve_output_reference(inputs, own_ref)

    let own_withdrawal = Inline(own_input.address.payment_credential)

    // Fork Spend(0) requirement: Withdrawal script is present
    dict.has_key(withdrawals, own_withdrawal)
  }
}
