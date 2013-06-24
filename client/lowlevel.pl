#!/usr/bin/perl -w
# This script simply udpates the sign with more data.  If you need to write a
# more sophisticated client, just call this file from somewhere else.

use strict qw(subs vars);
use warnings;
use Getopt::Long;
use Device::MiniLED;
my $sign=Device::MiniLED->new(devicetype => "sign");

my $type = 'text';

my $options_result = GetOptions(
  'type=s' => \$type,
);

if ($type eq 'pic') {
#   my $width = 96;
#   my $height = 16;
#   my $data = '';
#   for (my $i = 0; $i < $width * $height; ++$i) {
#     $data .= (rand(2) > 1) ? '0' : '1';
#   }
#   print $data, "\n";
  my $width = 0;
  my $height = 0;
  my $data = '';
  for (<STDIN>) {
    chomp;
    next unless $_;
    $height ++;
    $data .= $_;
  }
  # Remove wrong pixels
  $data =~ s/[^01]//g;
  $width = int(length($data)/$height);
  # This will verify if we have correct number of bits.
  my $pic = $sign->addPix(
    height => $height,
    width => $width,
    data => $data,
  );
  $sign->addMsg(
    data => $pic,
    effect => 'hold',
    speed => 5,
  );
} elsif ($type eq 'text') {
  my @lines = (<STDIN>);
  my $data = $lines[0];
  chomp $data;

  $sign->addMsg(
    data => $data,
    effect => (length($data) > 13) ? 'scroll' : 'hold',
    speed => 1,
  );
}

# #
# # add a text only message
# #
# $sign->addMsg(
#     data => "test",
#     effect => "scroll",
#     speed => 4
# );
# #
# # create a picture and an icon from built-in clipart
# #
# my $pic=$sign->addPix(clipart => "zen16");
# my $icon=$sign->addIcon(clipart => "heart16");
# #
# # add a message with the picture and animated icon we just created
# #
# $sign->addMsg(
#         data => "Message 2 with a picture: $pic and an icon: $icon",
#         effect => "scroll",
#         speed => 3
# );
$sign->send(device => "/dev/ttyUSB0");
