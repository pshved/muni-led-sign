# Ruby interface to Muni sign.  Relied on a perl wrapper over the official Perl
# API.
require_relative 'enhanced_open3'

class LED_Sign
  def self.text(data)
    # TODO: get rid of hardcoded path!
    draw = ['/usr/bin/perl', 'client/lowlevel.pl', '--type=text']
    print = proc {|line| $stderr.puts line}
    EnhancedOpen3.open3_input_linewise(data, print, print, *draw)
  end

  def self.pic(data)
    draw = ['/usr/bin/perl', 'client/lowlevel.pl', '--type=pic']
    print = proc {|line| $stderr.puts line}
    EnhancedOpen3.open3_input_linewise(data, print, print, *draw)
  end
  
end

# Supply Array with a conversion function that makes input to LED_Sign.pic out
# of a two-dimensional array.
class Array
  def zero_one
    map{|row| row.join('')}.join("\n")
  end
end

