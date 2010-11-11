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

#'''
#This module implements CIM operations over HTTP.
#
#This module should not know anything about the fact that the data
#being transferred is XML.  It is up to the caller to format the input
#data and interpret the result.
#'''

require "wbem/cim_obj"
require "net/https"

module WBEM
    class CIMHttpError < Exception
            #    """This exception is raised when a transport error occurs."""
    end
    class AuthError < StandardError
        #"""This exception is raised when an authentication error (401) occurs."""
    end

    def WBEM.parse_url(url)
        #"""Return an array of (host, port, ssl, credentials) from the URL parameter.
        #The returned port defaults to 5988 if not specified.  SSL supports
        #defaults to False if not specified. Credentials are optional
        #as they may be specified as a separate parameter to
        #wbem_request. """
        
        host = url.sub(%r{^https?://}, "")    # Eat protocol name
        port = 5988
        ssl = false
        
        if /^https/.match(url)          # Set SSL if specified
            ssl = true
            port = 5989
        end
            
        s = host.split("@")       # parse creds if specified
        if (s.length > 1 )
            creds = s[0].split(":")
            host = s[1]
        end
        s = host.split(":")         # Set port number
        if (s.length > 1 )
            host = s[0]
            port = s[1].to_i
        end
#        STDOUT << "host: #{host}, port: #{port}, ssl: #{ssl}, creds: #{creds}\n"
        return host, port, ssl, creds
    end

    def WBEM.wbem_request(url, data, creds, headers = [], debug = 0, x509 = nil,
                          verify_callback = nil)
        #"""Send XML data over HTTP to the specified url. Return the
        #response in XML.  Uses Python's build-in httplib.  x509 may be a
        #dictionary containing the location of the SSL certificate and key
        #files."""

        host, port, ssl, urlcreds = WBEM.parse_url(url)
        creds = urlcreds unless creds
        h = Net::HTTP.new(host, port)
        if (ssl)
            if x509 
                cert_file = x509.get("cert_file")
                key_file = x509.get("key_file", cert_file)
            else
                cert_file = nil
                key_file = nil
            end
            h.use_ssl = true
            unless verify_callback.nil?
                h.verify_mode = OpenSSL::SSL::VERIFY_PEER
                h.verify_callback = verify_callback
            end
            # key_file, cert_file ???
        end    
        data = "<?xml version='1.0' encoding='utf-8' ?>\n" + data
        response = nil
        begin
            h.start do |http|
                request = Net::HTTP::Post.new("/cimom")
                request.basic_auth(creds[0], creds[1]) if creds
                request.content_type = 'application/xml; charset="utf-8"'
                request.content_length = data.length
                headers.each do |header|
                    s = header.split(":", 2).collect { |x| x.strip }
                    request.add_field(URI.escape(s[0]), URI.escape(s[1]))
                end
                #STDOUT << "request: #{data}\n"
                response = http.request(request, data)
                #STDOUT << "response: #{response.body}\n"
            end
        rescue OpenSSL::SSL::SSLError => arg
            raise CIMHttpError, "SSL error: %s" % (arg)
        end
        unless response.kind_of?(Net::HTTPSuccess)
            if (response.kind_of?(NET::HTTPUnauthorized))
                raise AuthError, response.reason
            elsif (response.fetch("CIMError", []) or response.fetch("PGErrorDetail", []))
                raise CIMHttpError, "CIMError: #{response.fetch('CIMError',[])}: #{response.fetch('PGErrorDetail',[])}"
            end
            raise CIMHttpError, "HTTP error: #{response.reason}"
        end
        # TODO: do we need more error checking here?

        response.body
    end

    def WBEM.get_object_header(obj)
        #"""Return the HTTP header required to make a CIM operation request
        #using the given object.  Return None if the object does not need
        #to have a header."""

        # Local namespacepath

        if obj.kind_of?(String)
            return "CIMObject: #{obj}"
        end
        
        # CIMLocalClassPath

        if obj.kind_of?(CIMClassName)
            return "CIMObject: #{obj.namespace}:#{obj.classname}"
        end
            # CIMInstanceName with namespace
            
        if obj.kind_of?(CIMInstanceName) && !obj.namespace.nil?
            return 'CIMObject: %s' % obj
        end 
        raise CIMHttpError, "Don\'t know how to generate HTTP headers for #{obj}"
    end
end
