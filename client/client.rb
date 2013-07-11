#!/usr/bin/ruby
# Generic includes.
require 'optparse'

# Nonstandard gems
require 'muni'

# Local includes
require_relative 'lib/sign'
require_relative 'lib/simplefont'

sf = muni_sign_font(File.join(File.dirname(__FILE__), 'font'))


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


# Returns array of predictions for this route, direction, and stop in UTC times.
# in_out is 'inbound' for inbound routes, or 'outbound'
def get_arrival_times(route, stop, in_out)
  raise unless route and stop and in_out
  route_handler = Muni::Route.find(route)
  stop_handler = route_handler.send(in_out.to_sym).stop_at(stop)
  raise "Couldn't find stop: found '#{stop_handler.title}' for '#{stop}'" if
      stop != stop_handler.title
  return stop_handler.predictions.map(&:time)
end

# Returns hash of predictions for this stop in UTC times for all routes.  Keys
# are route names, and values are arrays of predictions for that route at this
# stop.
def get_stop_arrivals(stopId)
  raise unless stopId
  stop = Muni::Stop.new({ :stopId => stopId })
  return stop.predictions_for_all_routes
end

# Convert from Nextbus format to what it actually displayed on a minu sign.
# Ordered list of regexp -> string pairs.  The first regexp to match a
# prediction's dirTag field replaces the route name with the string.
ROUTE_FIXUP_MAP = [
  [ /^KT.*OB/, 'K-Ingleside'],
  [ /^KT.*IBMTME/, 'T-Metro East Garage'],
  # Let's all all inbound KT-s like this.
  [ /^KT.*IB/, 'T-Third Street'],
]
def fixup_route_name(route_name, prediction)
  # For now, just truncate, except for one thing.
  unstripped_result = route_name
  ROUTE_FIXUP_MAP.each do |regex, fixup|
    if regex =~ prediction.dirTag
      unstripped_result = fixup
      break
    end
  end
  # Strip result
  unstripped_result.slice(0, 16)
end

if options[:route] != 'all'
  arrival_times = get_arrival_times(options[:route], options[:stop], options[:direction])

  # Render these times
  puts arrival_times.inspect
  predictions = arrival_times.map{|t| ((t - Time.now)/60).floor}

  predictions_str = ''
  prev = 0

  for t in predictions do
    # 31 is a specific charater defined in specific.simpleglyphs
    predictions_str << "#{((t-prev) >= options[:bad_timing])? 128.chr : '-'}#{t}"
    prev = t
  end

  LED_Sign.pic(sf.render("#{options[:route]}#{predictions_str}", 8, :ignore_shift_h => true).zero_one)
else
  arrival_times = get_stop_arrivals(options[:stop])
  $stderr.puts arrival_times.inspect
  texts_for_sign = []
  arrival_times_text = arrival_times.each do |route, predictions|
    # Show first two predictions
    prediction_text = predictions.slice(0,2).map(&:muni_time).join(' & ')
    unless prediction_text.empty?
      # Fixup route name.
      route_name = fixup_route_name(route, predictions[0])
      texts_for_sign << sf.render_multiline([route_name, prediction_text], 8, :ignore_shift_h => true, :distance => 0)
    end
  end
  text_for_sign = texts_for_sign.map(&:zero_one).join("\n\n")
  LED_Sign.pic(text_for_sign)
end

