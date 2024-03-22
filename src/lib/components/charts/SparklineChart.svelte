<script lang="ts">
import { Chart, Svg, Area, Tooltip, LinearGradient, RectClipPath, Highlight, Axis } from "layerchart";
import { scaleTime } from "d3-scale";
import { format } from 'date-fns';
export let data: any = [];

  // Parse dates into JavaScript Date objects
  data.forEach(d => {
    d.date = new Date(d.date);
  });


</script>

<div>
    <div class="w-[35rem] h-[8rem]">
      <Chart
      data={data}
      x="date"
      xScale={scaleTime()}
      y="value"
      yDomain={[0, null]}
      yNice
      padding={{ top: 1, bottom: 1 }}
      tooltip={{ mode: "bisect-x" }}
      let:width
      let:height
      let:padding
      let:tooltip
    >
      <Svg>
        <LinearGradient class="from-primary/50 to-primary/0" vertical let:url>
          <Area
            line={{ class: "stroke-2 stroke-primary opacity-20" }}
            fill={url}
          />
          <RectClipPath
            x={0}
            y={0}
            width={tooltip.data ? tooltip.x : width}
            {height}
            spring
          >
            <Area line={{ class: "stroke-2 stroke-primary" }} fill={url} />
          </RectClipPath>
        </LinearGradient>
        <Highlight
          lines={{ class: "stroke-primary [stroke-dasharray:unset]" }}
        />
        
      </Svg>
  
      <Tooltip
        y={48}
        xOffset={4}
        variant="none"
        class="text-sm font-semibold text-primary leading-3 bg-base-300 p-2 border border-base-100 border-l-4 border-l-primary rounded-e-md"
        let:data
      >
      {data.value} ₳
      </Tooltip>
  
      <Tooltip
        x={4}
        y={4}
        variant="none"
        class="text-sm font-semibold leading-3"
        let:data
      >
      {format(data.date, 'yyyy-MM-dd')}
      </Tooltip>
  
      <Tooltip
        x="data"
        y={height + padding.top + 2}
        anchor="top"
        variant="none"
        class="text-sm font-semibold bg-primary text-primary-content leading-3 px-2 py-1 rounded whitespace-nowrap"
        let:data
      >
      {format(data.date, 'yyyy-MM-dd')}
      </Tooltip>
    </Chart>
    </div>
  </div>