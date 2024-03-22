<script lang="ts">
  import {
    Chart,
    Svg,
    Axis,
    Area,
    Points,
    Legend,
    Tooltip,
    TooltipItem,
    Highlight
  } from 'layerchart';
  import { type CurveFactory } from 'd3-shape';
  import { format } from 'date-fns';

  // props to make the AreaChart modular
  export let data: any = [];
  export let title: string = '';
  export let curveType: CurveFactory;
  export let placementy: any;
  export let placementx: any;
  export let areaClass: any;
  export let lineClass: any;
  export let yValue: any;
  export let xValue: any;
  export let hasPoints: boolean;
  export let isHighlighted: boolean;
</script>

<div class="card bg-base-300 max-w-[45vh] p-4">
  <div class="card-title">{title}</div>

  <div class="h-[300px] p-4 rounded card-body">
    <Chart
      {data}
      x={xValue}
      y={yValue}
      yNice
      padding={{ left: 16, bottom: 24 }}
      tooltip={{ mode: 'bisect-x' }}>
      <Svg>
        <Axis tweened placement={placementy} grid rule />
        <Axis tweened placement={placementx} rule />
        <Area
          curve={curveType}
          border={false}
          line={{ class: lineClass }}
          tweened
          class={areaClass} />
        {#if isHighlighted}
          <Highlight points lines />
        {/if}
        {#if hasPoints}
          <Points tweened r={3} class={lineClass} />
        {/if}
      </Svg>
      <Tooltip class="bg-base-300" header={(data) => format(data.date, 'eee, MMMM do')} let:data>
        <TooltipItem label="value" value={data.value} />
      </Tooltip>
    </Chart>
  </div>
</div>
