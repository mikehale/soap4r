=begin
WSDL4R - WSDL SOAP operation definition.
Copyright (C) 2002, 2003  NAKAMURA, Hiroshi.

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


require 'wsdl/info'


module WSDL
module SOAP


class Operation < Info
  class OperationInfo
    attr_reader :style
    attr_reader :op_name
    attr_reader :optype_name
    attr_reader :headerparts
    attr_reader :bodyparts
    attr_reader :faultpart
    attr_reader :soapaction
    
    def initialize(style, op_name, optype_name, headerparts, bodyparts, faultpart, soapaction)
      @style = style
      @op_name = op_name
      @optype_name = optype_name
      @headerparts = headerparts
      @bodyparts = bodyparts
      @faultpart = faultpart
      @soapaction = soapaction
    end
  end

  attr_reader :soapaction
  attr_reader :style

  def initialize
    super
    @soapaction = nil
    @style = nil
  end

  def parse_element(element)
    nil
  end

  def parse_attr(attr, value)
    case attr
    when StyleAttrName
      if ["document", "rpc"].include?(value)
	@style = value.intern
      else
	raise AttributeConstraintError.new("Unexpected value #{ value }.")
      end
    when SOAPActionAttrName
      @soapaction = value
    else
      nil
    end
  end

  def input_info
    name_info = parent.find_operation.input_info
    param_info(name_info, parent.input)
  end

  def output_info
    name_info = parent.find_operation.output_info
    param_info(name_info, parent.output)
  end

  def operation_style
    return @style if @style
    if parent_binding.soapbinding
      return parent_binding.soapbinding.style
    end
    nil
  end

private

  def parent_binding
    parent.parent
  end

  def param_info(name_info, param)
    op_name = name_info.op_name
    optype_name = name_info.optype_name

    soapheader = param.soapheader
    headerparts = soapheader.collect { |item| item.find_part }

    soapbody = param.soapbody
    if soapbody.encodingstyle and
	soapbody.encodingstyle != ::SOAP::EncodingNamespace
      raise NotImplementedError.new(
	"EncodingStyle '#{ soapbody.encodingstyle }' not supported.")
    end
    if soapbody.namespace
      op_name = op_name.dup
      op_name.namespace = soapbody.namespace
    end
    if soapbody.parts
      raise NotImplementedError.new("soap:body parts")
    else
      bodyparts = name_info.parts
    end

    faultpart = nil
    soapaction = parent.soapoperation.soapaction
    OperationInfo.new(operation_style, op_name, optype_name, headerparts, bodyparts, faultpart, soapaction)
  end
end


end
end
