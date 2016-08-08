#!/usr/bin/env python
import sys
import os
import signal

def write_stdout(s):
  # only eventlistener protocol messages may be sent to stdout
  sys.stdout.write(s)
  sys.stdout.flush()

def write_stderr(s):
  sys.stderr.write(s)
  sys.stderr.flush()

if __name__ == '__main__':
  while 1:

    # transition from ACKNOWLEDGED to READY
    write_stdout('READY\n')

    # read header line and print it to stderr
    line = sys.stdin.readline()

    # Ignore input - we always kill supervisord regardless of the event line

    try:
        pidfile = open('/supervisord.pid', 'r')
        pid = int(pidfile.readline())
        os.kill(pid, signal.SIGQUIT)
    except Exception as e:
        write_stdout('Could not kill supervisor: ' + e.strerror + '\n')

    # transition from READY to ACKNOWLEDGED
    write_stdout('RESULT 2\nOK')

