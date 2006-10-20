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
require 'password'

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
                                           [Hostinfo.instance.username, 
                                            Hostinfo.instance.password])
                @conn.debug = true
            end
            def cimcall(fn, *args)
                #"""Make a RubyWBEM call and log the request and response XML."""
                begin
                    result = self.conn.method(fn).call(*args)
                rescue Exception
                    self.log("Failed Request:\n\n%s\n" % self.conn.last_request)
                    self.log("Failed Reply:\n\n%s\n" % self.conn.last_reply)
                    raise
                end
                self.log("Request:\n\n%s\n" % self.conn.last_request)
                self.log("Reply:\n\n%s\n" % self.conn.last_reply)
                return result
            end
            def deletedtestinstance
                instance = CIMInstance.new(
                    'RubyWBEM_Person',
                    {'CreationClassName' => 'RubyWBEM_Person',
                     'Name' => 'Test'},
                    {},
                    CIMInstanceName.new('RubyWBEM_Person',
                                        {'CreationClassName' => 'RubyWBEM_Person',
                                         'Name' => 'Test'}))
                # Delete if already exists
                begin
                    cimcall(:DeleteInstance, instance.path)
                rescue CIMError => arg
                    # nothing here
                end
                instance
            end
        end
        #################################################################
        # Instance provider interface tests
        #################################################################

        class EnumerateInstanceNames < ClientTest
            def runtest
                # Single arg call
                deletedtestinstance
                names = cimcall(:EnumerateInstanceNames,
                                'RubyWBEM_Person')

                self.assert_equal(names.size, 3)
                names.each do |n| 
                    assert_(n.is_a?(CIMInstanceName)) 
                    assert_(n.namespace.length > 0) 
                end
                
                # Call with optional namespace path
                begin
                    self.cimcall(:EnumerateInstanceNames,
                                 'RubyWBEM_Person',
                                 :namespace => 'root/pywbem')
                rescue CIMError => arg
                    raise if arg.code != CIM_ERR_INVALID_NAMESPACE
                end
            end
        end

        class EnumerateInstances < ClientTest
            def runtest
                # Single arg call
                deletedtestinstance
                instances = cimcall(:EnumerateInstances,
                                    'RubyWBEM_Person')
                self.assert_equal(instances.size, 3)
                instances.each do |i| 
                    assert_(i.is_a?(CIMInstance)) 
                    assert_(i.path.is_a?(CIMInstanceName)) 
                    assert_(i.path.namespace.length > 0) 
                end
                
                # Call with optional namespace path
                begin
                    self.cimcall(:EnumerateInstances,
                                 'RubyWBEM_Person',
                                 :namespace => 'root/pywbem')
                rescue CIMError => arg
                    raise if arg.code != CIM_ERR_INVALID_NAMESPACE
                end
            end
        end

        class ExecQuery < ClientTest

            def runtest
                begin
                    deletedtestinstance
                    instances = cimcall(:ExecQuery, 
                                        'wql', 
                                        'Select * from RubyWBEM_Person')

                    self.assert_equal(instances.length, 3)
                    instances.each do |i|
                        self.assert_(i.is_a?(CIMInstance))
                        self.assert_(i.path.is_a?(CIMInstanceName))
                        self.assert_(i.path.namespace.length > 0)
                    end

                    # Call with optional namespace path
                    begin
                        cimcall(:ExecQuery, 
                                'wql',
                                'Select * from RubyWBEM_Person',
                                'root/pywbem')

                    rescue CIMError => arg
                        raise if arg.code != CIM_ERR_INVALID_NAMESPACE
                    end
                rescue CIMError => arg
                    if arg.code == CIM_ERR_NOT_SUPPORTED
                        raise Comfychair::NotRunError, "CIMOM doesn't support ExecQuery"
                    else
                        raise
                    end
                end
            end
        end

        class GetInstance < ClientTest
            def runtest
                name = cimcall(:EnumerateInstanceNames,
                               'RubyWBEM_Person')[0]

                # Simplest invocation
                obj = cimcall(:GetInstance, name)
                
                assert_(obj.is_a?(CIMInstance))
                assert_(obj.path.is_a?(CIMInstanceName))
                
                # Call with invalid namespace path
                invalid_name = name.clone
                invalid_name.namespace = 'blahblahblah'
                
                begin
                    self.cimcall(:GetInstance, invalid_name)
                rescue CIMError => arg
                    raise if arg.code != CIM_ERR_INVALID_NAMESPACE
                end
            end
        end

        class CreateInstance < ClientTest
            def runtest
                # Test instance
                instance = deletedtestinstance
                                                      
                # Simple create and delete
                result = cimcall(:CreateInstance, instance)

                self.assert_(result.is_a?(CIMInstanceName))
                self.assert_(result.namespace.length > 0)
        
                result = cimcall(:DeleteInstance, instance.path)

                self.assert_(result.nil?)

                begin
                    cimcall(:GetInstance, instance.path)
                rescue CIMError => arg
                    if arg == CIM_ERR_NOT_FOUND
                        # do nothing
                    end
                end

                # Arg plus namespace
                begin
                    cimcall(:CreateInstance, instance)
                rescue CIMError => arg
                    raise if arg.code != CIM_ERR_INVALID_NAMESPACE
                end
            end
        end

        class ModifyInstance < ClientTest

            def runtest

                # Test instance
                instance = deletedtestinstance

                # Create instance
                cimcall(:CreateInstance, instance)

                # Modify instance
                instance['Title'] = 'Sir'

                instance.path.namespace = 'root/cimv2'
                result = cimcall(:ModifyInstance, instance)

                self.assert_(result.nil?)

                # Clean up

                cimcall(:DeleteInstance, instance.path)
                namedInstance = cimcall(:EnumerateInstances, 'CIM_Process')[0]

                begin
                    obj = cimcall(:ModifyInstance, namedInstance)
                rescue CIMError => arg
                    raise if arg.code != CIM_ERR_NOT_SUPPORTED
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
                    raise if arg.code != CIM_ERR_METHOD_NOT_AVAILABLE
                end

                # Invoke on an InstanceName
                name = cimcall(:EnumerateInstanceNames, 'CIM_Process')[0]

                begin
                    cimcall(:InvokeMethod,
                            'FooMethod',
                            name)
                rescue CIMError => arg
                    raise if arg.code != CIM_ERR_METHOD_NOT_AVAILABLE
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
                    raise if arg.code != CIM_ERR_METHOD_NOT_AVAILABLE
                end

                # Test remote instance name
                name2 = name.clone
                name2.host = 'woot.com'
                name2.namespace = 'root/cimv2'

                begin
                    self.cimcall(:InvokeMethod, 'FooMethod', name)
                rescue CIMError => arg
                    raise if arg.code != CIM_ERR_METHOD_NOT_AVAILABLE
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
                    raise if arg.code != CIM_ERR_METHOD_NOT_AVAILABLE
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
                    raise if arg.code != CIM_ERR_METHOD_NOT_AVAILABLE
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
                # Call on named instance
                collection = cimcall(:EnumerateInstanceNames, 
                                     'RubyWBEM_PersonCollection')[0]

                instances = self.cimcall(:Associators, collection)
                instances.each do |i|
                    self.assert_(i.is_a?(CIMInstance))
                    self.assert_(i.classname == 'RubyWBEM_Person')
                    n = i.path
                    self.assert_(n.is_a?(CIMInstanceName))
                    self.assert_(!n.host.nil?)
                    self.assert_(!n.namespace.nil?)
                end

                # Call on class name
                classes = self.cimcall(:Associators, 'RubyWBEM_PersonCollection')
                # TODO: check return values
            end
        end
        
        class AssociatorNames < ClientTest
            def runtest
                # Call on named instance
                collection = cimcall(:EnumerateInstanceNames, 
                                     'RubyWBEM_PersonCollection')[0]

                names = self.cimcall(:AssociatorNames, collection)
                names.each do |n|
                    self.assert_(n.is_a?(CIMInstanceName))
                    self.assert_(n.classname == 'RubyWBEM_Person')
                    self.assert_(!n.host.nil?)
                    self.assert_(!n.namespace.nil?)
                end

                # Call on class name
                classes = self.cimcall(:AssociatorNames, 
                                       'RubyWBEM_PersonCollection')
                # TODO: check return values
            end
        end
        
        class References < ClientTest
            def runtest
                # Call on named instance
                collection = cimcall(:EnumerateInstanceNames, 
                                     'RubyWBEM_PersonCollection')[0]

                instances = self.cimcall(:References, collection)
                instances.each do |i|
                    self.assert_(i.is_a?(CIMInstance))
                    self.assert_(i.classname == 'RubyWBEM_MemberOfPersonCollection')
                    n = i.path
                    self.assert_(n.is_a?(CIMInstanceName))
                    self.assert_(!n.host.nil?)
                    self.assert_(!n.namespace.nil?)
                end

                # Call on class name
                classes = self.cimcall(:References, 'RubyWBEM_PersonCollection')
                # TODO: check return values
            end
        end
        
        class ReferenceNames < ClientTest
            def runtest
                # Call on named instance
                collection = cimcall(:EnumerateInstanceNames, 
                                     'RubyWBEM_PersonCollection')[0]

                names = self.cimcall(:ReferenceNames, collection)
                names.each do |n|
                    self.assert_(n.is_a?(CIMInstanceName))
                    self.assert_(n.classname == 'RubyWBEM_MemberOfPersonCollection')
                    self.assert_(!n.host.nil?)
                    self.assert_(!n.namespace.nil?)
                end

                # Call on class name
                classes = self.cimcall(:ReferenceNames, 'RubyWBEM_PersonCollection')
                # TODO: check return values
            end
        end
        
        #################################################################
        # Schema manipulation interface tests
        #################################################################

        module ClassVerifier
            #"""Includable module for testing CIMClass instances."""
            def verify_property(p)
                assert_(p.is_a?(CIMProperty))
            end

            def verify_qualifier(q)
                assert_(q.name)
                assert_(q.value)
            end

            def verify_method(m)
                # TODO: verify method
            end

            def verify_class(cl)
                
                # Verify simple attributes
                assert_(cl.classname)
                
                unless cl.superclass.nil?
                    assert_(cl.superclass)
                end

                # Verify properties, qualifiers and methods
                cl.properties.values.each { |p| self.verify_property(p) }
                cl.qualifiers.values.each { |p| self.verify_qualifier(p) }
                cl.cim_methods.values.each { |p| self.verify_method(p) }
            end
        end

        class EnumerateClassNames < ClientTest
            def runtest
                # Enumerate all classes
                names = cimcall(:EnumerateClassNames)
                names.each { |n| assert_(n.is_a?(String)) }

                # Enumerate with classname arg
                names = cimcall(:EnumerateClassNames,
                                 :ClassName => 'CIM_ManagedElement')
                names.each { |n| self.assert_(n.is_a?(String)) }
            end
        end

        class EnumerateClasses < ClientTest
            include ClassVerifier

            def runtest
                # Enumerate all classes
                classes = cimcall(:EnumerateClasses)
                classes.each { |c| assert_(c.is_a?(CIMClass))  }
                classes.each { |c| verify_class(c) }

                # Enumerate with classname arg
                classes = cimcall(:EnumerateClasses,
                                  :ClassName => 'CIM_ManagedElement')
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

                 ExecQuery,
                 ExecuteQuery

                ]

        if __FILE__ == $0
            
            if ARGV.size < 1
                print "Usage: test_cim_operations.rb HOST [USERNAME%PASSWORD]\n"
                exit(0)
            end
            
            Hostinfo.instance.host = ARGV[0]
            if ARGV.size == 2
                Hostinfo.instance.username, Hostinfo.instance.password = ARGV[1].split('%')
            else
                print 'Username: '
                username = STDIN.readline.strip
                password = Password.get( "Password: " )
            end
            ARGV.shift
            ARGV.shift
            
            Comfychair.main(TESTS)
        end

    end
end

