use aiken/builtin
use aiken/dict
use aiken/transaction.{Datum, InlineDatum, Input, Output, OutputReference} as tx
use aiken/transaction/value.{AssetName, PolicyId, Value}

pub fn resolve_output_reference(
  inputs: List<Input>,
  output_ref: OutputReference,
) -> Output {
  expect [input, ..] = inputs

  if input.output_reference == output_ref {
    input.output
  } else {
    resolve_output_reference(builtin.tail_list(inputs), output_ref)
  }
}

/// Disallows negative values by spiraling off into infinity (or the end of the list)
/// which will cause the transaction to fail.
pub fn list_at(l: List<a>, index: Int) -> a {
  if index == 0 {
    builtin.head_list(l)
  } else {
    list_at(builtin.tail_list(l), index - 1)
  }
}

test list_at_1() {
  list_at([1, 2, 3], 1) == 2
}

test list_at_2() {
  list_at([1, 2, 3], 2) == 3
}

test list_at_3() fail {
  list_at([], 1) == 0
}

test list_at_4() fail {
  list_at([4, 5, 6, 7, 8, 9, 10], -1) == 0
}

pub fn quantity_of(
  val: Value,
  policy_id: PolicyId,
  asset_name: AssetName,
) -> Int {
  when val |> value.to_dict |> dict.get(policy_id) is {
    Some(asset) ->
      when dict.get(asset, asset_name) is {
        Some(quantity) -> quantity
        None -> 0
      }
    None -> 0
  }
}

pub fn value_has_nft_and_lovelace(
  val: Value,
  policy: PolicyId,
  asset_name: AssetName,
) -> Bool {
  expect [(policy1, amount1), (policy2, amount2)] =
    val
      |> value.to_dict()
      |> dict.to_list()

  if policy1 == value.ada_policy_id {
    // Should always reach here since maps come in ordered on chain
    expect [(token_name, quantity)] = amount2 |> dict.to_list()

    and {
      policy2 == policy,
      quantity == 1,
      token_name == asset_name,
    }
  } else {
    expect [(token_name, quantity)] = amount1 |> dict.to_list()

    and {
      policy1 == policy,
      quantity == 1,
      token_name == asset_name,
    }
  }
}

test value_has_nft_and_lovelace_1() {
  let val_t =
    value.from_asset("", "", 1000000)
      |> value.add("policy", "asset", 1)

  value_has_nft_and_lovelace(val_t, "policy", "asset")
}

test value_has_nft_and_lovelace_2() {
  let val_t =
    value.from_asset("", "", 1000000)
      |> value.add("policy", "asset", 2)

  !value_has_nft_and_lovelace(val_t, "policy", "asset")
}

test value_has_nft_and_lovelace_3() fail {
  let val_t =
    value.from_asset("", "", 1000000)
      |> value.add("policy", "asset", 1)
      |> value.add("policy", "asset2", 1)

  value_has_nft_and_lovelace(val_t, "policy", "asset")
}

test value_has_nft_and_lovelace_4() fail {
  let val_t =
    value.from_asset("", "", 1000000)
      |> value.add("policy", "asset", 1)
      |> value.add("policy2", "asset", 1)

  value_has_nft_and_lovelace(val_t, "policy", "asset")
}

pub fn get_inline_datum(datum: Datum) -> Data {
  when datum is {
    InlineDatum(d) -> d
    _ -> fail @"Expected inline datum"
  }
}
