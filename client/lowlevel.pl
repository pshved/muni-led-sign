#!/usr/bin/perl -w
# This script simply udpates the sign with more data.  If you need to write a
# more sophisticated client, just call this file from somewhere else.
# 
# Usage:
# ./lowlevel.pl --type=text
# Then, supply messages as stdin, in form of pictures comprized out of 0s and 1s
# for --type=pic, or as text for --type=text.  Separate messaages by double
# lines.

use strict qw(subs vars);
use warnings;
use Getopt::Long;
use Device::MiniLED;
my $sign=Device::MiniLED->new(devicetype => "sign");

my $type = 'text';
my $number = undef;

my $options_result = GetOptions(
  'type=s' => \$type,
);

my $height = 0;
my $data = '';
my @messages = ();
while (<STDIN>) {
  chomp;
  if ($_) {
    $height ++;
    $data .= $_;
  }
  if (!$_ or eof(STDIN)) {
    # Add message if we have some.
    push @messages, {data => $data, height => $height} if ($data);
    $height = 0;
    $data = '';
  }
}

for my $message_data (@messages) {
  if ($type eq 'pic') {
    my $data = $message_data->{data};
    my $height = $message_data->{height};
    $data =~ s/[^01]//g;
    my $width = int(length($data)/$height);
    # This will verify if we have correct number of bits.
    my $pic = $sign->addPix(
      height => $height,
      width => $width,
      data => $data,
    );
    $sign->addMsg(
      data => $pic,
      effect => 'hold',
      # For multiple messages, the speed seems to control transition speed in
      # multi-message mode.
      speed => 1,
    );
  } else {
    $sign->addMsg(
      data => $_,
      effect => (length($_) > 13) ? 'scroll' : 'hold',
      speed => 1,
    );
  }
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
