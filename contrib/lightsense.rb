#!/usr/bin/ruby
# Read numbers from a stdndard input, and erase/create a file specified if the
# numbers are over/under a certain threashold.
#
# Use with morning_room.rb to shut down a sign when it's dark.

require 'optparse'

options = {
  :threshold => 100,
}
OptionParser.new do |opts|
  opts.banner = "Usage: lightsense.rb --file /tmp/light --threshold 100"

  opts.on('--threshold NUMBER', "Threshold.  If the reading is above it, remove the file") {|v| options[:threshold] = v.to_i}
  opts.on('--file file_name', "File name to maintain created/erased") {|v| options[:file] = v}
end.parse!

raise "Specify file!" unless options[:file]

ARGF.each do |line|
  # Remove all except numbers (and get rid of non-utf garbage).
  number = line.encode(Encoding.find('ASCII')).gsub(/[^0-9]/,'')
  # Do not allow an empty line be confused with a zero reading.
  if number != ''
    value = number.to_i
    if value < options[:threshold]
      if not File.exists?(options[:file])
        File.open(options[:file], "w") {|f| f.puts("dark!")}
      end
    else
      # Make sure the file is deleted
      File.delete(options[:file]) rescue nil
    end
  end
end

