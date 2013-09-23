require 'csv'
require 'statsample'

elements = []
CSV.open "transactions.tsv", col_sep: "\t", headers: true do |file|
  file.each do |row|
    if row["name"].eql? "/runs"
      elements << Time.at(row["timestamp"].to_i/1000).strftime("%Y-%m-%d %H:%M:%S") + "," + row["response"]
    end
  end
end

elements.sort!()
groups = elements.group_by {|k| k.split(",").first }
counters = []
groups.each_pair {|k,v| counters << {"t" => k, "r" => v.map {|t| t.split(",").last }.to_scale.mean } }
puts counters.map {|v| v["r"]}
