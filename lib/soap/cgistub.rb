=begin
SOAP4R - CGI stub library
Copyright (C) 2001 NAKAMURA Hiroshi.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PRATICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 675 Mass
Ave, Cambridge, MA 02139, USA.
=end


require 'soap/server'
require 'http-access2/http'


module SOAP


###
# SYNOPSIS
#   CGIStub.new
#
# DESCRIPTION
#   To be written...
#
class CGIStub < Server
  include SOAP

  class CGIError < Error; end

  class SOAPRequest
    ALLOWED_LENGTH = 1024 * 1024
    ReceiveMediaType = 'text/xml'

    def initialize( sourceStream = $stdin )
      @method = ENV[ 'REQUEST_METHOD' ]
      @size = ENV[ 'CONTENT_LENGTH' ].to_i || 0
      @content_type = ENV[ 'CONTENT_TYPE' ]
      @charset = nil
      @soap_action = ENV[ 'HTTP_SOAPAction' ]
      @source = sourceStream
      @body = nil
    end

    def init
      validate
      parseContentType
      @body = @source.read( @size )
      self
    end

    def dump
      @body.dup
    end

    def soap_action
      @soap_action
    end

    def charset
      @charset
    end

    def to_s
      "method: #{ @method }, size: #{ @size }"
    end

  private

    def parseContentType
      if /^#{ ReceiveMediaType }(?:;\s*charset=(.*))?/i !~ @content_type
	raise CGIError.new( "Illegal content-type." )
      end
      @charset = $1
    end

    def validate # raise CGIError
      if @method != 'POST'
	raise CGIError.new( "Method '#{ @method }' not allowed." )
      end

      if @size > ALLOWED_LENGTH
        raise CGIError.new( "Content-length too long." )
      end
    end
  end

  def initialize( appName, namespace )
    super( appName, namespace )
    @remote_user = ENV[ 'REMOTE_USER' ] || 'anonymous'
    @remote_host = ENV[ 'REMOTE_HOST' ] || ENV[ 'REMOTE_ADDR' ] || 'unknown'
    @request = nil
    @response = nil
  end
  
protected
  def methodDef
    # Override this method in derived class to call 'addMethod' to add methods.
  end

private
  
  def run
    @log.sevThreshold = SEV_INFO

    prologue

    begin
      log( SEV_INFO ) { "Received a request from '#{ @remote_user }@#{ @remote_host }'." }
    
      # SOAP request parsing.
      @request = SOAPRequest.new.init
      log( SEV_INFO ) { "SOAP CGI Request: #{@request}" }

      requestString = @request.dump
      log( SEV_DEBUG ) { "XML Request: #{requestString}" }

      parser = Processor.getDefaultParser
      kcodeAdjusted = false
      requestCharset = @request.charset.dup
      charsetStrBackup = nil
      if requestCharset
       	#requestString.sub!( /^([^>]*)\s+encoding=(['"])[^'"]*\2/ ) { $1 }
	charsetStr = Charset.getCharsetStr( requestCharset )
	Charset.setXMLInstanceEncoding( charsetStr )

	if parser.adjustKCode
  	  charsetStrBackup = $KCODE.to_s.dup
  	  $KCODE = charsetStr
	  kcodeAdjusted = true
   	end
      end

      responseString = isFault = nil
      begin
	responseString, isFault = route( requestString )
	log( SEV_DEBUG ) { "XML Response: #{responseString}" }
      ensure
	if kcodeAdjusted
	  $KCODE = charsetStrBackup
	end
      end

      @response = HTTP::Message.newResponse( responseString )
      @response.header.set( 'Cache-Control', 'private' )
      @response.header.bodyType = 'text/xml'
      @response.header.bodyCharset = requestCharset || Charset.getXMLInstanceEncoding
      unless isFault
	@response.status = 200
      else
	@response.status = 500
      end
      str = @response.dump
      log( SEV_DEBUG ) { "SOAP CGI Response:\n#{ str }" }
      print str

      epilogue

    rescue Exception
      responseString = createFaultResponseString( $! )
      @response = HTTP::Message.newResponse( responseString )
      @response.header.set( 'Cache-Control', 'private' )
      @response.header.bodyType = 'text/xml'
      @response.header.bodyCharset = Charset.getXMLInstanceEncoding
      @response.status = 500
      str = @response.dump
      log( SEV_DEBUG ) { "SOAP CGI Response:\n#{ str }" }
      print str

    end

    0
  end

  def prologue; end
  def epilogue; end
end


end
