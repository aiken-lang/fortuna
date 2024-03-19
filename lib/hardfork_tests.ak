use hardfork.{calculate_emission, check_block_signal}

test calculate_emission_1() {
  calculate_emission(3000) == 15000000000000
}

test calculate_emission_2() {
  calculate_emission(210000) == 1050000000000000
}

test calculate_emission_3() {
  calculate_emission(210001) == 1050002500000000
}

test calculate_emission_4() {
  calculate_emission(0) == 0
}

test calculate_emission_5() {
  calculate_emission(2) == 10000000000
}

/// Final supply of Fortuna is 2099999999755520
test calculate_emission_6() {
  calculate_emission(6_930_001) == 2099999999755520
}

test calculate_emission_7() {
  calculate_emission(6_929_999) == 2099999999755519
}

/// Final supply of Fortuna is 2099999999755520
test calculate_emission_8() {
  calculate_emission(6_930_000) == 2099999999755520
}

test check_block_signal_1() {
  check_block_signal(0, 1000, 0, 1)
}

test check_block_signal_2() {
  check_block_signal(0, 1001, 0, 0)
}

test check_block_signal_3() {
  check_block_signal(1, 1000, 0, 1)
}

test check_block_signal_4() {
  check_block_signal(1000, 1000, 0, 1)
}

test check_block_signal_5() {
  check_block_signal(0, 1000, 10, 11)
}

/// Technically increase can happen after hardfork block height, 
/// but since hardfork must occur at the blockheight this doesnt matter
test check_block_signal_6() {
  check_block_signal(1001, 1000, 10, 11)
}
