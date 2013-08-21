class window.TimeSeriesGraph
  constructor: (@data) ->

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

  # Rollup function used to retrive statistics from time series array
  @ts_roll: (arr) -> @ts_stats(arr.map( (d) -> {timestamp:d.timestamp, response:d.response} ), d3.functor( (d) -> d.response ))
    
  # Convert timeseries object into point coordinates  
  @pointify: (d) ->     
    { x: x(d["timestamp"]), y: y(d["response"]) }

  # Produce a subset of array with aggregation of n(range) elements
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

    # Loess regression
    loess = science.stats.loess().bandwidth(.5)

    data_by_name.forEach (serie, serie_idx) ->
      
      svg = d3.select("#graph").append("svg")
      svg.attr("width", width).attr("height", height)
      svg.append("text").attr("x", width).attr("y", 10).text( (d) -> serie.key)

      svg.append("path").datum(serie)      
      .attr("d", (d) ->
        inner_serie = TimeSeriesGraph.aggregate(d.values.raw, range_agg)
        y.domain([0, d3.max(inner_serie.map (d) -> d["response"])]).range([height, 10])
        process_array = inner_serie.map(TimeSeriesGraph.pointify)
        TimeSeriesGraph.line(process_array)
      ).attr("class", "mosaic")

      # Print pattern line
      svg.append("path").datum(serie)      
      .attr("d", (d) ->
        inner_serie = TimeSeriesGraph.aggregate(d.values.raw, range_agg)
        y.domain([0, d3.max(inner_serie.map (d) -> d["response"])]).range([height, 10])
        process_array = inner_serie.map(TimeSeriesGraph.pointify)
        x_values = process_array.map( (d) -> d.x )
        y_values = process_array.map( (d) -> d.y )
        loess_array = d3.zip(x_values, loess(x_values, y_values))
        loess_pointify = loess_array.map (p) -> {x:p[0], y:p[1]}
        pattern_loess = TimeSeriesGraph.pattern_string(loess_pointify, 6, d3.functor( (p) -> p.y ))
        
        TimeSeriesGraph.line(loess_pointify)
      ).attr("class", "loess")
      

    data_by_name

  @loessify_data = (d) ->


  # Obtain a string pattern from time series data in x number of splits
  @pattern_string: (data_arr, splits, data_accessor) ->
    # DNA of graph
    pattern_dna = ["a", "b", "c", "d", "e", "f"]
    data_size = data_arr.length
    slice = Math.ceil(data_size/splits)
    index_position = 0
    # Percentile Calculation
    #nst = d3.nest().key( (d) -> Math.floor(index_position++/slice)).rollup( (d) -> d3.quantile(d.map(data_accessor).sort(d3.ascending), .75 ) ).entries(data_arr)    

    # Mean Calculation
    nst = d3.nest().key( (d) -> Math.floor(index_position++/slice)).rollup( (d) -> d3.median(d.map(data_accessor))).entries(data_arr)    
    

    # Loess Regresion
    science.stats.loess().bandwidth(.2)

    
    pattern_levels = d3.scale.linear().domain([height,10]).rangeRound([0,5])
    dna_code = ""
    y.domain([0, d3.max(nst.map (d) -> d.values)]).range([height, 10])

    nst.forEach (d) ->      
      dna_code += pattern_dna[pattern_levels(y(d.values))]      
    dna_code

