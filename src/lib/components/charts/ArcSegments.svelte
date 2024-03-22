<script lang="ts">
  import { Chart, Svg, Arc, Group, Text } from 'layerchart';

  export let value: number;
  export let segments: number;
  export let title: string;
</script>

<div class="card bg-base-300 size-full p-4">
  <div class="card-title">{title}</div>
  <div class="h-full w-full p-8 rounded card-body">
    <Chart>
      <Svg>
        <Group center>
          {#each { length: segments } as _, segmentIndex}
            {@const segmentAngle = (2 * Math.PI) / segments}
            {@const startAngle = segmentIndex * segmentAngle}
            {@const endAngle = (segmentIndex + 1) * segmentAngle}
            {value}
            <Arc
              {startAngle}
              {endAngle}
              innerRadius={-20}
              cornerRadius={4}
              padAngle={0.02}
              class={(segmentIndex / segments) * 100 < value ? 'fill-primary' : 'fill-gray-700'}>
              <Text
                value={Math.round(value)}
                textAnchor="middle"
                verticalAnchor="middle"
                dy={16}
                class="text-6xl fill-white" />
            </Arc>
          {/each}
        </Group>
      </Svg>
    </Chart>
  </div>
</div>
