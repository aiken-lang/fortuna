use aiken/builtin
use aiken/dict
use aiken/transaction/value.{PolicyId, Value, tokens}
use fortuna/parameters.{epoch_target, padding}

pub const master_token_name = "lord tuna"

pub const token_name = "TUNA"

pub fn format_found_bytearray(target: ByteArray) -> (Int, Int) {
  let leading_zeros = find_first_nonzero_byte(target, 0)
  let bytearray_position = leading_zeros / 2

  // difficulty number takes the next 16 bits after the leading zeros
  // we truncate off since we only need 2 bytes of difficulty number
  // our comparison is that this difficulty number is less than the target difficulty number
  if leading_zeros % 2 == 0 {
    let difficulty_number =
      builtin.index_bytearray(target, bytearray_position) * 256 + builtin.index_bytearray(
        target,
        bytearray_position + 1,
      )

    (difficulty_number, leading_zeros)
  } else {
    let difficulty_number =
      builtin.index_bytearray(target, bytearray_position) * 4096 + builtin.index_bytearray(
        target,
        bytearray_position + 1,
      ) * 16 + builtin.index_bytearray(target, bytearray_position + 2) / 16

    (difficulty_number, leading_zeros)
  }
}

fn find_first_nonzero_byte(bytes: ByteArray, current_index: Int) -> Int {
  let current_byte = builtin.index_bytearray(bytes, current_index)

  if current_byte == 0 {
    2 + find_first_nonzero_byte(bytes, current_index + 1)
  } else if current_byte < 16 {
    1
  } else {
    0
  }
}

test find_first_nonzero_byte_1() {
  find_first_nonzero_byte(#"00000000000000ffdd00000000", 0) == 14
}

test find_first_nonzero_byte_2() {
  find_first_nonzero_byte(#"000001000000000ffdd000000000", 0) == 5
}

test find_first_nonzero_byte_3() {
  find_first_nonzero_byte(#"ef0001000000000ffdd000000000", 0) == 0
}

test find_first_nonzero_byte_4() {
  find_first_nonzero_byte(#"00000000000000000000000100", 0) == 23
}

pub fn value_has_only_master_and_lovelace(
  val: Value,
  own_policy: PolicyId,
) -> Bool {
  expect [(policy1, amount1), (policy2, amount2)] =
    val
      |> value.to_dict
      |> dict.to_list()

  if policy1 == value.ada_policy_id {
    // Should always reach here since maps come in ordered on chain
    expect [(token_name, quantity)] = amount2 |> dict.to_list()

    policy2 == own_policy && (
      quantity == 1 && token_name == master_token_name
    )
  } else {
    expect [(token_name, quantity)] = amount1 |> dict.to_list()

    policy1 == own_policy && (
      quantity == 1 && token_name == master_token_name
    )
  }
}

pub fn value_contains_master_token(val: Value, own_policy: PolicyId) -> Bool {
  expect [(token_name, quantity)] =
    val
      |> tokens(own_policy)
      |> dict.to_list()

  token_name == master_token_name && quantity == 1
}

pub fn get_difficulty_adjustment(total_epoch_time: Int) -> (Int, Int) {
  if
  epoch_target / total_epoch_time >= 4 && epoch_target % total_epoch_time > 0{
  
    (1, 4)
  } else if total_epoch_time / epoch_target >= 4 && total_epoch_time % epoch_target > 0 {
    (4, 1)
  } else {
    (total_epoch_time, epoch_target)
  }
}

pub fn get_new_difficulty(
  difficulty_number: Int,
  current_leading_zeros: Int,
  adjustment_numerator: Int,
  adjustment_denominator: Int,
) -> (Int, Int) {
  let new_padded_difficulty =
    difficulty_number * padding * adjustment_numerator / adjustment_denominator

  let new_difficulty = new_padded_difficulty / padding

  if new_padded_difficulty / 65536 == 0 {
    if current_leading_zeros >= 60 {
      (4096, 60)
    } else {
      (new_padded_difficulty, current_leading_zeros + 1)
    }
  } else if new_difficulty / 65536 > 0 {
    if current_leading_zeros <= 2 {
      (65535, 2)
    } else {
      (new_difficulty / padding, current_leading_zeros - 1)
    }
  } else {
    (new_difficulty, current_leading_zeros)
  }
}

pub fn calculate_interlink(
  interlink: List<Data>,
  current_hash: Data,
  found_leading_zeros: Int,
  found_difficulty_number: Int,
  difficulty_number: Int,
  leading_zeros: Int,
) -> List<Data> {
  let (quarter_difficulty, quarter_leading_zeroes) =
    get_new_difficulty(difficulty_number, leading_zeros, 1, 4)

  if
  found_leading_zeros > quarter_leading_zeroes || found_leading_zeros == quarter_leading_zeroes && found_difficulty_number < quarter_difficulty{
  
    when interlink is {
      [] ->
        [
          current_hash,
          current_hash,
          ..calculate_interlink(
            [],
            current_hash,
            found_leading_zeros,
            found_difficulty_number,
            quarter_difficulty,
            quarter_leading_zeroes,
          )
        ]
      [_] ->
        [
          current_hash,
          current_hash,
          ..calculate_interlink(
            [],
            current_hash,
            found_leading_zeros,
            found_difficulty_number,
            quarter_difficulty,
            quarter_leading_zeroes,
          )
        ]
      [_, _, ..rest] ->
        [
          current_hash,
          current_hash,
          ..calculate_interlink(
            rest,
            current_hash,
            found_leading_zeros,
            found_difficulty_number,
            quarter_difficulty,
            quarter_leading_zeroes,
          )
        ]
    }
  } else {
    do_calculate_interlink(
      interlink,
      current_hash,
      found_leading_zeros,
      found_difficulty_number,
      difficulty_number,
      leading_zeros,
    )
  }
}

fn do_calculate_interlink(
  interlink: List<Data>,
  current_hash: Data,
  found_leading_zeros: Int,
  found_difficulty_number: Int,
  difficulty_number: Int,
  leading_zeros: Int,
) -> List<Data> {
  let (halved_difficulty, halved_leading_zeroes) =
    get_new_difficulty(difficulty_number, leading_zeros, 1, 2)

  if
  found_leading_zeros > halved_leading_zeroes || found_leading_zeros == halved_leading_zeroes && found_difficulty_number < halved_difficulty{
  
    when interlink is {
      [] ->
        [
          current_hash,
          ..do_calculate_interlink(
            [],
            current_hash,
            found_leading_zeros,
            found_difficulty_number,
            halved_difficulty,
            halved_leading_zeroes,
          )
        ]
      [_, ..rest] ->
        [
          current_hash,
          ..do_calculate_interlink(
            rest,
            current_hash,
            found_leading_zeros,
            found_difficulty_number,
            halved_difficulty,
            halved_leading_zeroes,
          )
        ]
    }
  } else {
    interlink
  }
}
