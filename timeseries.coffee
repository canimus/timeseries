class window.TimeSeriesGraph
  constructor: (@data, @container, @width, @height) ->

  width = 300
  height = 100

  format_sec = d3.time.format("%Y-%m-%d %H:%M:%S")
  color = d3.scale.category10()
  x = d3.time.scale()
  y = d3.scale.linear()
  @line = d3.svg.line()

  # Stats analysis of data series
  @ts_stats: (d, accessor) ->
    stats = {
      mean: d3.mean(d,accessor),
      sd: Math.sqrt(science.stats.variance( d.map (p) -> 
        p.response )),    
      min: d3.min(d,accessor),
      max: d3.max(d,accessor),
      count: d.length,
      raw: d
    }

  @ts_roll: (arr) ->
    @ts_stats(arr.map( (d) -> {timestamp:d.timestamp, response:d.response} ), d3.functor( (d) -> d.response ))
    

  # Convert timeseries object into point coordinates
  @pointify: (d) -> 
    { x: x(d["timestamp"]), y: y(d["response"]) }

  @aggregate: (d, range) ->
    index_range = 0
    group_seconds = d3.nest().key((t) -> format_sec(t.timestamp)).rollup((t) -> d3.mean(t.map( (u) -> u.response ))).entries(d)
    group_seconds.forEach (u) ->
      u.timestamp = format_sec.parse(u.key)
      u.response = +u.values
      u
    
    range_start = group_seconds[0].timestamp    
    group_range = d3.nest().key((t) ->       
      Math.floor(index_range++/range)).rollup((t) -> 
      d3.mean(t.map( (u) -> u.response ))).entries(group_seconds)
    
    group_range.forEach (u) ->
      add_date = range_start.getTime() + parseInt(u.key)*1000*range
      u.timestamp = new Date(add_date)
      u.response = +u.values
      u
    
    group_range

  # Handle the canvas rendering of time series
  @graph_data: (rows, range_agg) ->
    inner_data = rows.sort (a,b) -> 
      d3.ascending(+a.timestamp,+b.timestamp)
    inner_data.forEach (d) ->
      d["timestamp"] = new Date(+d["timestamp"])
      d["response"] = +d["response"]

    
    data_by_name = d3.nest().key( (d) -> d.name).rollup( (d) -> TimeSeriesGraph.ts_roll(d) ).entries(inner_data)

    # Names for all transactions
    tx_names = d3.set(inner_data.map (d) -> d.name).values()

    x.domain(d3.extent(inner_data.map (d) -> d["timestamp"])).range([10,width-10])    
    @line.x((d) -> d.x ).y((d) -> d.y ).interpolate("monotone")

    # Create aggregation per minute
    
    # Work with coordinates from time series
    time_series_point = d3.functor(this.pointify)
    points = inner_data.map(time_series_point)

    #canvas = d3.select("#mycanvas").node()
    #context = canvas.getContext("2d")
    #context.lineWidth = .3

    data_by_name.forEach (serie, serie_idx) ->
      svg = d3.select("#graph").append("svg")
      svg.attr("width", width).attr("height", height)
      svg.append("text").attr("x", width).attr("y", 10).text( (d) -> serie.key)
      svg.append("path").datum(serie)      
      .attr("d", (d) ->
        inner_serie = TimeSeriesGraph.aggregate(d.values.raw, range_agg)
        y.domain([0, d3.max(inner_serie.map (d) -> d["response"])]).range([height, 10])
        TimeSeriesGraph.line(inner_serie.map(TimeSeriesGraph.pointify))
      ).attr("class", "mosaic")

    data_by_name


