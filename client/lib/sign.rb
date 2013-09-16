# Ruby interface to Muni sign.  Relied on a perl wrapper over the official Perl
# API.
require_relative 'enhanced_open3'

class LED_Sign
  SCRIPT = File.join(File.dirname(__FILE__), '..', '..', 'client', 'lowlevel.pl')
  def self.text(data)
    draw = ['/usr/bin/perl', SCRIPT, '--type=text']
    print = proc {|line| $stderr.puts line}
    EnhancedOpen3.open3_input_linewise(data, print, print, *draw)
  end

  def self.pic(data)
    draw = ['/usr/bin/perl', SCRIPT, '--type=pic']
    print = proc {|line| $stderr.puts line}
    EnhancedOpen3.open3_input_linewise(data, print, print, *draw)
  end
  
  # Sign dimensions (to aid in text formatting).
  # The sign I have has a peculiarity that if the picture width is about ~50px,
  # then it aligns the text a bit to the left.  We'll need the width to render
  # the text up to it.
  SCREEN_WIDTH = 96
  SCREEN_HEIGHT = 16
end

# Supply Array with a conversion function that makes input to LED_Sign.pic out
# of a two-dimensional array.
class Array
  def zero_one
    map{|row| row.join('')}.join("\n")
  end
end

# Darken the sign if dark_file exists.
# Return true if sign has been darkened.
def darken_if_necessary(options)
  dark_file = options[:dark_file]
  if dark_file && File.exists?(dark_file)
    # We can't "turn off" the sign, but we can send it an empty picture.
    LED_Sign.pic("0\n")
    return true
  end
  return false
end

