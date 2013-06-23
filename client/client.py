#!/usr/bin/python
# test drive client

import StringIO
import subprocess

pic = StringIO.StringIO()
#pic.close()

p = subprocess.Popen(['/usr/bin/perl', 'client/lowlevel.pl', '--type=pic'],
                     stdin=subprocess.PIPE)

p.stdin.write('1111\n1001\n1111\n')
p.communicate()[0]
p.stdin.close()
