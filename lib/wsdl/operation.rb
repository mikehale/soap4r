=begin
WSDL4R - WSDL operation definition.
Copyright (C) 2002, 2003 NAKAMURA Hiroshi.

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


class Operation < Info
  attr_reader :name		# required
  attr_reader :parameter_order	# optional
  attr_reader :input
  attr_reader :output
  attr_reader :fault
  attr_reader :type		# required

  def initialize
    super
    @name = nil
    @type = nil
    @parameter_order = nil
    @input = nil
    @output = nil
    @fault = nil
  end

  def targetnamespace
    parent.targetnamespace
  end

  def inputparts
    sort_parts(input.find_message.parts)
  end

  def outputparts
    sort_parts(output.find_message.parts)
  end

  def faultparts
    sort_parts(fault.find_message.parts)
  end

  def inputname
    XSD::QName.new(targetnamespace, input.name ? input.name.name : @name.name)
  end

  def outputname
    XSD::QName.new(targetnamespace,
      output.name ? output.name.name : @name.name + 'Response')
  end

  def parse_element(element)
    case element
    when InputName
      o = Param.new
      @input = o
      o
    when OutputName
      o = Param.new
      @output = o
      o
    when FaultName
      o = Param.new
      @fault = o
      o
    when DocumentationName
      o = Documentation.new
      o
    else
      nil
    end
  end

  def parse_attr(attr, value)
    case attr
    when NameAttrName
      @name = XSD::QName.new(targetnamespace, value)
    when TypeAttrName
      @type = value
    when ParameterOrderAttrName
      @parameter_order = value.split(/\s+/)
    else
      raise WSDLParser::UnknownAttributeError.new("Unknown attr #{ attr }.")
    end
  end

private

  def sort_parts(parts)
    return parts.dup unless parameter_order
    result = []
    parameter_order.each do |orderitem|
      if (ele = parts.find { |part| part.name == orderitem })
	result << ele
      end
    end
    if result.length == 0
      return parts.dup
    end
    if parts.length != result.length
      raise RuntimeError.new("Incomplete prarmeterOrder list.")
    end
    result
  end
end


end
