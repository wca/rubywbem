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
# Test CIM object interface.
#
# Ideally this file would completely describe the Ruby interface to
# CIM objects.  If a particular data structure or Ruby property is
# not implemented here, then it is not officially supported by RubyWBEM.
# Any breaking of backwards compatibility of new development should be
# picked up here.
#

require "comfychair"
require "validate"
require "wbem"

module WBEM
    module Test
        class ValidateTest < Comfychair::TestCase
            include Validate
            def validate(obj)
                #"""Run a CIM XML fragment through the validator."""
                self.log(obj.toxml())
                assert_(validate_xml(obj.toxml(), dtd_directory = '../..'))
            end
        end

        class DictTest < Comfychair::TestCase

            def runtest_dict(obj)

                # Test __getitem__
                self.assert_(obj['Chicken'] == 'Ham')
                self.assert_(obj['Beans'] == 42)

                self.assert_(obj['Cheepy'].nil?)
                begin
                    obj.fetch('Cheepy')
                rescue IndexError
                else
                    fail('IndexError not thrown')
                end

                # Test __setitem__

                obj['tmp'] = 'tmp'
                self.assert_(obj['tmp'] == 'tmp')

                # Test has_key

                self.assert_(obj.has_key?('tmp'))

                # Test __delitem__

                obj.delete('tmp')
                self.assert_(!obj.has_key?('tmp'))

                # Test __len__

                self.assert_(obj.length == 2)

                # Test keys

                keys = obj.keys()
                self.assert_(keys.include?('Chicken') && keys.include?('Beans'))
                self.assert_(keys.length == 2)

                # Test values

                values = obj.values()
                self.assert_(values.include?('Ham') && values.include?(42))
                self.assert_(values.length == 2)
                
                # Test items

                items = obj.to_a()
                self.assert_(items.include?(['Chicken', 'Ham']) &&
                             items.include?(['Beans', 42]))
                self.assert_(items.length == 2)

                # Test iterkeys
                # not in ruby
                # Test itervalues
                # not in ruby
                # Test iteritems
                # not in ruby
            end
        end

        #################################################################
        # CIMInstanceName
        #################################################################

        class InitCIMInstanceName < Comfychair::TestCase
            #"""A CIMInstanceName can be initialised with just a classname, or a
            #classname and dict of keybindings."""

            def runtest

                # Initialise with classname only

                obj = CIMInstanceName.new('CIM_Foo')
                self.assert_(obj.keys().length == 0)

                # Initialise with keybindings dict

                obj = CIMInstanceName.new('CIM_Foo', {'Name'=> 'Foo', 'Chicken' => 'Ham'})
                self.assert_(obj.keys().length == 2)

                # Initialise with all possible keybindings types

                obj = CIMInstanceName.new('CIM_Foo', {'Name' => 'Foo',
                                              'Number' => 42,
                                              'Boolean' => false,
                                              'Ref' => CIMInstanceName.new('CIM_Bar')})
                self.assert_(obj.keys().length == 4)

                # Initialise with namespace
                
                obj = CIMInstanceName.new('CIM_Foo',
                                          {'InstanceID' => '1234'},
                                          nil, 'root/cimv2')
                
                # Initialise with host and namespace
                
                obj = CIMInstanceName.new('CIM_Foo',
                                          {'InstanceID' => '1234'},
                                          'woot.com',
                                          'root/cimv2')
            end
        end

        class CopyCIMInstanceName < Comfychair::TestCase

            def runtest

                i = CIMInstanceName.new('CIM_Foo',
                                        {'InstanceID' => '1234'},
                                        'woot.com',
                                        'root/cimv2')

                c = i.clone

                self.assert_equal(i, c)

                c.classname = 'CIM_Bar'
                c.keybindings = NocaseHash.new({'InstanceID' => '5678'})
                c.host = nil
                c.namespace = nil

                self.assert_(i.classname == 'CIM_Foo')
                self.assert_(i.keybindings['InstanceID'] == '1234')
                self.assert_(i.host == 'woot.com')
                self.assert_(i.namespace == 'root/cimv2')
            end
        end

        class CIMInstanceNameAttrs < Comfychair::TestCase
            #"""Valid attributes for CIMInstanceName are 'classname' and
            #'keybindings'."""

            def runtest

                kb = {'Chicken' => 'Ham', 'Beans' => 42}

                obj = CIMInstanceName.new('CIM_Foo', kb)

                self.assert_(obj.classname == 'CIM_Foo')
                self.assert_(obj.keybindings == kb)
                self.assert_(obj.host.nil?)
                self.assert_(obj.namespace.nil?)
            end
        end

        class CIMInstanceNameDictInterface < DictTest
            #"""Test the Python dictionary interface for CIMInstanceName."""

            def runtest

                kb = {'Chicken' => 'Ham', 'Beans' => 42}
                obj = CIMInstanceName.new('CIM_Foo', kb)

                self.runtest_dict(obj)
            end
        end

        class CIMInstanceNameEquality < Comfychair::TestCase
            #"""Test comparing CIMInstanceName objects."""
            
            def runtest

                # Basic equality tests

                self.assert_equal(CIMInstanceName.new('CIM_Foo'),
                                  CIMInstanceName.new('CIM_Foo'))

                self.assert_notequal(CIMInstanceName.new('CIM_Foo', {'Cheepy' => 'Birds'}),
                                     CIMInstanceName.new('CIM_Foo'))

                self.assert_equal(CIMInstanceName.new('CIM_Foo', {'Cheepy' => 'Birds'}),
                                  CIMInstanceName.new('CIM_Foo', {'Cheepy' => 'Birds'}))

                # Classname should be case insensitive

                self.assert_equal(CIMInstanceName.new('CIM_Foo'),
                                  CIMInstanceName.new('cim_foo'))

                # NocaseDict should implement case insensitive keybinding names

                self.assert_equal(CIMInstanceName.new('CIM_Foo', {'Cheepy' => 'Birds'}),
                                  CIMInstanceName.new('CIM_Foo', {'cheepy' => 'Birds'}))

                self.assert_notequal(CIMInstanceName.new('CIM_Foo', {'Cheepy' => 'Birds'}),
                                     CIMInstanceName.new('CIM_Foo', {'cheepy' => 'birds'}))

                # Test a bunch of different keybinding types

                obj1 = CIMInstanceName.new('CIM_Foo', {'Name' => 'Foo',
                                               'Number' => 42,
                                               'Boolean' => false,
                                               'Ref' => CIMInstanceName.new('CIM_Bar')})

                obj2 = CIMInstanceName.new('CIM_Foo', {'Name' => 'Foo',
                                               'Number' => 42,
                                               'Boolean' => false,
                                               'Ref' => CIMInstanceName.new('CIM_Bar')})

                self.assert_equal(obj1, obj2)

                # Test keybinding types are not confused in comparisons

                self.assert_notequal(CIMInstanceName.new('CIM_Foo', {'Foo' => '42'}),
                                     CIMInstanceName.new('CIM_Foo', {'Foo' => 42}))

                self.assert_notequal(CIMInstanceName.new('CIM_Foo', {'Bar' => true}),
                                     CIMInstanceName.new('CIM_Foo', {'Bar' => 'TRUE'}))

                # Test hostname is case insensitive

                self.assert_equal(CIMInstanceName.new('CIM_Foo', {}, 'woot.com'),
                                  CIMInstanceName.new('CIM_Foo', {}, 'Woot.Com'))
            end
        end

        class CIMInstanceNameCompare < Comfychair::TestCase
            def runtest
                raise Comfychair::NotRunError
            end
        end

        class CIMInstanceNameSort < Comfychair::TestCase
            def runtest
                raise Comfychair::NotRunError
            end
        end

        class CIMInstanceNameString < Comfychair::TestCase
            #"""Test string representation functions for CIMInstanceName
            #objects."""
            
            def runtest
                
                obj = CIMInstanceName.new('CIM_Foo', {'Name' => 'Foo', 'Secret' => 42})
                
                # Test str() method generates output with classname and
                # keybindings: e.g CIM_Foo.Secret=42,Name="Foo"
                
                s = obj.to_s
                
                self.assert_re_match('^CIM_Foo\.', s)
                self.assert_re_match('Secret=42', s)
                self.assert_re_match('Name="Foo"', s)
                
                s = s.sub!('CIM_Foo.', '')
                s = s.sub!('Secret=42', '')
                s = s.sub!('Name="Foo"', '')
                
                self.assert_(s == ',')
                
                # not relevant for Ruby
                # Test repr() function contains slightly more verbose
                # output, but we're not too concerned about the format.
                #
                # CIMInstanceName(classname='CIM_Foo', \
                #     keybindings=NocaseDict({'Secret' => 42, 'Name' => 'Foo'}))
                
                #r = repr(obj)
                
                #self.assert_re_match('^CIMInstanceName\(classname=\'CIM_Foo\'', r)
                #self.assert_re_search('keybindings=', r)
                #self.assert_re_search('\'Secret\' => 42', r)
                #self.assert_re_search('\'Name\' => \'Foo\'', r)

                # Test str() with namespace

                obj = CIMInstanceName.new('CIM_Foo', {'InstanceID' => '1234'},
                                          nil, 'root/InterOp')

                self.assert_equal(obj.to_s, 'root/InterOp:CIM_Foo.InstanceID="1234"')

                # Test str() with host and namespace

                obj = CIMInstanceName.new('CIM_Foo', {'InstanceID' => '1234'},
                                          'woot.com',
                                          'root/InterOp')

                self.assert_equal(obj.to_s,
                                  '//woot.com/root/InterOp:CIM_Foo.InstanceID="1234"')
            end
        end

        class CIMInstanceNameToXML < ValidateTest
            #"""Test valid XML is generated for various CIMInstanceName objects."""

            def runtest

                self.validate(CIMInstanceName.new('CIM_Foo'))
                self.validate(CIMInstanceName.new('CIM_Foo', {'Cheepy' => 'Birds'}))
                self.validate(CIMInstanceName.new('CIM_Foo', {'Name' => 'Foo',
                                                      'Number' => 42,
                                                      'Boolean' => false,
                                                      'Ref' => CIMInstanceName.new('CIM_Bar')}))
                self.validate(CIMInstanceName.new('CIM_Foo', {}, nil, 'root/cimv2'))
                self.validate(CIMInstanceName.new('CIM_Foo', {}, 'woot.com', 'root/cimv2'))
            end
        end
        #################################################################
        # CIMInstance
        #################################################################

        class InitCIMInstance < Comfychair::TestCase
            #"""CIMInstance objects can be initialised in a similar manner to
            #CIMInstanceName, i.e classname only, or a list of properties."""

            def runtest

                # Initialise with classname only

                obj = CIMInstance.new('CIM_Foo')

                # Initialise with keybindings dict

                obj = CIMInstance.new('CIM_Foo', {'Name' => 'Foo', 'Chicken' => 'Ham'})
                self.assert_(obj.keys().length == 2)

                # Check that CIM type checking is done for integer and
                # floating point property values
                
                begin
                    obj = CIMInstance.new('CIM_Foo', {'Number' => 42})
                rescue TypeError
                else
                    self.fail('TypeError not raised')
                end

                obj = CIMInstance.new('CIM_Foo', {'Foo' => Uint32.new(42),
                                          'Bar' => Real32.new(42.0)})

                # Initialise with qualifiers

                obj = CIMInstance.new('CIM_Foo', {},
                                      {'Key' => CIMQualifier.new('Key', true)})

                # Initialise with path

                obj = CIMInstance.new('CIM_Foo',
                                      {'InstanceID' => '1234'},
                                      nil, CIMInstanceName.new('CIM_Foo',
                                                               {'InstanceID' => '1234'}))
            end
        end

        class CopyCIMInstance < Comfychair::TestCase

            def runtest

                i = CIMInstance.new('CIM_Foo',
                                    {'Name' => 'Foo', 'Chicken' => 'Ham'},
                                    {'Key' => 'Value'},
                                    CIMInstanceName.new('CIM_Foo', {'Name' => 'Foo'}))

                c = i.clone

                self.assert_equal(i, c)

                c.classname = 'CIM_Bar'
                c.properties = {'InstanceID' => '5678'}
                c.qualifiers = {}
                c.path = nil

                self.assert_(i.classname == 'CIM_Foo')
                self.assert_(i['Name'] == 'Foo')
                self.assert_(i.qualifiers['Key'] == 'Value')
                self.assert_(i.path == CIMInstanceName.new('CIM_Foo', {'Name' => 'Foo'}))

                # Test clone when path is None
    
                i = CIMInstance.new('CIM_Foo',
                                    {'Name' => 'Foo', 'Chicken' => 'Ham'},
                                    {'Key' => 'Value'},
                                    nil)
    
                self.assert_(i == i.clone)

            end
        end

        class CIMInstanceAttrs < Comfychair::TestCase
            #"""Valid attributes for CIMInstance are 'classname' and
            #'keybindings'."""

            def runtest

                props = {'Chicken' => 'Ham', 'Number' => Uint32.new(42)}

                obj = CIMInstance.new('CIM_Foo', props,
                                      {'Key' => CIMQualifier.new('Key', true)},
                                      CIMInstanceName.new('CIM_Foo',
                                                          {'Chicken' => 'Ham'}))

                self.assert_(obj.classname == 'CIM_Foo')

                self.assert_(obj.properties)
                self.assert_(obj.qualifiers)
                self.assert_(obj.path)
            end
        end

        class CIMInstanceDictInterface < DictTest
            #"""Test the Python dictionary interface for CIMInstance."""

            def runtest

                props = {'Chicken' => 'Ham', 'Beans' => Uint32.new(42)}
                obj = CIMInstance.new('CIM_Foo', props)

                self.runtest_dict(obj)

                # Test CIM type checking

                begin
                    obj['Foo'] = 43
                rescue TypeError
                else
                    self.fail('TypeError not raised')
                end

                obj['Foo'] = Uint32.new(43)
            end
        end

        class CIMInstanceEquality < Comfychair::TestCase
            #"""Test comparing CIMInstance objects."""

            def runtest

                # Basic equality tests

                self.assert_equal(CIMInstance.new('CIM_Foo'),
                                  CIMInstance.new('CIM_Foo'))

                self.assert_notequal(CIMInstance.new('CIM_Foo', {'Cheepy' => 'Birds'}),
                                     CIMInstance.new('CIM_Foo'))

                # Classname should be case insensitive

                self.assert_equal(CIMInstance.new('CIM_Foo'),
                                  CIMInstance.new('cim_foo'))

                # NocaseDict should implement case insensitive keybinding names

                self.assert_equal(CIMInstance.new('CIM_Foo', {'Cheepy' => 'Birds'}),
                                  CIMInstance.new('CIM_Foo', {'cheepy' => 'Birds'}))

                self.assert_notequal(CIMInstance.new('CIM_Foo', {'Cheepy' => 'Birds'}),
                                     CIMInstance.new('CIM_Foo', {'cheepy' => 'birds'}))

                # Qualifiers

                self.assert_notequal(CIMInstance.new('CIM_Foo'),
                                     CIMInstance.new('CIM_Foo', {},
                                                     {'Key' => CIMQualifier.new('Key', true)}))

                # Path

                self.assert_notequal(CIMInstance.new('CIM_Foo'),
                                     CIMInstance.new('CIM_Foo', {'Cheepy' => 'Birds'}))

                # Reference properties

                self.assert_equal(CIMInstance.new('CIM_Foo',
                                                  {'Ref1' => CIMInstanceName.new('CIM_Bar')}),
                                  CIMInstance.new('CIM_Foo',
                                                  {'Ref1' => CIMInstanceName.new('CIM_Bar')}))

                # Null properties

                self.assert_notequal(
                                     CIMInstance.new('CIM_Foo',
                                                     {'Null' => CIMProperty.new('Null', nil, 'string')}),
                                     CIMInstance.new('CIM_Foo',
                                                     {'Null' => CIMProperty.new('Null', '')}))

                self.assert_notequal(
                                     CIMInstance.new('CIM_Foo',
                                                     {'Null' => CIMProperty.new('Null', nil, type = 'uint32')}),
                                     CIMInstance.new('CIM_Foo',
                                                     {'Null' => CIMProperty.new('Null', Uint32.new(0))}))

                # Mix of CIMProperty and native Python types

                self.assert_equal(
                                  CIMInstance.new(
                                                  'CIM_Foo',
                                                  {'string' => 'string',
                                                      'uint8' => Uint8.new(0),
                                                      'uint8array' => [Uint8.new(1), Uint8.new(2)],
                                                      'ref' => CIMInstanceName.new('CIM_Bar')}),
                                  CIMInstance.new(
                                                  'CIM_Foo',
                                                  {'string' => CIMProperty.new('string', 'string'),
                                                      'uint8' => CIMProperty.new('uint8', Uint8.new(0)),
                                                      'uint8Array' => CIMProperty.new('uint8Array', [Uint8.new(1), Uint8.new(2)]),
                                                      'ref' => CIMProperty.new('ref', CIMInstanceName.new('CIM_Bar'))})
                                  )
            end
        end

        class CIMInstanceCompare < Comfychair::TestCase
            def runtest
                raise Comfychair::NotRunError
            end
        end

        class CIMInstanceSort < Comfychair::TestCase
            def runtest
                raise Comfychair::NotRunError
            end
        end

        class CIMInstanceString < Comfychair::TestCase
            #"""Test string representation functions for CIMInstance objects."""
            
            def runtest
                obj = CIMInstance.new('CIM_Foo', {'Name' => 'Spottyfoot',
                                          'Ref1' => CIMInstanceName.new('CIM_Bar')})

                s = obj.to_s

                self.assert_re_match('classname=CIM_Foo', s)
                self.assert_(s.index('Name').nil?)
                self.assert_(s.index('Ref1').nil?)

                #r = repr(obj)

                #self.assert_re_search('classname=\'CIM_Foo\'', r)
                #self.assert_(r.find('Name') == -1)
                #self.assert_(r.find('Ref1') == -1)
            end
        end

        class CIMInstanceToXML < ValidateTest
            """Test valid XML is generated for various CIMInstance objects."""

            def runtest

                # Simple instances, no properties

                self.validate(CIMInstance.new('CIM_Foo'))

                # Path

                self.validate(CIMInstance.new('CIM_Foo',
                                              {'InstanceID' => '1234'}, 
                                              {}, 
                                              CIMInstanceName.new('CIM_Foo',
                                                                  {'InstanceID' => '1234'})))

                # Multiple properties and qualifiers
                
                self.validate(CIMInstance.new('CIM_Foo', {'Spotty' => 'Foot',
                                                  'Age' => Uint32.new(42)},
                                              {'Key' => CIMQualifier.new('Key', true)}))

                # Test every numeric property type

                [Uint8, Uint16, Uint32, Uint64, Sint8, Sint16, Sint32, Sint64,
                 Real32, Real64].each do |t|
                    self.validate(CIMInstance.new('CIM_Foo', {'Number' => t.new(42)}))
                end
                
                # Other property types

                self.validate(CIMInstance.new('CIM_Foo', {'Value' => false}))

                self.validate(CIMInstance.new('CIM_Foo', {'Now' => DateTime.now()}))
                self.validate(CIMInstance.new('CIM_Foo', {'Now' => TimeDelta.new(60)}))

                self.validate(CIMInstance.new('CIM_Foo',
                                              {'Ref' => CIMInstanceName.new('CIM_Eep',
                                                                            {'Foo' => 'Bar'})}))
                
                # Array types.  Can't have an array of references

                [Uint8, Uint16, Uint32, Uint64, Sint8, Sint16, Sint32, Sint64,
                 Real32, Real64].each do |t|
                    
                    self.validate(CIMInstance.new('CIM_Foo', {'Number' => [t.new(42), t.new(43)]}))
                end

                self.validate(CIMInstance.new('CIM_Foo',
                                              {'Now' => [DateTime.now(), DateTime.now()]}))

                self.validate(CIMInstance.new('CIM_Foo',
                                              {'Then' => [TimeDelta.new(60), TimeDelta.new(61)]}))

                # Null properties.  Can't have a NULL property reference.

                obj = CIMInstance.new('CIM_Foo')

                obj.properties['Cheepy'] = CIMProperty.new('Cheepy', nil, 'string')
                obj.properties['Date'] = CIMProperty.new('Date', nil, 'datetime')
                obj.properties['Bool'] = CIMProperty.new('Bool', nil, 'boolean')

                ['uint8', 'uint16', 'uint32', 'uint64', 'sint8', 'sint16',
                 'sint32', 'sint64', 'real32', 'real64'].each do |t|
                    obj.properties[t] = CIMProperty.new(t, nil, t)
                end
                self.validate(obj)

                # Null property arrays.  Can't have arrays of NULL property
                # references.

                obj = CIMInstance.new('CIM_Foo')

                obj.properties['Cheepy'] = CIMProperty.new(
                                                           'Cheepy', nil, 'string', nil, nil, true)

                obj.properties['Date'] = CIMProperty.new(
                                                         'Date', nil, 'datetime', nil, nil, true)
                
                obj.properties['Bool'] = CIMProperty.new(
                                                         'Bool', nil, 'boolean', nil, nil, true)

                ['uint8', 'uint16', 'uint32', 'uint64', 'sint8', 'sint16',
                 'sint32', 'sint64', 'real32', 'real64'].each do |t|
                    obj.properties[t] = CIMProperty.new(t, nil, t, nil, nil, true)
                end            
                self.validate(obj)        
            end
        end

        class CIMInstanceToMOF < Comfychair::TestCase

            def runtest

                i = CIMInstance.new('CIM_Foo',
                                    {'string' => 'string',
                                     'uint8' => Uint8.new(0),
                                     'uint8array' => [Uint8.new(1), Uint8.new(2)],
                                     'ref' => CIMInstanceName.new('CIM_Bar')})

                i.tomof()
            end
        end
        #################################################################
        # CIMProperty
        #################################################################


        class InitCIMProperty < Comfychair::TestCase

            def runtest

                # Basic CIMProperty initialisations

                CIMProperty.new('Spotty', 'Foot', 'string')
                CIMProperty.new('Spotty', nil, 'string')
                #CIMProperty(u'Name', u'Brad')
                CIMProperty.new('Age', Uint16.new(32))
                CIMProperty.new('Age', nil, 'uint16')
                
                # Must specify a type when value is nil

                begin
                    CIMProperty.new('Spotty', nil)
                rescue TypeError
                else
                    self.fail('TypeError not raised')
                end

                # Numeric types must have CIM types

                begin
                    CIMProperty.new('Age', 42)
                rescue TypeError
                else
                    self.fail('TypeError not raised')
                end

                # Qualifiers

                CIMProperty.new('Spotty', 'Foot', nil, nil, nil, nil,
                                {'Key' => CIMQualifier.new('Key', true)})

                # Simple arrays

                CIMProperty.new('Foo', nil, 'string')
                CIMProperty.new('Foo', [1, 2, 3].collect {|x| Uint8.new(x)})
                CIMProperty.new('Foo', [1, 2, 3].collect {|x| Uint8.new(x)},
                                nil, nil, nil, nil, {'Key' => CIMQualifier.new('Key', true)})

                # Must specify type for empty property array

                begin
                    CIMProperty.new('Foo', [])
                rescue TypeError
                else
                    self.fail('TypeError not raised')
                end

                # Numeric property value arrays must be a CIM type

                begin
                    CIMProperty.new('Foo', [1, 2, 3])
                rescue TypeError
                else
                    self.fail('TypeError not raised')
                end
                
                # Property references

                CIMProperty.new('Foo', nil, type = 'reference')
                CIMProperty.new('Foo', CIMInstanceName.new('CIM_Foo'))
                CIMProperty.new('Foo', CIMInstanceName.new('CIM_Foo'),
                                nil, nil, nil, nil, {'Key' => CIMQualifier.new('Key', true)})
            end
        end

        class CopyCIMProperty < Comfychair::TestCase

            def runtest

                p = CIMProperty.new('Spotty', 'Foot')
                c = p.clone

                self.assert_equal(p, c)

                c.name = '1234'
                c.value = '1234'
                c.qualifiers = {'Key' => CIMQualifier.new('Value', true)}

                self.assert_(p.name == 'Spotty')
                self.assert_(p.value == 'Foot')
                self.assert_(p.qualifiers == {})
            end
        end

        class CIMPropertyAttrs < Comfychair::TestCase

            def runtest

                # Attributes for single-valued property

                obj = CIMProperty.new('Spotty', 'Foot', 'string')
                
                self.assert_(obj.name == 'Spotty')
                self.assert_(obj.value == 'Foot')
                self.assert_(obj.prop_type == 'string')
                self.assert_(obj.qualifiers == {})

                # Attributes for array property

                v = [1, 2, 3].collect {|x| Uint8.new(x)}

                obj = CIMProperty.new('Foo', v)

                self.assert_(obj.name == 'Foo')
                self.assert_(obj.value == v)
                self.assert_(obj.prop_type == 'uint8')
                self.assert_(obj.qualifiers == {})

                # Attributes for property reference

                v = CIMInstanceName.new('CIM_Foo')

                obj = CIMProperty.new('Foo', v, nil, nil, nil, nil, nil, 'CIM_Bar')

                self.assert_(obj.name == 'Foo')
                self.assert_(obj.value == v)
                self.assert_(obj.prop_type == 'reference')
                self.assert_(obj.reference_class == 'CIM_Bar')
                self.assert_(obj.qualifiers == {})
            end
        end

        class CIMPropertyEquality < Comfychair::TestCase

            def runtest

                # Compare single-valued properties

                self.assert_equal(CIMProperty.new('Spotty', nil, 'string'),
                                  CIMProperty.new('Spotty', nil, 'string'))

                self.assert_notequal(CIMProperty.new('Spotty', '', 'string'),
                                     CIMProperty.new('Spotty', nil, 'string'))

                self.assert_equal(CIMProperty.new('Spotty', 'Foot'),
                                  CIMProperty.new('Spotty', 'Foot'))

                self.assert_notequal(CIMProperty.new('Spotty', 'Foot'),
                                     CIMProperty.new('Spotty', Uint32.new(42)))

                self.assert_equal(CIMProperty.new('Spotty', 'Foot'),
                                  CIMProperty.new('spotty', 'Foot'))

                self.assert_notequal(CIMProperty.new('Spotty', 'Foot'),
                                     CIMProperty.new('Spotty', 'Foot',
                                                     nil, nil, nil, nil,
                                                     {'Key' =>
                                                         CIMQualifier.new('Key', true)}))

                # Compare property arrays

                self.assert_equal(
                                  CIMProperty.new('Array', nil, 'uint8', nil, nil, true),
                                  CIMProperty.new('array', nil, 'uint8', nil, nil, true))

                self.assert_equal(
                                  CIMProperty.new('Array', [1, 2, 3].collect {|x| Uint8.new(x)}),
                                  CIMProperty.new('Array', [1, 2, 3].collect {|x| Uint8.new(x)}))

                self.assert_notequal(
                                     CIMProperty.new('Array', [1, 2, 3].collect {|x| Uint8.new(x)}),
                                     CIMProperty.new('Array', [1, 2, 3].collect {|x| Uint16.new(x)}))

                self.assert_notequal(
                                     CIMProperty.new('Array', [1, 2, 3].collect {|x| Uint8.new(x)}),
                                     CIMProperty.new('Array', [1, 2, 3].collect {|x| Uint16.new(x)},
                                                     nil, nil, nil, nil, {'Key' => CIMQualifier.new('Key', true)}))

                # Compare property references
                
                self.assert_equal(
                                  CIMProperty.new('Foo', CIMInstanceName.new('CIM_Foo')),
                                  CIMProperty.new('Foo', CIMInstanceName.new('CIM_Foo')))
                
                self.assert_equal(
                                  CIMProperty.new('Foo', CIMInstanceName.new('CIM_Foo')),
                                  CIMProperty.new('foo', CIMInstanceName.new('CIM_Foo')))

                self.assert_notequal(
                                     CIMProperty.new('Foo', CIMInstanceName.new('CIM_Foo')),
                                     CIMProperty.new('foo', nil, 'reference'))

                self.assert_notequal(
                                     CIMProperty.new('Foo', CIMInstanceName.new('CIM_Foo')),
                                     CIMProperty.new('Foo', CIMInstanceName.new('CIM_Foo'),
                                                     nil, nil, nil, nil,
                                                     {'Key' => CIMQualifier.new('Key', true)}))        
            end
        end

        class CIMPropertyCompare < Comfychair::TestCase
            def runtest
                raise Comfychair::NotRunError
            end
        end

        class CIMPropertySort < Comfychair::TestCase
            def runtest
                raise Comfychair::NotRunError
            end
        end

        class CIMPropertyString < Comfychair::TestCase

            def runtest

                r = CIMProperty.new('Spotty', 'Foot', 'string').to_s

                self.assert_re_match('^WBEM::CIMProperty', r)
            end
        end

        class CIMPropertyToXML < ValidateTest
            #"""Test valid XML is generated for various CIMProperty objects."""

            def runtest

                # Single-valued properties

                self.validate(CIMProperty.new('Spotty', nil, 'string'))
                #self.validate(CIMProperty.new(u'Name', u'Brad'))
                self.validate(CIMProperty.new('Age', Uint16.new(32)))
                self.validate(CIMProperty.new('Age', Uint16.new(32),
                                              nil, nil, nil, nil, 
                                              {'Key' => CIMQualifier.new('Key', true)}))

                # Array properties

                self.validate(CIMProperty.new('Foo', nil, 'string', nil, nil, true))
                self.validate(CIMProperty.new('Foo', [], 'string'))
                self.validate(CIMProperty.new('Foo', [1, 2, 3].collect {|x| Uint8.new(x)}))

                self.validate(CIMProperty.new(
                                              'Foo', [1, 2, 3].collect {|x| Uint8.new(x)},
                                              nil, nil, nil, nil, {'Key' => CIMQualifier.new('Key', true)}))

                # Reference properties

                self.validate(CIMProperty.new('Foo', nil, 'reference'))
                self.validate(CIMProperty.new('Foo', CIMInstanceName.new('CIM_Foo')))

                self.validate(CIMProperty.new(
                                              'Foo',
                                              CIMInstanceName.new('CIM_Foo'),
                                              nil, nil, nil, nil, {'Key' => CIMQualifier.new('Key', true)}))        
            end
        end

        #################################################################
        # CIMQualifier
        #################################################################

        class InitCIMQualifier < Comfychair::TestCase
            #"""Test initialising a CIMQualifier object."""

            def runtest

                CIMQualifier.new('Revision', '2.7.0', 'string')
                CIMQualifier.new('RevisionList', ['1', '2', '3'], false)
            end
        end

        class CopyCIMQualifier < Comfychair::TestCase

            def runtest

                q = CIMQualifier.new('Revision', '2.7.0', 'string')
                c = q.clone

                self.assert_equal(q, c)

                c.name = 'Fooble'
                c.value = 'eep'

                self.assert_(q.name == 'Revision')
            end
        end

        class CIMQualifierAttrs < Comfychair::TestCase
            #"""Test attributes of CIMQualifier object."""
            
            def runtest
                
                q = CIMQualifier.new('Revision', '2.7.0')
                
                self.assert_equal(q.name, 'Revision')
                self.assert_equal(q.value, '2.7.0')
                
                self.assert_equal(q.propagated, nil)
                self.assert_equal(q.overridable, nil)
                self.assert_equal(q.tosubclass, nil)
                self.assert_equal(q.toinstance, nil)
                self.assert_equal(q.translatable, nil)
                
                q = CIMQualifier.new('RevisionList', ['1', '2', '3'], false)
                
                self.assert_equal(q.name, 'RevisionList')
                self.assert_equal(q.value, ['1', '2', '3'])
                self.assert_equal(q.propagated, false)
            end
        end
        
        class CIMQualifierEquality < Comfychair::TestCase
            #"""Compare CIMQualifier objects."""

            def runtest

                self.assert_equal(CIMQualifier.new('Spotty', 'Foot'),
                                  CIMQualifier.new('Spotty', 'Foot'))

                self.assert_equal(CIMQualifier.new('Spotty', 'Foot'),
                                  CIMQualifier.new('spotty', 'Foot'))

                self.assert_notequal(CIMQualifier.new('Spotty', 'Foot'),
                                     CIMQualifier.new('Spotty', 'foot'))
            end
        end

        class CIMQualifierCompare < Comfychair::TestCase
            def runtest
                raise Comfychair::NotRunError
            end
        end

        class CIMQualifierSort < Comfychair::TestCase
            def runtest
                raise Comfychair::NotRunError
            end
        end

        class CIMQualifierString < Comfychair::TestCase

            def runtest
                s = CIMQualifier.new('RevisionList', ['1', '2', '3'], false).to_s
                self.assert_re_match('RevisionList', s)
            end
        end
        
        class CIMQualifierToXML < ValidateTest

            def runtest

                self.validate(CIMQualifier.new('Spotty', 'Foot'))
                self.validate(CIMQualifier.new('Revision', Real32.new(2.7)))

                self.validate(CIMQualifier.new('RevisionList',
                                               [1, 2, 3].collect { |x| Uint16.new(x)},
                                               false))
            end
        end

        #################################################################
        # CIMClass
        #################################################################

        class InitCIMClass < Comfychair::TestCase

            def runtest

                # Initialise with classname, superclass

                CIMClass.new('CIM_Foo')
                CIMClass.new('CIM_Foo', nil, nil, nil, 'CIM_Bar')

                # Initialise with properties

                CIMClass.new('CIM_Foo', {'InstanceID' => CIMProperty.new('InstanceID', nil, 'string')})

                # Initialise with methods

                CIMClass.new('CIM_Foo', nil, nil, {'Delete' => CIMMethod.new('Delete')})

                # Initialise with qualifiers

                CIMClass.new('CIM_Foo', nil, {'Key' => CIMQualifier.new('Key', true)})
            end
        end

        class CopyCIMClass < Comfychair::TestCase

            def runtest

                c = CIMClass.new('CIM_Foo', 
                                 {},
                                 {'Key' => CIMQualifier.new('Value', true)},
                                 {'Delete' => CIMMethod.new('Delete')})

                co = c.clone

                self.assert_equal(c, co)

                co.classname = 'CIM_Bar'
                co.cim_methods.delete('Delete')
                co.qualifiers.delete('Key')

                self.assert_(c.classname == 'CIM_Foo')
                self.assert_(c.cim_methods['Delete'])
                self.assert_(c.qualifiers['Key'])
            end
        end

        class CIMClassAttrs < Comfychair::TestCase

            def runtest

                obj = CIMClass.new('CIM_Foo', nil, nil, nil, 'CIM_Bar')

                self.assert_(obj.classname == 'CIM_Foo')
                self.assert_(obj.superclass == 'CIM_Bar')
                self.assert_(obj.properties == {})
                self.assert_(obj.qualifiers == {})
                self.assert_(obj.cim_methods == {})
                self.assert_(obj.qualifiers == {})
            end
        end

        class CIMClassEquality < Comfychair::TestCase

            def runtest
                
                self.assert_equal(CIMClass.new('CIM_Foo'), CIMClass.new('CIM_Foo'))
                self.assert_equal(CIMClass.new('CIM_Foo'), CIMClass.new('cim_foo'))

                self.assert_notequal(CIMClass.new('CIM_Foo', nil, nil, nil, 'CIM_Bar'),
                                     CIMClass.new('CIM_Foo'))

                properties = {'InstanceID' => CIMProperty.new('InstanceID', nil, 'string')}

                methods = {'Delete' => CIMMethod.new('Delete')}

                qualifiers = {'Key' => CIMQualifier.new('Key', true)}
                
                self.assert_notequal(CIMClass.new('CIM_Foo'),
                                     CIMClass.new('CIM_Foo', properties))

                self.assert_notequal(CIMClass.new('CIM_Foo'),
                                     CIMClass.new('CIM_Foo', nil, nil, methods))
                
                self.assert_notequal(CIMClass.new('CIM_Foo'),
                                     CIMClass.new('CIM_Foo', nil, qualifiers))

                self.assert_equal(CIMClass.new('CIM_Foo', nil, nil, 
                                               nil, 'CIM_Bar'),
                                  CIMClass.new('CIM_Foo', nil, nil, 
                                               nil, 'cim_bar'))
            end
        end

        class CIMClassCompare < Comfychair::TestCase
            def runtest
                raise Comfychair::NotRunError
            end
        end

        class CIMClassSort < Comfychair::TestCase
            def runtest
                raise Comfychair::NotRunError
            end
        end

        class CIMClassString < Comfychair::TestCase

            def runtest

                s = CIMClass.new('CIM_Foo').to_s
                self.assert_re_match('CIM_Foo', s)
            end
        end

        class CIMClassToXML < ValidateTest

            def runtest

                self.validate(CIMClass.new('CIM_Foo'))
                self.validate(CIMClass.new('CIM_Foo', nil, nil, nil,  'CIM_Bar'))
                
                self.validate(
                              CIMClass.new(
                                           'CIM_Foo',
                                           {'InstanceID' => CIMProperty.new('InstanceID', nil, 'string')}))

                self.validate(
                              CIMClass.new(
                                           'CIM_Foo',
                                           nil, nil, {'Delete' => CIMMethod.new('Delete')}))


                self.validate(
                              CIMClass.new(
                                           'CIM_Foo',
                                           nil, {'Key' => CIMQualifier.new('Key', true)}))
            end
        end

        class CIMClassToMOF < Comfychair::TestCase
            
            def runtest
                
                c = CIMClass.new('CIM_Foo',
                                 {'InstanceID' => CIMProperty.new('InstanceID', nil, 'string')})
                
                c.tomof()
            end
        end

        #################################################################
        # CIMMethod
        #################################################################

        class InitCIMMethod < Comfychair::TestCase

            def runtest

                CIMMethod.new('FooMethod', 'uint32')

                CIMMethod.new('FooMethod', 'uint32',
                              {'Param1' => CIMParameter.new('Param1', 'uint32'),
                                  'Param2' => CIMParameter.new('Param2', 'string')})

                CIMMethod.new('FooMethod', 'uint32',
                              {'Param1' => CIMParameter.new('Param1', 'uint32'),
                                  'Param2' => CIMParameter.new('Param2', 'string')},
                              nil, false, {'Key' => CIMQualifier.new('Key', true)})
            end
        end

        class CopyCIMMethod < Comfychair::TestCase

            def runtest

                m = CIMMethod.new('FooMethod', 'uint32',
                                  {'P1' => CIMParameter.new('P1', 'uint32'),
                                      'P2' => CIMParameter.new('P2', 'string')},
                                  nil, nil,
                                  {'Key' => CIMQualifier.new('Key', true)})

                c = m.clone

                self.assert_equal(m, c)

                c.name = 'BarMethod'
                c.return_type = 'string'
                c.parameters.delete('P1')
                c.qualifiers.delete('Key')

                self.assert_(m.name == 'FooMethod')
                self.assert_(m.return_type == 'uint32')
                self.assert_(m.parameters['P1'])
                self.assert_(m.qualifiers['Key'])
            end
        end

        class CIMMethodAttrs < Comfychair::TestCase

            def runtest

                m = CIMMethod.new('FooMethod', 'uint32',
                                  {'Param1' => CIMParameter.new('Param1', 'uint32'),
                                      'Param2' => CIMParameter.new('Param2', 'string')}
                                  )

                self.assert_(m.name == 'FooMethod')
                self.assert_(m.return_type == 'uint32')
                self.assert_(m.parameters.length == 2)
                self.assert_(m.qualifiers == {})
            end
        end

        class CIMMethodEquality < Comfychair::TestCase

            def runtest

                self.assert_equal(CIMMethod.new('FooMethod', 'uint32'),
                                  CIMMethod.new('FooMethod', 'uint32'))

                self.assert_equal(CIMMethod.new('FooMethod', 'uint32'),
                                  CIMMethod.new('fooMethod', 'uint32'))
                
                self.assert_notequal(CIMMethod.new('FooMethod', 'uint32'),
                                     CIMMethod.new('FooMethod', 'uint32',
                                                   nil, nil, nil,
                                                   {'Key' => CIMQualifier.new('Key', true)}))
            end
        end

        class CIMMethodCompare < Comfychair::TestCase
            def runtest
                raise Comfychair::NotRunError
            end
        end

        class CIMMethodSort < Comfychair::TestCase
            def runtest
                raise Comfychair::NotRunError
            end
        end

        class CIMMethodString < Comfychair::TestCase

            def runtest

                s = CIMMethod.new('FooMethod', 'uint32').to_s

                self.assert_re_match('FooMethod', s)
                self.assert_re_match('uint32', s)
            end
        end

        class CIMMethodToXML < ValidateTest

            def runtest

                self.validate(CIMMethod.new('FooMethod', 'uint32'))

                self.validate(
                              CIMMethod.new('FooMethod', 'uint32',
                                            {'Param1' => CIMParameter.new('Param1', 'uint32'),
                                                'Param2' => CIMParameter.new('Param2', 'string')},
                                            nil, false,
                                            {'Key' => CIMQualifier.new('Key', true)}))
            end
        end

        #################################################################
        # CIMParameter
        #################################################################

        class InitCIMParameter < Comfychair::TestCase

            def runtest

                # Single-valued parameters

                CIMParameter.new('Param1', 'uint32')
                CIMParameter.new('Param2', 'string')
                CIMParameter.new('Param2', 'string',
                                 nil, nil, nil, {'Key' => CIMQualifier.new('Key', true)})

                # Array parameters

                CIMParameter.new('ArrayParam', 'uint32', nil, true)
                CIMParameter.new('ArrayParam', 'uint32', nil, true, 10)
                CIMParameter.new('ArrayParam', 'uint32', nil, true, 10,
                                 {'Key' => CIMQualifier.new('Key', true)})

                # Reference parameters
                
                CIMParameter.new('RefParam', 'reference', 'CIM_Foo')
                CIMParameter.new('RefParam', 'reference', 'CIM_Foo',
                                 nil, nil, {'Key' => CIMQualifier.new('Key', true)})
                
                # Refarray parameters
                
                CIMParameter.new('RefArrayParam', 'reference', true)
                CIMParameter.new('RefArrayParam', 'reference', 'CIM_Foo', true)
                CIMParameter.new('RefArrayParam', 'reference', 'CIM_Foo', true, 10)
                CIMParameter.new('RefArrayParam', 'reference', 'CIM_Foo', true, 10,
                                 {'Key' => CIMQualifier.new('Key', true)})
            end
        end

        class CopyCIMParameter < Comfychair::TestCase

            def runtest

                p = CIMParameter.new('RefParam', 'reference', 'CIM_Foo', nil, nil,
                                     {'Key' => CIMQualifier.new('Key', true)})

                c = p.clone

                self.assert_equal(p, c)

                c.name = 'Fooble'
                c.param_type = 'string'
                c.reference_class = nil
                c.qualifiers.delete('Key')

                self.assert_(p.name == 'RefParam')
                self.assert_(p.param_type == 'reference')
                self.assert_(p.reference_class == 'CIM_Foo')
                self.assert_(p.qualifiers['Key'])
            end
        end

        class CIMParameterAttrs < Comfychair::TestCase

            def runtest

                # Single-valued parameters

                p = CIMParameter.new('Param1', 'string')

                self.assert_(p.name == 'Param1')
                self.assert_(p.param_type == 'string')
                self.assert_(p.qualifiers == {})

                # Array parameters

                p = CIMParameter.new('ArrayParam', 'uint32', nil, true)

                self.assert_(p.name == 'ArrayParam')
                self.assert_(p.param_type == 'uint32')
                self.assert_(p.array_size == nil)
                self.assert_(p.qualifiers == {})
                
                # Reference parameters

                p = CIMParameter.new('RefParam', 'reference', 'CIM_Foo')

                self.assert_(p.name == 'RefParam')
                self.assert_(p.reference_class == 'CIM_Foo')
                self.assert_(p.qualifiers == {})

                # Reference array parameters

                p = CIMParameter.new('RefArrayParam', 'reference',
                                     'CIM_Foo', true, 10)

                self.assert_(p.name == 'RefArrayParam')
                self.assert_(p.reference_class == 'CIM_Foo')
                self.assert_(p.array_size == 10)
                self.assert_(p.is_array == true)
                self.assert_(p.qualifiers == {})
            end
        end

        class CIMParameterEquality < Comfychair::TestCase
            def runtest

                # Single-valued parameters
                self.assert_equal(CIMParameter.new('Param1', 'uint32'),
                                  CIMParameter.new('Param1', 'uint32'))

                self.assert_equal(CIMParameter.new('Param1', 'uint32'),
                                  CIMParameter.new('param1', 'uint32'))

                self.assert_notequal(CIMParameter.new('Param1', 'uint32'),
                                     CIMParameter.new('param1', 'string'))

                self.assert_notequal(CIMParameter.new('Param1', 'uint32'),
                                     CIMParameter.new('param1', 'uint32',
                                                      nil, nil, nil, 
                                                      {'Key' => CIMQualifier.new('Key', true)}))

                # Array parameters
                self.assert_equal(CIMParameter.new('ArrayParam', 'uint32', nil, true),
                                  CIMParameter.new('ArrayParam', 'uint32', nil, true))

                self.assert_equal(CIMParameter.new('ArrayParam', 'uint32', nil, true),
                                  CIMParameter.new('arrayParam', 'uint32', nil, true))

                self.assert_notequal(CIMParameter.new('ArrayParam', 'uint32', nil, true),
                                     CIMParameter.new('ArrayParam', 'string', nil, true))

                self.assert_notequal(CIMParameter.new('ArrayParam', 'uint32', nil, true),
                                     CIMParameter.new('ArrayParam', 'string', nil, true, 10))

                self.assert_notequal(CIMParameter.new('ArrayParam', 'uint32', nil, true),
                                     CIMParameter.new('ArrayParam', 'uint32', nil, true, nil,
                                                      {'Key' => CIMQualifier.new('Key', true)}))

                # Reference parameters
                self.assert_equal(CIMParameter.new('RefParam', 'reference', 'CIM_Foo'),
                                  CIMParameter.new('RefParam', 'reference', 'CIM_Foo'))
                
                self.assert_equal(CIMParameter.new('RefParam', 'reference', 'CIM_Foo'),
                                  CIMParameter.new('refParam', 'reference', 'CIM_Foo'))

                self.assert_equal(CIMParameter.new('RefParam', 'reference', 'CIM_Foo'),
                                  CIMParameter.new('refParam', 'reference', 'CIM_foo'))

                self.assert_notequal(CIMParameter.new('RefParam', 'reference', 'CIM_Foo'),
                                     CIMParameter.new('RefParam', 'reference', 'CIM_Bar'))

                self.assert_notequal(CIMParameter.new('RefParam', 'reference', 'CIM_Foo'),
                                     CIMParameter.new('RefParam', 'reference', 'CIM_Foo',
                                                      nil, nil,
                                                      {'Key' => CIMQualifier.new('Key', true)}))

                # Reference array parameters
                self.assert_equal(CIMParameter.new('ArrayParam', 'reference', 'CIM_Foo', true),
                                  CIMParameter.new('ArrayParam', 'reference', 'CIM_Foo', true))

                self.assert_equal(CIMParameter.new('ArrayParam', 'reference', 'CIM_Foo', true),
                                  CIMParameter.new('arrayparam', 'reference', 'CIM_Foo', true))

                self.assert_notequal(CIMParameter.new('ArrayParam', 'reference', 'CIM_Foo', 
                                                      true),
                                     CIMParameter.new('arrayParam', 'reference', 'CIM_foo',
                                                      true, 10))

                self.assert_notequal(CIMParameter.new('ArrayParam', 'reference', 'CIM_Foo',
                                                      true),
                                     CIMParameter.new('ArrayParam', 'reference', 'CIM_Foo',
                                                      true, nil,
                                                      {'Key' => CIMQualifier.new('Key', true)}))
            end
        end

        class CIMParameterCompare < Comfychair::TestCase
            def runtest
                raise Comfychair::NotRunError
            end
        end

        class CIMParameterSort < Comfychair::TestCase
            def runtest
                raise Comfychair::NotRunError
            end
        end

        class CIMParameterString < Comfychair::TestCase

            def runtest

                s = CIMParameter.new('Param1', 'uint32').to_s

                self.assert_re_match('Param1', s)
                self.assert_re_match('uint32', s)
            end
        end

        class CIMParameterToXML < ValidateTest

            def runtest

                # Single-valued parameters

                self.validate(CIMParameter.new('Param1', 'uint32'))

                self.validate(CIMParameter.new('Param1', 'string', nil, nil, nil,
                                               {'Key' => CIMQualifier.new('Key', true)}))

                # Array parameters

                self.validate(CIMParameter.new('ArrayParam', 'uint32', nil, true))

                self.validate(CIMParameter.new('ArrayParam', 'uint32', nil, true, 10))

                self.validate(CIMParameter.new('ArrayParam', 'uint32', nil, true, 10,
                                               {'Key' => CIMQualifier.new('Key', true)}))

                # Reference parameters

                self.validate(CIMParameter.new('RefParam', 'reference', 'CIM_Foo',
                                               nil, nil, {'Key' => CIMQualifier.new('Key', true)}))

                # Reference array parameters

                self.validate(CIMParameter.new('RefArrayParam', 'reference', nil, true))

                self.validate(CIMParameter.new('RefArrayParam', 'reference', 'CIM_Foo', true))

                self.validate(CIMParameter.new('RefArrayParam', 'reference', 'CIM_Foo', true, 10))

                self.validate(CIMParameter.new('RefArrayParam', 'reference', 'CIM_Foo', true, 
                                               nil, {'Key' => CIMQualifier.new('Key', true)}))
            end
        end

        #################################################################
        # Main function
        #################################################################


        TESTS = [
                 #############################################################
                 # Property and qualifier classes
                 #############################################################

                 # CIMProperty

                 InitCIMProperty,
                 CopyCIMProperty,
                 CIMPropertyAttrs,
                 CIMPropertyEquality,
                 CIMPropertyCompare,
                 CIMPropertySort,
                 CIMPropertyString,
                 CIMPropertyToXML,
                 
                 # CIMQualifier

                 InitCIMQualifier,
                 CopyCIMQualifier,
                 CIMQualifierAttrs,
                 CIMQualifierEquality,
                 CIMQualifierCompare,
                 CIMQualifierSort,
                 CIMQualifierString,
                 CIMQualifierToXML,
                 
                 #############################################################
                 # Instance and instance name classes
                 #############################################################

                 # CIMInstanceName

                 InitCIMInstanceName,
                 CopyCIMInstanceName,
                 CIMInstanceNameAttrs,
                 CIMInstanceNameDictInterface,
                 CIMInstanceNameEquality,
                 CIMInstanceNameCompare,
                 CIMInstanceNameSort,
                 CIMInstanceNameString,
                 CIMInstanceNameToXML,

                 # CIMInstance

                 InitCIMInstance,
                 CopyCIMInstance,
                 CIMInstanceAttrs,
                 CIMInstanceDictInterface,
                 CIMInstanceEquality,
                 CIMInstanceCompare,
                 CIMInstanceSort,
                 CIMInstanceString,
                 CIMInstanceToXML,
                 CIMInstanceToMOF,

                 #############################################################
                 # Schema classes
                 #############################################################

                 # CIMClass

                 InitCIMClass,
                 CopyCIMClass,
                 CIMClassAttrs,
                 CIMClassEquality,
                 CIMClassCompare,
                 CIMClassSort,
                 CIMClassString,
                 CIMClassToXML,
                 CIMClassToMOF,

                 # TODO: CIMClassName
    
                 # CIMMethod

                 InitCIMMethod,
                 CopyCIMMethod,
                 CIMMethodAttrs,
                 CIMMethodEquality,
                 CIMMethodCompare,
                 CIMMethodSort,
                 CIMMethodString,
                 CIMMethodToXML,

                 # CIMParameter

                 InitCIMParameter,
                 CopyCIMParameter,
                 CIMParameterAttrs,
                 CIMParameterEquality,
                 CIMParameterCompare,
                 CIMParameterSort,
                 CIMParameterString,
                 CIMParameterToXML

                ]

        if __FILE__ == $0
            Comfychair.main(TESTS)
        end
    end
end

