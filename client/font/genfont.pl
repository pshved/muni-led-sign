#!/usr/bin/perl
# In order to not introduce extra dependencies such as Freetype O_o, I just
# convert the font into simpler and more editable format.  Besides, I add some
# of my own glyphs.
#
# <code> <horizontal shift> <vertical shift> ...
# 101
# 110
# 111
#  <---- empty line
#
#
# Shifts are coords of top left corner as viewed from baseline (not from top).

use Font::FreeType;
my $freetype = Font::FreeType->new;
# I have no idea how this stuff works, but this font and size 10 give 7x7
# bitmaps!
my $face = $freetype->face($ARGV[0]);
my $sz = $ARGV[1] || 10;
$face->set_pixel_size($sz, $sz);

# $face->set_char_size($sz, $sz, 100, 100);

for my $c (1..127) {
  my $glyph = $face->glyph_from_char_code($c);
  # Do not print the unprintable.
  next unless $glyph;
  my ($bitmap, $left, $top) = $glyph->bitmap(FT_RENDER_MODE_MONO);
  $,=' ';
  $\="\n";
  # Do not print characters that are invisible.
  my $packed = ($c >= 32) ? chr($c) : '';
  print $c, $left, $top, $packed;
  for my $line (@$bitmap) {
    # This is silly, but I don't know a better way to convert a binary string to
    # 0s and 1s.
    my $byte_line = unpack('H*', $line);
    $byte_line =~ s/ff/1/g;
    $byte_line =~ s/00/0/g;
    print $byte_line;
  }
  print;
}

