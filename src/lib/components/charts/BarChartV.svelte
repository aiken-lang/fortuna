<script lang="ts">
  import {
    Chart,
    Svg,
    Axis,
    Bars,
    Highlight,
    RectClipPath,
    Tooltip,
    TooltipItem
  } from 'layerchart';
  import { format } from 'date-fns';
  import { scaleBand } from 'd3-scale';

  interface data {
    date: string;
    value: number;
    baseline: number;
  }

  export let data: data[] = [];
  export let title: string = '';
</script>

<div class="card bg-base-300">
  <div class="card-title m-4">{title}</div>
  <div class="card-body h-[300px] p-4">
    <Chart
      {data}
      x="date"
      xScale={scaleBand().padding(0.4)}
      y="value"
      yDomain={[0, null]}
      yNice={4}
      padding={{ left: 16, bottom: 24 }}
      tooltip={{ mode: 'band' }}>
      <Svg label="Bar Chart">
        <Axis placement="bottom" format={(d) => format(d, 'dd MMM ')} rule />
        <Bars
          radius={4}
          strokeWidth={1}
          class="fill-white/95  group-hover:fill-base-300 transition-colors" />
        <Highlight
          area={{
            class: 'fill-black/15'
          }}
          bar={{
            class: 'fill-primary',
            strokeWidth: 1,
            radius: 4
          }} />
      </Svg>
      <Tooltip class="bg-base-300" header={(data) => format(data.date, 'eee, MMMM do')} let:data>
        <TooltipItem label="Mined" value={data.value} />
      </Tooltip>
    </Chart>
  </div>
</div>
