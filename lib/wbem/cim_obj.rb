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

require "wbem/cim_types"
require "wbem/cim_xml"
require "date"

#"""
#Representations of CIM Objects.
#
#In general we try to map CIM objects directly into standard Ruby types,
#except when that is not possible or would be ambiguous.  For example,
#CIM Class names are simply strings, but a ClassPath is
#represented as a special object.
#
#These objects can also be mapped back into XML, by the toxml() method
#which returns a string.
#"""

module WBEM

    class NocaseHash < Hash
        
        def initialize(initial_values = {})
            super()
            initial_values = initial_values.to_a if initial_values.is_a?(Hash)
            if initial_values.is_a?(Array)
                initial_values.each do |item|
                    self[item[0]] = item[1] if item.is_a?(Array)
                end
            end
        end

        def get_key(key)
            key.is_a?(String) ? key.downcase : key
        end
        def [](key)
            v = super(get_key(key))
            v[1] unless v.nil?
        end
        def []=(key, value)
            unless key.is_a?(String)
                raise IndexError, "Key must be a String"
            end
            super(get_key(key),[key, value])
        end
        alias rawkeys keys
        alias rawvalues values
        alias rawarray to_a
        def keys
            rawvalues.collect { |v| v[0] }
        end
        def values
            super.collect { |v| v[1] }
        end
        def to_a
            super.collect { |k,v| [v[0], v[1]] }
        end
        def each(&block)
            to_a.each(&block)
        end
        def sort 
            rawarray.sort.collect { |k,v| [v[0], v[1]] }
        end
        def ==(other)
            self.each do |key, value|
                return false unless (other.include?(key) and other[key] == value)
            end
            return self.length == other.length
        end

        def delete(key)
            super(get_key(key))
        end
        def fetch(key)
            super(get_key(key))[1]
        end
        def has_key?(key)
            super(get_key(key))
        end
        def include?(key)
            super(get_key(key))
        end
        def update(otherHash)
            otherHash.to_a.each { |key, value| self[key] = value }
        end
        def clone
            return NocaseHash.new(self)
        end
        alias copy clone
    end

    class XMLObject
        #"""Base class for objects that produce cim_xml document fragments."""

        def toxml
            #"""Return the XML string representation of ourselves."""
            ret = ""
            self.tocimxml().write(ret)
            return ret
        end
        def hash
            self.toxml().hash
        end
        # probably not the best equality method, as trivial
        # differences such as attribute order will affect the results,
        # but better than the default eql? method defined in object --
        # subclasses can define this in a better way
        def eql?(other)
            (self.toxml == other.toxml)
        end

        def nilcmp(obj1, obj2)
            cmpname(obj1, obj2, false)
        end

        def cmpname(name1, name2, downcase_strings = true)
            #"""Compare to CIM names.  The comparison is done
            #case-insensitvely, and one or both of the names may be None."""

            if name1.nil? and name2.nil?
                return 0
            end
            unless (name1 || name2)
                return 0
            end

            if name1.nil?
                return -1
            end

            if name2.nil?
                return 1
            end
            if (downcase_strings)
                name1.downcase <=> name2.downcase
            elsif (name2.is_a?(Boolean))
                (name2 <=> name1)*-1
            elsif (!name1.methods.include?("<=>"))
                (name1 == name2) ? 0 : 1
            elsif ((name1.nil? || name1 == false) && 
                   (name2.nil? || name2 == false))
                return 0
            else
                name1 <=> name2
            end
        end
    end

    class CIMClassName < XMLObject

        attr_writer :classname, :host, :namespace
        attr_reader :classname, :host, :namespace

        def initialize(classname, host = nil, namespace = nil)
            unless classname.kind_of?(String)
                raise TypeError, "classname argument must be a string"
            end
            
            # TODO: There are some odd restrictions on what a CIM
            # classname can look like (i.e must start with a
            # non-underscore and only one underscore per classname).
            @classname=classname
            @host = host
            @namespace = namespace
        end

        def clone
            return CIMClassName.new(@classname, @host, @namespace)
        end

        def eql?(other)
            (self <=> other) == 0
        end
        def hash
            self.host.hash + self.localnamespacepath.hash + self.classname.hash + self.instancename.hash
        end
        def <=>(other)
            if equal?(other)
                return 0
            elsif (!other.kind_of?(CIMClassName))
                return 1
            end
            ret_val = cmpname(self.classname, other.classname) 
            ret_val = cmpname(self.host, other.host) if (ret_val == 0)
            ret_val = nilcmp(self.namespace, other.namespace) if (ret_val == 0)
            ret_val
        end

        def to_s
            s = ''

            unless self.host.nil?
                s += '//%s/' % self.host
            end
            unless self.namespace.nil?
                s += '%s:' % self.namespace
            end
            s += self.classname
            return s
        end

        def tocimxml
            classnamexml = CLASSNAME.new(self.classname)

            unless self.namespace.nil?

                localnsp = LOCALNAMESPACEPATH.new(
                        self.namespace.split('/').collect { |ns| NAMESPACE.new(ns)})

                unless self.host.nil?

                    # Classname + namespace + host = CLASSPATH

                    return CLASSPATH.new(NAMESPACEPATH.new(HOST.new(self.host), 
                                                           localnsp), 
                                         classnamexml)
                end
                # Classname + namespace = LOCALCLASSPATH
                return LOCALCLASSPATH.new(localnsp, classnamexml)
            end
            # Just classname = CLASSNAME
            return classnamexml
        end
        

    end

    class CIMProperty < XMLObject
        include Comparable
        #"""A property of a CIMInstance.

        #Property objects represent both properties on particular instances,
        #and the property defined in a class.  In the first case, the property
        #will have a Value and in the second it will not.

        #The property may hold an array value, in which case it is encoded
        #in XML to PROPERTY.ARRAY containing VALUE.ARRAY.
        
        #Properties holding references are handled specially as
        #CIMPropertyReference."""
        
        attr_writer :name, :prop_type, :class_origin, :propagated, :value, :is_array, :reference_class, :array_size
        attr_reader :name, :prop_type, :class_origin, :propagated, :value, :is_array, :qualifiers, :reference_class, :array_size

        def initialize(name, value, type=nil, class_origin=nil, propagated=nil,
                       is_array = false, qualifiers = {},
                       reference_class = nil, array_size = nil)
            #"""Construct a new CIMProperty
            #Either the type or the value must be given.  If the value is not
            #given, it is left as nil.  If the type is not given, it is implied
            #from the value."""
            unless name.kind_of?(String)
                raise TypeError, "name argument must be a string"
            end
            unless (class_origin.nil? or class_origin.kind_of?(String))
                raise TypeError, "class_origin argument must be a string"
            end

            @name = name
            @value = value
            @prop_type = type
            @class_origin = class_origin
            @propagated = propagated
            @qualifiers = NocaseHash.new(qualifiers)
            @is_array = is_array
            @array_size = array_size
            @reference_class = reference_class

            if type.nil?
                if (value.nil?)
                    raise TypeError, "value argument must not be nil if type is missing"
                end
                if (value.is_a?(Array))
                    if (value.empty?)
                        raise TypeError, "Empty property array #{name} must have a type"
                    end
                    @is_array = true
                    @prop_type = WBEM.cimtype(value[0])
                else
                    @prop_type = WBEM.cimtype(value)
                end
            else
                @is_array = true if (value.is_a?(Array))
                @prop_type = type
            end
            @value = value
        end
        
        def qualifiers=(qualifiers)
            @qualifiers = NocaseHash.new(qualifiers)
        end

        def clone
            return CIMProperty.new(self.name,
                                   self.value,
                                   self.prop_type,
                                   self.class_origin,
                                   self.propagated,
                                   self.is_array,
                                   self.qualifiers,
                                   self.reference_class,
                                   self.array_size)
        end

        def to_s
            r = "#{self.class}(name=#{self.name}, type=#{self.prop_type}"
            r += ", class_origin=#{self.class_origin}" if self.class_origin
            r += ", propagated=#{self.propagated}" if self.propagated
            r += ", value=#{self.value}" if self.value
            r += ", qualifiers=#{self.qualifiers}" if self.qualifiers
            r += ", is_array=#{self.is_array}"
            r += ")"
        end

        def <=>(other)
            if equal?(other)
                ret_val = 0
            elsif (!other.kind_of?(CIMProperty ))
                ret_val = 1
            else
                ret_val = cmpname(self.name, other.name)
                ret_val = nilcmp(self.value, other.value) if (ret_val == 0)
                ret_val = nilcmp(self.prop_type, other.prop_type) if (ret_val == 0)
                ret_val = nilcmp(self.class_origin, other.class_origin) if (ret_val == 0)
                ret_val = nilcmp(self.propagated, other.propagated) if (ret_val == 0)
                ret_val = nilcmp(self.qualifiers, other.qualifiers) if (ret_val == 0)
                ret_val = nilcmp(self.is_array, other.is_array) if (ret_val == 0)
                ret_val = cmpname(self.reference_class, other.reference_class) if (ret_val == 0)
            end
            ret_val
        end

        def tocimxml
            if self.is_array
                return PROPERTY_ARRAY.new(self.name,
                                          self.prop_type,
                                          WBEM.tocimxml(self.value),
                                          self.array_size,
                                          self.class_origin,
                                          self.propagated,
                                          self.qualifiers.values.collect { |q| q.tocimxml})
            elsif self.prop_type == 'reference'
                return PROPERTY_REFERENCE.new(self.name,
                                              WBEM.tocimxml(self.value, true),
                                              self.reference_class,
                                              self.class_origin,
                                              self.propagated,
                                              self.qualifiers.values.collect { |q| q.tocimxml})
            else
                return PROPERTY.new(self.name,
                                    self.prop_type,
                                    WBEM.tocimxml(self.value),
                                    self.class_origin,
                                    self.propagated,
                                    self.qualifiers.values.collect { |q| q.tocimxml})
            end
        end
    end

    class CIMInstanceName < XMLObject
        include Comparable
        #"""Name (keys) identifying an instance.

        #This may be treated as a hash to retrieve the keys."""
        # qualifiers removed?
        attr_reader :classname, :keybindings, :host, :namespace
        attr_writer :classname, :keybindings, :host, :namespace
        def initialize(classname, keybindings = {}, host = nil, namespace = nil)
            @classname = classname
            @keybindings = NocaseHash.new(keybindings)
            @host = host
            @namespace = namespace
        end

        def clone
            return CIMInstanceName.new(@classname, @keybindings, @host, @namespace)
        end

        def <=>(other)
            if equal?(other)
                ret_val = 0
            elsif (!other.kind_of?(CIMInstanceName ))
                ret_val =  1
            else
                ## TODO: Allow for the type to be null as long as the values
                ## are the same and non-null?
                ret_val = cmpname(self.classname, other.classname)
                ret_val = nilcmp(self.keybindings, other.keybindings) if (ret_val == 0)
                ret_val = cmpname(self.host, other.host) if (ret_val == 0)
                ret_val = cmpname(self.namespace, other.namespace) if (ret_val == 0)
            end
            ret_val
        end

        def keybindings=(keybindings)
            @keybindings = NocaseHash.new(keybindings)
        end

        def to_s
            s = ''

            unless self.host.nil?
                s += '//%s/' % self.host
            end
            unless self.namespace.nil?
                s += '%s:' % self.namespace
            end
            s += '%s.' % self.classname

            self.keybindings.to_a.each do |key, value|
                
                s += "#{key}="
                
                if value.kind_of?(Integer)
                    s += value.to_s
                else
                    s += '"%s"' % value
                end
                s += ","
            end
            return s[0..-2]
        end
        # A whole bunch of dictionary methods that map to the equivalent
        # operation on self.keybindings.
        
        def fetch(key) 
            return self.keybindings.fetch(key)
        end
        def [](key) 
            return self.keybindings[key]
        end
        def []=(key, value) 
            return self.keybindings[key] = value
        end
        def delete(key) 
            self.keybindings.delete(key)
        end
        def length
            return self.keybindings.length 
        end
        def has_key?(key)
            return self.keybindings.has_key?(key)
        end
        def keys
            return self.keybindings.keys()
        end
        def values
            return self.keybindings.values()
        end
        def to_a
            return self.keybindings.to_a()
        end
        
        def tocimxml
            # Generate an XML representation of the instance classname and
            # keybindings.
            
            if (self.keybindings.kind_of?(String))
                # Class with single key string property
                instancename_xml = INSTANCENAME.new(self.classname,
                                                    KEYVALUE.new(self.keybindings, "string"))

            elsif (self.keybindings.kind_of?(Integer))
            # Class with single key numeric property
                instancename_xml =  INSTANCENAME.new(self.classname,
                                                     KEYVALUE.new(self.keybindings.to_s, "numeric"))

            elsif (self.keybindings.kind_of?(NocaseHash))
            # Dictionary of keybindings
                kbs = []
                self.keybindings.to_a.each do |kb|
                    # Keybindings can be integers, booleans, strings or
                    # value references.                
                    if (kb[1].methods.include?("tocimxml"))
                        kbs << KEYBINDING.new(kb[0], VALUE_REFERENCE.new(kb[1].tocimxml()))
                        next
                    end
                    
                    if (kb[1].kind_of?(Integer) or kb[1].kind_of?(CIMInt))
                        _type = "numeric"
                        value = kb[1].to_s
                    elsif (kb[1] == true or kb[1] == false)
                        _type = "boolean"
                        if kb[1]
                            value = "TRUE"
                        else
                            value = "FALSE"
                        end
                    elsif (kb[1].kind_of?(String )) # unicode?
                        _type = "string"
                        value = kb[1]
                    else
                        raise TypeError, "Invalid keybinding type #{kb[1]}(#{kb[1].class}) for keybinding #{kb[0]}"
                    end
                    
                    kbs << KEYBINDING.new(kb[0], KEYVALUE.new(value, _type))
                    
                end
                instancename_xml = INSTANCENAME.new(self.classname, kbs)

            else
                # Value reference
            
                instancename_xml = INSTANCENAME.new(self.classname, self.keybindings.nil? ? nil : VALUE_REFERENCE.new(self.keybindings.tocimxml()))
            end
            # Instance name plus namespace = LOCALINSTANCEPATH

            if (self.host.nil? && !self.namespace.nil?)
                return LOCALINSTANCEPATH.new(
                    LOCALNAMESPACEPATH.new(
                        self.namespace.split('/').collect { |ns| NAMESPACE.new(ns)}),
                        instancename_xml)
            end

            # Instance name plus host and namespace = INSTANCEPATH
            if (!self.host.nil? && !self.namespace.nil?)
                return INSTANCEPATH.new(
                    NAMESPACEPATH.new(
                        HOST.new(self.host),
                        LOCALNAMESPACEPATH.new(
                            self.namespace.split('/').collect { |ns| NAMESPACE.new(ns)})),
                    instancename_xml)
            end

            # Just a regular INSTANCENAME
            return instancename_xml
        end
    end

    class CIMInstance < XMLObject
        include Comparable
        #"""Instance of a CIM Object.
        
        #Has a classname (string), and named arrays of properties and qualifiers.
        
        #The properties is indexed by name and points to CIMProperty
        #instances."""
        
        attr_reader :classname, :properties, :qualifiers, :path
        attr_writer :classname, :path
        def initialize(classname, properties = {}, qualifiers = {},
                       path = nil)
            #"""Create CIMInstance.
            
            @classname = classname
            @qualifiers = NocaseHash.new(qualifiers)
            @path = path
            @properties = NocaseHash.new
            properties.each do |k, v|
                self[k]=v
            end
        end
        
        def clone
            result = CIMInstance.new(@classname, @properties, @qualifiers)
            result.path = @path.clone unless @path.nil?
            result
        end

        def properties=(properties)
            @properties = NocaseHash.new
            properties.each do |k, v|
                self[k]=v
            end
        end

        def qualifiers=(qualifiers)
            @qualifiers = NocaseHash.new(qualifiers)
        end

        def <=>(other)
            if equal?(other)
                return 0
            elsif (!other.kind_of?(CIMInstance))
                return 1
            end
            ## TODO: Allow for the type to be null as long as the values
            ## are the same and non-null?
            ret_val = cmpname(self.classname, other.classname)
            ret_val = nilcmp(self.path, other.path) if (ret_val == 0)
            ret_val = nilcmp(self.properties, other.properties) if (ret_val == 0)
            ret_val = nilcmp(self.qualifiers, other.qualifiers) if (ret_val == 0)
            ret_val
        end
        
        def to_s
            # Don't show all the properties and qualifiers because they're
            # just too big
            "#{self.class}(classname=#{self.classname} ...)"
        end
        
        # A whole bunch of dictionary methods that map to the equivalent
        # operation on self.properties.
        
        def fetch(key) 
            return self.properties.fetch(key)
        end
        def [](key) 
            ret = self.properties[key]
            ret = ret.value unless ret.nil?
        end
        def delete(key) 
            self.properties.delete(key)
        end
        def length
            self.properties.length 
        end
        def has_key?(key)
            self.properties.has_key?(key)
        end
        def keys
            self.properties.keys()
        end
        def values
            self.properties.values.collect { |v| v.value }
        end
        def to_a
            self.properties.to_a.collect { |k, v| [k, v.value] }
        end
        #def iterkeys(self): return self.properties.iterkeys()
        #def itervalues(self): return self.properties.itervalues()
        #def iteritems(self): return self.properties.iteritems()

        def []=(key, value) 
            
            # Don't let anyone set integer or float values.  You must use
            # a subclass from the cim_type module.
            
            unless (value.is_a?(CIMProperty))
                unless WBEM.valid_cimtype?(value)
                    raise TypeError, "Must use a CIM type assigning numeric values."
                end
                value = CIMProperty.new(key, value)
            end
            self.properties[key] = value
        end
        
        def tocimxml
            props = []
            self.properties.each do |key, prop|
                if (prop.is_a?(CIMProperty))
                    props << prop
                else
                    props << CIMProperty.new(key, prop)
                end
            end
            instance_xml = INSTANCE.new(self.classname, 
                                        props.collect { |p| p.tocimxml}, 
                                        self.qualifiers.values.collect { |q| q.tocimxml})
            if self.path.nil?
                return instance_xml
            end
            return VALUE_NAMEDINSTANCE.new(self.path.tocimxml,
                                           instance_xml)
        end
    end

    class CIMClass < XMLObject
        #"""Class, including a description of properties, methods and qualifiers.
        #superclass may be None."""
        include Comparable
        attr_reader :classname, :properties, :qualifiers, :cim_methods, :superclass
        attr_writer :classname, :superclass
        def initialize(classname, properties = {}, qualifiers = {},
                       methods = {}, superclass = nil)
            unless (classname.kind_of?(String))
                raise TypeError, "classname must be a String"
            end
            @classname = classname
            @properties = NocaseHash.new
            unless properties.nil?
                properties.each do |k, v|
                    @properties[k]=v
                end
            end
            @qualifiers = NocaseHash.new(qualifiers)
            @cim_methods = NocaseHash.new(methods)
            @superclass = superclass
        end

        def clone
            return CIMClass.new(@classname, @properties, @qualifiers,
                                @cim_methods, @superclass)
        end

        def properties=(properties)
            @properties = NocaseHash.new
            unless properties.nil?
                properties.each do |k, v|
                    @properties[k]=v
                end
            end
        end

        def qualifiers=(qualifiers)
            @qualifiers = NocaseHash.new(qualifiers)
        end

        def cim_methods=(cim_methods)
            @cim_methods = NocaseHash.new(cim_methods)
        end

        def to_s
            "#{self.class}(#{self.classname}, ...)"
        end

        def <=>(other)
            if equal?(other)
                return 0
            elsif (!other.kind_of?(CIMClass))
                return 1
            end
            ret_val = cmpname(self.classname, other.classname)
            ret_val = cmpname(self.superclass, other.superclass) if (ret_val == 0)
            ret_val = nilcmp(self.properties, other.properties) if (ret_val == 0)
            ret_val = nilcmp(self.qualifiers, other.qualifiers) if (ret_val == 0)
            ret_val = nilcmp(self.cim_methods, other.cim_methods) if (ret_val == 0)
            ret_val
        end
        
        def tocimxml
            return CLASS.new(self.classname,
                             self.properties.values.collect {|p| p.tocimxml()},
                             self.cim_methods.values.collect {|m| m.tocimxml()},
                             self.qualifiers.values.collect {|q| q.tocimxml()},
                             self.superclass)
        end
    end

    class CIMMethod < XMLObject
        include Comparable
        
        attr_reader :name, :parameters, :qualifiers, :class_origin, :return_type, :propagated
        attr_writer :name, :class_origin, :return_type, :propagated
        def initialize(methodname, return_type = nil, parameters = {}, class_origin = nil, propagated = false, qualifiers = {} ) 
            @name = methodname
            @return_type = return_type
            @parameters = NocaseHash.new(parameters)
            @class_origin = class_origin
            @propagated = propagated
            @qualifiers = NocaseHash.new(qualifiers)
        end

        def clone
            return CIMMethod.new(@name, @return_type, @parameters,
                                 @class_origin, @propagated, @qualifiers)
        end
                   
        def parameters=(parameters)
            @parameters = NocaseHash.new(parameters)
        end

        def qualifiers=(qualifiers)
            @qualifiers = NocaseHash.new(qualifiers)
        end

        def tocimxml
            METHOD.new(self.name,
                       self.parameters.values.collect {|p| p.tocimxml()},
                       self.return_type,
                       self.class_origin,
                       self.propagated,
                       self.qualifiers.values.collect {|q| q.tocimxml()})
        end
        
        def <=>(other)
            ret_val = 0
            if equal?(other)
                return 0
            elsif (!other.kind_of?(CIMMethod))
                return 1
            end
            ret_val = cmpname(self.name, other.name)
            ret_val = nilcmp(self.parameters, other.parameters) if (ret_val == 0)
            ret_val = nilcmp(self.qualifiers, other.qualifiers) if (ret_val == 0)
            ret_val = nilcmp(self.class_origin, other.class_origin) if (ret_val == 0)
            ret_val = nilcmp(self.propagated, other.propagated) if (ret_val == 0)
            ret_val = nilcmp(self.return_type, other.return_type) if (ret_val == 0)
            ret_val
        end

        def to_s
            "#{self.class}(name=#{self.name}, return_type=#{self.return_type}...)"
        end
    end

    class CIMParameter < XMLObject
        include Comparable
        
        attr_writer :name, :param_type, :is_array, :reference_class, :array_size
        attr_reader :name, :param_type, :is_array, :qualifiers, :reference_class, :array_size

        def initialize(name, type, reference_class=nil, is_array = nil,
                       array_size = nil, qualifiers = {})
            @name = name
            @param_type = type
            @reference_class = reference_class
            @is_array = is_array
            @array_size = array_size
            @qualifiers = NocaseHash.new(qualifiers)
        end

        def clone
            CIMParameter.new(@name, @param_type, @reference_class, 
                                      @is_array, @array_size, @qualifiers)
        end

        def qualifiers=(qualifiers)
            @qualifiers = NocaseHash.new(qualifiers)
        end

        def to_s
            "#{self.class}(name=#{self.name}, type=#{self.param_type}, is_array=#{self.is_array})"
        end

        def <=>(other)
            if equal?(other)
                return 0
            elsif (!other.kind_of?(CIMParameter ))
                return 1
            end
            ret_val = cmpname(self.name, other.name)
            ret_val = nilcmp(self.param_type, other.param_type) if (ret_val == 0)
            ret_val = cmpname(self.reference_class, other.reference_class) if (ret_val == 0)
            ret_val = nilcmp(self.is_array, other.is_array) if (ret_val == 0)
            ret_val = nilcmp(self.array_size, other.array_size) if (ret_val == 0)
            ret_val = nilcmp(self.qualifiers, other.qualifiers) if (ret_val == 0)
            ret_val
        end

        def tocimxml
            if self.param_type == 'reference'
                if self.is_array
                    return PARAMETER_REFARRAY.new(self.name,
                                                  self.reference_class,
                                                  array_size.nil? ? nil : self.array_size.to_s,
                                                  self.qualifiers.values.collect {|q| q.tocimxml()})
                else
                    return PARAMETER_REFERENCE.new(self.name,
                                                   self.reference_class,
                                                   self.qualifiers.values.collect {|q| q.tocimxml()})
                end
            elsif self.is_array
                return PARAMETER_ARRAY.new(self.name,
                                           self.param_type,
                                           array_size.nil? ? nil : self.array_size.to_s,
                                           self.qualifiers.values.collect { |q| q.tocimxml})
            else
                return PARAMETER.new(self.name,
                                     self.param_type,
                                     self.qualifiers.values.collect { |q| q.tocimxml})
            end
        end
    end

    class CIMQualifier < XMLObject
        include Comparable
        #"""Represents static annotations of a class, method, property, etc.

        #Includes information such as a documentation string and whether a property
        #is a key."""

        attr_reader :name, :qual_type, :value, :overridable, :propagated, :toinstance, :tosubclass, :translatable
        attr_writer :name, :qual_type, :value, :overridable, :propagated, :toinstance, :tosubclass, :translatable
        def initialize(name, value, propagated=nil, overridable=nil,
                       tosubclass=nil, toinstance=nil, translatable=nil)
            @name = name
            @value = value
            @overridable = overridable
            @propagated = propagated
            @toinstance = toinstance
            @tosubclass = tosubclass
            @translatable = translatable
            @qual_type = WBEM.cimtype(value)
        end

        def clone
            CIMQualifier.new(@name, @value, @propagated, @overridable,
                             @tosubclass, @toinstance, @translatable)
        end

        def to_s
            "#{self.class}(#{self.name}, #{self.value}, ...)"
        end

        def <=>(other)
            ret_val = 0
            if equal?(other)
                return 0
            elsif (!other.kind_of?(CIMQualifier))
                return 1
            end
            ret_val = cmpname(self.name, other.name)
            ret_val = nilcmp(self.value, other.value) if (ret_val == 0)
            ret_val = nilcmp(self.propagated, other.propagated) if (ret_val == 0)
            ret_val = nilcmp(self.overridable, other.overridable) if (ret_val == 0)
            ret_val = nilcmp(self.tosubclass, other.tosubclass) if (ret_val == 0)
            ret_val = nilcmp(self.toinstance, other.toinstance) if (ret_val == 0)
            ret_val = nilcmp(self.translatable, other.translatable) if (ret_val == 0)
            ret_val
        end
        def tocimxml
            QUALIFIER.new(self.name, 
                          self.qual_type,
                          WBEM.tocimxml(self.value),
                          self.propagated,
                          self.overridable,
                          self.tosubclass,
                          self.toinstance,
                          self.translatable)
        end
    end

    def WBEM.tocimxml(value, wrap_references = false)
        #"""Convert an arbitrary object to CIM xml.  Works with cim_obj
        #objects and builtin types."""
        
        
        # CIMType or builtin type
        
        if ([CIMType, String, Integer, DateTime, TimeDelta, TrueClass, FalseClass].any? do |item| 
                value.is_a?(item) 
            end)
            return VALUE.new(WBEM.atomic_to_cim_xml(value))
        elsif (wrap_references and (value.is_a?(CIMInstanceName) or
                                    value.is_a?(CIMClassName)))
            return VALUE_REFERENCE.new(WBEM.atomic_to_cim_xml(value))
        elsif (value.methods.include?("tocimxml"))
            return value.tocimxml()
        elsif (value.is_a?(Array))
            if (wrap_references and (value[0].is_a?(CIMInstanceName) or  
                                     value[0].is_a?(CIMClassName)))
                return VALUE_REFARRAY.new(value.collect {|val| WBEM.tocimxml(val, wrap_references)})
            else
                return VALUE_ARRAY.new(value.collect {|val| WBEM.tocimxml(val, wrap_references)})
            end
        elsif (value.nil?)
            return value
        end
        raise TypeError, "Can't convert #{value} (#{value.class}) to CIM XML"
    end

    def WBEM.tocimobj(_type, value)
        #"""Convert a CIM type and a string value into an appropriate
        #builtin type."""

        # Lists of values

        if (value.nil? || _type.nil?)
            return nil
        end

        if value.is_a?(Array)
            return value.collect { |val| WBEM.tocimobj(_type, val) }
        end

        case _type
            # Boolean type
        when "boolean"
            return Boolean.new(value)
            # String type
        when "string"
            return value
            # Integer types
        when "uint8"
            return Uint8.new(value)
        when "sint8"
            return Sint8.new(value)
        when "uint16"
            return Uint16.new(value)
        when "sint16"
            return Sint16.new(value)
        when "uint32"
            return Uint32.new(value)
        when "sint32"
            return Sint32.new(value)
        when "uint64"
            return Uint64.new(value)
        when "sint64"
            return Sint64.new(value)
            # Real types
        when "real32"
            return Real32.new(value)
        when "real64"
            return Real64.new(value)
            # Char16
        when "char16"
            raise TypeError, "CIMType char16 not handled"
            # Datetime
        when "datetime"
            tv_pattern = /^(\d{8})(\d{2})(\d{2})(\d{2})\.(\d{6})(:)(\d{3})/
            date_pattern = /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})\.(\d{6})([+|-])(\d{3})/
            if ((s = tv_pattern.match(value)).nil?)
		if ((s = date_pattern.match(value)).nil?)
                    raise TypeError, "Invalid Datetime format #{value}"
                end
                return DateTime.new(s[1].to_i,s[2].to_i,s[3].to_i,s[4].to_i,s[5].to_i,s[6].to_i+Rational(s[7].to_i,1000000))
            else
                # returning a rational num for the #days rather than a python timedelta
                return TimeDelta.new(s[1].to_i, s[2].to_i, s[3].to_i, s[4].to_i, s[5].to_i)
            end
        else
            raise TypeError, "Invalid CIM type #{_type}"
        end
    end
    def WBEM.byname(nlist)
        #"""Convert a list of named objects into a map indexed by name"""
        hash = Hash.new
        nlist.each { |x| hash[x.name] = x }
        return hash
    end
    class TimeDelta 
        attr_reader :days, :hours, :minutes, :seconds, :microseconds
        attr_writer :days, :hours, :minutes, :seconds, :microseconds
        def initialize(days=0, hours=0, minutes=0, seconds=0, microseconds=0)
            @days = days
            @hours = hours
            @minutes = minutes
            @seconds = seconds
            @microseconds = microseconds
        end
    end
end
