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

# '''Tuple parser for the XML schema representing CIM messages.

# This framework is meant to add some value to the tuple-tree
# representation of CIM in XML by having the following properties: 

#   - Silently ignoring whitespace text elements

#   - Conversion from tuple-tree representation into a python dictionary
#     which can then be accessed in a readable fashion.

#   - Validation of the XML elements and attributes without having to
#     use the DTD file or any external tools.

# '''

# Implementation: this works by a recursive descent down the CIM XML
# tupletree.  As we walk down, we produce cim_obj and cim_type
# objects representing the CIM message in digested form.

# For each XML node type FOO there is one function parse_foo, which
# returns the digested form by examining a tuple tree rooted at FOO.

# The resulting objects are constrained to the shape of the CIM XML
# tree: if one node in XML contains another, then the corresponding
# CIM object will contain the second.  However, there can be local
# transformations at each node: some levels are ommitted, some are
# transformed into lists or hashes.

# We try to validate that the tree is well-formed too.  The validation
# is more strict than the DTD, but it is forgiving of implementation
# quirks and bugs in Pegasus.

# Bear in mind in the parse functions that each tupletree tuple is
# structured as

#   tt[0]: name string             == name(tt)
#   tt[1]: hash of attributes      == attrs(tt)
#   tt[2]: sequence of children    == kids(tt)

# At the moment this layer is a little inconsistent: in some places it
# returns tupletrees, and in others Python objects.  It may be better
# to hide the tupletree/XML representation from higher level code.


# TODO: Maybe take a DTD fragment like "(DECLGROUP |
# DECLGROUP.WITHNAME | DECLGROUP.WITHPATH)*", parse that and check it
# directly.

# TODO: Syntax-check some attributes with defined formats, such as NAME

# TODO: Implement qualifiers by making subclasses of CIM types with a
# .qualifiers property.

require "wbem/cim_obj"
require "date"

module WBEM

    class ParseError < Exception
        #"""This exception is raised when there is a validation error detected
        #by the parser."""    
    end

    def WBEM.filter_tuples(l)
#     """Return only the tuples in a list.

#     In a tupletree, tuples correspond to XML elements.  Useful for
#     stripping out whitespace data in a child list."""
        if l.nil?
            []
        else
            l.find_all { |x| x.is_a? Array }
        end
    end

    def WBEM.pcdata(tt)
#     """Return the concatenated character data within a tt.

#     The tt must not have non-character children."""
        tt[2].each do |x|
            unless x.is_a? String
                raise ParseError, "unexpected node #{x} under #{tt}"
            end
        end
        tt[2].join
    end

    def WBEM.name(tt)
        tt[0]
    end

    def WBEM.attrs(tt)
        tt[1]
    end

    def WBEM.kids(tt)
        WBEM.filter_tuples(tt[2])
    end

    def WBEM.check_node(tt, nodename, required_attrs = [], optional_attrs = [],
                   allowed_children = nil,
                   allow_pcdata = false)
#     """Check static local constraints on a single node.

#     The node must have the given name.  The required attrs must be
#     present, and the optional attrs may be.

#     If allowed_children is not nil, the node may have children of the
#     given types.  It can be [] for nodes that may not have any
#     children.  If it's nil, it is assumed the children are validated
#     in some other way.

#     If allow_pcdata is true, then non-whitespace text children are allowed.
#     (Whitespace text nodes are always allowed.)
#     """
    
        unless WBEM.name(tt) == nodename
            raise ParseError, "expected node type #{nodename}, not #{WBEM.name(tt)} \n #{tt}"
        end

        # Check we have all the required attributes, and no unexpected ones
        tt_attrs = {}
        tt_attrs = WBEM.attrs(tt).clone unless WBEM.attrs(tt).nil?

        required_attrs.each do |attr|
            unless tt_attrs.has_key?(attr)
                raise ParseError, "expected #{attr} attribute on #{WBEM.name(tt)} node, but only have #{WBEM.attrs(tt).keys()}"
            end
            tt_attrs.delete(attr)
        end

        optional_attrs.each { |attr| tt_attrs.delete(attr) }

        unless tt_attrs.empty?
            raise ParseError, "invalid extra attributes #{tt_attrs.keys()}"
        end

        unless allowed_children.nil?
            WBEM.kids(tt).each do |c|
                unless allowed_children.include?(WBEM.name(c))
                    raise ParseError, "unexpected node #{WBEM.name(c)} under #{WBEM.name(tt)}; wanted #{allowed_children}"
                end
            end
        end

        unless allow_pcdata
            tt[2].each do |c|
                if (c.is_a? String and c.delete(" \t\n").length > 0)
                    raise ParseError, "unexpected non-blank pcdata node #{c} under #{WBEM.name(tt)}"
                end
            end
        end
    end

    def WBEM.one_child(tt, acceptable)
#     """Parse children of a node with exactly one child node.

#     PCData is ignored.
#     """
        k = WBEM.kids(tt)

        unless k.length == 1
            raise ParseError, "expecting just one #{acceptable}, got #{k.each {|t| t[0] }}"
        end

        child = k[0]

        unless acceptable.include?(WBEM.name(child))
            raise ParseError, "expecting one of #{acceptable}, got #{WBEM.name(child)} under #{WBEM.name(tt)}"
        end
        
        return WBEM.parse_any(child)
    end

    def WBEM.optional_child(tt, allowed)
#     """Parse exactly zero or one of a list of elements from the
#     child nodes."""
        k = WBEM.kids(tt)

        if k.length > 1
            raise ParseError, "expecting zero or one of #{allowed} under #{tt}"
        elsif k.length == 1
            return WBEM.one_child(tt, allowed)
        else
            return nil
        end
    end

    def WBEM.list_of_various(tt, acceptable)
#     """Parse zero or more of a list of elements from the child nodes.

#     Each element of the list can be any type from the list of acceptable
#     nodes."""

        r = []

        WBEM.kids(tt).each do |child|
            unless acceptable.include?(WBEM.name(child))
                raise ParseError, "expected one of #{acceptable} under #{WBEM.name(tt)}, got #{WBEM.name(child)}"
            end
            r << WBEM.parse_any(child)
        end
        return r
    end

    def WBEM.list_of_matching(tt, matched)
#     """Parse only the children of particular types under tt.

#     Other children are ignored rather than giving an error."""

        r = []

        WBEM.kids(tt).each do |child|
            r << WBEM.parse_any(child) if matched.include?(WBEM.name(child))
        end
        return r
    end

    def WBEM.list_of_same(tt, acceptable)
#     """Parse a list of elements from child nodes.

#     The children can be any of the listed acceptable types, but they
#     must all be the same.
#     """

        unless (k = WBEM.kids(tt))
            return [] # empty list, consistent with list_of_various
        end
    
        w = WBEM.name(k[0])
        unless acceptable.include?(w)
            raise ParseError, "expected one of #{acceptable} under #{WBEM.name(tt)}, got #{WBEM.name(child)}"
        end
        r = []
        k.each do |child|
            unless WBEM.name(child) == w
                raise ParseError, "expected list of #{w} under #{WBEM.name(child)}, but found #{WBEM.name(tt)}"
            end
            r << WBEM.parse_any(child)
        end
        return r
    end

    def WBEM.notimplemented(tt)
        raise ParseError, "parser for #{WBEM.name(tt)} not implemented"
    end
#
# Root element
#

    def WBEM.parse_cim(tt)
#     """
#     <!ELEMENT CIM (MESSAGE | DECLARATION)>
#     <!ATTLIST CIM
# 	CIMVERSION CDATA #REQUIRED
# 	DTDVERSION CDATA #REQUIRED>
#     """

        WBEM.check_node(tt, "CIM", ["CIMVERSION", "DTDVERSION"])
    
        unless WBEM.attrs(tt)["CIMVERSION"] == "2.0"
            raise ParseError, "CIMVERSION is #{WBEM.attrs(tt)[CIMVERSION]}, expected 2.0"
        end
        child = WBEM.one_child(tt, ["MESSAGE", "DECLARATION"])
        return [WBEM.name(tt), WBEM.attrs(tt), child]
    end

    #
    # Object value elements
    #

    def WBEM.parse_value(tt)
        #    '''Return VALUE contents as a string'''
        ## <!ELEMENT VALUE (#PCDATA)>
        WBEM.check_node(tt, "VALUE", [], [], [], true)
        return WBEM.pcdata(tt)
    end

    def WBEM.parse_value_array(tt)
        #"""Return list of strings."""
        ## <!ELEMENT VALUE.ARRAY (VALUE*)>
        WBEM.check_node(tt, "VALUE.ARRAY", [], [], ["VALUE"])
        return WBEM.list_of_same(tt, ["VALUE"])
    end

    def WBEM.parse_value_reference(tt)
#     """
#     <!ELEMENT VALUE.REFERENCE (CLASSPATH | LOCALCLASSPATH | CLASSNAME |
#                                INSTANCEPATH | LOCALINSTANCEPATH |
#                                INSTANCENAME)>
#     """

        WBEM.check_node(tt, "VALUE.REFERENCE", [])

        child = WBEM.one_child(tt,
                          ["CLASSPATH", "LOCALCLASSPATH", "CLASSNAME",
                           "INSTANCEPATH", "LOCALINSTANCEPATH",
                           "INSTANCENAME"])
                      
        # The VALUE.REFERENCE wrapper element is discarded
        return child
    end
    
    def WBEM.parse_value_refarray(tt)
#     """
#     <!ELEMENT VALUE.REFARRAY (VALUE.REFERENCE*)>
#     """
    
        WBEM.check_node(tt, "VALUE.REFARRAY")
        children = WBEM.list_of_various(tt, ["VALUE.REFERENCE"])
        return [WBEM.name(tt), WBEM.attrs(tt), children]
    end

    def WBEM.parse_value_object(tt)
#     """
#     <!ELEMENT VALUE.OBJECT (CLASS | INSTANCE)>
#     """

        WBEM.check_node(tt, "VALUE.OBJECT")
        child = WBEM.one_child(tt, ["CLASS", "INSTANCE"])
        return [WBEM.name(tt), WBEM.attrs(tt), child]
    end

    def WBEM.parse_value_namedinstance(tt)
#     """
#     <!ELEMENT VALUE.NAMEDINSTANCE (INSTANCENAME, INSTANCE)>
#     """

        WBEM.check_node(tt, "VALUE.NAMEDINSTANCE")
        k = WBEM.kids(tt)
        unless k.length == 2
            raise ParseError, "expecting (INSTANCENAME, INSTANCE), got #{k}"
        end
        instancename = WBEM.parse_instancename(k[0])
        instance = WBEM.parse_instance(k[1])        
        instance.path = instancename
        return instance
    end

    def WBEM.parse_value_namedobject(tt)
#     """
#     <!ELEMENT VALUE.NAMEDOBJECT (CLASS | (INSTANCENAME, INSTANCE))>
#     """

        WBEM.check_node(tt, "VALUE.NAMEDOBJECT")
        k = WBEM.kids(tt)
        if k.length == 1
            object = WBEM.parse_class(k[0])
        elsif k.length == 2
            path = WBEM.parse_instancename(k[0])
            object = WBEM.parse_instance(k[1])
            object.path = path
        else
            raise ParseError, "Expecting one or two elements, got #{k}"
        end
        return [WBEM.name(tt), WBEM.attrs(tt), object]
    end

    def WBEM.parse_value_objectwithlocalpath(tt)
#     """
#     <!ELEMENT VALUE.OBJECTWITHLOCALPATH ((LOCALCLASSPATH, CLASS) |
#                                          (LOCALINSTANCEPATH, INSTANCE))>
#     """

        WBEM.check_node(tt, "VALUE.OBJECTWITHLOCALPATH")
        k = WBEM.kids(tt)
        unless k.length == 2
            raise ParseError, "Expecting two elements, got #{k.length}"
        end
        if k[0][0] == "LOCALCLASSPATH"
            object = [WBEM.parse_localclasspath(k[0]),
                      WBEM.parse_class(k[1])]
        else
            path = WBEM.parse_localinstancepath(k[0])
            object = WBEM.parse_instance(k[1])
            object.path = path
        end
        return [WBEM.name(tt), WBEM.attrs(tt), object]
    end

    def WBEM.parse_value_objectwithpath(tt)
#     """
#     <!ELEMENT VALUE.OBJECTWITHPATH ((CLASSPATH, CLASS) |
#                                     (INSTANCEPATH, INSTANCE))>
#     """

        WBEM.check_node(tt, "VALUE.OBJECTWITHPATH")
        k = WBEM.kids(tt)
        unless k.length == 2
            raise ParseError, "Expecting two elements, got #{k.length}"
        end

        if WBEM.name(k[0]) == "CLASSPATH"
            object = [WBEM.parse_classpath(k[0]),
                      WBEM.parse_class(k[1])]
        else
            path = WBEM.parse_instancepath(k[0])
            object = WBEM.parse_instance(k[1])
            object.path = path
        end
        return [WBEM.name(tt), WBEM.attrs(tt), object]
    end

#
# Object naming and locating elements
#

    def WBEM.parse_namespacepath(tt)
#     """
#     <!ELEMENT NAMESPACEPATH (HOST, LOCALNAMESPACEPATH)>
#     """
    
        WBEM.check_node(tt, "NAMESPACEPATH")
        unless ((k = WBEM.kids(tt)).length == 2)
            raise ParseError, "Expecting (HOST, LOCALNAMESPACEPATH) got #{WBEM.kids(tt).keys()}"
        end

        host = WBEM.parse_host(k[0])
        localnspath = WBEM.parse_localnamespacepath(k[1])
        return CIMNamespacePath.new(host, localnspath)
    end

    def WBEM.parse_localnamespacepath(tt)
#     """
#     <!ELEMENT LOCALNAMESPACEPATH (NAMESPACE+)>
#     """
        WBEM.check_node(tt, "LOCALNAMESPACEPATH", [], [], ["NAMESPACE"])
        if WBEM.kids(tt).length == 0
            raise ParseError, "Expecting one or more of NAMESPACE, got nothing"
        end
        WBEM.list_of_various(tt, ["NAMESPACE"]).join("/")
    end

    def WBEM.parse_host(tt)
#     """
#     <!ELEMENT HOST (#PCDATA)>
#     """
        WBEM.check_node(tt, "HOST", [], [], nil , true)
        return WBEM.pcdata(tt)
    end

    def WBEM.parse_namespace(tt)
#     """
#     <!ELEMENT NAMESPACE EMPTY>
#     <!ATTLIST NAMESPACE
# 	%CIMName;>
#     """

        WBEM.check_node(tt, "NAMESPACE", ["NAME"], [], [])
        return WBEM.attrs(tt)["NAME"]
    end

    def WBEM.parse_classpath(tt)
#     """
#     <!ELEMENT CLASSPATH (NAMESPACEPATH, CLASSNAME)>
#     """
        WBEM.check_node(tt, "CLASSPATH")
        unless ((k = WBEM.kids(tt)).length == 2)
            raise ParseError, "Expecting (NAMESPACEPATH, CLASSNAME) got #{k.keys()}"
        end
        nspath = WBEM.parse_namespacepath(k[0])
        classname = WBEM.parse_classname(k[1])
        return CIMClassPath.new(nspath.host, nspath.localnamespacepath,
                                classname.classname)
    end

    def WBEM.parse_localclasspath(tt)
#     """
#     <!ELEMENT LOCALCLASSPATH (LOCALNAMESPACEPATH, CLASSNAME)>
#     """
        WBEM.check_node(tt, "LOCALCLASSPATH")
        unless ((k = WBEM.kids(tt)).length == 2)
            raise ParseError, "Expecting (LOCALNAMESPACEPATH, CLASSNAME) got #{k.keys()}"
        end
        localnspath = WBEM.parse_localnamespacepath(k[0])
        classname = WBEM.parse_classname(k[1])
        return CIMLocalClassPath.new(localnspath, classname.classname)
    end

    def WBEM.parse_classname(tt)
#     """
#     <!ELEMENT CLASSNAME EMPTY>
#     <!ATTLIST CLASSNAME
# 	%CIMName;>
#     """
        WBEM.check_node(tt, "CLASSNAME", ["NAME"], [], [])
        return CIMClassName.new(WBEM.attrs(tt)["NAME"])
    end

    def WBEM.parse_instancepath(tt)
#     """
#     <!ELEMENT INSTANCEPATH (NAMESPACEPATH, INSTANCENAME)>
#     """

        WBEM.check_node(tt, "INSTANCEPATH")
        
        unless ((k = WBEM.kids(tt)).length == 2)
            raise ParseError, "Expecting (NAMESPACEPATH, INSTANCENAME) got #{k}"
        end
        nspath = WBEM.parse_namespacepath(k[0])
        instancename = WBEM.parse_instancename(k[1])
        instancename.host = nspath.host
        instancename.namespace = nspath.localnamespacepath
        
        return instancename
        end

    def WBEM.parse_localinstancepath(tt)
#     """
#     <!ELEMENT LOCALINSTANCEPATH (LOCALNAMESPACEPATH, INSTANCENAME)>
#     """

        WBEM.check_node(tt, "LOCALINSTANCEPATH")

        unless ((k = WBEM.kids(tt)).length == 2)
            raise ParseError, "Expecting (LOCALNAMESPACEPATH, INSTANCENAME) got #{k.keys()}"
        end
        localnspath = WBEM.parse_localnamespacepath(k[0])
        instancename = WBEM.parse_instancename(k[1])
        instancename.namespace = localnspath
        return instancename
    end

    def WBEM.parse_instancename(tt)
#    """Parse XML INSTANCENAME into CIMInstanceName object."""
    
    ## <!ELEMENT INSTANCENAME (KEYBINDING* | KEYVALUE? | VALUE.REFERENCE?)>
    ## <!ATTLIST INSTANCENAME %ClassName;>

        WBEM.check_node(tt, "INSTANCENAME", ["CLASSNAME"])

        if ((k = WBEM.kids(tt)).length == 0)
            # probably not ever going to see this, but it's valid
            # according to the grammar
            return CIMInstanceName.new(WBEM.attrs(tt)["CLASSNAME"], {})
        end
        classname = WBEM.attrs(tt)["CLASSNAME"]
        w = WBEM.name(k[0])
        if w == "KEYVALUE" or w == "VALUE.REFERENCE"
            unless ((k = WBEM.kids(tt)).length == 1)
                raise ParseError, "expected only one #{w} under #{WBEM.name(tt)}"
            end
        
            # FIXME: This is probably not the best representation of these forms...
            return CIMInstanceName(classname, {nil => WBEM.parse_any(k[0])})
        elsif w == "KEYBINDING"
            kbs = {}
            WBEM.list_of_various(tt, ["KEYBINDING"]).each { |kb| kbs.update(kb)}
            return CIMInstanceName.new(classname, kbs)        
        else
            raise ParseError, "unexpected node #{w} under #{WBEM.name(tt)}"
        end
    end

    def WBEM.parse_objectpath(tt)
#     """
#     <!ELEMENT OBJECTPATH (INSTANCEPATH | CLASSPATH)>
#     """

        WBEM.check_node(tt, "OBJECTPATH")
        child  = WBEM.one_child(tt, ["INSTANCEPATH", "CLASSPATH"])
        return [WBEM.name(tt), WBEM.attrs(tt), child]


    end

    def WBEM.parse_keybinding(tt)
    ##<!ELEMENT KEYBINDING (KEYVALUE | VALUE.REFERENCE)>
    ##<!ATTLIST KEYBINDING
    ##	%CIMName;>

#    """Returns one-item dictionary from name to Python value."""
    
        WBEM.check_node(tt, "KEYBINDING", ["NAME"])
        child = WBEM.one_child(tt, ["KEYVALUE", "VALUE.REFERENCE"])
        return {WBEM.attrs(tt)["NAME"] => child}
    end

    def WBEM.parse_keyvalue(tt)
    ##<!ELEMENT KEYVALUE (#PCDATA)>
    ##<!ATTLIST KEYVALUE
    ##          VALUETYPE (string | boolean | numeric) "string">

#    """Parse VALUETYPE into Python primitive value"""
    
        WBEM.check_node(tt, "KEYVALUE", [], ["VALUETYPE"], [], true)
        vt = WBEM.attrs(tt).fetch("VALUETYPE", "string")
        p = WBEM.pcdata(tt)
        if vt == "string"
            return p
        elsif vt == "boolean"
            return WBEM.unpack_boolean(p)
        elsif vt == "numeric"
            return p.strip().to_i
        else
            raise ParseError, "invalid VALUETYPE #{vt} in #{WBEM.name(tt)}"
        end
    end

#
# Object definition elements
#
    def WBEM.parse_class(tt)
    ## <!ELEMENT CLASS (QUALIFIER*, (PROPERTY | PROPERTY.ARRAY |
    ##                               PROPERTY.REFERENCE)*, METHOD*)>
    ## <!ATTLIST CLASS
    ##     %CIMName; 
    ##     %SuperClass;>

    # This doesn't check the ordering of elements, but it's not very important
        WBEM.check_node(tt, "CLASS", ["NAME"], ["SUPERCLASS"],
                   ["QUALIFIER", "PROPERTY", "PROPERTY.REFERENCE",
                    "PROPERTY.ARRAY", "METHOD"])

        obj = CIMClass.new(WBEM.attrs(tt)["NAME"])
        obj.superclass = WBEM.attrs(tt)["SUPERCLASS"]

        obj.properties = WBEM.byname(WBEM.list_of_matching(tt, ["PROPERTY", "PROPERTY.REFERENCE",
                                                      "PROPERTY.ARRAY"]))

        obj.qualifiers = WBEM.byname(WBEM.list_of_matching(tt, ["QUALIFIER"]))
        obj.cim_methods = list_of_matching(tt, ["METHOD"])
        
        return obj
    end

    def WBEM.parse_instance(tt)
#     """Return a CIMInstance.

#     The instance contains the properties, qualifiers and classname for
#     the instance"""
    
    ##<!ELEMENT INSTANCE (QUALIFIER*, (PROPERTY | PROPERTY.ARRAY |
    ##                                 PROPERTY.REFERENCE)*)>
    ##<!ATTLIST INSTANCE
    ##	%ClassName;>
    
        WBEM.check_node(tt, "INSTANCE", ["CLASSNAME"],
                   ["QUALIFIER", "PROPERTY", "PROPERTY.ARRAY",
                    "PROPERTY.REFERENCE"])

        ## XXX: This does not enforce ordering constraint
        
        ## XXX: This does not enforce the constraint that there be only
        ## one PROPERTY or PROPERTY.ARRAY.
        
        ## TODO: Parse instance qualifiers
        qualifiers = {}
        props = WBEM.list_of_matching(tt, ["PROPERTY.REFERENCE", "PROPERTY", "PROPERTY.ARRAY"])
        
        obj = CIMInstance.new(WBEM.attrs(tt)["CLASSNAME"])
        obj.qualifiers = qualifiers
        props.each { |p| obj[p.name] = p }
        return obj
    end

    def WBEM.parse_qualifier(tt)
    ## <!ELEMENT QUALIFIER (VALUE | VALUE.ARRAY)>
    ## <!ATTLIST QUALIFIER %CIMName;
    ##      %CIMType;              #REQUIRED
    ##      %Propagated;
    ##      %QualifierFlavor;>

        WBEM.check_node(tt, "QUALIFIER", ["NAME", "TYPE"],
                   ["OVERRIDABLE", "TOSUBCLASS", "TOINSTANCE",
                    "TRANSLATABLE", "PROPAGATED"],
                   ["VALUE", "VALUE.ARRAY"])

        a = WBEM.attrs(tt)

        q = CIMQualifier.new(a["NAME"], WBEM.unpack_value(tt))

        ## TODO: Lift this out?
        ["OVERRIDABLE", "TOSUBCLASS", "TOINSTANCE", "TRANSLATABLE", "PROPAGATED"].each do |i|
            rv = a[i]
            unless ["true", "false", nil].include?(rv)
                raise ParseError, "invalid value #{rv} for #{i} on #{WBEM.name(tt)}"
            end
            if rv == "true"
                rv = true
            elsif rv == "false"
                rv = false
            end
            q.method("#{i.downcase()}=").call(rv)
        end
        return q
    end

    def WBEM.parse_property(tt)
#     """Parse PROPERTY into a CIMProperty object.

#     VAL is just the pcdata of the enclosed VALUE node."""
    
    ## <!ELEMENT PROPERTY (QUALIFIER*, VALUE?)>
    ## <!ATTLIST PROPERTY %CIMName;
    ##      %ClassOrigin;
    ##      %Propagated;
    ##      %CIMType;              #REQUIRED>

    ## TODO: Parse this into NAME, VALUE, where the value contains
    ## magic fields for the qualifiers and the propagated flag.
    
        WBEM.check_node(tt, "PROPERTY", ["TYPE", "NAME"],
                   ["NAME", "CLASSORIGIN", "PROPAGATED"],
                   ["QUALIFIER", "VALUE"])

        quals = {}
        WBEM.list_of_matching(tt, ["QUALIFIER"]).each { |q| quals[q.name] = q }
        val = WBEM.unpack_value(tt)
        a = WBEM.attrs(tt)

        return CIMProperty.new(a["NAME"], val, a["TYPE"],
                               a["CLASSORIGIN"],
                               WBEM.unpack_boolean(a["PROPAGATED"]),
                               nil, 
                               quals)

    end

    def WBEM.parse_property_array(tt)
#     """
#     <!ELEMENT PROPERTY.ARRAY (QUALIFIER*, VALUE.ARRAY?)>
#     <!ATTLIST PROPERTY.ARRAY %CIMName;
#          %CIMType;              #REQUIRED
#          %ArraySize;
#          %ClassOrigin;
#          %Propagated;>
#     """

        WBEM.check_node(tt, "PROPERTY.ARRAY", ["NAME", "TYPE"],
                   ["REFERENCECLASS", "CLASSORIGIN", "PROPAGATED",
                    "ARRAYSIZE"],
                   ["QUALIFIER", "VALUE.ARRAY"])

        qualifiers = WBEM.byname(WBEM.list_of_matching(tt, ["QUALIFIER"]))
        values = WBEM.unpack_value(tt)
        a = WBEM.attrs(tt)
        return CIMProperty.new(a["NAME"], values, a["TYPE"], 
                              a["CLASSORIGIN"],
                              nil, true, qualifiers)
    ## TODO qualifiers, other attributes
    end

    def WBEM.parse_property_reference(tt)
#     """
#     <!ELEMENT PROPERTY.REFERENCE (QUALIFIER*, (VALUE.REFERENCE)?)>
#     <!ATTLIST PROPERTY.REFERENCE
# 	%CIMName; 
# 	%ReferenceClass; 
# 	%ClassOrigin; 
# 	%Propagated;>
#     """
    
        WBEM.check_node(tt, "PROPERTY.REFERENCE", ["NAME"],
                   ["REFERENCECLASS", "CLASSORIGIN", "PROPAGATED"])
        
        value = WBEM.list_of_matching(tt, ["VALUE.REFERENCE"])
        
        if value.nil? or value.length == 0
            value = nil
        elsif value.length == 1
            value = value[0]
        else
            raise ParseError, "Too many VALUE.REFERENCE elements."
        end
    
        attributes = WBEM.attrs(tt)
        pref = CIMProperty.new(attributes["NAME"], value, "reference")

        WBEM.list_of_matching(tt, ["QUALIFIER"]).each { |q| pref.qualifiers[q.name] = q}
        if attributes.has_key?("REFERENCECLASS")
            pref.reference_class = attributes["REFERENCECLASS"]
        end
        if attributes.has_key?("CLASSORIGIN")
            pref.class_origin = attributes["CLASSORIGIN"]
        end
        if attributes.has_key?("PROPAGATED")
            pref.propagated = attributes["PROPAGATED"]
        end
        return pref
    end

    def WBEM.parse_method(tt)
#     """
#     <!ELEMENT METHOD (QUALIFIER*, (PARAMETER | PARAMETER.REFERENCE |
#                                    PARAMETER.ARRAY | PARAMETER.REFARRAY)*)>
#     <!ATTLIST METHOD %CIMName;
#          %CIMType;              #IMPLIED
#          %ClassOrigin;
#          %Propagated;>
#     """

        WBEM.check_node(tt, "METHOD", ["NAME"],
                   ["TYPE", "CLASSORIGIN", "PROPAGATED"],
                   ["QUALIFIER", "PARAMETER", "PARAMETER.REFERENCE",
                    "PARAMETER.ARRAY", "PARAMETER.REFARRAY"])
        
        qualifiers = WBEM.byname(WBEM.list_of_matching(tt, ["QUALIFIER"]))
        
        parameters = WBEM.byname(WBEM.list_of_matching(tt, ["PARAMETER",
                                                            "PARAMETER.REFERENCE",
                                                            "PARAMETER.ARRAY",
                                                            "PARAMETER.REFARRAY",]))
        a = WBEM.attrs(tt)
        return CIMMethod.new(a["NAME"], 
                             a["TYPE"],
                             parameters, 
                             a["CLASSORIGIN"],
                             unpack_boolean(a["PROPAGATED"]),
                             qualifiers)
    end

    def WBEM.parse_parameter(tt)
#     """
#     <!ELEMENT PARAMETER (QUALIFIER*)>
#     <!ATTLIST PARAMETER 
#          %CIMName;
#          %CIMType;              #REQUIRED>
#     """
    
        WBEM.check_node(tt, "PARAMETER", ["NAME", "TYPE"], [])

        quals = {}
        list_of_matching(tt, ['QUALIFIER']).each {|q| quals[q.name] = q }

        a = WBEM.attrs(tt)

        return CIMParameter.new(a["NAME"], a["TYPE"], nil, nil, nil, quals)
    end

    def WBEM.parse_parameter_reference(tt)
#     """
#     <!ELEMENT PARAMETER.REFERENCE (QUALIFIER*)>
#     <!ATTLIST PARAMETER.REFERENCE 
#          %CIMName;
#          %ReferenceClass;>
#     """
    
        WBEM.check_node(tt, "PARAMETER.REFERENCE", ["NAME"], ["REFERENCECLASS"])

        quals = {}
        list_of_matching(tt, ['QUALIFIER']).each {|q| quals[q.name] = q }

        a = WBEM.attrs(tt)

        return CIMParameter.new(a["NAME"], "reference", a['REFERENCECLASS'], nil, nil, quals)
    end

    def WBEM.parse_parameter_array(tt)
#     """
#     <!ELEMENT PARAMETER.ARRAY (QUALIFIER*)>
#     <!ATTLIST PARAMETER.ARRAY 
#          %CIMName;
#          %CIMType;              #REQUIRED
#          %ArraySize;>
#     """
    
        WBEM.check_node(tt, "PARAMETER.ARRAY", ["NAME", "TYPE"], ["ARRAYSIZE"])

        quals = {}
        list_of_matching(tt, ['QUALIFIER']).each {|q| quals[q.name] = q }

        a = WBEM.attrs(tt)
        array_size = a["ARRAYSIZE"]
        array_size = array_size.to_i unless array_size.nil?

        return CIMParameter.new(a["NAME"], a["TYPE"], nil, true, array_size, quals)
    end

    def WBEM.parse_parameter_refarray(tt)
#     """
#     <!ELEMENT PARAMETER.REFARRAY (QUALIFIER*)>
#     <!ATTLIST PARAMETER.REFARRAY 
#          %CIMName;
#          %ReferenceClass;
#          %ArraySize;>
#     """
    
        WBEM.check_node(tt, "PARAMETER.REFARRAY", ["NAME"], ["REFERENCECLASS", "ARRAYSIZE"])

        quals = {}
        list_of_matching(tt, ['QUALIFIER']).each {|q| quals[q.name] = q }

        a = WBEM.attrs(tt)
        array_size = a["ARRAYSIZE"]
        array_size = array_size.to_i unless array_size.nil?

        return CIMParameter.new(a["NAME"], "reference", a["REFERENCECLASS"], 
                                true, array_size, quals)
    end

#
# Message elements
#
    def WBEM.parse_message(tt)
#     """
#     <!ELEMENT MESSAGE (SIMPLEREQ | MULTIREQ | SIMPLERSP | MULTIRSP)>
#     <!ATTLIST MESSAGE
# 	ID CDATA #REQUIRED
# 	PROTOCOLVERSION CDATA #REQUIRED>
#     """
        WBEM.check_node(tt, "MESSAGE", ["ID", "PROTOCOLVERSION"])
        messages = WBEM.one_child(
                             tt, ["SIMPLEREQ", "MULTIREQ", "SIMPLERSP", "MULTIRSP"])
        unless messages[0].is_a?(Array)
            # make single and multi forms consistent
            messages = [messages]
        end
        return [WBEM.name(tt), WBEM.attrs(tt), messages]
    end

    def WBEM.parse_multireq(tt)
        raise ParseError, "MULTIREQ parser not implemented"
    end

    def WBEM.parse_multiexpreq(tt)
        raise ParseError, "MULTIEXPREQ parser not implemented"
    end

    def WBEM.parse_simplereq(tt)
#     """
#     <!ELEMENT SIMPLEREQ (IMETHODCALL | METHODCALL)>
#     """

        WBEM.check_node(tt, "SIMPLEREQ")
        child = WBEM.one_child(tt, ["IMETHODCALL", "METHODCALL"])
        return [WBEM.kids(tt)[0][0], child]
    end

    def WBEM.parse_simpleexpreq(tt)
        raise ParseError, "SIMPLEEXPREQ parser not implemented"
    end

    def WBEM.parse_imethodcall(tt)
#     """
#     <!ELEMENT IMETHODCALL (LOCALNAMESPACEPATH, IPARAMVALUE*)>
#     <!ATTLIST IMETHODCALL
# 	%CIMName;>
#     """

        WBEM.check_node(tt, "IMETHODCALL", ["NAME"])
        if ((k = WBEM.kids(tt)).length < 1)
            raise ParseError, "Expecting LOCALNAMESPACEPATH, got nothing"
        end
        localnspath = WBEM.parse_localnamespacepath(k[0])
        params = k[1..-1].collect { |x| WBEM.parse_iparamvalue(x) }
        return [WBEM.name(tt), WBEM.attrs(tt), localnspath, params]
    end

    def WBEM.parse_methodcall(tt)
        raise ParseError, "METHODCALL parser not implemented"
    end

    def WBEM.parse_expmethodcall(tt)
        raise ParseError, "EXPMETHODCALL parser not implemented"
    end

    def WBEM.parse_paramvalue(tt)
    ## <!ELEMENT PARAMVALUE (VALUE | VALUE.REFERENCE | VALUE.ARRAY |
    ##                       VALUE.REFARRAY)?>
    ## <!ATTLIST PARAMVALUE
    ##   %CIMName;
    ##   %ParamType;  #IMPLIED>

    ## Version 2.1.1 of the DTD lacks the %ParamType attribute but it
    ## is present in version 2.2.  Make it optional to be backwards
    ## compatible.

        WBEM.check_node(tt, "PARAMVALUE", ["NAME"], ["PARAMTYPE"])

        child = WBEM.optional_child(tt,
                               ["VALUE", "VALUE.REFERENCE", "VALUE.ARRAY",
                                "VALUE.REFARRAY",])

        if WBEM.attrs(tt).has_key?("PARAMTYPE")
            paramtype = WBEM.attrs(tt)["PARAMTYPE"]
        else
            paramtype = nil
        end
        return [WBEM.attrs(tt)["NAME"], paramtype, child]
    end

    def WBEM.parse_iparamvalue(tt)
    ## <!ELEMENT IPARAMVALUE (VALUE | VALUE.ARRAY | VALUE.REFERENCE |
    ##                       INSTANCENAME | CLASSNAME | QUALIFIER.DECLARATION |
    ##                       CLASS | INSTANCE | VALUE.NAMEDINSTANCE)?>
    ## <!ATTLIST IPARAMVALUE %CIMName;>

#    """Returns NAME, VALUE pair."""
    
        WBEM.check_node(tt, "IPARAMVALUE", ["NAME"], [])
        
        child = WBEM.optional_child(tt, 
                               ["VALUE", "VALUE.ARRAY", "VALUE.REFERENCE",
                                "INSTANCENAME", "CLASSNAME",
                                "QUALIFIER.DECLARATION", "CLASS", "INSTANCE",
                                "VALUE.NAMEDINSTANCE"])
        ## TODO: WBEM.unpack_value() where appropriate.
        return [WBEM.attrs(tt)["NAME"],  child ]
    end

    def WBEM.parse_expparamvalue(tt)
        raise ParseError, "EXPPARAMVALUE parser not implemented"
    end

    def WBEM.parse_multirsp(tt)
        raise ParseError, "MULTIRSP parser not implemented"
    end

    def WBEM.parse_multiexprsp(tt)
        raise ParseError, "MULTIEXPRSP parser not implemented"
    end

    def WBEM.parse_simplersp(tt)
    ## <!ELEMENT SIMPLERSP (METHODRESPONSE | IMETHODRESPONSE)>
        WBEM.check_node(tt, "SIMPLERSP", [], [])
        child = WBEM.one_child(tt, ["METHODRESPONSE", "IMETHODRESPONSE"])
        return [WBEM.name(tt), WBEM.attrs(tt), child]
    end

    def WBEM.parse_simpleexprsp(tt)
        raise ParseError, "SIMPLEEXPRSP parser not implemented"
    end

    def WBEM.parse_methodresponse(tt)
    ## <!ELEMENT METHODRESPONSE (ERROR | (RETURNVALUE?, PARAMVALUE*))>
    ## <!ATTLIST METHODRESPONSE
    ##    %CIMName;>

        WBEM.check_node(tt, "METHODRESPONSE", ["NAME"], [])

        return [WBEM.name(tt), WBEM.attrs(tt), WBEM.list_of_various(tt, ["ERROR", "RETURNVALUE",
                                                          "PARAMVALUE"])]
    end

    def WBEM.parse_expmethodresponse(tt)
        raise ParseError, "EXPMETHODRESPONSE parser not implemented"
    end

    def WBEM.parse_imethodresponse(tt)
    ## <!ELEMENT IMETHODRESPONSE (ERROR | IRETURNVALUE?)>
    ## <!ATTLIST IMETHODRESPONSE %CIMName;>
        WBEM.check_node(tt, "IMETHODRESPONSE", ["NAME"], [])
        return [WBEM.name(tt), WBEM.attrs(tt), WBEM.optional_child(tt, ["ERROR", "IRETURNVALUE"])]
    end

    def WBEM.parse_error(tt)
#     """
#     <!ELEMENT ERROR EMPTY>
#     <!ATTLIST ERROR
# 	CODE CDATA #REQUIRED
# 	DESCRIPTION CDATA #IMPLIED>
#     """

    ## TODO: Return a CIMError object, not a tuple
        WBEM.check_node(tt, "ERROR", ["CODE"], ["DESCRIPTION"])
        return [WBEM.name(tt), WBEM.attrs(tt), nil]
    end

    def WBEM.parse_returnvalue(tt)
    ## <!ELEMENT RETURNVALUE (VALUE | VALUE.ARRAY | VALUE.REFERENCE |
    ##                        VALUE.REFARRAY)>
    ## <!ATTLIST RETURNVALUE %ParamType;       #IMPLIED>

    ## Version 2.1.1 of the DTD lacks the %ParamType attribute but it
    ## is present in version 2.2.  Make it optional to be backwards
    ## compatible.

        WBEM.check_node(tt, "RETURNVALUE", [], ["PARAMTYPE"])
        return name[(tt), WBEM.attrs(tt), WBEM.one_child(tt, ["VALUE", "VALUE.ARRAY",
                                                    "VALUE.REFERENCE",
                                                    "VALUE.REFARRAY"])]
    end

    def WBEM.parse_ireturnvalue(tt)
    ## <!ELEMENT IRETURNVALUE (CLASSNAME* | INSTANCENAME* | VALUE* |
    ##                         VALUE.OBJECTWITHPATH* |
    ##                         VALUE.OBJECTWITHLOCALPATH* | VALUE.OBJECT* |
    ##                         OBJECTPATH* | QUALIFIER.DECLARATION* |
    ##                         VALUE.ARRAY? | VALUE.REFERENCE? | CLASS* |
    ##                         INSTANCE* | VALUE.NAMEDINSTANCE*)>

        WBEM.check_node(tt, "IRETURNVALUE", [], [])

        # XXX: doesn"t prohibit the case of only one VALUE.ARRAY or
        # VALUE.REFERENCE.  But why is that required?  Why can it return
        # multiple VALUEs but not multiple VALUE.REFERENCEs?
        
        values = WBEM.list_of_same(tt, ["CLASSNAME", "INSTANCENAME",
                                   "VALUE", "VALUE.OBJECTWITHPATH", "VALUE.OBJECT",
                                   "OBJECTPATH", "QUALIFIER.DECLARATION",
                                   "VALUE.ARRAY", "VALUE.REFERENCE",
                                   "CLASS", "INSTANCE",
                                   "VALUE.NAMEDINSTANCE",])
    ## TODO: Call WBEM.unpack_value if appropriate
        return [WBEM.name(tt), WBEM.attrs(tt), values]
    end

#
# Object naming and locating elements
#

    class MethodHelper
        
    end
    def WBEM.parse_any(tt)
#    """Parse any fragment of XML."""
        h = MethodHelper.new
        nodename = WBEM.name(tt).downcase().tr(".", "_")
        fn_name = "parse_" + nodename
        method = self.method(fn_name)
        unless method
            raise ParseError, "no parser #{fn_name} for node type #{WBEM.name(tt)}" 
        end
        return method.call(tt)
    end

    def WBEM.unpack_value(tt)
#     """Find VALUE or VALUE.ARRAY under TT and convert to a Python value.

#     Looks at the TYPE of the node to work out how to decode it.
#     Handles nodes with no value (e.g. in CLASS.)
#     """
        val = WBEM.list_of_matching(tt, ["VALUE", "VALUE.ARRAY"])

        ## TODO: Handle VALUE.REFERENCE, VALUE.REFARRAY

        valtype = WBEM.attrs(tt)["TYPE"]
        raw_val = WBEM.list_of_matching(tt, ["VALUE", "VALUE.ARRAY"])
        if raw_val.empty?
            return nil
        elsif raw_val.length > 1
            raise ParseError, "more than one VALUE or VALUE.ARRAY under #{WBEM.name(tt)}"
        end
        raw_val = raw_val[0]
    
        if raw_val.is_a?(Array)
            return raw_val.collect { |x| tocimobj(valtype, x) }
        elif raw_val.empty?
            return nil
        else
            return WBEM.tocimobj(valtype, raw_val)
        end
    end

    def WBEM.unpack_boolean(p)
#    """Unpack a boolean, represented as "TRUE" or "FALSE" in CIM."""
        if p.nil?
            return nil
        end
        ## CIM-XML says "These values MUST be treated as case-insensitive"
        ## (even though the XML definition requires them to be lowercase.)
    
        p = p.strip().downcase()                   # ignore space
        if p == "true"
            return true
        elsif p == "false"
            return false
        elsif p == ""
            return nil
        else
            raise ParseError, "invalid boolean #{p}"
        end
    end
end
