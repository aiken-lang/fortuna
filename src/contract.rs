use async_trait::async_trait;
use chrono::{DateTime, Utc};
use naumachia::scripts::raw_validator_script::plutus_data::{Constr, PlutusData};
use naumachia::{
    address::PolicyId,
    backend::Backend,
    ledger_client::LedgerClient,
    logic::{SCLogic, SCLogicError, SCLogicResult},
    scripts::{
        raw_policy_script::RawPolicy, raw_validator_script::RawPlutusValidator, MintingPolicy,
        ScriptError, ScriptResult, ValidatorCode,
    },
    smart_contract::{SmartContract, SmartContractTrait},
    transaction::TxActions,
    trireme_ledger_client::get_trireme_ledger_client_from_file,
    values::Values,
};
use sha2::{Digest, Sha256};
use thiserror::Error;

use crate::queries::FortunaQuery;
use crate::{
    datums::State,
    error, mutations, queries,
    redeemers::{FortunaRedeemer, InputNonce, MintingState},
    Puzzle,
};

const SCRIPT_VALUES: &str = include_str!("../genesis/mainnet.json");
pub const MASTER_TOKEN_NAME: &str = "lord tuna";
pub const TOKEN_NAME: &str = "TUNA";
pub const CONVERSION_TIME_SEC: u64 = 1691996128;
pub const SLOT_OFFSET: u64 = 25325728;

#[derive(Error, Debug)]
pub enum FortunaError {
    #[error("No datum found")]
    DatumNotFound,
    #[error("Output containing NFT not found")]
    MasterTokenNotFound,
}

#[derive(Debug, PartialEq, Eq)]
pub struct Fortuna;

#[async_trait]
impl SCLogic for Fortuna {
    type Endpoints = mutations::FortunaMutation;
    type Lookups = queries::FortunaQuery;
    type LookupResponses = queries::FortunaQueryResponse;
    type Datums = State;
    type Redeemers = FortunaRedeemer;

    async fn handle_endpoint<Record: LedgerClient<Self::Datums, Self::Redeemers>>(
        endpoint: Self::Endpoints,
        ledger_client: &Record,
    ) -> SCLogicResult<TxActions<Self::Datums, Self::Redeemers>> {
        use mutations::FortunaMutation::*;

        match endpoint {
            Genesis { output_reference } => {
                let hasher = Sha256::new_with_prefix(output_reference);

                let hasher = Sha256::new_with_prefix(hasher.finalize());

                let current_hash = hasher.finalize();

                let current_utc: DateTime<Utc> = Utc::now();

                let current_time_off_chain = current_utc.timestamp() as u64;
                let current_time_on_chain = current_time_off_chain + 45;

                let current_slot_time = calculate_slot_from_epoch_time(current_time_off_chain);

                let datum = State::genesis(current_hash.to_vec(), current_time_on_chain);

                let network = ledger_client
                    .network()
                    .await
                    .map_err(|err| SCLogicError::Endpoint(err.into()))?;

                let (spend, mint) =
                    tuna_validators().map_err(|e| SCLogicError::Endpoint(e.into()))?;

                let address = spend
                    .address(network)
                    .map_err(|e| SCLogicError::Endpoint(Box::new(e)))?;

                let mut values = Values::default();

                let policy_id =
                    PolicyId::NativeToken(mint.id().unwrap(), Some(MASTER_TOKEN_NAME.to_string()));

                values.add_one_value(&policy_id, 1);

                let actions = TxActions::v2()
                    .with_script_init(datum, values, address)
                    .with_mint(
                        1,
                        Some(MASTER_TOKEN_NAME.to_string()),
                        FortunaRedeemer::Mint(MintingState::Genesis),
                        Box::new(mint),
                    )
                    .with_valid_range_secs(
                        Some(current_slot_time.try_into().unwrap()),
                        Some((current_slot_time + 90).try_into().unwrap()),
                    );

                Ok(actions)
            }
            Mine {
                block_data,
                redeemer,
                current_slot_time,
            } => {
                let network = ledger_client
                    .network()
                    .await
                    .map_err(|err| SCLogicError::Endpoint(err.into()))?;

                let (spend, mint) =
                    tuna_validators().map_err(|e| SCLogicError::Endpoint(e.into()))?;

                let address = spend
                    .address(network)
                    .map_err(|e| SCLogicError::Endpoint(Box::new(e)))?;

                let outputs = ledger_client
                    .all_outputs_at_address(&address)
                    .await
                    .map_err(|err| SCLogicError::Endpoint(err.into()))?;

                let policy_id =
                    PolicyId::NativeToken(mint.id().unwrap(), Some(MASTER_TOKEN_NAME.to_string()));

                let input = outputs
                    .into_iter()
                    .find(|output| output.values().get(&policy_id).is_some())
                    .unwrap();

                let mut values = Values::default();

                values.add_one_value(&policy_id, 1);

                let amount = calculate_amount(block_data.block_number);

                let actions = TxActions::v2()
                    .with_script_init(block_data, values, address)
                    .with_script_redeem(input, FortunaRedeemer::Spend(redeemer), Box::new(spend))
                    .with_mint(
                        amount,
                        Some(TOKEN_NAME.to_string()),
                        FortunaRedeemer::Mint(MintingState::Mine),
                        Box::new(mint),
                    )
                    .with_valid_range_secs(
                        Some(current_slot_time as i64),
                        Some(current_slot_time as i64 + 90),
                    );

                Ok(actions)
            }
            Answer(_) => {
                todo!()
            }
        }
    }

    async fn lookup<Record: LedgerClient<Self::Datums, Self::Redeemers>>(
        query: Self::Lookups,
        ledger_client: &Record,
    ) -> SCLogicResult<Self::LookupResponses> {
        match query {
            FortunaQuery::CurrentBlock => {
                todo!()
            }
            FortunaQuery::LatestPuzzle => {
                let (script, policy) = tuna_validators()?;
                let network = ledger_client.network().await?;
                let address = script.address(network)?;
                let master_token = PolicyId::NativeToken(
                    policy.id().unwrap(),
                    Some(MASTER_TOKEN_NAME.to_string()),
                );

                let outputs = ledger_client.all_outputs_at_address(&address).await?;
                let input = outputs
                    .into_iter()
                    .find(|output| output.values().get(&master_token).is_some())
                    .ok_or(FortunaError::MasterTokenNotFound)
                    .map_err(|e| SCLogicError::Lookup(Box::new(e)))?;
                let state = input
                    .typed_datum()
                    .ok_or(FortunaError::DatumNotFound)
                    .map_err(|e| SCLogicError::Lookup(Box::new(e)))?;
                let current_difficulty_hash = state.current_hash.clone();
                let untyped_datum: PlutusData = state.into();
                let PlutusData::Constr(Constr { fields, .. }) = untyped_datum else {
                    unreachable!()
                };

                let puzzle = Puzzle {
                    current_difficulty_hash,
                    fields,
                };
                Ok(queries::FortunaQueryResponse::Puzzle(puzzle))
            }
        }
    }
}

pub async fn mutate(mutation: mutations::FortunaMutation) -> error::Result<()> {
    let ledger_client = get_trireme_ledger_client_from_file().await?;
    let backend = Backend::new(ledger_client);
    let contract = SmartContract::new(Fortuna, backend);

    contract.hit_endpoint(mutation).await?;

    Ok(())
}

pub async fn genesis(output_reference: Vec<u8>) -> error::Result<()> {
    mutate(mutations::FortunaMutation::Genesis { output_reference }).await
}

pub async fn mine(
    block_data: State,
    redeemer: InputNonce,
    current_slot_time: u64,
) -> error::Result<()> {
    mutate(mutations::FortunaMutation::Mine {
        block_data,
        redeemer,
        current_slot_time,
    })
    .await
}

pub fn tuna_validators() -> ScriptResult<(
    RawPlutusValidator<State, FortunaRedeemer>,
    RawPolicy<FortunaRedeemer>,
)> {
    let values: serde_json::Value = serde_json::from_str(SCRIPT_VALUES)
        .map_err(|e| ScriptError::FailedToConstruct(e.to_string()))?;

    let bytes =
        &values
            .get("validator")
            .and_then(|v| v.as_str())
            .ok_or(ScriptError::FailedToConstruct(
                "validator not found".to_string(),
            ))?;

    let raw_spend_script_validator = RawPlutusValidator::v2_from_cbor(bytes.to_string())
        .map_err(|e| ScriptError::FailedToConstruct(e.to_string()))?;

    let raw_mint_script_validator = RawPolicy::v2_from_cbor(bytes.to_string())
        .map_err(|e| ScriptError::FailedToConstruct(e.to_string()))?;

    Ok((raw_spend_script_validator, raw_mint_script_validator))
}

fn calculate_amount(block_number: u64) -> u64 {
    (50 * 100_000_000) / (2 ^ ((block_number - 1) / 210_000))
}

fn calculate_slot_from_epoch_time(unix_time: u64) -> u64 {
    unix_time - CONVERSION_TIME_SEC + SLOT_OFFSET
}
