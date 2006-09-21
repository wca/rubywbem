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

#
# Test CIM operations function interface.  The return codes here may
# be specific to OpenPegasus.
#

require "comfychair"
require "date"
require "singleton"
require "wbem"

module WBEM
    module Test
        class Hostinfo
            include Singleton
            private_class_method :new
            attr_reader :host, :username, :password
            attr_writer :host, :username, :password
        end
        class ClientTest < Comfychair::TestCase
            #"""A base class that creates a WBEM::WBEMConnection for
            #subclasses to use."""
            attr :conn
            def setup
                #"""Create a connection."""
                
                # Use globals host, username and password
                @conn = WBEMConnection.new("https://%s" % Hostinfo.instance.host,
                                           [Hostinfo.instance.username, Hostinfo.instance.password])
            end
            #def cimcall(fn, *args, **kw)
            def cimcall(fn, *args)
                #"""Make a RubyWBEM call and log the request and response XML."""
                begin
                    result = self.conn.method(fn).call(*args)
                ensure
                    self.log("Request:\n\n%s\n" % self.conn.last_request)
                    self.log("Reply:\n\n%s\n" % self.conn.last_reply)
                end
                return result
            end
        end
        #################################################################
        # Instance provider interface tests
        #################################################################

        class EnumerateInstances < ClientTest

            def runtest
                
                # Simplest invocation
                instances = cimcall(:EnumerateInstances,
                                    "CIM_Process")
                
                instances.each {|i| assert_(i.is_a?(CIMInstance)) }
                
                # Call with optional namespace path
                
                begin
                    self.cimcall(:EnumerateInstances,
                                 'CIM_Process',
                                 :LocalNamespacePath => 'root/pywbem')
                    
                rescue CIMError => arg
                    if arg.code != CIM_ERR_INVALID_NAMESPACE
                        raise
                    end
                end
                # Try some keyword parameters
                
                begin
                    self.cimcall(:EnumerateInstances,
                                 'CIM_Process',
                                 :FooParam => 'FooValue')
                rescue CIMError => arg
                    if arg.code != CIM_ERR_NOT_SUPPORTED
                        raise
                    end
                end
            end
        end

        class EnumerateInstanceNames < ClientTest

            def runtest

                # Simplest invocation

                names = cimcall(:EnumerateInstanceNames,
                                'CIM_Process')

                names.each {|i| assert_(i.is_a?(CIMInstanceName)) }
                
                # Call with optional namespace path
                
                begin
                    self.cimcall(:EnumerateInstanceNames,
                                 'CIM_Process',
                                 :LocalNamespacePath => 'root/pywbem')
                    
                rescue CIMError => arg
                    if arg.code != CIM_ERR_INVALID_NAMESPACE
                        raise
                    end
                end
                # Try some keyword parameters
                
                begin
                    self.cimcall(:EnumerateInstanceNames,
                                 'CIM_Process',
                                 :FooParam => 'FooValue')
                rescue CIMError => arg
                    if arg.code != CIM_ERR_NOT_SUPPORTED
                        raise
                    end
                end
            end
        end

        class GetInstance < ClientTest

            def runtest

                names = cimcall(:EnumerateInstanceNames,
                                'CIM_Process')
                # Simplest invocation

                obj = cimcall(:GetInstance, names[0])
                
                assert_(obj.is_a?(CIMInstance))
                
                # Call with optional namespace path
                
                begin
                    self.cimcall(:GetInstance,
                                 names[0],
                                 :LocalNamespacePath => 'root/pywbem')
                    
                rescue CIMError => arg
                    if arg.code != CIM_ERR_INVALID_NAMESPACE
                        raise
                    end
                end
                # Try some keyword parameters
                
                begin
                    self.cimcall(:GetInstance,
                                 names[0],
                                 :FooParam => 'FooValue')
                rescue CIMError => arg
                    if arg.code != CIM_ERR_NOT_SUPPORTED
                        raise
                    end
                end
                
                # CIMInstanceName with host and namespace set

                iname = names[0].clone

                iname.host = 'woot.com'
                iname.namespace = 'smash'

                self.cimcall(:GetInstance, iname)

            end
        end

        class CreateInstance < ClientTest

            def runtest

                instance = cimcall(:EnumerateInstances, 'CIM_Process')[0]

                # Single arg
                begin
                    obj = cimcall(:CreateInstance, instance)
                rescue CIMError => arg
                    if arg.code != CIM_ERR_NOT_SUPPORTED
                        raise
                    end
                end
                
                # Arg plus namespace
                
                begin
                    self.cimcall(:CreateInstance,
                                 instance,
                                 :LocalNamespacePath => 'root/pywbem')
                    
                rescue CIMError => arg
                    if arg.code != CIM_ERR_INVALID_NAMESPACE
                        raise
                    end
                end
            end
        end

        class DeleteInstance < ClientTest

            def runtest

                name = cimcall(:EnumerateInstanceNames, 'CIM_Process')[0]

                # Single arg
                begin
                    obj = cimcall(:DeleteInstance, name)
                rescue CIMError => arg
                    if arg.code != CIM_ERR_NOT_SUPPORTED
                        raise
                    end
                end
                
                # Arg plus namespace
                
                begin
                    self.cimcall(:DeleteInstance,
                                 name,
                                 :LocalNamespacePath => 'root/pywbem')
                    
                rescue CIMError => arg
                    if arg.code != CIM_ERR_INVALID_NAMESPACE
                        raise
                    end
                end

                # CIMInstanceName with host and namespace set

                iname = name.clone

                iname.host = 'woot.com'
                iname.namespace = 'smash'

                begin
                    self.cimcall(:DeleteInstance, iname)
                rescue CIMError => arg
                    raise if arg.code != CIM_ERR_NOT_SUPPORTED
                end

            end
        end

        class ModifyInstance < ClientTest

            def runtest

                namedInstance = cimcall(:EnumerateInstances, 'CIM_Process')[0]

                begin
                    obj = cimcall(:ModifyInstance, namedInstance)
                rescue CIMError => arg
                    if arg.code != CIM_ERR_NOT_SUPPORTED
                        raise
                    end
                end
                
                # Test without a named instance
                namedInstance2 = namedInstance.clone
                namedInstance2.path = nil
                begin
                    obj = cimcall(:ModifyInstance, namedInstance2)
                rescue ArgumentError => arg
                    # should throw an argument error
                else
                    fail('ArgumentError not thrown')
                end
            end
        end

        #################################################################
        # Method provider interface tests
        #################################################################

        class InvokeMethod < ClientTest

            def runtest

                # Invoke on classname

                begin
                    cimcall(:InvokeMethod,
                            'FooMethod',
                            'CIM_Process')
                rescue CIMError => arg
                    if arg.code != CIM_ERR_METHOD_NOT_AVAILABLE
                        raise
                    end
                end

                # Invoke on an InstanceName

                name = cimcall(:EnumerateInstanceNames, 'CIM_Process')[0]

                begin
                    cimcall(:InvokeMethod,
                            'FooMethod',
                            name)
                rescue CIMError => arg
                    if arg.code != CIM_ERR_METHOD_NOT_AVAILABLE
                        raise
                    end
                end

                # Test remote instance name
                name2 = name.clone
                name2.host = 'woot.com'
                name2.namespace = 'root/cimv2'

                begin
                    self.cimcall(:InvokeMethod,
                                 'FooMethod',
                                 name)
                rescue CIMError => arg
                    if arg.code != CIM_ERR_METHOD_NOT_AVAILABLE
                        raise
                    end
                end

                # Call with all possible parameter types

                begin
                    cimcall(:InvokeMethod,
                            'FooMethod',
                            'CIM_Process',
                            :String => 'Spotty',
                            :Uint8  => Uint8.new(1),
                            :Sint8  => Sint8.new(2),
                            :Uint16 => Uint16.new(3),
                            :Uint32 => Uint32.new(4),
                            :Sint32 => Sint32.new(5),
                            :Uint64 => Uint64.new(6),
                            :Sint64 => Sint64.new(7),
                            :Real32 => Real32.new(8),
                            :Real64 => Real64.new(9),
                            :Bool   => Boolean.new(true),
                            :Date1  => DateTime.now,
                            :Date2  => TimeDelta.new(60),
                            :Ref    => name)
                rescue CIMError => arg
                    if arg.code != CIM_ERR_METHOD_NOT_AVAILABLE
                        raise
                    end
                end

                # Call with non-empty arrays

                begin
                    cimcall(:InvokeMethod,
                            'FooMethod',
                            name,
                            :StringArray => 'Spotty',
                            :Uint8Array  => [Uint8.new(1)],
                            :Sint8Array  => [Sint8.new(2)],
                            :Uint16Array => [Uint16.new(3)],
                            :Uint32Array => [Uint32.new(4)],
                            :Sint32Array => [Sint32.new(5)],
                            :Uint64Array => [Uint64.new(6)],
                            :Sint64Array => [Sint64.new(7)],
                            :Real32Array => [Real32.new(8)],
                            :Real64Array => [Real64.new(9)],
                            :BoolArray   => [Boolean.new(false), Boolean.new(true)],
                            :Date1Array  => [DateTime.now, DateTime.now],
                            :Date2Array  => [TimeDelta.new(0), TimeDelta.new(60)],
                            :RefArray    => [name, name])
                rescue CIMError => arg
                    if arg.code != CIM_ERR_METHOD_NOT_AVAILABLE
                        raise
                    end
                end

                # TODO: Call with empty arrays
                
                # TODO: Call with weird VALUE.REFERENCE child types:
                # (CLASSPATH|LOCALCLASSPATH|CLASSNAME|INSTANCEPATH|LOCALINSTANCEPATH|
                #  INSTANCENAME)
            end
        end
        #################################################################
        # Association provider interface tests
        #################################################################

        class Associators < ClientTest
            def runtest
                # TODO: Associators call on ClassName and ClassPath

                css = self.cimcall(:EnumerateInstanceNames, 'CIM_ComputerSystem')

                css.each do |cs|
                    begin
                        instances = self.cimcall(:Associators, cs)
                        instances.each do |i|
                            self.assert_(i.is_a?(CIMInstance))
                            n = i.path
                            self.assert_(n.is_a?(CIMInstanceName))
                            self.assert_(n.host && n.namespace)
                        end
                    rescue CIMError => arg
                        if arg.code != CIM_ERR_NOT_SUPPORTED
                            raise
                        end
                    end
                end
            end
        end
        
        class AssociatorNames < ClientTest
            def runtest
                # TODO: AssociatorNames call on ClassName and ClassPath

                css = self.cimcall(:EnumerateInstanceNames, 'CIM_ComputerSystem')

                css.each do |cs|
                    begin
                        names = self.cimcall(:AssociatorNames, cs)
                        names.each do |n|
                            self.assert_(n.is_a?(CIMInstanceName))
                            self.assert_(n.host && n.namespace)
                        end
                    rescue CIMError => arg
                        if arg.code != CIM_ERR_NOT_SUPPORTED
                            raise
                        end
                    end
                end
            end
        end
        
        class References < ClientTest
            def runtest
                # TODO: References call on ClassName and ClassPath

                css = self.cimcall(:EnumerateInstanceNames, 'CIM_ComputerSystem')

                css.each do |cs|
                    begin
                        instances = self.cimcall(:References, cs)
                        instances.each do |i|
                            self.assert_(i.is_a?(CIMInstance))
                            n = i.path
                            self.assert_(n.is_a?(CIMInstanceName))
                            self.assert_(n.host && n.namespace)
                        end
                    rescue CIMError => arg
                        if arg.code != CIM_ERR_NOT_SUPPORTED
                            raise
                        end
                    end
                end
            end
        end
        
        class ReferenceNames < ClientTest
            def runtest
                # TODO: ReferenceNames call on ClassName and ClassPath

                css = self.cimcall(:EnumerateInstanceNames, 'CIM_ComputerSystem')

                css.each do |cs|
                    begin
                        names = self.cimcall(:ReferenceNames, cs)
                        names.each do |n|
                            self.assert_(n.is_a?(CIMInstanceName))
                            self.assert_(n.host && n.namespace)
                        end
                    rescue CIMError => arg
                        if arg.code != CIM_ERR_NOT_SUPPORTED
                            raise
                        end
                    end
                end
            end
        end
        
        #################################################################
        # Schema manipulation interface tests
        #################################################################

        module ClassVerifier
            #"""Includable module for testing CIMClass instances."""
            
            def verify_property(p)
                assert_(p.value.nil?)
                assert_(p.is_a?(CIMProperty))
            end

            def verify_qualifier(q)
                assert_(q.name)
                assert_(q.value)
            end

            def verify_method(m)
            end

            def verify_class(cl)
                
                # Verify simple attributes
                assert_(cl.classname)
                
                unless cl.superclass.nil?
                    assert_(cl.superclass)
                end

                # Verify properties

                assert_(!cl.properties.empty?)
                cl.properties.values.each { |p| self.verify_property(p) }

                # Verify qualifiers

                #            assert_(!cl.qualifiers.empty?)
                cl.qualifiers.values.each { |p| self.verify_qualifier(p) }

                # Verify methods
                cl.cim_methods.values.each { |p| self.verify_method(p) }
            end
        end

        class EnumerateClassNames < ClientTest
            def runtest
                names = cimcall(:EnumerateClassNames)
                names.each { |n| assert_(n.is_a?(String)) }
            end
        end

        class EnumerateClasses < ClientTest
            include ClassVerifier

            def runtest
                classes = cimcall(:EnumerateClasses)
                classes.each { |c| assert_(c.is_a?(CIMClass))  }
                classes.each { |c| verify_class(c) }
            end
        end

        class GetClass < ClientTest
            include ClassVerifier

            def runtest
                name = cimcall(:EnumerateClassNames)[0]
                cimcall(:GetClass, name)
            end
        end

        class CreateClass < ClientTest
            def runtest
                raise Comfychair::NotRunError
            end
        end

        class DeleteClass < ClientTest
            def runtest
                raise Comfychair::NotRunError
            end
        end

        class ModifyClass < ClientTest
            def runtest
                raise Comfychair::NotRunError
            end
        end

        #################################################################
        # Property provider interface tests
        #################################################################

        class GetProperty < ClientTest
            def runtest
                raise Comfychair::NotRunError
            end
        end

        class SetProperty < ClientTest
            def runtest
                raise Comfychair::NotRunError
            end
        end

        #################################################################
        # Qualifier provider interface tests
        #################################################################

        class EnumerateQualifiers < ClientTest
            def runtest
                raise Comfychair::NotRunError
            end
        end

        class GetQualifier < ClientTest
            def runtest
                raise Comfychair::NotRunError
            end
        end

        class SetQualifier < ClientTest
            def runtest
                raise Comfychair::NotRunError
            end
        end

        class DeleteQualifier < ClientTest
            def runtest
                raise Comfychair::NotRunError
            end
        end

        #################################################################
        # Query provider interface
        #################################################################

        class ExecuteQuery < ClientTest
            def runtest
                raise Comfychair::NotRunError
            end
        end

        #################################################################
        # Main function
        #################################################################



        TESTS = [
                 # Instance provider interface tests

                 EnumerateInstances,
                 EnumerateInstanceNames,
                 GetInstance,
                 CreateInstance,
                 DeleteInstance,
                 ModifyInstance,

                 # Method provider interface tests

                 InvokeMethod,

                 # Association provider interface tests
                 
                 Associators,
                 AssociatorNames,
                 References,
                 ReferenceNames,

                 # Schema manipulation interface tests

                 EnumerateClassNames,
                 EnumerateClasses,
                 GetClass,
                 CreateClass,
                 DeleteClass,
                 ModifyClass,

                 # Property provider interface tests

                 GetProperty,
                 SetProperty,

                 # Qualifier provider interface tests
                 
                 EnumerateQualifiers,
                 GetQualifier,
                 SetQualifier,
                 DeleteQualifier,

                 # Query provider interface tests

                 ExecuteQuery

                ]

        if __FILE__ == $0
            
            if ARGV.size < 2
                print 'Usage: test_cim_operations.rb HOST USERNAME%PASSWORD\n'
                exit(0)
            end
            
            Hostinfo.instance.host = ARGV[0]
            Hostinfo.instance.username, Hostinfo.instance.password = ARGV[1].split('%')
            
            ARGV.shift
            ARGV.shift
            
            Comfychair.main(TESTS)
        end

    end
end

