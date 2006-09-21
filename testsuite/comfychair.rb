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

require "getoptlong"
require "fileutils"

COMFYCHAIRDOC = <<END
comfychair: a Ruby-based instrument of software torture.
(based on the Python version)

This is a test framework designed for testing programs written in
Ruby, or (through a fork/exec interface) any other language.

For more information, see the file README.comfychair.

To run a test suite based on ComfyChair, just run it as a program.
END


module Comfychair

    class TestCase
        #"""A base class for tests.  This class defines required functions which
        #can optionally be overridden by subclasses.  It also provides some
        #utility functions for"""


        attr_reader :test_log, :_cleanups, :basedir, :rundir, :tmpdir
        attr_writer :test_log, :_cleanups, :basedir, :rundir, :tmpdir
        def initialize
            @test_log = ""
            @background_pids = []
            @_cleanups = []
            _enter_rundir()
            _save_environment()
            add_cleanup(:teardown)
        end

        # --------------------------------------------------
        # Save and restore directory
        def _enter_rundir
            @basedir = Dir.getwd
            self.add_cleanup(:_restore_directory)
            @rundir = File.join(self.basedir,
                                'testtmp', 
                                self.class.name)
            @tmpdir = File.join(@rundir, 'tmp')
            system("rm -fr %s" % @rundir)
            FileUtils.mkdir_p(@tmpdir)
            system("mkdir -p %s" % @rundir)
            Dir.chdir(@rundir)
        end
        
        def _restore_directory
            Dir.chdir(@basedir)
        end

        # --------------------------------------------------
        # Save and restore environment
        def _save_environment
            @_saved_environ = ENV.to_hash
            #ENV.each do |key, val|
            #    @_saved_environ[key] = val
            #end
            add_cleanup(:_restore_environment)
        end
        
        def _restore_environment
            ENV.clear()
            ENV.update(@_saved_environ)
        end
        
        def setup
            #"""Set up test fixture."""
        end

        def teardown
            #"""Tear down test fixture."""
        end

        def runtest
            #"""Run the test."""
        end

        def add_cleanup(methodname, obj = self)
            #"""Queue a cleanup to be run when the test is complete."""
            @_cleanups << obj.method(methodname)
        end

        def fail(reason = "")
            #"""Say the test failed."""
            raise AssertionError, reason
        end

        #############################################################
        # Requisition methods
        
        def require( predicate, message)
            #"""Check a predicate for running this test.

            #If the predicate value is not true, the test is skipped with a message explaining
            #why."""
            raise NotRunError, message unless predicate
        end

        def require_root
            #"""Skip this test unless run by root."""
            self.require(Process.uid == 0, "must be root to run this test")
        end

        #############################################################
        # Assertion methods
        
        def assert_(expr, reason = "")
            raise AssertionError, reason unless expr
        end
        
        def assert_equal(a, b)
            raise AssertionError, "assertEquals failed: %s, %s" % [a, b] unless (a == b)
        end
        
        def assert_notequal(a, b)        
            raise AssertionError, "assertNotEqual failed: %s, %s" % [a, b] if (a == b)
        end

        def assert_re_match(pattern, s)
            #"""Assert that a string *contains* a particular pattern

            #Inputs:
            #pattern      string: regular expression
            #s            string: to be searched

            #Raises:
            #AssertionError if not matched
            #"""
            unless Regexp.new(pattern).match(s)
                raise AssertionError, "string does not contain regexp\n    string: %s\n    re: %s" % [s, pattern]
            end
        end

        def assert_no_file(filename)
            if File.exists?(filename) 
                raise AssertionError, "file exists but should not: %s" % filename
            end
        end

        #############################################################
        # Methods for running programs

        def runcmd_background(cmd)
            self.test_log = self.test_log + "Run in background:\n#{cmd}\n"
            pid = fork()
            if pid.nil?
                # child
                begin
                    exec("/bin/sh", "-c", cmd)
                ensure
                    exit!(127)
                end
            end
            self.test_log = self.test_log + "pid: %d\n" % pid
            return pid
        end

        def runcmd(cmd, expectedResult = 0)
            #"""Run a command, fail if the command returns an unexpected exit
            #code.  Return the output produced."""
            rc, output, stderr = self.runcmd_unchecked(cmd)
            unless rc == expectedResult
                raise AssertionError, "command returned %d; expected %s: \"%s\"\nstdout:\n%s\nstderr:\n%s""" % [rc, expectedResult, cmd, output, stderr]
            end
            return output, stderr
        end

        def run_captured(cmd)
            #"""Run a command, capturing stdout and stderr.
            #
            #Based in part on popen2.py
            #
            #Returns (waitstatus, stdout, stderr)."""
            pid = fork()
            if pid.nil?
                # child
                begin
                    pid = Process.pid
                    openmode = FILE::O_WRONLY|FILE::O_CREAT|FILE::O_TRUNC

                    outfd = File.open('%d.out' % pid, openmode, 0666)
                    $stdout.reopen(outfd)

                    errfd = File.open('%d.err' % pid, openmode, 0666)
                    $stderr.reopen(errfd)
                    
                    if cmd.is_a?(String)
                        cmd = ['/bin/sh', '-c', cmd]
                    end
                    exec(*cmd)
                ensure
                    exit!(127)
                end
            else
                # parent
                exited_pid, waitstatus = Process.waitpid2(pid, 0)
                stdout = File.open('%d.out' % pid)
                stderr = File.open('%d.err' % pid)
                return waitstatus, stdout, stderr
                
            end
        end
        
        def runcmd_unchecked(cmd, skip_on_noexec = 0)
            #"""Invoke a command; return (exitcode, stdout, stderr)"""
            waitstatus, stdout, stderr = self.run_captured(cmd)
            if waitstatus.signaled?
                raise AssertionError, "%s terminated with signal %d" % [cmd, os.waitstatus.termsig]
            end
            rc = waitstatus.exitstatus
            self.test_log = self.test_log + "Run command: %s\nWait status: %#x (exit code %d, signal %d)\nstdout:\n%s\nstderr:\n%s" % [cmd, waitstatus, waitstatus, waitstatus.termsig, stdout, stderr]
            if skip_on_noexec and rc == 127
                # Either we could not execute the command or the command
                # returned exit code 127.  According to system(3) we can't
                # tell the difference.
                raise NotRunError, "could not execute %s" % cmd
            end
            return rc, stdout, stderr
        end

        def explain_failure(exc_info = nil)
            print "test_log:\n"
            print test_log, "\n"
        end

        def log(msg)
            #"""Log a message to the test log.  This message is displayed if
            #the test fails, or when the runtests function is invoked with
            #the verbose option."""
            self.test_log = self.test_log + msg + "\n" unless msg.nil?
        end
    end

    class AssertionError < Exception; end
    class NotRunError < Exception
        #"""Raised if a test must be skipped because of missing resources"""
        attr :value
        def initialize(value = nil)
            @value = value
        end
    end
    
    def Comfychair._report_error(testcase, ex, debugger)
        #"""Ask the test case to explain failure, and optionally run a debugger
        
        #Input:
        #testcase         TestCase instance
        #debugger     if true, a debugger function to be applied to the traceback
        #"""
        print  "-----------------------------------------------------------------\n"
        unless ex.nil?
            print ex, "\n"
            ex.backtrace.each do |line|
                print line, "\n"
            end
            testcase.explain_failure()
            print "-----------------------------------------------------------------\n"
        end
        if debugger
            #tb = ex[2]
            #debugger(tb)
        end
    end
    
    def Comfychair.runtests(test_list, verbose = false, debugger = nil, quiet = false)
        #       """Run a series of tests.

        #       Inputs:
        #         test_list    sequence of TestCase classes
        #         verbose      print more information as testing proceeds
        #         debugger     debugger object to be applied to errors

        #       Returns:
        #         unix return code: 0 for success, 1 for failures, 2 for test failure
        #       """
        ret = 0
        test_list.each do |test_class|
            print  "%-30s" % Comfychair._test_name(test_class)
            # flush now so that long running tests are easier to follow
            STDOUT.flush
            
            obj = nil
            begin
                begin # run test and show result
                    obj = test_class.new
                    obj.setup()
                    obj.runtest()
                    print "OK\n"
#                rescue KeyboardInterrupt => ex
#                    print "INTERRUPT\n"
#                    Comfychair._report_error(obj, ex, debugger) unless quiet
#                    ret = 2
#                    break
                rescue NotRunError => msg
                    print "NOTRUN, %s\n" % msg.value
                rescue Exception => ex
                    print "FAIL\n"
                    Comfychair._report_error(obj, ex, debugger) unless quiet
                    ret = 1
                end
            ensure
                while obj and !obj._cleanups.empty?
                    begin
                        obj._cleanups.pop().call
#                    rescue KeyboardInterrupt => ex
#                        print "interrupted during teardown\n"
#                        Comfychair._report_error(obj, ex, debugger)
#                        ret = 2
#                        break
                    rescue => ex
                        print "error during teardown\n"
                        Comfychair._report_error(obj, ex, debugger) unless quiet
                        ret = 1
                    end
                end
            end
            # Display log file if we're verbose
            obj.explain_failure() if ret == 0 and verbose
        end
        return ret
    end

    def Comfychair._test_name(test_class)
        #"""Return a human-readable name for a test class.
        #"""
        begin
            return test_class.name
        rescue
            return test_class
        end
    end

    def Comfychair.print_help()
        #"""Help for people running tests"""
        msg = <<END 
: software test suite based on ComfyChair

usage:
    To run all tests, just run this program.  To run particular tests,
    list them on the command line.

options:
    --help              show usage message
    --list              list available tests
    --verbose, -v       show more information while running tests
END
        #    --post-mortem, -p   enter Python debugger on error 
        print $0, msg
    end

    def Comfychair.print_list(test_list)
        #"""Show list of available tests"""
        test_list.each do |test_class|
            print "    %s\n" % Comfychair._test_name(test_class)
        end
    end

    def Comfychair.main(tests, extra_tests=[])
        #     """Main entry point for test suites based on ComfyChair.

        #     inputs:
        #       tests       Sequence of TestCase subclasses to be run by default.
        #       extra_tests Sequence of TestCase subclasses that are available but
        #                   not run by default.

        # Test suites should contain this boilerplate:

        #     if __FILE__ == $0
        #         Comfychair.main(tests)

        # This function handles standard options such as --help and --list, and
        # by default runs all tests in the suggested order.

        # Calls sys.exit() on completion.
        #"""
        opt_verbose = false
        opt_quiet = false
        debugger = nil

        opts = GetoptLong.new(
                              [ '--help', GetoptLong::NO_ARGUMENT ],
                              [ '--list', GetoptLong::NO_ARGUMENT ],
                              [ '--verbose', '-v', GetoptLong::NO_ARGUMENT ],
                              [ '--post-mortem', '-p', GetoptLong::NO_ARGUMENT ],
                              [ '--quiet', '-q', GetoptLong::NO_ARGUMENT ])
        
        opts.each do |opt, opt_arg|
            case opt
            when '--help'
                Comfychair.print_help()
                return
            when '--list'
                Comfychair.print_list(tests + extra_tests)
                return
            when '--verbose'
                opt_verbose = true
            when '--post-mortem'
                # anything similar for ruby?
                #import pdb
                #debugger = pdb.post_mortem
                raise ArgumentError, "--post-mortem not supported for Ruby"
            when '--quiet'
                opt_quiet = true unless opt_verbose
            end
        end
        unless ARGV.empty?
            all_tests = tests + extra_tests
            by_name = {}
            all_tests.each { |t| by_name[Comfychair._test_name(t)] = t}
            which_tests = []
            ARGV.each { |name| which_tests << by_name[name]}
        else
            which_tests = tests
        end

        exit(Comfychair.runtests(which_tests, opt_verbose, debugger, opt_quiet))
    end
end

if __FILE__ == $0
    print COMFYCHAIRDOC, "\n"
end
