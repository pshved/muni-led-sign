#!/usr/bin/ruby
# test

require 'optparse'

require 'muni'
require_relative 'lib/enhanced_open3'

options = {
  :bad_timing => 13,
}
OptionParser.new do |opts|
  opts.banner = "Usage: client.rb --route F --direction inbound --stop 'Ferry Building'"

  opts.on('--route [ROUTE]', "Route to get predictions for") {|v| options[:route] = v}
  opts.on('--direction [inbound/outbound]', "Route direction") {|v| options[:direction] = v}
  opts.on('--stop [STOP_NAME]', "Stop to watch") {|v| options[:stop] = v}
  opts.on('--timing MINUTES', Integer, "Warn if distance is longer than this.") {|v| options[:bad_timing] = v}
end.parse!

def text(data)
  draw = ['/usr/bin/perl', 'client/lowlevel.pl', '--type=text']
  EnhancedOpen3.open3_input_linewise(data, nil, nil, *draw)
end

# Returns array of predictions for this stop in UTC times.  in_out is 'inbound'
# for inbound routes, or 'outbound'
def get_arrival_times(route, stop, in_out)
  route_handler = Muni::Route.find(route)
  stop_handler = route_handler.send(in_out.to_sym).stop_at(stop)
  raise "Couldn't find stop: found '#{stop_handler.title}' for '#{stop}'" if
      stop != stop_handler.title
  return stop_handler.predictions.map(&:epochTime).map{|t| Time.at(t.to_i / 1000)}
end

arrival_times = get_arrival_times(options[:route], options[:stop], options[:direction])
puts arrival_times.inspect
predictions = arrival_times.map{|t| ((t - Time.now)/60).floor}

predictions_str = ''
prev = 0

for t in predictions do
  predictions_str << "#{((t-prev) >= options[:bad_timing])? '|' : '-'}#{t}"
  prev = t
end

text("N#{predictions_str}")

