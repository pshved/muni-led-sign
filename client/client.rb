#!/usr/bin/ruby

require 'optparse'

require_relative 'lib'

font = muni_sign_font(File.join(File.dirname(__FILE__), 'font'))

options = {
  :update_interval => 30,
}
OptionParser.new do |opts|
  opts.banner = "Usage: client.rb --route F --direction inbound --stop 'Ferry Building'"

  opts.on('--stopId [STOP_NAME]', "Stop to watch") {|v| options[:stop] = v}
  opts.on('--update-interval SECONDS', Integer, "Update sign each number of seconds") {|v| options[:update_interval] = v}

  # Darkening
  opts.on('--dark-file [FILENAME]', "Turn off the sign instead of updating, if FILENAME exists") {|v| options[:dark_file] = v}
end.parse!


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
  unstripped_result.slice(0, 18)
end

def update_sign(font, options)
  arrival_times = get_stop_arrivals(options[:stop])
  # Only debugging: $stderr.puts arrival_times.inspect
  texts_for_sign = []
  arrival_times_text = arrival_times.each do |route, predictions|
    # Show first two predictions
    prediction_text = predictions.slice(0,2).map(&:muni_time).join(' & ')
    unless prediction_text.empty?
      # Fixup route name.
      route_name = fixup_route_name(route, predictions[0])
      texts_for_sign << font.render_multiline([route_name, prediction_text], 8, :ignore_shift_h => true, :distance => 0, :fixed_width => LED_Sign::SCREEN_WIDTH)
    end
  end
  if texts_for_sign && !texts_for_sign.empty?
    text_for_sign = texts_for_sign.map(&:zero_one).join("\n\n")
  else
    # Empty predictions array: this may be just nighttime.
    text_for_sign = font.render_multiline(["No routes", "until next morning."], 8, :ignore_shift_h => true, :distance => 0, :fixed_width => LED_Sign::SCREEN_WIDTH).zero_one
  end
  LED_Sign.pic(text_for_sign)
end

while true
  begin
    darken_if_necessary(options) or update_sign(font, options)
  rescue => e
    $stderr.puts "Well, we continue despite this error: #{e}\n#{e.backtrace.join("\n")}"
  end
  sleep(options[:update_interval])
end

