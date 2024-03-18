use aiken/builtin
use aiken/fuzz.{and_then,
  bytearray, int_at_least, int_at_most, int_between, map}
use aiken/math/rational
use fortuna.{format_found_bytearray, get_difficulty_adjustment}
use fortuna/parameters.{epoch_target}

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

test format_found_bytearray_8(bytes via bytearray()) {
  let (_, leading_zeros) = format_found_bytearray(bytes)

  let bytearray_position = leading_zeros / 2

  builtin.index_bytearray(bytes, bytearray_position) != 0
}

test format_found_bytearray_9(bytes via bytearray()) {
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

fn epoch_numb() -> Fuzzer<Int> {
  int_between(epoch_target / 4, epoch_target * 4)
}

fn epoch_numb_boundary() -> Fuzzer<(Int, Int)> {
  let lower = epoch_target / 4
  let upper = epoch_target * 4

  let first_int <- and_then(int_between(0, lower))

  let second_int <- map(int_at_least(upper))

  (first_int, second_int)
}

test get_difficulty_adjustment_5(i via epoch_numb()) {
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
