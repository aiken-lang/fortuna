<script lang="ts">
import SparkBar from "./SparkBar.svelte";

export let progressValue: number = 49;
export let epochNumber: number = 16;
export let percentNumber: number = 52;
export let daysLeft: number = 7;
export let blockNumbers: any = [];

</script>


<div class="card bg-base-300 w-full h-full p-4">
    <div class="card-title"> Epoch Progress</div>
    <div class="p-4">
        <div class="flex justify-between items-center text-lg">
            <span>Epoch <span class="text-primary font-semibold">{epochNumber}</span></span>
            <span>Ends in <span class="text-primary font-semibold">{daysLeft}</span> days~</span>
        </div>

        <progress class="progress progress-primary " value={progressValue} max="100"></progress>
        <div class="flex justify-end items-center">
            <span>This epoch is <span class="text-primary font-semibold">{percentNumber}%</span> complete</span>
        </div>
    </div>
    <div class="w-full h-full">
    <SparkBar data={blockNumbers} />
    </div>
</div>