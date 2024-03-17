<script lang="ts">
  import { onMount } from 'svelte';
  import { type WalletOption, type WalletApi } from '../app.d';
  import { Constr, Translucent, C, Data } from 'translucent-cardano';

  let open = false;
  let walletApi: WalletApi | undefined;
  let wallet: WalletOption | undefined;
  let tunaBalance = 0;
  let wallets: [string, WalletOption][] = [];

  // button states
  let locking = false;

  async function connect(walletKey: string) {
    wallet = window.cardano?.[walletKey];
    walletApi = await wallet?.enable();

    open = false;
  }

  async function lockTuna() {
    locking = true;

    if (walletApi && wallet) {
      // TODO: lock $TUNA
      const lucid = await Translucent.new();

      const tunav1Policy = '';
      const hardforkScriptHash = '';

      const hardforkRewardAddress = lucid.utils.credentialToRewardAddress(
        lucid.utils.scriptHashToCredential(hardforkScriptHash)
      );

      const hardforkAddress = lucid.utils.credentialToAddress(
        lucid.utils.scriptHashToCredential(hardforkScriptHash)
      );

      const forkStateUtxo = (await lucid.utxosAt(hardforkScriptHash))[0];
      const lockStateUtxo = (await lucid.utxosAt(hardforkScriptHash))[1];
      const lockStateNft = '';

      const userTunaUtxos = await lucid.wallet.getUtxos();

      const lockStateDatum = new Constr(2, [5000000000n]);

      const hardforkStateRef = new Constr(0, [
        new Constr(0, [forkStateUtxo.txHash]),
        BigInt(forkStateUtxo.outputIndex)
      ]);

      const userNftOutputRef = new Constr(0, [
        new Constr(0, [userTunaUtxos[0].txHash]),
        BigInt(userTunaUtxos[0].outputIndex)
      ]);

      const userNftName = lucid.utils.datumToHash(Data.to(userNftOutputRef));

      const userNftDatum = new Constr(3, [userNftName]);

      const hardforkRedeemer = new Constr(1, [
        // hard fork state reference input
        hardforkStateRef,
        // lock state output index
        0n,
        // user nft output index
        1n,
        // user NFT ownership proof (for locking more tuna)
        new Constr(1, []),
        // Lock action is UserLock
        new Constr(1, [])
      ]);

      const lockTx = lucid
        .newTx()
        .readFrom([forkStateUtxo])
        .mintAssets({ [hardforkScriptHash + userNftName]: 1n }, Data.to(0n))
        .collectFrom([lockStateUtxo], Data.to(0n))
        .collectFrom(userTunaUtxos)
        .payToContract(
          hardforkAddress,
          { inline: Data.to(lockStateDatum) },
          { [hardforkScriptHash + lockStateNft]: 1n }
        )
        .payToContract(
          hardforkAddress,
          { inline: Data.to(userNftDatum) },
          {
            [tunav1Policy + 'TUNA']: 5000000000n
          }
        )
        .withdraw(hardforkRewardAddress, 0n, Data.to(hardforkRedeemer))
        .complete();
    }

    setTimeout(() => {
      locking = false;
    }, 5000);
  }

  onMount(async () => {
    if (typeof window.cardano !== 'undefined') {
      wallets = Object.entries(window.cardano);

      for (const [key, walletOption] of wallets) {
        const isEnabled = await walletOption.isEnabled();

        if (isEnabled) {
          connect(key);
          break;
        }
      }
    }
  });
</script>

<div>
  <div
    class="flex min-h-[550vh] max-w-[100vw] flex-col items-center justify-start xl:flex-row xl:items-start xl:justify-between">
    <div class="shrink xl:w-1/2">
      <div
        class="flex min-h-[calc(100vh-4rem)] items-center justify-center px-2 py-10 text-center xl:justify-start xl:pe-0 xl:ps-10 xl:text-start">
        <div>
          <h1
            class="font-title xl:w-[115%] xl:text-start text-center text-[clamp(2rem,6vw,4.2rem)] font-black leading-[1.1] [word-break:auto-phrase] [:root[dir=rtl]_&]:leading-[1.35]">
            <span
              class="[&::selection]:text-base-content brightness-150 contrast-150 [&::selection]:bg-blue-700/20">
              Fortuna is a
            </span>
            <br />
            <span class="inline-grid">
              <span
                class="pointer-events-none col-start-1 row-start-1 bg-[linear-gradient(90deg,theme(colors.error)_0%,theme(colors.secondary)_9%,theme(colors.secondary)_42%,theme(colors.primary)_47%,theme(colors.accent)_100%)] bg-clip-text blur-xl [-webkit-text-fill-color:transparent] [transform:translate3d(0,0,0)] before:content-[attr(data-text)] [@supports(color:oklch(0_0_0))]:bg-[linear-gradient(90deg,oklch(var(--s))_4%,color-mix(in_oklch,oklch(var(--s)),oklch(var(--er)))_22%,oklch(var(--p))_45%,color-mix(in_oklch,oklch(var(--p)),oklch(var(--a)))_67%,oklch(var(--a))_100.2%)]"
                aria-hidden="true"
                data-text="Bitcoin PoW">
              </span>
              <span
                class="[&::selection]:text-base-content relative col-start-1 row-start-1 bg-[linear-gradient(90deg,theme(colors.error)_0%,theme(colors.secondary)_9%,theme(colors.secondary)_42%,theme(colors.primary)_47%,theme(colors.accent)_100%)] bg-clip-text [-webkit-text-fill-color:transparent] [&::selection]:bg-blue-700/20 [@supports(color:oklch(0_0_0))]:bg-[linear-gradient(90deg,oklch(var(--s))_4%,color-mix(in_oklch,oklch(var(--s)),oklch(var(--er)))_22%,oklch(var(--p))_45%,color-mix(in_oklch,oklch(var(--p)),oklch(var(--a)))_67%,oklch(var(--a))_100.2%)]">
                Bitcoin PoW
              </span>
            </span>
            <br />
            <span
              class="[&::selection]:text-base-content brightness-150 contrast-150 [&::selection]:bg-blue-700/20">
              Smart Contract
            </span>
          </h1>
          <div class="h-4" />
          <p class="text-base-content/70 font-title py-4 font-light md:text-lg xl:text-2xl">
            The hardfork is coming. In order to prepare for the hardfork<br /> lock your $TUNA by
            clicking this button. Locked $TUNA will<br /> be claimable on a new policy after the hardfork.
          </p>
          <div class="h-10" />
          <div>
            <div
              class="inline-flex w-full flex-col items-stretch justify-center gap-2 px-4 md:flex-row xl:justify-start xl:px-0">
              <a
                data-sveltekit-preload-data
                href="/mine/"
                class="btn md:btn-lg md:btn-wide group rounded-full px-12">
                Mine
              </a>
              <a
                data-sveltekit-preload-data
                href="/hardfork/"
                class="btn btn-neutral md:btn-lg md:btn-wide group rounded-full px-12">
                Hardfork
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  class="hidden h-6 w-6 transition-transform duration-300 group-hover:translate-x-1 rtl:rotate-180 rtl:group-hover:-translate-x-1 md:inline-block">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M17.25 8.25L21 12m0 0l-3.75 3.75M21 12H3" />
                </svg>
              </a>
            </div>
          </div>
        </div>
      </div>
    </div>
    {#if walletApi && wallet}
      <button
        class="btn btn-primary"
        disabled={locking}
        on:click={(e) => {
          e.preventDefault();

          lockTuna();
        }}>Lock $TUNA</button>
    {:else}
      <button
        class="btn btn-primary"
        on:click={(e) => {
          open = true;
        }}>connect</button>
      <dialog id="my_modal_1" class="modal modal-bottom sm:modal-middle" {open}>
        <div class="modal-box flex flex-col gap-8">
          <h3 class="font-bold text-lg">Select a wallet</h3>

          {#each wallets as [key, value]}
            <button
              class="btn btn-ghost flex items-center justify-center gap-2"
              on:click={(e) => {
                e.preventDefault();

                connect(key);
              }}>
              <img src={value.icon} alt={value.name} class="w-6 h-6" />
              {value.name}
            </button>
          {/each}

          <div class="modal-action">
            <form method="dialog">
              <button
                class="btn"
                on:click={(_e) => {
                  open = false;
                }}>Close</button>
            </form>
          </div>
        </div>
        <form method="dialog" class="modal-backdrop">
          <button
            on:click={(_e) => {
              open = false;
            }}>close</button>
        </form>
      </dialog>
    {/if}
  </div>
</div>
