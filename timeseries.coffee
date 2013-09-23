class window.TimeSeriesAnalyzer

  data: 0
  width: 300
  height: 100
  padding: 10
  format: d3.time.format("%Y-%m-%d %H:%M:%S")
  x: d3.time.scale()
  y: d3.scale.linear()
  line: d3.svg.line().x((d) -> d.x ).y((d) -> d.y ).interpolate("monotone")
  x_functor: d3.functor (d) -> d.timestamp
  y_functor: d3.functor (d) -> d.response
  z_functor: d3.functor (d) -> d.name
  millis_to_date: d3.functor (d) -> new Date(@x_functor(d))  

  constructor: (source) ->
    @data = source
    @data.forEach (d) ->
      d.timestamp = +d.timestamp
      d.response = +d.response
    @data = @data.sort (a,b) -> d3.ascending(a.timestamp, b.timestamp)

  # TimeSeriesAnalyzer.names(): A set of all names in the data series
  names: => d3.set(@data.map @z_functor).values()

  # TimeSeriesAnalyzer.filter(): Obtain a subset of data based on series name
  snap: (name) => @data.filter (p) => @z_functor(p) == name

  # TimeSeriesAnalyzer.stats(): Provide statistics summary for a time series array
  # accessor  : functor to access the values in array
  # constraint: string to filter name of timeseries
  stats: (accessor, constraint) ->    
    attr = accessor || @y_functor
    if constraint?
      subset = @snap(constraint)
    else
      subset = @data

    {
      mean: +d3.mean(subset, attr)
      min: +d3.min(subset,attr),
      max: +d3.max(subset,attr),
      count: +subset.length,
      sd: +Math.sqrt(science.stats.variance( subset.map(attr) ))
    }

  point: (item) => {x: @x(@x_functor(item)), y:@y(@y_functor(item)) }
  coords: (name) => 
    subset = @snap(name)
    domain_x = d3.extent(subset.map (t) => @millis_to_date(t))    
    @x.domain(domain_x).range([@padding,@width-@padding])     

    domain_y = [0, d3.max(subset.map (t) => @y_functor(t))]    
    @y.domain(domain_y).range([@height, @padding])

    subset.map (d) => [@x(@x_functor(d)), @y(@y_functor(d))]

  loess_coords: (name, range) =>
    subset = @snap(name)

    subset = @aggregate(range, name) if range?

    domain_x = d3.extent(subset.map (t) => @millis_to_date(t))    
    @x.domain(domain_x).range([@padding,@width-@padding])     

    domain_y = [0, d3.max(subset.map (t) => @y_functor(t))]    
    @y.domain(domain_y).range([@height, @padding])

    x_values = subset.map( (d) => @point(d) ).map (d) -> d.x      
    y_values = subset.map( (d) => @point(d) ).map (d) -> d.y
    loess = science.stats.loess().bandwidth(.5)
    loess_data = d3.zip(x_values, loess(x_values, y_values))

  aggregate: (range, tx_name) =>
    nest_in_seconds = d3.nest()
    .key((t) => @format(@millis_to_date(t)) )
    .rollup((t) => d3.mean(t.map(@y_functor)))
    .entries(@data.filter (a) -> a.name == tx_name)

    nest_in_seconds.forEach (u) =>
      u.timestamp = @format.parse(u.key)
      u.response = +u.values
      u

    range_start = nest_in_seconds[0].timestamp
    index_range = 0
    group_range = d3.nest()
    .key((t) -> Math.floor(index_range++/range))
    .rollup((t) => d3.mean(t.map(@y_functor)))
    .entries(nest_in_seconds)

    group_range.map (u) ->
      add_date = range_start.getTime() + parseInt(u.key)*1000*range
      {
        timestamp: new Date(add_date),
        response: +u.values
      }

  graph: (container, serie, range, trend) =>
    subset = @aggregate(range, serie)
    
    domain_x = d3.extent(subset.map (t) => @millis_to_date(t))
    @x.domain(domain_x).range([@padding,@width-@padding])     

    domain_y = [0, d3.max(subset.map (t) => @y_functor(t))]
    @y.domain(domain_y).range([@height, @padding])    

    create = false
    if (d3.select("#" + "#{container}").select("svg").size() == 0 )
      svg = d3.select("#" + "#{container}").append("svg")
      create = true
    else
      svg = d3.select("#" + "#{container}").select("svg")

    svg.attr("width", @width).attr("height", @height)
    svg.selectAll("text").remove()
    svg.append("text").attr("x", @width).attr("y", @padding).text(serie)
    svg.append("text").attr("x", @padding).attr("y", @padding).text( (t,r) => @names().indexOf(serie) )

    if create
      svg.append("path").datum(subset)      
      .attr("d", (d) => @line(d.map (t) => @point(t)))
      .attr("class", "mosaic")
    else      
      svg.select("path").datum(subset)      
      .attr("d", (d) => @line(d.map (t) => @point(t)))


    svg.selectAll("path.loess").remove()
    if trend      
      x_values = subset.map( (d) => @point(d) ).map (d) -> d.x      
      y_values = subset.map( (d) => @point(d) ).map (d) -> d.y
      loess = science.stats.loess().bandwidth(.5)
      loess_data = d3.zip(x_values, loess(x_values, y_values))
      loess_subset = loess_data.map (p) -> {x:p[0], y:p[1]}
      
      svg.append("path").datum(loess_subset)
      .attr("d", (d) => @line(d))
      .attr("class", "loess")    
      
    svg.size()?

  dna: (name, splits=7, bandwidth=.2) ->
    # DNA of graph
    pattern_dna = ["a", "b", "c", "d", "e", "f"]

    subset = @snap(name)
    data_size = subset.length
    
    slice = Math.ceil(data_size/splits)    
    index_position = 0
    
    # Mean Calculation      
    nest_slices = d3.nest().key( (d) -> Math.floor(index_position++/slice)).rollup( (d) => d3.mean(d.map(@y_functor))).entries(subset)    
  
    # Loess Regresion
    science.stats.loess().bandwidth(bandwidth)

    pattern_scale = d3.scale.linear().domain([@height,@padding]).rangeRound([0,5])
    dna_code = ""
    @y.domain([0, d3.max(nest_slices.map (d) -> d.values)]).range([@height, @padding])

    nest_slices.forEach (d) =>
      dna_code += pattern_dna[pattern_scale(@y(d.values))]
    dna_code

  genetic: =>
    @names().map (d) => @dna(d)

  barebone: =>
    d3.set(@genetic()).values()



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

