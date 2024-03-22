<script lang="ts">
    import { Chart, Svg, Bars, Tooltip, TooltipItem } from "layerchart";
    import { scaleBand } from "d3-scale";
    import { afterUpdate } from 'svelte';

    export let data: any = [];
    
    afterUpdate(() => {
      data.map(d => ({
        ...d,
        epoch_time: new Date(d.epoch_time * 1000)
      }));
    });
    </script>
    
    <div class="w-full h-full">
        <Chart {data} x="date" xScale={scaleBand()} y="value" yDomain={[0, null]}>
            <Svg>
              <Bars strokeWidth={1} class="fill-primary/20 stroke-primary" />
            </Svg>
            <Tooltip class="bg-base-300" header={(data) => format(data.date, 'eee, MMMM do')} let:data>
                <TooltipItem label="Mined" value={data.value} />
              </Tooltip>
          </Chart>
    </div>