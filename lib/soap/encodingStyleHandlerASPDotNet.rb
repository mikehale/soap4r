=begin
SOAP4R - ASP.NET EncodingStyle handler library
Copyright (C) 2001, 2003  NAKAMURA, Hiroshi.

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

require 'soap/encodingStyleHandler'


module SOAP


class EncodingStyleHandlerASPDotNet < EncodingStyleHandler
  Namespace = 'http://tempuri.org/ASP.NET'
  add_handler

  def initialize(charset = nil)
    super(charset)
    @textbuf = ''
    @decode_typemap = nil
  end


  ###
  ## encode interface.
  #
  def encode_data(buf, ns, qualified, data, parent, indent = '')
    attrs = {}
    name = if qualified and data.elename.namespace
        SOAPGenerator.assign_ns(attrs, ns, data.elename.namespace)
        ns.name(data.elename)
      else
        data.elename.name
      end

    case data
    when SOAPRawString
      SOAPGenerator.encode_tag(buf, name, attrs, indent)
      buf << data.to_s
    when XSDString
      SOAPGenerator.encode_tag(buf, name, attrs, indent)
      buf << SOAPGenerator.encode_str(@charset ?
	Charset.encoding_to_xml(data.to_s, @charset) : data.to_s)
    when XSDAnySimpleType
      SOAPGenerator.encode_tag(buf, name, attrs, indent)
      buf << SOAPGenerator.encode_str(data.to_s)
    when SOAPStruct
      SOAPGenerator.encode_tag(buf, name, attrs, indent)
      data.each do |key, value|
	if !value.elename.namespace
          value.elename.namespace = data.elename.namespace 
        end
        yield(value, true)
      end
    when SOAPArray
      SOAPGenerator.encode_tag(buf, name, attrs, indent)
      data.traverse do |child, *rank|
	data.position = nil
        yield(child, true)
      end
    else
      raise EncodingStyleError.new("Unknown object:#{ data } in this encodingSt
yle.")
    end
  end

  def encode_data_end(buf, ns, qualified, data, parent, indent = "")
    name = if qualified and data.elename.namespace
        ns.name(data.elename)
      else
        data.elename.name
      end
    cr = data.is_a?(SOAPCompoundtype)
    SOAPGenerator.encode_tag_end(buf, name, indent, cr)
  end


  ###
  ## decode interface.
  #
  class SOAPTemporalObject
    attr_accessor :parent

    def initialize
      @parent = nil
    end
  end

  class SOAPUnknown < SOAPTemporalObject
    def initialize(handler, elename)
      super()
      @handler = handler
      @elename = elename
    end

    def as_struct
      o = SOAPStruct.decode(@elename, XSD::AnyTypeName)
      o.parent = @parent
      o.type.name = @name
      @handler.decode_parent(@parent, o)
      o
    end

    def as_string
      o = SOAPString.decode(@elename)
      o.parent = @parent
      @handler.decode_parent(@parent, o)
      o
    end

    def as_nil
      o = SOAPNil.decode(@elename)
      o.parent = @parent
      @handler.decode_parent(@parent, o)
      o
    end
  end

  def decode_tag(ns, elename, attrs, parent)
    # ToDo: check if @textbuf is empty...
    @textbuf = ''
    o = SOAPUnknown.new(self, elename)
    o.parent = parent
    o
  end

  def decode_tag_end(ns, node)
    o = node.node
    if o.is_a?(SOAPUnknown)
      newnode = o.as_string
#	if /\A\s*\z/ =~ @textbuf
#	  o.as_struct
#	else
#	  o.as_string
#	end
      node.replace_node(newnode)
      o = node.node
    end

    decode_textbuf(o)
    @textbuf = ''
  end

  def decode_text(ns, text)
    # @textbuf is set at decode_tag_end.
    @textbuf << text
  end

  def decode_prologue
  end

  def decode_epilogue
  end

  def decode_parent(parent, node)
    case parent.node
    when SOAPUnknown
      newparent = parent.node.as_struct
      node.parent = newparent
      parent.replace_node(newparent)
      decode_parent(parent, node)

    when SOAPStruct
      data = parent.node[node.elename.name]
      case data
      when nil
	parent.node.add(node.elename.name, node)
      when SOAPArray
	name, type_ns = node.elename.name, node.type.namespace
	data.add(node)
	node.elename, node.type.namespace = name, type_ns
      else
	parent.node[node.elename.name] = SOAPArray.new
	name, type_ns = data.elename.name, data.type.namespace
	parent.node[node.elename.name].add(data)
	data.elename.name, data.type.namespace = name, type_ns
	name, type_ns = node.elename.name, node.type.namespace
	parent.node[node.elename.name].add(node)
	node.elename.name, node.type.namespace = name, type_ns
      end

    when SOAPArray
      if node.position
	parent.node[*(decode_arypos(node.position))] = node
	parent.node.sparse = true
      else
	parent.node.add(node)
      end

    when SOAPBasetype
      raise EncodingStyleError.new("SOAP base type must not have a child.")

    else
      # SOAPUnknown does not have parent.
      # raise EncodingStyleError.new("Illegal parent: #{ parent }.")
    end
  end

private

  def decode_textbuf(node)
    if node.is_a?(XSDString)
      if @charset
	node.set(Charset.encoding_from_xml(@textbuf, @charset))
      else
	node.set(@textbuf)
      end
    else
      # Nothing to do...
    end
  end
end

EncodingStyleHandlerASPDotNet.new


end
