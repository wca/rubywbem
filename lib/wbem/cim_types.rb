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

#"""
#Subclasses of builtin Python types to remember CIM types.  This is
#necessary as we need to remember whether an integer property is a
#uint8, uint16, uint32 etc, while still being able to treat it as a
#integer.
#"""

#from datetime import datetime, timedelta

module WBEM

    class CIMType
        include Comparable
        #"""Base type for all CIM types."""
        attr_reader :cimtype, :value
        attr_writer :cimtype, :value
        def initialize(cimtype, value) 
            @cimtype = cimtype
            @value = value
        end
        def to_s
            @value.to_s
        end
        def <=>(obj)
            if obj.is_a?(CIMType)
                @value <=> obj.value
            else
                @value <=> obj
            end
        end
    end

    # CIM integer types
    class CIMInt < CIMType
        def initialize(arg, base, cimtype) 
            super(cimtype, arg.is_a?(String) ? arg.to_i(base) : arg.to_i)
        end
    end

    class Uint8 < CIMInt
        def initialize(arg, base = 0)
            super(arg, base, "uint8")
        end
    end
    class Sint8 < CIMInt
        def initialize(arg, base = 0)
            super(arg, base, "sint8")
        end
    end
    class Uint16 < CIMInt
        def initialize(arg, base = 0)
            super(arg, base, "uint16")
        end
    end
    class Sint16 < CIMInt
        def initialize(arg, base = 0)
            super(arg, base, "sint16")
        end
    end
    class Uint32 < CIMInt
        def initialize(arg, base = 0)
            super(arg, base, "uint32")
        end
    end
    class Sint32 < CIMInt
        def initialize(arg, base = 0)
            super(arg, base, "sint32")
        end
    end
    class Uint64 < CIMInt
        def initialize(arg, base = 0)
            super(arg, base, "uint64")
        end
    end
    class Sint64 < CIMInt
        def initialize(arg, base = 0)
            super(arg, base, "sint64")
        end
    end

    # CIM float types
    
    class CIMFloat < CIMType
        def initialize(arg, cimtype)
            super(cimtype, Float(arg))
        end
    end

    class Real32 < CIMFloat
        def initialize(arg)
            super(arg, "real32")
        end
    end
    class Real64 < CIMFloat
        def initialize(arg)
            super(arg, "real64")
        end
    end

    class Boolean < CIMType
        def initialize(arg)
            arg = arg.downcase if arg.is_a?(String)
            if [:true, true, "true"].include?(arg) 
                value = true
            elsif [:false, false, "false"].include?(arg) 
                value = false
            else
                raise TypeError, "Invalid boolean value #{arg}"
            end
            super("boolean", value)
        end
        def <=>(obj)
            if obj.is_a?(Boolean)
                (self.value ^ obj.value) ? 1 : 0
            elsif obj == true || obj == false
                (self.value ^ obj) ? 1 : 0
            elsif obj.nil?
                self.value ? 1 : 0
            else
                1
            end
        end
            
    end

    def WBEM.cimtype(obj)
        #"""Return the CIM type name of an object as a string.  For a list, the
        #type is the type of the first element as CIM arrays must be
        #homogeneous."""
    
        if (obj.is_a?(CIMType))
            return obj.cimtype
        elsif (obj == true or obj == false)
            return 'boolean'
        elsif (obj.is_a?(String)) # unicode?
            return 'string'
        elsif (obj.is_a?(CIMClassName) || obj.is_a?(CIMLocalClassPath) || obj.is_a?(CIMInstanceName))
            return 'reference'
        elsif (obj.is_a?(DateTime) or obj.is_a?(TimeDelta))
            return 'datetime'
        elsif (obj.is_a?(Array))
            return WBEM.cimtype(obj[0])
        else
            raise TypeError, "Invalid CIM type for #{obj} (#{obj.class})"
        end
    end
    def WBEM.valid_cimtype?(obj)
        begin
            WBEM.cimtype(obj)
        rescue TypeError
            false
        else
            true
        end
    end

    def WBEM.atomic_to_cim_xml(obj)
        #"""Convert an atomic type to CIM external form"""
        if (obj == true or (obj.is_a?(Boolean) and obj.value==true))
            return "TRUE"
        elsif (obj == false or (obj.is_a?(Boolean) and obj.value==false))
            return "FALSE"
        elsif (obj.is_a?(DateTime))
            # TODO: Figure out UTC offset stuff
            return sprintf("%d%02d%02d%02d%02d%02d.%06d+000",
                           obj.year, obj.month, obj.day, obj.hour,
                           obj.min, obj.sec, obj.sec_fraction.to_f)
        elsif (obj.is_a?(TimeDelta))
            return sprintf("%08d%02d%02d%02d.%06d:000",
                           obj.days, obj.hours, obj.minutes, obj.seconds, obj.microseconds)
        elsif (obj.methods.include?("tocimxml"))
            return obj.tocimxml
        elsif obj.nil?
            return obj
        else
            return obj.to_s # unicode?
        end
    end
end
