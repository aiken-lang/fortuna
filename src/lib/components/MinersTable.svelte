<script lang="ts">
    import { onMount } from 'svelte';
    import { format } from 'date-fns';
    import MdiArrowTopRightBoldBoxOutline from '~icons/mdi/arrow-top-right-bold-box-outline';
  
    export let data: any;
  
    let currentPage = 1;
    const itemsPerPage = 15;
    let paginatedData: any = [];
  
    onMount(() => {
    data = data.map(item => ({
      ...item,
      first_block: format(new Date(item.first_block), 'dd/MM/yyyy HH:mm:ss'),
      last_block: format(new Date(item.last_block), 'dd/MM/yyyy HH:mm:ss'),
      total_rewards: new Intl.NumberFormat().format(item.total_rewards / 100000000)
    })).sort((a, b) => b.first_block - a.first_block);

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
        <div class="table-cell p-4">Address</div>
        <div class="table-cell p-4">First Block</div>
        <div class="table-cell p-4">Last Block</div>
        <div class="table-cell p-4">Total Blocks</div>
        <div class="table-cell p-4">Total Rewards</div>
      </div>
  
      {#each paginatedData as row (row.address)}
        <div class="table-row-group bg-base-200">
          <div class="table-cell p-4 border-t-2 border-gray-800">
            <a href="https://pool.pm/{row.address}" target="_blank">
              <span class="link link-primary link-hover flex">
                {row.address} <MdiArrowTopRightBoldBoxOutline class="size-5 shrink-0 ml-2"/>
              </span>
            </a>
          </div>
          <div class="table-cell p-4 border-t-2 border-gray-800">{row.first_block}</div>
          <div class="table-cell p-4 border-t-2 border-gray-800">{row.last_block}</div>
          <div class="table-cell p-4 border-t-2 border-gray-800">{row.total_blocks}</div>
          <div class="table-cell p-4 border-t-2 border-gray-800">
            <div class="badge badge-success">{row.total_rewards}</div>
          </div>
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