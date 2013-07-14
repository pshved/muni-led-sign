#!/usr/bin/ruby
# Client to help you in the morning.
#
# Displays departure time from one or two stops and outside temperature.

require 'optparse'
require_relative '../client/lib'

font = muni_sign_font(File.join(File.dirname(__FILE__), '..', 'client', 'font'))

options = {
  :bad_timing => 13,
  :update_interval => 30,
}
OptionParser.new do |opts|
  opts.banner = "Usage: morning_room.rb --route F --direction inbound --stop 'Ferry Building'"

  opts.on('--route [ROUTE]', "Route to get predictions for") {|v| options[:route] = v}
  opts.on('--direction [inbound/outbound]', "Route direction") {|v| options[:direction] = v}
  opts.on('--stop [STOP_NAME]', "Stop to watch") {|v| options[:stop] = v}
  opts.on('--timing MINUTES', Integer, "Warn if distance is longer than this.") {|v| options[:bad_timing] = v}
  opts.on('--update-interval SECONDS', Integer, "Update sign each number of seconds") {|v| options[:update_interval] = v}
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

def update_sign
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

  LED_Sign.pic(font.render("#{options[:route]}#{predictions_str}", 8, :ignore_shift_h => true).zero_one)
end

while true
  update_sign(font, options)
  sleep(options[:update_interval])
end

