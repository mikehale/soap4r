=begin
SOAP4R - Base definitions.
Copyright (C) 2000, 2001 NAKAMURA Hiroshi.

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

module SOAP
  public

  EnvelopeNamespace = 'http://schemas.xmlsoap.org/soap/envelope/'
  EncodingNamespace = 'http://schemas.xmlsoap.org/soap/encoding/'

  NextActor = 'http://schemas.xmlsoap.org/soap/actor/next'

  AttrMustUnderstand = 'mustUnderstand'
  AttrEncodingStyle = 'encodingStyle'
  AttrRoot = 'root'
  AttrArrayType = 'arrayType'
  AttrActor = 'actor'

  Base64Literal = 'base64'

  class Error < StandardError; end

  class MethodDefinitionError < Error; end
  class HTTPStreamError < Error; end
  class PostUnavailableError < HTTPStreamError; end
  class MPostUnavailableError < HTTPStreamError; end

  class ArrayIndexOutOfBoundsError < Error; end
  class ArrayStoreError < Error; end

  class FaultError < Error
    public

    attr_reader :faultCode
    attr_reader :faultString
    attr_reader :faultActor
    attr_reader :detail

    def initialize( fault )
      @faultCode = fault.faultCode
      @faultString = fault.faultString
      @faultActor = fault.faultActor
      @detail = fault.detail
    end

    def to_s
      @faultString.data
    end
  end

  class FormatDecodeError < Error; end

end
