<script lang="ts">
  import { onMount } from 'svelte';
  import { fromText, type Cardano } from 'translucent-cardano';

  import geroIcon from '$lib/assets/geroicon.png';
  import fortunaIconBlack from '$lib/assets/fortunaIconBlack.png';
  import { walletApi, v1TunaAmount, wallet, userAddress, translucent } from '$lib/store';
  import { V1_TUNA_POLICY_ID } from '$lib/constants';

  let open = false;

  let wallets: [string, Cardano['']][] = [];

  // change to the new address later OR just hide/delete this component inside /Navbar.svelte after the hardfork
  let tunaMinswap =
    'https://app.minswap.org/pt-BR/swap?currencySymbolA=&tokenNameA=&currencySymbolB=279f842c33eed9054b9e3c70cd6a3b32298259c24b78b895cb41d91a&tokenNameB=54554e41';

  const WalletNames = [
    'flint',
    'nami',
    'eternl',
    'gerowallet',
    'nufi',
    'begin',
    'lace',
    'yoroi',
    'begin',
    'typhoncip30',
  ];

  function disconnect() {
    $wallet = undefined;
    $walletApi = undefined;
  }

  async function connect(walletKey: string) {
    $wallet = window.cardano?.[walletKey];

    $walletApi = await $wallet?.enable();

    $translucent?.selectWallet($walletApi!);

    open = false;
  }

  $: if ($walletApi && !$v1TunaAmount) {
    (async () => {
      //const stakeAddr = await walletApi.getRewardAddresses();
      //const stakeAddrHex = stakeAddr[0];

      // the stakeAddrHex value needs to be converted to bench32
      // and passed in the function below replacing userAddr

      $userAddress = await $translucent?.wallet.address();

      console.log('User address:', $userAddress);

      if ($userAddress && $translucent) {
        const utxos = await $translucent.utxosAt($userAddress);

        $v1TunaAmount = utxos.reduce((acc, u) => {
          return acc + (u.assets[V1_TUNA_POLICY_ID + fromText('TUNA')] ?? 0n);
        }, 0n);
      }
    })();
  }

  onMount(async () => {
    if (typeof window.cardano !== 'undefined') {
      wallets = Object.entries(window.cardano)
        .filter(([key, value]) => typeof value === 'object' && WalletNames.includes(key))
        .map(([key, value]) => [key, value]);

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

{#if $walletApi && $wallet}
  <div class="dropdown dropdown-hover dropdown-left md:dropdown-right md:dropdown-bottom">
    <div tabIndex={0} role="button" class="btn btn-accent btn-outline">
      <img
        src={$wallet.name === 'GeroWallet' ? geroIcon : $wallet.icon}
        alt="logo"
        class="w-6 h-6 justify-center" />
    </div>
    <ul
      tabIndex={0}
      class="dropdown-content bg-slate-800 z-[1] menu md:-ml-36 p-2 shadow rounded-box w-52 gap-1">
      {#if $v1TunaAmount > 0}
        <li class="mt-2">
          <button class="indicator w-full btn btn-sm btn-accent">
            <img src={fortunaIconBlack} alt="fortuna icon" class="w-4 h-4 justify-center" />
            {($v1TunaAmount / 100_000_000n).toLocaleString('en-US')}
          </button>
        </li>
      {:else}
        <li class="mt-2">
          <button class="indicator w-full btn btn-sm btn-accent">
            <img src={fortunaIconBlack} alt="fortuna icon" class="w-6 h-6 justify-center" /> You have
            no Tuna
          </button>
        </li>
      {/if}
      {#if $v1TunaAmount > 0}
        <li class="mt-2">
          <button class="indicator w-full btn btn-sm">
            <span class="indicator-item indicator-top indicator-end badge badge-secondary">
              TUNA V2
            </span>
            <a href="/hardfork">Lock Tuna</a>
          </button>
        </li>
      {:else}
        <li class="mt-2">
          <button class="indicator w-full btn btn-sm">
            <span class="indicator-item indicator-top indicator-end badge badge-secondary">
              Mine Now
            </span>
            <a href="/mine">Get Tuna</a>
          </button>
        </li>

        <li class="">
          <button class=" w-full btn btn-sm">
            <a href={tunaMinswap} target="_blank">Buy on Minswap</a>
          </button>
        </li>
      {/if}

      <li class="mt-4">
        <button class="btn btn-danger" on:click={disconnect}>Disconnect</button>
      </li>
    </ul>
  </div>
{:else}
  <button
    class="btn btn-primary"
    on:click={(e) => {
      open = true;
    }}>Connect</button>
  <dialog id="my_modal_1" class="modal modal-middle" {open}>
    <div class="modal-box flex flex-col border border-gray-700 bg-base-300 gap-4 md:gap-8">
      <h3 class="font-bold text-lg text-center">Select a wallet</h3>

      {#each wallets as [key, value]}
        <button
          class="btn btn-ghost flex items-center justify-center gap-2"
          on:click={(e) => {
            e.preventDefault();

            connect(key);
          }}>
          <img
            src={value.name === 'GeroWallet' ? geroIcon : value.icon}
            alt={value.name}
            class="w-6 h-6" />
          <span class="capitalize">{value.name}</span>
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
