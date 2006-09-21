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
# Exercise routines in cim_xml by creating xml document fragments and
# passing them through a validator.
#
# TODO: Currently this forks of an instance of xmllint which is a
# little slow.  It would be nicer to have an in-process validator.
#
# TODO: A bunch of tests are still unimplemented for bits of the
# schema that PyWBEM doesn't use right now.
#

require "comfychair"
require "validate"
require "wbem"

module WBEM
    module Test
        def WBEM.LOCALNAMESPACEPATH()
            return LOCALNAMESPACEPATH.new([NAMESPACE.new('root'),
                                           NAMESPACE.new('cimv2')])
        end

        def WBEM.NAMESPACEPATH()
            return NAMESPACEPATH.new(
                                     HOST.new('leonardo'), WBEM.LOCALNAMESPACEPATH())
        end

        def WBEM.CLASSNAME()
            return CLASSNAME.new('CIM_Foo')
        end
        
        def WBEM.INSTANCENAME()
            return INSTANCENAME.new(
                                    'CIM_Pet',
                                    [KEYBINDING.new('type', KEYVALUE.new('dog', 'string')),
                                     KEYBINDING.new('age', KEYVALUE.new('2', 'numeric'))])
        end

        class CIMXMLTest < Comfychair::TestCase
            include Validate
            #"""Run validate. script against an xml document fragment."""

            def initialize
                super
                @xml = []
            end
            attr_reader :xml

            def validate(xml, expectedResult = 0)
                self.log(xml)
                self.assert_(validate_xml(xml, dtd_directory = '../..'))
            end

            def runtest
                # Test xml fragments pass validation
                self.xml.each do |x|
                    self.validate(x.toxml)
                end
            end
        end

        class UnimplementedTest < CIMXMLTest
            def runtest
                raise Comfychair::NotRunError, 'unimplemented'
            end
        end

        #################################################################
        #     3.2.1. Top Level Elements
        #################################################################

        #     3.2.1.1. CIM

        class CIM < CIMXMLTest
            def setup
                self.xml << WBEM::CIM.new(
                                    MESSAGE.new(
                                                SIMPLEREQ.new(
                                                              IMETHODCALL.new(
                                                                              'IntrinsicMethod',
                                                                              WBEM.LOCALNAMESPACEPATH())),
                                                '1001', '1.0'),
                                    '2.0', '2.0')
            end
        end

        #################################################################
        #     3.2.2. Declaration Elements
        #################################################################

        #     3.2.2.1. DECLARATION
        #     3.2.2.2. DECLGROUP
        #     3.2.2.3. DECLGROUP.WITHNAME
        #     3.2.2.4. DECLGROUP.WITHPATH
        #     3.2.2.5. QUALIFIER.DECLARATION
        #     3.2.2.6. SCOPE


        class Declaration < UnimplementedTest
#     """
#     <!ELEMENT DECLARATION  (DECLGROUP|DECLGROUP.WITHNAME|DECLGROUP.WITHPATH)+>
#     """
        end

        class DeclGroup < UnimplementedTest
#     """
#     <!ELEMENT DECLGROUP  ((LOCALNAMESPACEPATH|NAMESPACEPATH)?,
#                           QUALIFIER.DECLARATION*,VALUE.OBJECT*)>
#     """
        end

        class DeclGroupWithName < UnimplementedTest
#     """
#     <!ELEMENT DECLGROUP.WITHNAME  ((LOCALNAMESPACEPATH|NAMESPACEPATH)?,
#                                    QUALIFIER.DECLARATION*,VALUE.NAMEDOBJECT*)>
#     """
        end

        class DeclGroupWithPath < UnimplementedTest
#     """
#     <!ELEMENT DECLGROUP.WITHPATH  (VALUE.OBJECTWITHPATH|
#                                    VALUE.OBJECTWITHLOCALPATH)*>
#     """
        end

        class QualifierDeclaration < UnimplementedTest
#     """
#     <!ELEMENT QUALIFIER.DECLARATION (SCOPE?, (VALUE | VALUE.ARRAY)?)>
#     <!ATTLIST QUALIFIER.DECLARATION
#         %CIMName;               
#         %CIMType;               #REQUIRED
#         ISARRAY    (true|false) #IMPLIED
#         %ArraySize;
#         %QualifierFlavor;>
#     """
        end

        class Scope < CIMXMLTest
#     """
#     <!ELEMENT SCOPE EMPTY> 
#     <!ATTLIST SCOPE 
#          CLASS        (true|false)      'false'
#          ASSOCIATION  (true|false)      'false'
#          REFERENCE    (true|false)      'false'
#          PROPERTY     (true|false)      'false'
#          METHOD       (true|false)      'false'
#          PARAMETER    (true|false)      'false'
#          INDICATION   (true|false)      'false'>
#     """
            def setup
                self.xml << SCOPE.new()
            end
        end

#################################################################
#     3.2.3. Value Elements
#################################################################

#     3.2.3.1. VALUE
#     3.2.3.2. VALUE.ARRAY
#     3.2.3.3. VALUE.REFERENCE
#     3.2.3.4. VALUE.REFARRAY
#     3.2.3.5. VALUE.OBJECT
#     3.2.3.6. VALUE.NAMEDINSTANCE
#     3.2.3.7. VALUE.NAMEDOBJECT
#     3.2.3.8. VALUE.OBJECTWITHPATH
#     3.2.3.9. VALUE.OBJECTWITHLOCALPATH
#     3.2.3.10. VALUE.NULL

        class Value < CIMXMLTest
#     """
#     <!ELEMENT VALUE (#PCDATA)>
#     """
            def setup
                self.xml << VALUE.new('dog')
                self.xml << VALUE.new(nil)
                self.xml << VALUE.new('')
            end
        end

        class ValueArray < CIMXMLTest
#     """
#     <!ELEMENT VALUE.ARRAY (VALUE*)>
#     """
            def setup
                self.xml << VALUE_ARRAY.new([])
                self.xml << VALUE_ARRAY.new([VALUE.new('cat'), VALUE.new('dog')])
            end
        end

        class ValueReference < CIMXMLTest
#     """
#     <!ELEMENT VALUE.REFERENCE (CLASSPATH|LOCALCLASSPATH|CLASSNAME|
#                                INSTANCEPATH|LOCALINSTANCEPATH|INSTANCENAME)>
#     """
            def setup

                # CLASSPATH
                self.xml << VALUE_REFERENCE.new(CLASSPATH.new(WBEM.NAMESPACEPATH(), WBEM.CLASSNAME()))

                # LOCALCLASSPATH
                self.xml << VALUE_REFERENCE.new(LOCALCLASSPATH.new(WBEM.LOCALNAMESPACEPATH(), 
                                                                   WBEM.CLASSNAME()))
        
                # CLASSNAME
                self.xml << VALUE_REFERENCE.new(WBEM.CLASSNAME())

                # INSTANCEPATH
                self.xml << VALUE_REFERENCE.new(INSTANCEPATH.new(WBEM.NAMESPACEPATH(), 
                                                                 WBEM.INSTANCENAME()))
        
                # LOCALINSTANCEPATH
                self.xml << VALUE_REFERENCE.new(LOCALINSTANCEPATH.new(WBEM.LOCALNAMESPACEPATH(), 
                                                                      WBEM.INSTANCENAME()))
        
                # INSTANCENAME
                self.xml << VALUE_REFERENCE.new(WBEM.INSTANCENAME())
            end
        end

        class ValueRefArray < CIMXMLTest
#     """
#     <!ELEMENT VALUE.REFARRAY (VALUE.REFERENCE*)>
#     """

            def setup

                # Empty
                self.xml << VALUE_REFARRAY.new([])

                # VALUE.REFARRAY
                self.xml << VALUE_REFARRAY.new(
                    [VALUE_REFERENCE.new(WBEM.CLASSNAME()),
                     VALUE_REFERENCE.new(LOCALCLASSPATH.new(WBEM.LOCALNAMESPACEPATH(), 
                                                    WBEM.CLASSNAME()))])
            end
        end

        class ValueObject < CIMXMLTest
#     """
#     <!ELEMENT VALUE.OBJECT (CLASS|INSTANCE)>
#     """
            def setup

                # CLASS
                self.xml << VALUE_OBJECT.new(CLASS.new('CIM_Foo'))

                # INSTANCE
                self.xml << VALUE_OBJECT.new(INSTANCE.new('CIM_Pet', []))
            end
        end

        class ValueNamedInstance < CIMXMLTest
#     """
#     <!ELEMENT VALUE.NAMEDINSTANCE (INSTANCENAME,INSTANCE)>
#     """
            def setup
                self.xml << VALUE_NAMEDINSTANCE.new(WBEM.INSTANCENAME(),
                                                    INSTANCE.new('CIM_Pet', []))
            end
        end

        class ValueNamedObject < CIMXMLTest
#     """
#     <!ELEMENT VALUE.NAMEDOBJECT (CLASS|(INSTANCENAME,INSTANCE))>
#     """
            def setup

                # CLASS
                self.xml << VALUE_NAMEDOBJECT.new(CLASS.new('CIM_Foo'))
        
                # INSTANCENAME, INSTANCE
                self.xml << VALUE_NAMEDOBJECT.new([WBEM.INSTANCENAME(),
                                                   INSTANCE.new('CIM_Pet', [])])
            end
        end

        class ValueObjectWithPath < CIMXMLTest
#     """
#     <!ELEMENT VALUE.OBJECTWITHPATH ((CLASSPATH,CLASS)|
#                                     (INSTANCEPATH,INSTANCE))>
#     """
    
            def setup

                # (CLASSPATH, CLASS)
                self.xml << VALUE_OBJECTWITHPATH.new(CLASSPATH.new(WBEM.NAMESPACEPATH(), 
                                                                   WBEM.CLASSNAME()),
                                                     CLASS.new('CIM_Foo'))

                # (INSTANCEPATH, INSTANCE)
                self.xml << VALUE_OBJECTWITHPATH.new(INSTANCEPATH.new(WBEM.NAMESPACEPATH(), 
                                                                      WBEM.INSTANCENAME()),
                                                     INSTANCE.new('CIM_Pet', []))
            end
        end

        class ValueObjectWithLocalPath < CIMXMLTest
#     """
#     <!ELEMENT VALUE.OBJECTWITHLOCALPATH ((LOCALCLASSPATH,CLASS)|
#                                          (LOCALINSTANCEPATH,INSTANCE))>
#    """
    
            def setup

                # (LOCALCLASSPATH, CLASS)
                self.xml << VALUE_OBJECTWITHLOCALPATH.new(LOCALCLASSPATH.new(WBEM.LOCALNAMESPACEPATH(), 
                                                                             WBEM.CLASSNAME()),
                                                          CLASS.new('CIM_Foo'))

                # (LOCALINSTANCEPATH, INSTANCE)
                self.xml << VALUE_OBJECTWITHLOCALPATH.new(LOCALINSTANCEPATH.new(WBEM.LOCALNAMESPACEPATH(),
                                                                                WBEM.INSTANCENAME()),
                                                          INSTANCE.new('CIM_Pet', []))
            end
        end

        class ValueNull < UnimplementedTest
#     """
#     <!ELEMENT VALUE.NULL EMPTY>
#     """
        end

#################################################################
#     3.2.4. Naming and Location Elements
#################################################################

#     3.2.4.1. NAMESPACEPATH
#     3.2.4.2. LOCALNAMESPACEPATH
#     3.2.4.3. HOST
#     3.2.4.4. NAMESPACE
#     3.2.4.5. CLASSPATH
#     3.2.4.6. LOCALCLASSPATH
#     3.2.4.7. CLASSNAME
#     3.2.4.8. INSTANCEPATH
#     3.2.4.9. LOCALINSTANCEPATH
#     3.2.4.10. INSTANCENAME
#     3.2.4.11. OBJECTPATH
#     3.2.4.12. KEYBINDING
#     3.2.4.13. KEYVALUE

        class NamespacePath < CIMXMLTest
#    """
#    <!ELEMENT NAMESPACEPATH (HOST,LOCALNAMESPACEPATH)> 
#    """
            def setup
                self.xml << WBEM.NAMESPACEPATH()
            end
        end

        class LocalNamespacePath < CIMXMLTest
#    """
#    <!ELEMENT LOCALNAMESPACEPATH (NAMESPACE+)> 
#    """
            def setup
                self.xml << WBEM.LOCALNAMESPACEPATH()
            end
        end

        class Host < CIMXMLTest
#    """
#    <!ELEMENT HOST (#PCDATA)> 
#    """
            def setup
                self.xml << HOST.new('leonardo')
            end
        end

        class Namespace < CIMXMLTest
#    """
#    <!ELEMENT NAMESPACE EMPTY> 
#    <!ATTLIST NAMESPACE
#        %CIMName;>
#    """
            def setup
                self.xml << NAMESPACE.new('root')
            end
        end

        class ClassPath < CIMXMLTest
#    """
#    <!ELEMENT CLASSPATH (NAMESPACEPATH,CLASSNAME)>
#    """
            def setup
                self.xml << CLASSPATH.new(WBEM.NAMESPACEPATH(), WBEM.CLASSNAME())
            end
        end

        class LocalClassPath < CIMXMLTest
#    """
#    <!ELEMENT LOCALCLASSPATH (LOCALNAMESPACEPATH, CLASSNAME)>
#    """
            def setup
                self.xml << LOCALCLASSPATH.new(WBEM.LOCALNAMESPACEPATH(), WBEM.CLASSNAME())
            end
        end

        class ClassName < CIMXMLTest
#    """
#    <!ELEMENT CLASSNAME EMPTY>
#    <!ATTLIST CLASSNAME
#        %CIMName;>
#    """
            def setup
                self.xml << WBEM.CLASSNAME()
            end
        end

        class InstancePath < CIMXMLTest
#    """
#    <!ELEMENT INSTANCEPATH (NAMESPACEPATH,INSTANCENAME)>
#    """
            def setup
                self.xml << INSTANCEPATH.new(WBEM.NAMESPACEPATH(), WBEM.INSTANCENAME())
            end
        end

        class LocalInstancePath < CIMXMLTest
#    """
#    <!ELEMENT LOCALINSTANCEPATH (LOCALNAMESPACEPATH,INSTANCENAME)>
#    """
            def setup
                self.xml << LOCALINSTANCEPATH.new(WBEM.LOCALNAMESPACEPATH(), 
                                                  WBEM.INSTANCENAME())
            end
        end

        class InstanceName < CIMXMLTest
#    """
#    <!ELEMENT INSTANCENAME (KEYBINDING*|KEYVALUE?|VALUE.REFERENCE?)>
#    <!ATTLIST INSTANCENAME
#        %ClassName;>
#    """
            def setup

                # Empty
                self.xml << INSTANCENAME.new('CIM_Pet', nil)
                                        
                # KEYBINDING
                self.xml << WBEM.INSTANCENAME()

                # KEYVALUE
                self.xml << INSTANCENAME.new('CIM_Pet', KEYVALUE.new('FALSE', 'boolean'))

                # VALUE.REFERENCE
                self.xml << INSTANCENAME.new('CIM_Pet',
                                             VALUE_REFERENCE.new(WBEM.INSTANCENAME()))
            end
        end

        class ObjectPath < CIMXMLTest
#    """
#    <!ELEMENT OBJECTPATH (INSTANCEPATH|CLASSPATH)>
#    """
    
            def setup

                self.xml << OBJECTPATH.new(INSTANCEPATH.new(WBEM.NAMESPACEPATH(), 
                                                            WBEM.INSTANCENAME()))

                self.xml << OBJECTPATH.new(CLASSPATH.new(WBEM.NAMESPACEPATH(), 
                                                         WBEM.CLASSNAME()))
            end
        end

        class KeyBinding < CIMXMLTest
#    """
#    <!ELEMENT KEYBINDING (KEYVALUE|VALUE.REFERENCE)>
#    <!ATTLIST KEYBINDING
#        %CIMName;>
#    """
            def setup

                self.xml << KEYBINDING.new('pet', KEYVALUE.new('dog', 'string'))

                self.xml << KEYBINDING.new(
                    'CIM_Foo',
                    VALUE_REFERENCE.new(
                        CLASSPATH.new(WBEM.NAMESPACEPATH(), WBEM.CLASSNAME())))
            end
        end

        class KeyValue < CIMXMLTest
#    """
#    <!ELEMENT KEYVALUE (#PCDATA)>
#    <!ATTLIST KEYVALUE
#        VALUETYPE    (string|boolean|numeric)  'string'
#        %CIMType;    #IMPLIED>
#    """
            def setup
                self.xml << KEYVALUE.new('dog', 'string')
                self.xml << KEYVALUE.new('2', 'numeric')
                self.xml << KEYVALUE.new('FALSE', 'boolean')
                self.xml << KEYVALUE.new('2', 'numeric', 'uint16')
                self.xml << KEYVALUE.new(nil)
            end
        end

#################################################################
#     3.2.5. Object Definition Elements
#################################################################

#     3.2.5.1. CLASS
#     3.2.5.2. INSTANCE
#     3.2.5.3. QUALIFIER
#     3.2.5.4. PROPERTY
#     3.2.5.5. PROPERTY.ARRAY
#     3.2.5.6. PROPERTY.REFERENCE
#     3.2.5.7. METHOD
#     3.2.5.8. PARAMETER
#     3.2.5.9. PARAMETER.REFERENCE
#     3.2.5.10. PARAMETER.ARRAY
#     3.2.5.11. PARAMETER.REFARRAY
#     3.2.5.12. TABLECELL.DECLARATION
#     3.2.5.13. TABLECELL.REFERENCE
#     3.2.5.14. TABLEROW.DECLARATION
#     3.2.5.15. TABLE
#     3.2.5.16. TABLEROW

        class Class < CIMXMLTest
#    """
#    <!ELEMENT CLASS (QUALIFIER*,(PROPERTY|PROPERTY.ARRAY|PROPERTY.REFERENCE)*,
#                     METHOD*)>
#    <!ATTLIST CLASS 
#        %CIMName;
#        %SuperClass;>
#    """
            def setup

                # Empty
                self.xml << CLASS.new('CIM_Foo')

                # PROPERTY
                self.xml << CLASS.new('CIM_Foo', [PROPERTY.new('Dog', 'string', 
                                                               VALUE.new('Spotty'))])

                # QUALIFIER + PROPERTY
                self.xml << CLASS.new('CIM_Foo',
                       [PROPERTY.new('Dog', 'string', VALUE.new('Spotty'))],
                       [],
                       [QUALIFIER.new('IMPISH', 'string', VALUE.new('true'))])

                # PROPERTY.ARRAY

                self.xml << CLASS.new('CIM_Foo',
                    [PROPERTY_ARRAY.new('Dogs', 'string', nil)])

                # PROPERTY.REFERENCE

                self.xml << CLASS.new('CIM_Foo',
                    [PROPERTY_REFERENCE.new('Dogs', nil)])

                # METHOD

                self.xml << CLASS.new('CIM_Foo', [], 
                    [METHOD.new('FooMethod')])
            end
        end

        class Instance < CIMXMLTest
#    """
#    <!ELEMENT INSTANCE (QUALIFIER*,(PROPERTY|PROPERTY.ARRAY|
#                                    PROPERTY.REFERENCE)*)>
#    <!ATTLIST INSTANCE
#        %ClassName;
#         xml:lang   NMTOKEN  #IMPLIED>
#    """
            def setup

                # Empty
                self.xml << INSTANCE.new('CIM_Foo', [])

                # PROPERTY
                self.xml << INSTANCE.new(
                    'CIM_Foo',
                    [PROPERTY.new('Dog', 'string', VALUE.new('Spotty')),
                     PROPERTY.new('Cat', 'string', VALUE.new('Bella'))])

                # PROPERTY + QUALIFIER

                self.xml << INSTANCE.new(
                    'CIM_Foo',
                        [PROPERTY.new('Dog', 'string', VALUE.new('Spotty')),
                         PROPERTY.new('Cat', 'string', VALUE.new('Bella'))],
                        [QUALIFIER.new('IMPISH', 'string', VALUE.new('true'))])

                # PROPERTY.ARRAY
                self.xml << INSTANCE.new(
                    'CIM_Pets',
                    [PROPERTY_ARRAY.new(
                        'Dogs',
                        'string',
                        VALUE_ARRAY.new([VALUE.new('Spotty'),
                                         VALUE.new('Bronte')])),
                     PROPERTY_ARRAY.new(
                        'Cats',
                        'string',
                         VALUE_ARRAY.new([VALUE.new('Bella'),
                                          VALUE.new('Faux Lily')]))])

                # PROPERTY.REFERENCE
                self.xml << INSTANCE.new(
                    'CIM_Pets',
                    [PROPERTY_REFERENCE.new(
                        'Dog',
                        VALUE_REFERENCE.new(CLASSNAME.new('CIM_Dog'))),
                     PROPERTY_REFERENCE.new(
                        'Cat',
                        VALUE_REFERENCE.new(CLASSNAME.new('CIM_Cat')))])
            end
        end
             
        class Qualifier < CIMXMLTest
#    """
#    <!ELEMENT QUALIFIER (VALUE | VALUE.ARRAY)>
#    <!ATTLIST QUALIFIER
#        %CIMName;
#        %CIMType;              #REQUIRED
#        %Propagated;
#        %QualifierFlavor;
#        xml:lang   NMTOKEN  #IMPLIED>
#    """
            def setup

                # Note: DTD 2.2 allows qualifier to be empty

                # VALUE
                self.xml << QUALIFIER.new('IMPISH', 'string', VALUE.new('true'))

                # VALUE + attributes
                self.xml << QUALIFIER.new('Key', 'string', VALUE.new('true'),
                                          nil, 'true')
                self.xml << QUALIFIER.new('Description', 'string', VALUE.new('blahblah'),
                                          nil, nil, nil, 'true')
                self.xml << QUALIFIER.new('Version', 'string', VALUE.new('foorble'),
                                          nil, 'false', nil, 'true')

                # VALUE.ARRAY
                self.xml << QUALIFIER.new('LUCKYNUMBERS', 'uint32',
                                          VALUE_ARRAY.new([VALUE.new('1'), VALUE.new('2')]))
            end
        end
        
        class Property < CIMXMLTest
#    """
#    <!ELEMENT PROPERTY (QUALIFIER*,VALUE?)>
#    <!ATTLIST PROPERTY 
#        %CIMName;
#        %CIMType;           #REQUIRED 
#        %ClassOrigin;
#        %Propagated;
#        xml:lang   NMTOKEN  #IMPLIED>
#    """
            def setup

                # Empty
                self.xml << PROPERTY.new('PropertyName', 'string', nil)

                # PROPERTY
                self.xml << PROPERTY.new('PropertyName', 'string', VALUE.new('dog'))
            
                # PROPERTY + attributes
                self.xml << PROPERTY.new('PropertyName', 'string', VALUE.new('dog'),
                                         'CIM_Pets', 'true')

                # PROPERTY + QUALIFIER
                self.xml << PROPERTY.new('PropertyName', 'string', VALUE.new('dog'),
                                         nil, nil, [QUALIFIER.new('IMPISH', 'string', 
                                                                  VALUE.new('true'))])
            end
        end

        class PropertyArray < CIMXMLTest
#    """
#    <!ELEMENT PROPERTY.ARRAY (QUALIFIER*,VALUE.ARRAY?)>
#    <!ATTLIST PROPERTY.ARRAY 
#       %CIMName;
#       %CIMType;           #REQUIRED 
#       %ArraySize;
#       %ClassOrigin;
#       %Propagated;
#       xml:lang   NMTOKEN  #IMPLIED>
#
#    """
            def setup

                # Empty
                self.xml << PROPERTY_ARRAY.new('Dogs', 'string')

                # VALUE.ARRAY
                self.xml << PROPERTY_ARRAY.new('Dogs', 'string',
                                               VALUE_ARRAY.new([VALUE.new('Spotty'),
                                                                VALUE.new('Bronte')]))

                # VALUE.ARRAY + attributes
                self.xml << PROPERTY_ARRAY.new('Dogs', 'string',
                                               VALUE_ARRAY.new([VALUE.new('Spotty'),
                                                                VALUE.new('Bronte')]),
                                               '2', 'CIM_Dog')

                self.xml << PROPERTY_ARRAY.new('Dogs', 'string', nil)

                # QUALIFIER + VALUE.ARRAY
                self.xml << PROPERTY_ARRAY.new('Dogs', 'string',
                                               VALUE_ARRAY.new([VALUE.new('Spotty'),
                                                                VALUE.new('Bronte')]),
                                               nil, nil, nil, 
                                               [QUALIFIER.new('IMPISH', 'string',
                                                              VALUE.new('true'))])
            end
        end

        class PropertyReference < CIMXMLTest
#    """
#    <!ELEMENT PROPERTY.REFERENCE (QUALIFIER*,VALUE.REFERENCE?)>
#    <!ATTLIST PROPERTY.REFERENCE
#        %CIMName;
#        %ReferenceClass;
#        %ClassOrigin;
#        %Propagated;>
#    """
            def setup

                # Empty
                self.xml << PROPERTY_REFERENCE.new('Dogs', nil)

                # VALUE.REFERENCE
                self.xml << PROPERTY_REFERENCE.new('Dogs',
                    VALUE_REFERENCE.new(CLASSNAME.new('CIM_Dog')))

                # VALUE.REFERENCE + attributes
                self.xml << PROPERTY_REFERENCE.new('Dogs',
                    VALUE_REFERENCE.new(CLASSNAME.new('CIM_Dog')),
                    'CIM_Dog', 'CIM_Dog', 'true')

                # QUALIFIER + VALUE.REFERENCE
                self.xml << PROPERTY_REFERENCE.new('Dogs',
                    VALUE_REFERENCE.new(CLASSNAME.new('CIM_Dog')),
                    nil, nil, nil, 
                   [QUALIFIER.new('IMPISH', 'string', VALUE.new('true'))])
            end
        end

        class Method < CIMXMLTest
#    """
#    <!ELEMENT METHOD (QUALIFIER*,(PARAMETER|PARAMETER.REFERENCE|
#                                  PARAMETER.ARRAY|PARAMETER.REFARRAY)*)>
#    <!ATTLIST METHOD 
#        %CIMName;
#        %CIMType;          #IMPLIED 
#        %ClassOrigin;
#        %Propagated;>
#    """
            def setup

                # Empty
                self.xml << METHOD.new('FooMethod')

                # PARAMETER
                self.xml << METHOD.new('FooMethod', [PARAMETER.new('arg', 'string')])

                # PARAMETER.REFERENCE
                self.xml << METHOD.new('FooMethod', [PARAMETER_REFERENCE.new('arg', 'CIM_Foo')])

                # PARAMETER.ARRAY
                self.xml << METHOD.new('FooMethod', [PARAMETER_ARRAY.new('arg', 'string')])

                # PARAMETER.REFARRAY
                self.xml << METHOD.new('FooMethod', [PARAMETER_REFARRAY.new('arg', 'CIM_Foo')])

                # PARAMETER + attributes
                self.xml << METHOD.new('FooMethod', [PARAMETER.new('arg', 'string')],
                                       'uint32', 'CIM_Foo', 'true')

                # QUALIFIER + PARAMETER
                self.xml << METHOD.new('FooMethod', [PARAMETER.new('arg', 'string')],
                                       nil, nil, nil,
                                       [QUALIFIER.new('IMPISH', 'string', VALUE.new('true'))])
            end
        end

        class Parameter < CIMXMLTest
#    """
#    <!ELEMENT PARAMETER (QUALIFIER*)>
#    <!ATTLIST PARAMETER 
#        %CIMName;
#        %CIMType;      #REQUIRED>
#    """
            def setup

                # Empty
                self.xml << PARAMETER.new('arg', 'string')

                # QUALIFIER
                self.xml << PARAMETER.new('arg', 'string',
                                          [QUALIFIER.new('IMPISH', 'string', 
                                                         VALUE.new('true'))])
            end
        end

        class ParameterReference < CIMXMLTest
#    """
#    <!ELEMENT PARAMETER.REFERENCE (QUALIFIER*)>
#    <!ATTLIST PARAMETER.REFERENCE
#        %CIMName;
#        %ReferenceClass;>
#    """
            def setup
        
                # Empty
                self.xml << PARAMETER_REFERENCE.new('arg')

                # QUALIFIER + attributes
                self.xml << PARAMETER_REFERENCE.new('arg', 'CIM_Foo',           
                    [QUALIFIER.new('IMPISH', 'string', VALUE.new('true'))])
            end
        end

        class ParameterArray < CIMXMLTest
#    """
#    <!ELEMENT PARAMETER.ARRAY (QUALIFIER*)>
#    <!ATTLIST PARAMETER.ARRAY
#        %CIMName;
#        %CIMType;           #REQUIRED
#        %ArraySize;>
#    """
            def setup

                # Empty
                self.xml << PARAMETER_ARRAY.new('arg', 'string')

                # QUALIFIERS + attributes
                self.xml << PARAMETER_ARRAY.new('arg', 'string', '0',
                     [QUALIFIER.new('IMPISH', 'string', VALUE.new('true'))])
            end
        end

        class ParameterReferenceArray < CIMXMLTest
#    """
#    <!ELEMENT PARAMETER.REFARRAY (QUALIFIER*)>
#    <!ATTLIST PARAMETER.REFARRAY
#        %CIMName;
#        %ReferenceClass;
#        %ArraySize;>
#    """
            def setup

                # Empty
                self.xml << PARAMETER_REFARRAY.new('arg')

                # QUALIFIERS + attributes
                self.xml << PARAMETER_REFARRAY.new('arg', 'CIM_Foo', '0',
                    [QUALIFIER.new('IMPISH', 'string', VALUE.new('true'))])
            end
        end

# New in v2.2 of the DTD

# TABLECELL.DECLARATION
# TABLECELL.REFERENCE
# TABLEROW.DECLARATION
# TABLE
# TABLEROW

#################################################################
#     3.2.6. Message Elements
#################################################################

#     3.2.6.1. MESSAGE
#     3.2.6.2. MULTIREQ
#     3.2.6.3. SIMPLEREQ
#     3.2.6.4. METHODCALL
#     3.2.6.5. PARAMVALUE
#     3.2.6.6. IMETHODCALL
#     3.2.6.7. IPARAMVALUE
#     3.2.6.8. MULTIRSP
#     3.2.6.9. SIMPLERSP
#     3.2.6.10. METHODRESPONSE
#     3.2.6.11. IMETHODRESPONSE
#     3.2.6.12. ERROR
#     3.2.6.13. RETURNVALUE
#     3.2.6.14. IRETURNVALUE
#     3.2.6.15 MULTIEXPREQ
#     3.2.6.16 SIMPLEEXPREQ
#     3.2.6.17 EXPMETHODCALL
#     3.2.6.18 MULTIEXPRSP
#     3.2.6.19 SIMPLEEXPRSP
#     3.2.6.20 EXPMETHODRESPONSE
#     3.2.6.21 EXPPARAMVALUE
#     3.2.6.22 RESPONSEDESTINATION
#     3.2.6.23 SIMPLEREQACK

        class Message < CIMXMLTest
#    """
#    <!ELEMENT MESSAGE (SIMPLEREQ | MULTIREQ | SIMPLERSP | MULTIRSP |
#                       SIMPLEEXPREQ | MULTIEXPREQ | SIMPLEEXPRSP |
#                       MULTIEXPRSP)>
#    <!ATTLIST MESSAGE
#	ID CDATA #REQUIRED
#	PROTOCOLVERSION CDATA #REQUIRED>
#    """
            def setup

                # SIMPLEREQ
                self.xml << MESSAGE.new(
                    SIMPLEREQ.new(
                        IMETHODCALL.new(
                            'FooMethod',
                            WBEM.LOCALNAMESPACEPATH())),
                        '1001', '1.0')

                # MULTIREQ
                self.xml << MESSAGE.new(
                    MULTIREQ.new(
                    [SIMPLEREQ.new(IMETHODCALL.new(
                                           'FooMethod',
                                           WBEM.LOCALNAMESPACEPATH())),
                     SIMPLEREQ.new(IMETHODCALL.new(
                                           'FooMethod',
                                           WBEM.LOCALNAMESPACEPATH()))]),
                       '1001', '1.0')

                # SIMPLERSP
                self.xml << MESSAGE.new(
                    SIMPLERSP.new(
                        IMETHODRESPONSE.new('FooMethod')),
                    '1001', '1.0')

                # MULTIRSP
                self.xml << MESSAGE.new(
                    MULTIRSP.new(
                    [SIMPLERSP.new(IMETHODRESPONSE.new('FooMethod')),
                     SIMPLERSP.new(IMETHODRESPONSE.new('FooMethod'))]),
                    '1001', '1.0')
            end
        end

        # TODO:

        # SIMPLEEXPREQ
        # MULTIEXPREQ
        # SIMPLEEXPRSP
        # MULTIEXPRSP        

        class MultiReq < CIMXMLTest
#    """
#    <!ELEMENT MULTIREQ (SIMPLEREQ, SIMPLEREQ+)>
#    """
            def setup
                self.xml << MULTIREQ.new(
                     [SIMPLEREQ.new(IMETHODCALL.new(
                                           'FooMethod',
                                           WBEM.LOCALNAMESPACEPATH())),
                     SIMPLEREQ.new(IMETHODCALL.new(
                                           'FooMethod',
                                           WBEM.LOCALNAMESPACEPATH()))])
            end
        end

        class MultiExpReq < CIMXMLTest
#    """
#    <!ELEMENT MULTIEXPREQ (SIMPLEEXPREQ, SIMPLEEXPREQ+)>
#    """
            def setup
                self.xml << MULTIEXPREQ.new(
                    [SIMPLEEXPREQ.new(EXPMETHODCALL.new('FooMethod')),
                     SIMPLEEXPREQ.new(EXPMETHODCALL.new('FooMethod'))])
            end
        end

        class SimpleReq < CIMXMLTest
#    """
#    <!ELEMENT SIMPLEREQ (IMETHODCALL | METHODCALL)>
#    """
            def setup
        
                # IMETHODCALL
                self.xml << SIMPLEREQ.new(
                    IMETHODCALL.new('FooIMethod', WBEM.LOCALNAMESPACEPATH()))

                # METHODCALL
                self.xml << SIMPLEREQ.new(
                    METHODCALL.new(
                        'FooMethod',
                        LOCALCLASSPATH.new(WBEM.LOCALNAMESPACEPATH(), WBEM.CLASSNAME())))
            end
        end

        class SimpleExpReq < CIMXMLTest
#    """
#    <!ELEMENT SIMPLEEXPREQ (EXPMETHODCALL)>
#    """
            def setup
                self.xml << SIMPLEEXPREQ.new(
                    EXPMETHODCALL.new('FooMethod'))
            end
        end

        class IMethodCall < CIMXMLTest
#    """
#    <!ELEMENT IMETHODCALL (LOCALNAMESPACEPATH, IPARAMVALUE*,
#                           RESPONSEDESTINATION?)>
#    <!ATTLIST IMETHODCALL
#	%CIMName;>
#    """

            def setup

                self.xml << IMETHODCALL.new('FooMethod', WBEM.LOCALNAMESPACEPATH())
                self.xml << IMETHODCALL.new(
                    'FooMethod2', WBEM.LOCALNAMESPACEPATH(),
                    [IPARAMVALUE.new('Dog', VALUE.new('Spottyfoot'))])
            end
        end

        # TODO: RESPONSEDESTINATION

        class MethodCall < CIMXMLTest
#    """
#    <!ELEMENT METHODCALL ((LOCALINSTANCEPATH | LOCALCLASSPATH), PARAMVALUE*,
#                          RESPONSEDESTINATION?>
#    <!ATTLIST METHODCALL
#	%CIMName;>
#    """

            def setup

                # LOCALINSTANCEPATH
                self.xml << METHODCALL.new('FooMethod',
                    LOCALINSTANCEPATH.new(WBEM.LOCALNAMESPACEPATH(), WBEM.INSTANCENAME()))

                # LOCALCLASSPATH
                self.xml << METHODCALL.new('FooMethod',
                    LOCALCLASSPATH.new(WBEM.LOCALNAMESPACEPATH(), WBEM.CLASSNAME()))

                # PARAMVALUEs
                self.xml << METHODCALL.new('FooMethod',
                    LOCALINSTANCEPATH.new(WBEM.LOCALNAMESPACEPATH(), WBEM.INSTANCENAME()),
                    [PARAMVALUE.new('Dog', VALUE.new('Spottyfoot'))])
            end
        end

        # TODO: RESPONSEDESTINATION

        class ExpMethodCall < CIMXMLTest
#    """
#    <!ELEMENT EXPMETHODCALL (EXPPARAMVALUE*)>
#    <!ATTLIST EXPMETHODCALL
#	%CIMName;>
#    """
            def setup
                self.xml << EXPMETHODCALL.new('FooMethod')
                self.xml << EXPMETHODCALL.new('FooMethod', [EXPPARAMVALUE.new('Dog')])
            end
        end                                   

        class ParamValue < CIMXMLTest
#    """
#    <!ELEMENT PARAMVALUE (VALUE | VALUE.REFERENCE | VALUE.ARRAY |
#                          VALUE.REFARRAY)?>
#    <!ATTLIST PARAMVALUE
#	%CIMName;
#        %ParamType;  #IMPLIED>
#    """
            def setup

                # Empty
                self.xml << PARAMVALUE.new('Pet')

                # VALUE
                self.xml << PARAMVALUE.new('Pet', VALUE.new('Dog'), 'string')

                # VALUE.REFERENCE
                self.xml << PARAMVALUE.new('Pet',
                    VALUE_REFERENCE.new(CLASSPATH.new(WBEM.NAMESPACEPATH(),
                                                      WBEM.CLASSNAME())))

                # VALUE.ARRAY
                self.xml << PARAMVALUE.new('Pet', VALUE_ARRAY.new([]))

                # VALUE.REFARRAY
                self.xml << PARAMVALUE.new('Pet', VALUE_REFARRAY.new([]))
            end
        end

        class IParamValue < CIMXMLTest
#    """
#    <!ELEMENT IPARAMVALUE (VALUE | VALUE.ARRAY | VALUE.REFERENCE |
#                           INSTANCENAME | CLASSNAME | QUALIFIER.DECLARATION |
#                           CLASS | INSTANCE | VALUE.NAMEDINSTANCE)?>
#    <!ATTLIST IPARAMVALUE
#	%CIMName;>
#    """
            def setup

                # Empty
                self.xml << IPARAMVALUE.new('Bird')

                # VALUE
                self.xml << IPARAMVALUE.new('Pet', VALUE.new('Dog'))

                # VALUE.ARRAY
                self.xml << IPARAMVALUE.new('Pet', VALUE_ARRAY.new([]))

                # VALUE.REFERENCE
                self.xml << IPARAMVALUE.new('Pet',
                    VALUE_REFERENCE.new(
                        CLASSPATH.new(WBEM.NAMESPACEPATH(), WBEM.CLASSNAME())))

                # INSTANCENAME
                self.xml << IPARAMVALUE.new('Pet', WBEM.INSTANCENAME())

                # CLASSNAME
                self.xml << IPARAMVALUE.new('Pet', WBEM.CLASSNAME())

                # TODO: QUALIFIER.DECLARATION

                # CLASS
                self.xml << IPARAMVALUE.new('Pet', CLASS.new('CIM_Foo'))

                # INSTANCE
                self.xml << IPARAMVALUE.new('Pet', INSTANCE.new('CIM_Pet', []))

                # VALUE.NAMEDINSTANCE
                self.xml << IPARAMVALUE.new('Pet',
                    VALUE_NAMEDINSTANCE.new(WBEM.INSTANCENAME(), INSTANCE.new('CIM_Pet', [])))
            end
        end

        class ExpParamValue < CIMXMLTest
#    """
#    <!ELEMENT EXPPARAMVALUE (INSTANCE? | VALUE? | METHODRESPONSE? |
#                             IMETHODRESPONSE?)>
#    <!ATTLIST EXPPARAMVALUE
#	%CIMName;
#        %ParamType;  #IMPLIED>
#    """
            def setup
                self.xml << EXPPARAMVALUE.new('FooParam')
                self.xml << EXPPARAMVALUE.new('FooParam', INSTANCE.new('CIM_Pet', []))
            end
        end

        class MultiRsp < CIMXMLTest
#    """
#    <!ELEMENT MULTIRSP (SIMPLERSP, SIMPLERSP+)>
#    """
            def setup
                self.xml << MULTIRSP.new([SIMPLERSP.new(IMETHODRESPONSE.new('FooMethod')),
                                          SIMPLERSP.new(IMETHODRESPONSE.new('FooMethod'))])
            end
        end

        class MultiExpRsp < CIMXMLTest
#    """
#    <!ELEMENT MULTIEXPRSP (SIMPLEEXPRSP, SIMPLEEXPRSP+)>
#    """
            def setup
                self.xml << MULTIEXPRSP.new([SIMPLEEXPRSP.new(EXPMETHODRESPONSE.new('FooMethod')),
                                             SIMPLEEXPRSP.new(EXPMETHODRESPONSE.new('FooMethod'))])
            end
        end

        class SimpleRsp < CIMXMLTest
#    """
#    <!ELEMENT SIMPLERSP (METHODRESPONSE | IMETHODRESPONSE | SIMPLEREQACK>
#    """
            def setup

                # METHODRESPONSE
                self.xml << SIMPLERSP.new(METHODRESPONSE.new('FooMethod'))
                
                # IMETHODRESPONSE
                self.xml << SIMPLERSP.new(IMETHODRESPONSE.new('FooMethod'))
            end
        end
        # TODO: SIMPLEREQACK

        class SimpleExpRsp < CIMXMLTest
#    """
#    <!ELEMENT SIMPLEEXPRSP (EXPMETHODRESPONSE)>
#    """
            def setup
                self.xml << SIMPLEEXPRSP.new(EXPMETHODRESPONSE.new('FooMethod'))
            end
        end

        class MethodResponse < CIMXMLTest
#    """
#    <!ELEMENT METHODRESPONSE (ERROR | (RETURNVALUE?, PARAMVALUE*))>
#    <!ATTLIST METHODRESPONSE
#	%CIMName;>
#    """
            def setup

                # ERROR
                self.xml << METHODRESPONSE.new('FooMethod', ERROR.new('123'))

                # Empty
                self.xml << METHODRESPONSE.new('FooMethod')

                # RETURNVALUE
                self.xml << METHODRESPONSE.new('FooMethod',
                                               PARAMVALUE.new('Dog', VALUE.new('Spottyfoot')))
        
                # PARAMVALUE
                self.xml << METHODRESPONSE.new('FooMethod',
                                               PARAMVALUE.new('Dog', VALUE.new('Spottyfoot')))
                
                # RETURNVALUE + PARAMVALUE
                self.xml << METHODRESPONSE.new('FooMethod',
                        [RETURNVALUE.new(VALUE.new('Dog')),
                         PARAMVALUE.new('Dog', VALUE.new('Spottyfoot'))])
            end
        end

        class ExpMethodResponse < CIMXMLTest
#    """
#    <!ELEMENT EXPMETHODRESPONSE (ERROR | IRETURNVALUE?)>
#    <!ATTLIST EXPMETHODRESPONSE
#	%CIMName;>
#    """
            def setup

                # Empty
                self.xml << EXPMETHODRESPONSE.new('FooMethod')

                # ERROR
                self.xml << EXPMETHODRESPONSE.new('FooMethod', ERROR.new('123'))

                # IRETURNVALUE
                self.xml << EXPMETHODRESPONSE.new('FooMethod', 
                                                  IRETURNVALUE.new(VALUE.new('Dog')))
            end
        end

        class IMethodResponse < CIMXMLTest
#    """
#    <!ELEMENT IMETHODRESPONSE (ERROR | IRETURNVALUE?)>
#    <!ATTLIST IMETHODRESPONSE
#	%CIMName;>
#    """
            def setup

                # Empty
                self.xml << IMETHODRESPONSE.new('FooMethod')

                # ERROR
                self.xml << IMETHODRESPONSE.new('FooMethod', ERROR.new('123'))

                # IRETURNVALUE
                self.xml << IMETHODRESPONSE.new('FooMethod', 
                                                IRETURNVALUE.new(VALUE.new('Dog')))
            end
        end

        class Error < CIMXMLTest
#    """
#    <!ELEMENT ERROR (INSTANCE*)>
#    <!ATTLIST ERROR
#	CODE CDATA #REQUIRED
#	DESCRIPTION CDATA #IMPLIED>
#    """
            def setup
                self.xml << ERROR.new('1')
                self.xml << ERROR.new('1', 'Foo not found')
                # TODO: INSTANCE*
            end
        end

        class ReturnValue < CIMXMLTest
#    """
#    <!ELEMENT RETURNVALUE (VALUE | VALUE.REFERENCE)>
#    <!ATTLIST RETURNVALUE
#        %ParamType;     #IMPLIED>
#    """
            def setup

                # VALUE
                self.xml << RETURNVALUE.new(VALUE.new('Dog'))

                # VALUE.REFERENCE
                self.xml << RETURNVALUE.new(VALUE_REFERENCE.new(
                    CLASSPATH.new(WBEM.NAMESPACEPATH(), WBEM.CLASSNAME())))

                # TODO: PARAMTYPE
            end
        end

        class IReturnValue < CIMXMLTest
#    """
#    <!ELEMENT IRETURNVALUE (CLASSNAME* | INSTANCENAME* | VALUE* |
#                            VALUE.OBJECTWITHPATH* |
#                            VALUE.OBJECTWITHLOCALPATH* | VALUE.OBJECT* |
#                            OBJECTPATH* | QUALIFIER.DECLARATION* |
#                            VALUE.ARRAY? | VALUE.REFERENCE? | CLASS* |
#                            INSTANCE* | VALUE.NAMEDINSTANCE*)>
#    """
            def setup

                # Empty
                self.xml << IRETURNVALUE.new(nil)

                # CLASSNAME
                self.xml << IRETURNVALUE.new(WBEM.CLASSNAME())

                # INSTANCENAME
                self.xml << IRETURNVALUE.new(WBEM.INSTANCENAME())
            
                # VALUE
                self.xml << IRETURNVALUE.new(VALUE.new('Dog'))
            
                # VALUE.OBJECTWITHPATH
                self.xml << IRETURNVALUE.new(
                    VALUE_OBJECTWITHPATH.new(
                        CLASSPATH.new(WBEM.NAMESPACEPATH(), WBEM.CLASSNAME()),
                        CLASS.new('CIM_Foo')))
        
                # VALUE.OBJECTWITHLOCALPATH
                self.xml << IRETURNVALUE.new(
                    VALUE_OBJECTWITHLOCALPATH.new(
                        LOCALCLASSPATH.new(WBEM.LOCALNAMESPACEPATH(), WBEM.CLASSNAME()),
                        CLASS.new('CIM_Foo')))
        
                # VALUE.OBJECT
                self.xml << IRETURNVALUE.new(VALUE_OBJECT.new(INSTANCE.new('CIM_Pet', [])))
        
                # OBJECTPATH
                self.xml << IRETURNVALUE.new(
                    OBJECTPATH.new(INSTANCEPATH.new(
                            WBEM.NAMESPACEPATH(), WBEM.INSTANCENAME())))
        
                # TODO: QUALIFIER.DECLARATION
            
                # VALUE.ARRAY
                self.xml << IRETURNVALUE.new(VALUE_ARRAY.new([]))
            
                # VALUE.REFERENCE
                self.xml << IRETURNVALUE.new(
                    VALUE_REFERENCE.new(
                        CLASSPATH.new(WBEM.NAMESPACEPATH(), WBEM.CLASSNAME())))
        
                # CLASS
                self.xml << IRETURNVALUE.new(CLASS.new('CIM_Foo'))
        
                # INSTANCE
                self.xml << IRETURNVALUE.new(INSTANCE.new('CIM_Pet', []))
        
                # VALUE.NAMEDINSTANCE
                self.xml << IRETURNVALUE.new(
                    VALUE_NAMEDINSTANCE.new(WBEM.INSTANCENAME(), 
                                            INSTANCE.new('CIM_Pet', [])))
            end
        end

        class ResponseDestination < UnimplementedTest
#    """
#    The RESPONSEDESTINATION element contains an instance that
#    describes the desired destination for the response.
#
#    <!ELEMENT RESPONSEDESTINATON (INSTANCE)>
#    """
        end

        class SimpleReqAck < UnimplementedTest
#    """
#
#    The SIMPLEREQACK defines the acknowledgement response to a Simple
#    CIM Operation asynchronous request. The ERROR subelement is used
#    to report a fundamental error which prevented the asynchronous
#    request from being initiated.
#
#    <!ELEMENT SIMPLEREQACK (ERROR?)>
#    <!ATTLIST SIMPLEREQACK 
#        INSTANCEID CDATA     #REQUIRED>
#    """
        end

        #################################################################
        # Root element
        #################################################################


        #################################################################
        # Main function
        #################################################################

        TESTS = [

                 # Root element

                 CIM,                                # CIM

                 # Object declaration elements

                 Declaration,                        # DECLARATION
                 DeclGroup,                          # DECLGROUP
                 DeclGroupWithName,                  # DECLGROUP.WITHNAME
                 DeclGroupWithPath,                  # DECLGROUP.WITHPATH
                 QualifierDeclaration,               # QUALIFIER.DECLARATION
                 Scope,                              # SCOPE

                 # Object value elements

                 Value,                              # VALUE
                 ValueArray,                         # VALUE.ARRAY
                 ValueReference,                     # VALUE.REFERENCE
                 ValueRefArray,                      # VALUE.REFARRAY
                 ValueObject,                        # VALUE.OBJECT
                 ValueNamedInstance,                 # VALUE.NAMEDINSTANCE
                 ValueNamedObject,                   # VALUE.NAMEDOBJECT
                 ValueObjectWithLocalPath,           # VALUE.OBJECTWITHLOCALPATH
                 ValueObjectWithPath,                # VALUE.OBJECTWITHPATH
                 ValueNull,                          # VALUE.NULL

                 # Object naming and locating elements

                 NamespacePath,                      # NAMESPACEPATH
                 LocalNamespacePath,                 # LOCALNAMESPACEPATH
                 Host,                               # HOST
                 Namespace,                          # NAMESPACE
                 ClassPath,                          # CLASSPATH
                 LocalClassPath,                     # LOCALCLASSPATH
                 ClassName,                          # CLASSNAME
                 InstancePath,                       # INSTANCEPATH
                 LocalInstancePath,                  # LOCALINSTANCEPATH
                 InstanceName,                       # INSTANCENAME
                 ObjectPath,                         # OBJECTPATH
                 KeyBinding,                         # KEYBINDING
                 KeyValue,                           # KEYVALUE
                 
                 # Object definition elements
                 
                 Class,                              # CLASS
                 Instance,                           # INSTANCE
                 Qualifier,                          # QUALIFIER
                 Property,                           # PROPERTY
                 PropertyArray,                      # PROPERTY.ARRY
                 PropertyReference,                  # PROPERTY.REFERENCE
                 Method,                             # METHOD
                 Parameter,                          # PARAMETER
                 ParameterReference,                 # PARAMETER.REFERENCE
                 ParameterArray,                     # PARAMETER.ARRAY
                 ParameterReferenceArray,            # PARAMETER.REFARRAY

                 # Message elements

                 Message,                            # MESSAGE
                 MultiReq,                           # MULTIREQ
                 MultiExpReq,                        # MULTIEXPREQ
                 SimpleReq,                          # SIMPLEREQ
                 SimpleExpReq,                       # SIMPLEEXPREQ
                 IMethodCall,                        # IMETHODCALL
                 MethodCall,                         # METHODCALL
                 ExpMethodCall,                      # EXPMETHODCALL
                 ParamValue,                         # PARAMVALUE
                 IParamValue,                        # IPARAMVALUE
                 ExpParamValue,                      # EXPPARAMVALUE
                 MultiRsp,                           # MULTIRSP
                 MultiExpRsp,                        # MULTIEXPRSP
                 SimpleRsp,                          # SIMPLERSP
                 SimpleExpRsp,                       # SIMPLEEXPRSP
                 MethodResponse,                     # METHODRESPONSE
                 ExpMethodResponse,                  # EXPMETHODRESPONSE
                 IMethodResponse,                    # IMETHODRESPONSE
                 Error,                              # ERROR
                 ReturnValue,                        # RETURNVALUE
                 IReturnValue,                       # IRETURNVALUE
                 ResponseDestination,                # RESPONSEDESTINATION
                 SimpleReqAck                       # SIMPLEREQACK
                ]

        if __FILE__ == $0
            
            Comfychair.main(TESTS)
        end

    end
end
