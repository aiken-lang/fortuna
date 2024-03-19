use aiken/builtin
use aiken/bytearray
use aiken/cbor
use aiken/fuzz.{
  and_then, bytearray_between, int_at_least, int_between, label, map,
}
use aiken/math
use aiken/math/rational
use aiken/string
use fortuna.{
  calculate_interlink, format_found_bytearray, get_difficulty_adjustment,
  get_new_difficulty,
}
use fortuna/parameters.{epoch_target}

fn bytearray_append_zero(bytes, zeros) -> ByteArray {
  if zeros == 0 {
    bytes
  } else {
    bytearray_append_zero(builtin.append_bytearray(#"00", bytes), zeros - 1)
  }
}

fn bytearray_append_filler_byte(bytes, odd) -> ByteArray {
  if odd {
    builtin.append_bytearray(#"0e", bytes)
  } else {
    builtin.append_bytearray(#"00", bytes)
  }
}

fn epoch_number() -> Fuzzer<Int> {
  int_between(epoch_target / 4, epoch_target * 4)
}

fn epoch_numb_boundary() -> Fuzzer<(Int, Int)> {
  let lower = epoch_target / 4
  let upper = epoch_target * 4

  let first_int <- and_then(int_between(0, lower))

  let second_int <- map(int_at_least(upper))

  (first_int, second_int)
}

fn difficulty_level() -> Fuzzer<(Int, Int)> {
  let difficulty_number <- and_then(int_between(4096, 65535))

  let leading_zeros <- map(int_between(2, 59))

  (difficulty_number, leading_zeros)
}

fn difficulty_adjustment_fuzz() -> Fuzzer<(Int, Int, Int, Int)> {
  let numerator <- and_then(int_between(1, epoch_target * 4))

  let denominator_lower =
    if numerator / 4 == 0 {
      1
    } else {
      numerator / 4
    }

  let denominator <- and_then(int_between(denominator_lower, numerator * 4))

  let (difficulty_number, leading_zeros) <- map(difficulty_level())

  (difficulty_number, leading_zeros, numerator, denominator)
}

fn get_bytes_and_difficulty() -> Fuzzer<(ByteArray, Int, Int)> {
  let (difficulty_number, leading_zeros) <- and_then(difficulty_level())

  let bytearray_size = ( 64 - leading_zeros ) / 2

  let bytes <- map(bytearray_between(bytearray_size, bytearray_size))

  let bytes = bytearray_append_filler_byte(bytes, leading_zeros % 2 == 0)

  let bytes = bytearray_append_zero(bytes, 32 - bytearray_size - 1)

  (bytes, difficulty_number, leading_zeros)
}

fn interlink_create(
  bytes: ByteArray,
  difficulty: Int,
  bytes_as_int: Int,
  current_list: List<Data>,
) -> List<Data> {
  let thing: Data = bytes

  if bytes_as_int < difficulty / 2 {
    [
      thing,
      ..interlink_create(bytes, difficulty / 2, bytes_as_int, current_list)
    ]
  } else {
    current_list
  }
}

test format_found_bytearray_1() {
  format_found_bytearray(#"00000000000000ffdd00000000") == (65501, 14)
}

test format_found_bytearray_2() {
  format_found_bytearray(#"00000101000000ffdd00000000") == (4112, 5)
}

test format_found_bytearray_3() {
  format_found_bytearray(#"ef0001000000000ffdd000000000") == (61184, 0)
}

test format_found_bytearray_4() {
  format_found_bytearray(#"0000000000000000000000010000") == (4096, 23)
}

test format_found_bytearray_5() fail {
  format_found_bytearray(#"00000000000000000000000100") == (1, 23)
}

test format_found_bytearray_6() fail {
  format_found_bytearray(#"00000000000000000000000000") == (4096, 23)
}

test format_found_bytearray_7() {
  format_found_bytearray(#"00000000000000000000001000") == (4096, 22)
}

test format_found_bytearray_8(random_input via get_bytes_and_difficulty()) {
  let (bytes, _, _) = random_input

  let (_, leading_zeros) = format_found_bytearray(bytes)

  let bytearray_position = leading_zeros / 2

  builtin.index_bytearray(bytes, bytearray_position) != 0
}

test format_found_bytearray_9(random_input via get_bytes_and_difficulty()) {
  let (bytes, _, _) = random_input

  let (difficulty_number, leading_zeros) = format_found_bytearray(bytes)

  let bytearray_position = leading_zeros / 2

  let bytearray_offset =
    if leading_zeros % 2 == 0 {
      2
    } else {
      3
    }

  let bytes_sliced =
    builtin.slice_bytearray(bytearray_position, bytearray_offset, bytes)

  let bytes_as_number =
    if leading_zeros % 2 == 0 {
      builtin.bytearray_to_integer(True, bytes_sliced)
    } else {
      builtin.bytearray_to_integer(True, bytes_sliced) / 16
    }

  difficulty_number == bytes_as_number
}

test get_difficulty_adjustment_1() {
  get_difficulty_adjustment(1_209_600_000) == (1_209_600_000, 1_209_600_000)
}

test get_difficulty_adjustment_2() {
  get_difficulty_adjustment(1_200_600_000) == (1_200_600_000, 1_209_600_000)
}

test get_difficulty_adjustment_3() {
  get_difficulty_adjustment(50_000_000_000) == (4, 1)
}

test get_difficulty_adjustment_4() {
  get_difficulty_adjustment(200_000_000) == (1, 4)
}

test get_difficulty_adjustment_5(i via epoch_number()) {
  let (numer, denom) = get_difficulty_adjustment(i)

  expect Some(rat) = rational.new(numer, denom)

  expect Some(lower) = rational.new(1, 4)
  expect Some(upper) = rational.new(4, 1)

  and {
    rational.compare(lower, rat) != Greater,
    rational.compare(upper, rat) != Less,
  }
}

test get_difficulty_adjustment_6(boundaries via epoch_numb_boundary()) {
  let (lower, upper) = boundaries

  let lower = get_difficulty_adjustment(lower)

  let upper = get_difficulty_adjustment(upper)

  and {
    lower == (1, 4),
    upper == (4, 1),
  }
}

test get_new_difficulty_1() {
  get_new_difficulty(20001, 4, 4, 1) == (5000, 3)
}

test get_new_difficulty_2() {
  get_new_difficulty(20001, 4, 1, 4) == (5000, 4)
}

test get_new_difficulty_3() {
  get_new_difficulty(5005, 4, 1, 4) == (20020, 5)
}

test get_new_difficulty_4() {
  get_new_difficulty(9000, 6, 57, 37) == (13864, 6)
}

test get_new_difficulty_5() {
  get_new_difficulty(30000, 4, 3, 1) == (5625, 3)
}

test get_new_difficulty_6() {
  get_new_difficulty(9000, 4, 1, 3) == (48000, 5)
}

test get_new_difficulty_7() {
  get_new_difficulty(9000, 60, 1, 3) == (4096, 60)
}

test get_new_difficulty_8() {
  get_new_difficulty(27000, 2, 3, 1) == (65535, 2)
}

test get_new_difficulty_9(i via difficulty_adjustment_fuzz()) {
  let (difficulty_number, leading_zeros, numerator, denominator) = i

  let (new_difficulty, new_leading_zeros) =
    get_new_difficulty(difficulty_number, leading_zeros, numerator, denominator)

  and {
    new_difficulty >= 4096,
    new_difficulty <= 65535,
    new_leading_zeros <= 60,
    new_leading_zeros >= 2,
  }
}

test interlink_1() {
  let current_hash =
    #"0000000000000000009c40000000000012000000000000000000000000000000"

  let (found_difficulty_number, found_leading_zeros) =
    format_found_bytearray(current_hash)

  let current_hash: Data = current_hash

  calculate_interlink(
    [],
    current_hash,
    found_leading_zeros,
    found_difficulty_number,
    40000,
    5,
  ) == [
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
  ]
}

test interlink_2() {
  let current_hash =
    #"0000000000000000000000000000000101000000000123000000000000000000"

  let (found_difficulty_number, found_leading_zeros) =
    format_found_bytearray(current_hash)

  let current_hash: Data = current_hash

  calculate_interlink(
    [],
    current_hash,
    found_leading_zeros,
    found_difficulty_number,
    40000,
    5,
  ) == [
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
  ]
}

test interlink_3() {
  let prev_hash =
    #"0000000000000000009c40000000000000000000000000000000000000000000"

  let current_hash =
    #"0000000000000000000000000000000101000000000000000000000000000000"

  let (found_difficulty_number, found_leading_zeros) =
    format_found_bytearray(current_hash)

  let current_hash: Data = current_hash
  let prev_hash: Data = prev_hash

  calculate_interlink(
    [prev_hash, prev_hash, prev_hash, prev_hash, prev_hash, prev_hash],
    current_hash,
    found_leading_zeros,
    found_difficulty_number,
    40000,
    5,
  ) == [
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
  ]
}

test interlink_4() {
  let prev_hash =
    #"0000000000000000000000000000000101000000000000000000000000000000"

  let current_hash =
    #"0000000000000000009c40000000000000000000000000000000000000000000"

  let (found_difficulty_number, found_leading_zeros) =
    format_found_bytearray(current_hash)

  let current_hash: Data = current_hash
  let prev_hash: Data = prev_hash

  let current_list =
    [
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
      prev_hash,
    ]

  calculate_interlink(
    current_list,
    current_hash,
    found_leading_zeros,
    found_difficulty_number,
    40000,
    5,
  ) == [
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    current_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
    prev_hash,
  ]
}

test interlink_5(i via get_bytes_and_difficulty()) {
  let (bytes, difficulty_number, leading_zeros) = i

  let x = difficulty_number * math.pow2(4 * ( 64 - leading_zeros - 4 ))

  let (found_difficulty_number, found_leading_zeros) =
    format_found_bytearray(bytes)

  let y =
    interlink_create(bytes, x, builtin.bytearray_to_integer(True, bytes), [])

  // label(
  //   builtin.append_string(
  //     builtin.append_string(
  //       builtin.append_string(@"Bytes :", bytearray.to_hex(bytes)),
  //       builtin.append_string(
  //         @"\n Difficulty Real number: ",
  //         string.from_int(x),
  //       ),
  //     ),
  //     cbor.diagnostic(y),
  //   ),
  // )
  y == calculate_interlink(
    [],
    bytes,
    found_leading_zeros,
    found_difficulty_number,
    difficulty_number,
    leading_zeros,
  )
}
