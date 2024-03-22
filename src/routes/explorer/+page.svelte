<script lang="ts">
  import AreaChart from '$lib/components/charts/AreaChart.svelte';
  import BarChartV from '$lib/components/charts/BarChartV.svelte';
  import ArcSegments from '$lib/components/charts/ArcSegments.svelte';
  import BlocksTable from '$lib/components/BlocksTable.svelte';
  import MinersTable from '$lib/components/MinersTable.svelte';


  // Dummy data for the charts, barebones dates and values and tunaInfo 
  import AreaChartData from '$lib/components/charts/AreaChartData.json';
  import BarChartVData from '$lib/components/charts/BarChartVData.json';
  import SparklineData from '$lib/components/charts/SparklineData.json';
  import blocksTableDummy from '$lib/components/charts/blocksTableDummy.json'
  import minersTableDummy from '$lib/components/charts/minersTableDummy.json'

  // curve style for the area chart, those are the ones that can be imported  https://d3js.org/d3-shape/curve
  import { curveStep } from 'd3-shape';

  import LatestBlocks from '$lib/components/LatestBlocks.svelte';
  import ProgressChart from '$lib/components/charts/progressChart.svelte';

  // todo: responsive/mobile tailwind code

  let activeTab = 'blocks';
</script>

<div class="mt-4 mb-[5vw]">
  <div><LatestBlocks marketData={SparklineData}/></div>
  <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mt-4">
    <div class="col-span-4 h-full w-full">
      <BarChartV data={BarChartVData} title="Mined Tuna/Day" />
    </div>
    <div>
      <AreaChart
        data={AreaChartData}
        title="Estimated Hash Power"
        curveType={curveStep}
        placementx="top"
        placementy="right"
        lineClass="stroke-primary stroke-2"
        areaClass="fill-primary/10"
        yValue="value"
        xValue="x"
        hasPoints={true}
        isHighlighted={true} />
    </div>
    
    <div class="">
      <ArcSegments value={8} segments={100} title="Block Difficult" />
    </div>
    <div class="col-span-2">
      <ProgressChart blockNumbers={BarChartVData}/>
    </div>
  </div>
  <div>
    <div class="pt-8 flex justify-center">
      <span class="text-4xl font-semibold">Tuna Index</span>
    </div>
    <div role="tablist" class="tabs tabs-boxed tabs-lg mt-5">
      <span role="tab" class="tab" on:click={() => activeTab = 'blocks'} class:tab-active={activeTab === 'blocks'}>Blocks</span>
      <span role="tab" class="tab" on:click={() => activeTab = 'miners'} class:tab-active={activeTab === 'miners'}>Miners</span>
    </div>
    
    {#if activeTab === 'blocks'}
      <div>
        <BlocksTable data={blocksTableDummy}/>
      </div>
    {:else if activeTab === 'miners'}
      <div>
        <MinersTable data={minersTableDummy}/>
      </div>
    {/if}
  </div>
</div>
