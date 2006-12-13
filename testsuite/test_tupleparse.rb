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
# Test XML parsing routines.
#
# These tests check that we don't lose any information by converting
# an object to XML then parsing it again.  The round trip should
# produce an object that is identical to the one we started with.
#
require "comfychair"
require "validate"
require "wbem"

module WBEM
    module Test

        class TupleTest < Comfychair::TestCase

            def test(obj)

                # Convert object to xml

                xml = obj.tocimxml().toxml()
                self.log('before: %s' % xml)

                # Parse back to an object
                result = WBEM.parse_any(WBEM.xml_to_tupletree(xml))
                self.log('after:  %s' % result.tocimxml().toxml())

                # Assert that the before and after objects should be equal
        
                self.assert_equal(obj, result)

            end
        end

        class RawXMLTest < Comfychair::TestCase

            def test(xml, obj)

                # Parse raw XML to an object

                result = WBEM.parse_any(WBEM.xml_to_tupletree(xml))
                self.log('parsed XML: %s' % result)

                # Assert XML parses to particular Python object

                self.assert_equal(obj, result)
            end
        end
        class ParseCIMInstanceName < TupleTest
            #"""Test parsing of CIMInstanceName objects."""
           
            def runtest
                self.test(CIMInstanceName.new('CIM_Foo'))
                self.test(CIMInstanceName.new('CIM_Foo', 
                                              {'Name' => 'Foo', 'Chicken' => 'Ham'}))

                self.test(CIMInstanceName.new('CIM_Foo', 
                                              {'Name' => 'Foo',
                                               'Number' => 42,
                                               'Boolean' => false,
                                               'Ref' => CIMInstanceName.new('CIM_Bar')}))

                self.test(CIMInstanceName.new('CIM_Foo', {'Name' => 'Foo'},
                                               nil, 'root/cimv2'))

                self.test(CIMInstanceName.new('CIM_Foo', {'Name' => 'Foo'},
                                              'woot.com',
                                              'root/cimv2'))
                self.test(CIMInstanceName.new('CIM_Foo', {'Name' => 'Foo'},
                                              nil, 'root/cimv2'))
     
                self.test(CIMInstanceName.new('CIM_Foo', {'Name' => 'Foo'},
                                              'woot.com',
                                              'root/cimv2'))
            end
        end

        class ParseCIMInstance < TupleTest
            #"""Test parsing of CIMInstance objects."""
    
            def runtest

                self.test(CIMInstance.new('CIM_Foo'))

                self.test(CIMInstance.new('CIM_Foo',{'string' => 'string',
                                              'uint8' => Uint8.new(0),
                                              'uint8array' => [Uint8.new(1), Uint8.new(2)],
                                              'ref' => CIMInstanceName.new('CIM_Bar')}))

                self.test(CIMInstance.new('CIM_Foo',
                                          {'InstanceID' => '1234'},
                                          {},
                                          CIMInstanceName.new('CIM_Foo',
                                                              {'InstanceID' => '1234'})))
     
                self.test(CIMInstance.new('CIM_Foo',
                                          {'InstanceID' => '1234'},
                                          {},
                                          CIMInstanceName.new('CIM_Foo',
                                                    {'InstanceID' => '1234'})))
            end
        end

        class ParseCIMClass < TupleTest
            #"""Test parsing of CIMClass objects."""

            def runtest

                self.test(CIMClass.new('CIM_Foo'))
                self.test(CIMClass.new('CIM_Foo', nil, nil, nil, 'CIM_bar'))

                self.test(
                    CIMClass.new(
                        'CIM_CollectionInSystem', 
                         {'Parent' => CIMProperty.new('Parent', nil, 'reference', nil, nil, nil,
                                                      {'Key' => CIMQualifier.new('Key', 
                                                                                 true, 
                                                                                 nil, 
                                                                                 false),
                                                          'Aggregate' => CIMQualifier.new('Aggregate', 
                                                                                          true, 
                                                                                          nil, 
                                                                                          false),
                                                          'Max' => CIMQualifier.new('Max', 
                                                                                    Uint32.new(1))},
                                                      'CIM_System'),
                          'Child' => CIMProperty.new('Child', nil, 'reference', nil, nil, nil, 
                                                     {'Key' => CIMQualifier.new('Key', 
                                                                                true, 
                                                                                nil, 
                                                                                false)},
                                                     'CIM_Collection')},
                         {'ASSOCIATION' => CIMQualifier.new('ASSOCIATION', true, nil, false),
                          'Aggregation' => CIMQualifier.new('Aggregation', true, nil, false),
                          'Version' => CIMQualifier.new('Version', '2.6.0', nil, nil, false, nil, false),
                          'Description' => CIMQualifier.new('Description',
                                                            'CIM_CollectionInSystem is an association used to establish a parent-child relationship between a collection and an \'owning\' System such as an AdminDomain or ComputerSystem. A single collection should not have both a CollectionInOrganization and a CollectionInSystem association.',
                                                            nil, nil, nil, nil, true)}
                                 ))
            end
        end
         
        class ParseCIMProperty < TupleTest
            #"""Test parsing of CIMProperty objects."""

            def runtest

                # Single-valued properties

                self.test(CIMProperty.new('Spotty', 'Foot'))
                self.test(CIMProperty.new('Age', Uint16.new(32)))
                self.test(CIMProperty.new('Foo', '', 'string'))
                self.test(CIMProperty.new('Foo', nil, 'string'))
                self.test(CIMProperty.new('Age', nil, 'uint16', nil, nil, nil,
                                          {'Key' => CIMQualifier.new('Key', true)}))

                # Property arrays

                self.test(CIMProperty.new('Foo', ['a', 'b', 'c']))
                self.test(CIMProperty.new('Foo', nil, 'string', nil, nil, true))
                self.test(CIMProperty.new('Foo', [1, 2, 3].collect {|x| Uint8.new(x)},
                                          nil, nil, nil, nil, 
                                          {'Key' => CIMQualifier.new('Key', true)}))

                # Reference properties
                              
                self.test(CIMProperty.new('Foo', nil, 'reference'))
                self.test(CIMProperty.new('Foo', CIMInstanceName.new('CIM_Foo')))
                self.test(CIMProperty.new('Foo', CIMInstanceName.new('CIM_Foo'),
                                          nil, nil, nil, nil, 
                                          {'Key' => CIMQualifier.new('Key', true)}))
            end
        end

        class ParseCIMParameter < TupleTest
            #"""Test parsing of CIMParameter objects."""

            def runtest

                # Single-valued parameters

                self.test(CIMParameter.new('Param', 'string'))
                self.test(CIMParameter.new('Param', 'string', nil, nil, nil,
                                           {'Key' => CIMQualifier.new('Key', true)}))

                # Reference parameters

                self.test(CIMParameter.new('RefParam', 'reference'))
                self.test(CIMParameter.new('RefParam', 'reference', 'CIM_Foo'))
                self.test(CIMParameter.new('RefParam', 'reference', 'CIM_Foo', nil, nil,
                                           {'Key' => CIMQualifier.new('Key', true)}))

                # Array parameters

                self.test(CIMParameter.new('Array', 'string', nil, true))
                self.test(CIMParameter.new('Array', 'string', nil, true, 10))
                self.test(CIMParameter.new('Array', 'string', nil, true, 10,
                                           {'Key' => CIMQualifier.new('Key', true)}))

                # Reference array parameters

                self.test(CIMParameter.new('RefArray', 'reference', nil, true))
                self.test(CIMParameter.new('RefArray', 'reference', 'CIM_Foo', true))
                self.test(CIMParameter.new('RefArray', 'reference', 'CIM_Foo', true, 10))
                self.test(CIMParameter.new('RefArray', 'reference', 'CIM_Foo', true, 10,
                                           {'Key' => CIMQualifier.new('Key', true)}))
            end

        end

        class ParseXMLKeyValue < RawXMLTest

            def runtest
                
                self.test('<KEYVALUE VALUETYPE="numeric">1234</KEYVALUE>', 1234)
                
                self.test('<KEYVALUE TYPE="uint32" VALUETYPE="numeric">1234</KEYVALUE>',
                          1234)
            end
        end

        TESTS = [
                 ParseCIMInstanceName,
                 ParseCIMInstance,
                 ParseCIMClass,
                 ParseCIMProperty,
                 ParseCIMParameter,
                 
                 # Parse specific bits of XML
                 
                 ParseXMLKeyValue,
                 
                ]
        
        if __FILE__ == $0
            Comfychair.main(TESTS)
        end
    end
end
