<script lang="ts">
  import LatestBlocks from '$lib/components/charts/LatestBlocks.json';
  import { format, differenceInMinutes } from 'date-fns';
  // icons
  import BxCommentError from '~icons/bx/comment-error'
  import MaterialSymbolsLightBolt from '~icons/material-symbols-light/bolt'
  import Carbon3dSoftware from '~icons/carbon/3d-software'
  import MdiArrowTopRightBoldBoxOutline from '~icons/mdi/arrow-top-right-bold-box-outline'
  import TdesignBlockchain from '~icons/tdesign/blockchain'
  import MaterialSymbolsDeployedCodeAccount from '~icons/material-symbols/deployed-code-account'
  import MaterialSymbolsFitbitArrowUpward from '~icons/material-symbols/fitbit-arrow-upward'
  import MaterialSymbolsFitbitArrowDownwardSharp from '~icons/material-symbols/fitbit-arrow-downward-sharp'

import SparklineChart from './charts/SparklineChart.svelte';
 
export let marketData: any = [];

let priceUp: boolean = true;

// marketData should return information to be displayed not only in sparkline chart
// but also inside the card with the market information as marketData.supply marketData.volume etc

</script>
<div role="alert" class="alert alert-error my-6">
 <BxCommentError class="shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24"/>
  <span>WARNING: The explorer is under construction and the data here is not accurate or real for now.</span>
</div>

<div class="flex gap-4">

  <div class="card bg-base-300 w-[100vh] h-[45vh] p-4">
    <div class="card-title">$TUNA Market</div>
    <div class="card-body">
      <div class="grid grid-cols-4 grid-rows-2 gap-2">
        <div class="col-start-1">
          <div class="flex-row">
            <span class="text-sm font-light">Circulating Supply</span><br />
            <span class="text-3xl font-bold text-primary"
              >◎ 1.5<span class="text-primary/40">M</span></span
            ><br />
            <span class="text-sm font-light">of 21M: </span><span
              class="text-sm font-light text-primary">
              7.6%</span>
          </div>
        </div>
        <div class="col-start-1 border-t-2 border-primary pt-2">
          <div class="flex-row">
            <span class="text-sm font-light">Volume 24h</span><br />
            <span class="text-3xl font-bold text-primary">452.00 ₳</span><br />
            <span class="text-sm font-light">Total Liquidity: </span><span
              class="text-sm font-light text-primary">
              6K ₳</span>
          </div>
        </div>
        <div class=" col-start-2 col-end-5 row-start-1">
          <div class="flex justify-between items-center">
            <div>
              <span class="text-sm font-light">TUNA Price</span><br />
              <span class="text-6xl font-bold text-primary">0,0905 <span class="text-primary/70 font-medium">₳</span></span><br />
              <div class="flex items-center">
              <span class="text-sm font-light">Price change: </span>
              {#if priceUp}<span
                class="text-sm font-light text-success flex items-center"><MaterialSymbolsFitbitArrowUpward class="size-6"/> 3,00%</span>
                {:else}
                <span
                class="text-sm font-light text-error flex items-center"><MaterialSymbolsFitbitArrowDownwardSharp class="size-6"/> 3,00%</span>
                {/if}
              </div>
            </div>
            <div>
              <span class="text-sm font-light"
                >Holders: <span class="font-semibold text-primary">999</span></span
              ><br />
              <span class="text-sm font-light"
                ><span class="font-semibold text-primary">1</span> ADA:
                <span class="font-semibold text-primary">11.04 TUNA</span></span>
            </div>
          </div>
        </div>
        <div class=" col-start-2 col-end-5 row-start-2 pt-2">
          <SparklineChart data={marketData} />
        </div>
      </div>
    </div>
  </div>

  <div class="card bg-base-300 w-[70vh] h-[45vh] p-4">
    <div class="card-title mb-4">
      Latest Blocks<span class="badge badge-success text-white"><MaterialSymbolsLightBolt class="shrink-0 size-5" fill="none" viewBox="0 0 24 24"/> LIVE</span>
    </div>
    <div class="overflow-y-auto hide-scrollbar">
      {#each LatestBlocks as data (data.blockNumber)}
        <div class="flex">
          <div class="card bg-base-100 w-full m-2">
            <div class="flex items-center m-2">
              <div><Carbon3dSoftware class="shrink-0 size-10 text-white" fill="none" /> </div>
              <div>
                <div
                  class="tooltip"
                  data-tip="012366e8bdd0fe504d56c00f0fd7fd29f843ed2c69eeeb754a77acf">
                  <div class="text-2xl font-semibold ml-2 text-accent">{data.blockNumber}</div>
                </div>
                <div
                  class="tooltip"
                  data-tip={format(new Date(data.blockTime), "dd/MM/yyyy 'at' hh:mm a")}>
                  <div class="badge badge-neutral ml-2">
                    {differenceInMinutes(new Date(), new Date(data.blockTime))} minutes ago
                  </div>
                  <div class="badge badge-warning">
                    +{data.minted} $TUNA
                  </div>
                </div>
              </div>
              <div class="ml-auto text-right">
                <div class="text-lg font-semibold flex">
                  <a href="https://cardanoscan.io/transaction/{data.mintTx}" target="_blank">
                    <span class="link link-primary link-hover flex">
                      {data.mintTx.slice(0, 4)}...{data.mintTx.slice(-8)}<span class="ml-2"
                        ><MdiArrowTopRightBoldBoxOutline class="size-5 shrink-0"/></span>
                    </span>
                  </a>
                </div>
                {#if data.isPool}
                  <div class="tooltip" data-tip="Minted by a Pool">
                    <div class="badge badge-accent">
                      <TdesignBlockchain class="size-4"/><span class="ml-1">{data.poolTicker}</span>
                    </div>
                  </div>
                {:else}
                  <div class="tooltip" data-tip="Minted by a single Miner">
                    <div class="badge badge-secondary">
                      <MaterialSymbolsDeployedCodeAccount class="size-5 shrink-0"/>
                      <span class="ml-1"> {data.miner.slice(0, 5)}...{data.miner.slice(-4)}</span>
                    </div>
                  </div>
                {/if}
              </div>
            </div>
          </div>
        </div>
      {/each}
    </div>
  </div>
</div>
