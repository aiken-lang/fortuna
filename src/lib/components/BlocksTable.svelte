<script lang="ts">
    import { onMount } from 'svelte';
    import { format } from 'date-fns';
    import MdiArrowTopRightBoldBoxOutline from '~icons/mdi/arrow-top-right-bold-box-outline';

   export let data: any;
  
    let currentPage = 1;
  const itemsPerPage = 15;
  let paginatedData = [];

  onMount(() => {
    data = data.map(item => ({
      ...item,
      posix_time: format(new Date(item.posix_time), 'dd/MM/yyyy HH:mm:ss'),
      rewards: (item.rewards / 100000000).toFixed(2)
    })).sort((a, b) => b.posix_time - a.posix_time);

    paginatedData = data.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);
  });

  const changePage = (delta: number) => {
    currentPage += delta;
    paginatedData = data.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);
  };
</script>

  <div>
  <div class="table w-full text-white overflow-hidden rounded-lg shadow-lg mt-4">
    <div class="table-header-group bg-base-300">
      <div class="table-cell p-4">Epoch</div>
      <div class="table-cell p-4">Block</div>
      <div class="table-cell p-4">Leading Zeroes</div>
      <div class="table-cell p-4">Target</div>
      <div class="table-cell p-4">Hash</div>
      <div class="table-cell p-4">Miner</div>
      <div class="table-cell p-4">Rewards</div>
      <div class="table-cell p-4">Time</div>
    </div>
  

      
    {#each paginatedData as row (row.number)}
      <div class="table-row-group bg-base-200">
        <div class="table-cell p-4 border-t-2 border-gray-800">{row.epoch}</div>
        <div class="table-cell p-4 border-t-2 border-gray-800"><div class="badge badge-primary">{row.number}</div></div>
        <div class="table-cell p-4 border-t-2 border-gray-800">{row.leading_zeroes}</div>
        <div class="table-cell p-4 border-t-2 border-gray-800">{row.target.toString(16)}</div>
        <div class="table-cell p-4 border-t-2 border-gray-800">{row.target.toString(16) + row.hash.slice(row.leading_zeroes)}</div>
        <div class="table-cell p-4 border-t-2 border-gray-800">    <a href="https://pool.pm/{row.miner}" target="_blank">
            <span class="link link-primary link-hover flex">
                {row.miner.slice(0, 6) + '…' + row.miner.slice(-6)} <span class="ml-2"
                ><MdiArrowTopRightBoldBoxOutline class="size-5 shrink-0"/></span>
            </span>
          </a></div>
        <div class="table-cell p-4 border-t-2 border-gray-800"><div class="badge badge-success">{row.rewards}</div></div>
        <div class="table-cell p-4 border-t-2 border-gray-800">{row.posix_time}</div>
      </div>
    {/each}
  </div>
  <div class="w-full flex justify-center mt-5">
    <div class="join">
      <button class="join-item btn" on:click={() => changePage(-1)} disabled={currentPage === 1}>«</button>
      <button class="join-item btn">Page {currentPage}</button>
      <button class="join-item btn" on:click={() => changePage(1)} disabled={currentPage === Math.ceil(data.length / itemsPerPage)}>»</button>
    </div>
  </div>
  </div>