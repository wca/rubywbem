#
# Copyright 2006, Red Hat, Inc
# Scott Seago <sseago@redhat.com>
#
# derived from pywbem, written by Tim Potter <tpot@hp.com>, Martin Pool <mbp@hp.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#   
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#

# Validate XML input on stdin against the CIM DTD.



DTD_FILE = 'CIM_DTD_V22.dtd'

module WBEM
    module Validate
        def validate_xml(data, dtd_directory = nil)
            
            # Run xmllint to validate file
            
            dtd_file = DTD_FILE
            unless dtd_directory.nil?
                dtd_file = '%s/%s' % [dtd_directory, DTD_FILE]
            end
            
            pid, stdin, stdout, stderr = run_pipe('xmllint --dtdvalid %s --noout -' % dtd_file)
            stdin.puts(data)
            stdin.close_write
            exited_pid, waitstatus = Process.waitpid2(pid, 0)
            out = stdout.gets(nil)
            log(out) if out
            err = stderr.gets(nil)
            log(err) if err

            if (waitstatus.signaled? || waitstatus.exitstatus != 0)
                return false
            end

            return true    
        end

        def run_pipe(cmd)
            #"""Run a command, capturing stdin, stdout, stderr, and PID
            #
            #
            #Returns (pid, stdin, stdout, stderr)."""
            inread, inwrite = IO.pipe
            outread, outwrite = IO.pipe
            errread, errwrite = IO.pipe
            pid = fork()
            if pid.nil?
                # child
                begin
                    inwrite.close
                    outread.close
                    errread.close
                    $stdout.reopen(outwrite)
                    $stderr.reopen(errwrite)
                    $stdin.reopen(inread)
                    if cmd.is_a?(String)
                        cmd = ['/bin/sh', '-c', cmd]
                    end
                    exec(*cmd)
                ensure
                    exit!(127)
                end
            else
                # parent
                inread.close
                outwrite.close
                errwrite.close
                return pid, inwrite, outread, errread
                
            end
        end
        

    end
end

if __FILE__ == $0

    data = string.join(STDIN.readlines(), '')
    exit(validate_xml(data))
end
