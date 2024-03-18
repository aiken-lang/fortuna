use aiken/builtin
use aiken/dict
use aiken/hash.{blake2b_256, sha2_256}
use aiken/interval.{Finite, Interval, IntervalBound}
use aiken/list
use aiken/math
use aiken/transaction.{
  Mint, Output, OutputReference, ScriptContext, Spend, Transaction,
} as tx
use aiken/transaction/credential.{Address, ScriptCredential}
use aiken/transaction/value.{tokens}
use fortuna
use fortuna/parameters.{epoch_number, halving_number, initial_payout}
use fortuna/types.{ExtraState, MineState, Statev2}
use fortuna/utils.{
  get_inline_datum, list_at, quantity_of, resolve_output_reference,
}
use hardfork/hftypes.{ForkDatum, NftState}
use hardfork_validation.{hard_fork_state_token}

type TunaAction {
  Genesis
  Mine
  Redeem(OutputReference)
  NominateUpgradeContract
  VoteContractToken { script_hash: ByteArray, vote: Bool }
  ApplyContractVote { script_hash: ByteArray, for: Bool }
  ApplyUpgradeContract
}

type Miner {
  Pkh(ByteArray)
  Nft { policy: ByteArray, name: ByteArray, output_index: Int }
}

type MineAction {
  nonce: ByteArray,
  miner: Miner,
}

type TargetState {
  nonce: ByteArray,
  miner: ByteArray,
  epoch_time: Int,
  block_number: Int,
  current_hash: ByteArray,
  leading_zeros: Int,
  target_number: Int,
}

validator(
  init_utxo_ref: OutputReference,
  fortuna_v1_hash: ByteArray,
  fork_script_hash: ByteArray,
) {
  fn tuna(redeemer: TunaAction, ctx: ScriptContext) -> Bool {
    expect ScriptContext { transaction: tx, purpose: Mint(own_policy) } = ctx

    when redeemer is {
      Genesis -> {
        // This time genesis mints "lord tuna" and hands it over to the hard fork contract
        // Then after the hard fork, "lord tuna" is handed over to the miner contract
        // This allows us to maintain the miner contract with the same logic as the old one
        let Transaction { inputs, outputs, mint, .. } = tx

        // To simplify the logic, we expect the first output to hold the hard fork state
        let output = list_at(outputs, 0)

        let Output { address: out_address, value: out_value, .. } = output

        let mint = value.from_minted_value(mint)

        // The reason we check minted amount but not token name 
        // is because we check the token name and presence in the output to the hard fork script
        // Plus this action can only be run once in the lifetime of this script
        expect [(_, 1)] = mint |> tokens(own_policy) |> dict.to_list

        let genesis_input =
          utils.resolve_output_reference(inputs, init_utxo_ref)

        and {
          out_address == Address {
            payment_credential: ScriptCredential(fork_script_hash),
            stake_credential: None,
          },
          quantity_of(out_value, fork_script_hash, hard_fork_state_token) == 1,
          quantity_of(out_value, own_policy, fortuna.master_token_name) == 1,
          genesis_input == genesis_input,
        }
      }
      Redeem(locked_tokens_ref) -> {
        let Transaction { reference_inputs, mint, .. } = tx

        let mint = value.from_minted_value(mint)

        // We reference the locked v1 tuan NFTState that we have the NFT key for.
        let own_input =
          utils.resolve_output_reference(reference_inputs, locked_tokens_ref)

        let Output { address: in_address, value: in_value, datum: in_datum, .. } =
          own_input

        let locked_tokens =
          quantity_of(in_value, fortuna_v1_hash, fortuna.token_name)

        expect NftState { nft_key }: ForkDatum = get_inline_datum(in_datum)

        expect [(token_name, quantity)] =
          mint |> tokens(own_policy) |> dict.to_list

        and {
          quantity_of(mint, fork_script_hash, nft_key) == -1,
          token_name == fortuna.token_name,
          quantity == locked_tokens,
          in_address == Address {
            payment_credential: ScriptCredential(fork_script_hash),
            stake_credential: None,
          },
        }
      }
      Mine -> todo
      NominateUpgradeContract -> todo
      VoteContractToken { .. } -> todo
      ApplyContractVote { .. } -> todo
      ApplyUpgradeContract -> todo
    }
  }
}

validator(tunav2_minting_policy: ByteArray) {
  fn mine(datum: Statev2, redeemer: MineAction, ctx: ScriptContext) -> Bool {
    let Statev2 {
      mining_state: MineState {
        block_number,
        current_hash,
        leading_zeros,
        target_number,
        epoch_time,
        current_posix_time,
      },
      extra: ExtraState { interlink, .. },
    } = datum

    let ScriptContext { transaction, purpose } = ctx

    expect Spend(own_reference) = purpose

    let Transaction { inputs, outputs, mint, validity_range, .. } = transaction

    let mint = value.from_minted_value(mint)

    let own_input = resolve_output_reference(inputs, own_reference)

    let Output { address: in_address, value: in_value, .. } = own_input

    let MineAction { nonce, miner } = redeemer

    // Spend(0) requirement: Contract has only one output with the master token going back to itself
    expect Some(own_output) =
      list.find(outputs, fn(output: Output) { output.address == in_address })

    let Output { datum: out_datum, value: out_value, .. } = own_output

    // Time Range Span is 3 minutes or less 
    let Interval {
      upper_bound: IntervalBound {
        bound_type: upper_range,
        is_inclusive: upper_is_inclusive,
      },
      lower_bound: IntervalBound {
        bound_type: lower_range,
        is_inclusive: lower_is_inclusive,
      },
    } = validity_range

    // We have a constant expectation of the transaction time range
    expect Finite(upper_range) = upper_range
    expect Finite(lower_range) = lower_range
    let averaged_current_time = ( upper_range - lower_range ) / 2 + lower_range

    // Posix time is in milliseconds
    // Spend(1) requirement: Time range span is 3 minutes or less and inclusive
    expect and {
        !upper_is_inclusive?,
        lower_is_inclusive?,
        (upper_range - lower_range <= 180000)?,
      }
    //
    // In case you are wondering here is what enables pools
    // A miner can be a pkh or an nft
    // Nfts can come from any input, even validators
    // So any validator logic can be enforced to run along with fortuna
    expect
      when miner is {
        Pkh(signer) -> list.has(transaction.extra_signatories, signer)
        Nft { policy: nft_policy, name: nft_name, output_index } -> {
          //
          let quantity =
            utils.list_at(outputs, output_index).value
              |> quantity_of(nft_policy, nft_name)
          //
          // Spend(2) requirement: Output has nft
          quantity == 1
        }
      }
    //
    // Target state now includes a miner credential
    let target =
      TargetState {
        nonce,
        block_number,
        epoch_time,
        current_hash,
        leading_zeros,
        target_number,
        miner: blake2b_256(builtin.serialise_data(miner)),
      }

    let found_bytearray =
      target
        |> builtin.serialise_data()
        |> sha2_256()
        |> sha2_256()

    let (found_target_number, found_leading_zeros) =
      fortuna.format_found_bytearray(found_bytearray)

    // Mining Difficulty Met
    // Spend(2) requirement: Found difficulty is less than or equal to the current difficulty
    // We do this by checking the leading zeros and the difficulty number
    expect or {
        (found_leading_zeros > leading_zeros)?,
        and {
          (found_leading_zeros == leading_zeros)?,
          (found_target_number < target_number)?,
        },
      }
    //
    // Spend(3) requirement: Input has master token
    expect
      (quantity_of(in_value, tunav2_minting_policy, fortuna.master_token_name) == 1)?
    //
    // Spend(4) requirement: Only one type of token minted under the validator policy
    expect [(token_name, quantity)] =
      mint
        |> tokens(tunav2_minting_policy)
        |> dict.to_list

    let halving_exponent = block_number / halving_number

    let expected_quantity =
      // This should be 32 not 29
      if halving_exponent > 32 {
        0
      } else {
        initial_payout / math.pow2(halving_exponent)
      }

    // Spend(5) requirement: Minted token is the correct name and amount
    expect and {
        (token_name == fortuna.token_name)?,
        (quantity == expected_quantity)?,
      }
    //
    // Spend(6) requirement: Output has only master token and ada
    expect
      fortuna.value_has_only_master_and_lovelace(
        out_value,
        tunav2_minting_policy,
      )?

    // Check output datum contains correct epoch time, block number, hash, and leading zeros
    // Check for every divisible by 2016 block: 
    // - Epoch time resets
    // - leading zeros is adjusted based on percent of hardcoded target time for 2016 blocks vs epoch time
    // Spend(7) requirement: Expect Output Datum to be of type State
    expect Statev2 {
      mining_state: MineState {
        epoch_time: out_epoch_time,
        block_number: out_block_number,
        current_hash: out_current_hash,
        leading_zeros: out_leading_zeros,
        target_number: out_target_number,
        current_posix_time: out_current_posix_time,
      },
      extra: ExtraState { interlink: out_interlink, extra, .. },
    }: Statev2 = get_inline_datum(out_datum)

    // Spend(8) requirement: Check output has correct difficulty number, leading zeros, and epoch time
    expect
      if block_number % epoch_number == 0 && block_number > 0 {
        // use total epoch time with target epoch time to get difficulty adjustment ratio
        // ratio maxes out at 4/1 and mins to 1/4
        let total_epoch_time =
          epoch_time + averaged_current_time - current_posix_time
        let (adjustment_numerator, adjustment_denominator) =
          fortuna.get_difficulty_adjustment(total_epoch_time)
        // Now use ratio to find new leading zeros difficulty
        let (new_difficulty, new_leading_zeroes) =
          fortuna.get_new_difficulty(
            target_number,
            leading_zeros,
            adjustment_numerator,
            adjustment_denominator,
          )
        //
        and {
          (new_leading_zeroes == out_leading_zeros)?,
          (new_difficulty == out_target_number)?,
          (0 == out_epoch_time)?,
        }
      } else {
        let new_epoch_time =
          epoch_time + averaged_current_time - current_posix_time
        // 
        and {
          (leading_zeros == out_leading_zeros)?,
          (target_number == out_target_number)?,
          (new_epoch_time == out_epoch_time)?,
        }
      }
    //
    and {
      // Spend(9) requirement: Output posix time is the averaged current time
      (out_current_posix_time == averaged_current_time)?,
      // Spend(10) requirement: Output block number is the input block number + 1 
      (block_number + 1 == out_block_number)?,
      // Spend(11) requirement: Output current hash is the target hash
      (out_current_hash == found_bytearray)?,
      //Spend(12) requirement: Check output extra field is within a certain size
      (builtin.length_of_bytearray(builtin.serialise_data(extra)) <= 512)?,
      // Spend(13) requirement: Check output interlink is correct
      (fortuna.calculate_interlink(
        interlink,
        found_bytearray,
        found_leading_zeros,
        found_target_number,
        target_number,
        leading_zeros,
      ) == out_interlink)?,
    }
  }
}
