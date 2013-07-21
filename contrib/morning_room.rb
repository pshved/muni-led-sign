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

  # Backup route
  opts.on('--backup-route [ROUTE]', "Route to get predictions for on 2nd line (3 predictions only)") {|v| options[:route2] = v}
  opts.on('--backup-direction [inbound/outbound]', "2nd line route direction") {|v| options[:direction2] = v}
  opts.on('--backup-stop [STOP_NAME]', "2nd line stop to watch") {|v| options[:stop2] = v}
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

def update_sign(font, options)
  # Render these times
  def prediction_string(arrival_times, options)
    puts arrival_times.inspect
    predictions = arrival_times.map{|t| ((t - Time.now)/60).floor}

    predictions_str = ''
    prev = 0
    first = true

    for t in predictions do
      # Add ellipsis between predictions if distance's too long.
      # 31 is a specific charater defined in specific.simpleglyphs
      if not first
        predictions_str << "#{((t-prev) >= options[:bad_timing])? 128.chr : '-'}"
      end
      first = false
      predictions_str << "#{t}"
      prev = t
    end

    return predictions_str
  end

  arrival_times = get_arrival_times(options[:route], options[:stop], options[:direction])
  line1 = "#{options[:route]}:#{prediction_string(arrival_times, options)}"

  if options[:route2]
    arrival_times = get_arrival_times(options[:route2], options[:stop2], options[:direction2])
    arrival_times = arrival_times.slice(0, 3)
    line2 = "#{options[:route2]}:#{prediction_string(arrival_times, options)}"
  else
    line2 = ""
  end

  LED_Sign.pic(font.render_multiline([line1, line2], 8, :ignore_shift_h => true, :distance => 0).zero_one)
end

while true
  begin
    update_sign(font, options)
  rescue => e
    $stderr.puts "Well, we continue despite this error: #{e}\n#{e.backtrace.join("\n")}"
  end
  sleep(options[:update_interval])
end

