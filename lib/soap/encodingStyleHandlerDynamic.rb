=begin
SOAP4R - SOAP Dynamic EncodingStyle handler library
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

require 'soap/encoding'
require 'soap/nqxmlDocument'


module SOAP


class SOAPEncodingStyleHandlerDynamic < EncodingStyleHandler

  def initialize
    super( EncodingNamespace )
    @referencePool = []
    @idPool = []
    @textBuf = ''
  end


  ###
  ## encode interface.
  #
  def encodeData( ns, data, name, parent )
  end

  def encodeBaseData( ns, data, name, parent )
    # for basetype...
    attrs = []
    addNSDeclAttr( attrs, ns )
#    if parentEncodingStyle != EncodingNamespace
#      addEncodingAttr( attrs, ns )
#    end
    if !parent.is_a?( SOAPArray )
      attrs.push( datatypeAttr( ns )) if data.typeName
    else
      if parent.position
	attrs.push( positionAttr( parent.position, ns ))
      end
      if parent.typeNamespace != data.typeNamespace ||
	  parent.baseTypeName != data.typeName
	attrs.push( datatypeAttr( ns )) if data.typeName
      end
    end

    if ( data.to_s.empty? )
      Node.initializeWithChildren( name, attrs )
    else
      Node.initializeWithChildren( name, attrs, Text.new( data.to_s ))
    end
  end

# @
  def encodeStruct( ns, data, name, parent )
    attrs = @extraAttributes.collect { | attr | attr.create( ns ) }
    addNSDeclAttr( attrs, ns )
#    if parentEncodingStyle != EncodingNamespace
#      addEncodingAttr( attrs, ns )
#    end
    if !parent.is_a?( SOAPArray )
      attrs.push( datatypeAttr( ns )) if data.typeName
    else
      if parent.position
       	attrs.push( positionAttr( parent.position, ns ))
      end
      if parent.typeNamespace != data.typeNamespace ||
	  parentArray.baseTypeName != data.typeName
	attrs.push( datatypeAttr( ns )) if data.typeName
      end
    end

    children = []
    0.upto( @array.length - 1 ) do | i |
      children.push( @data[ i ].encodeData( ns.clone, @array[ i ], data ))
    end

    # Element.new( name, attrs, children )
    Node.initializeWithChildren( name, attrs, children )
  end

  def encodeDataArray( ns, data, name, parent )
    attrs = @extraAttributes.collect { | attr | attr.create( ns ) }
    addNSDeclAttr( attrs, ns )
#    if parentEncodingStyle != EncodingNamespace
#      addEncodingAttr( attrs, ns )
#    end

    attrs.push( arrayTypeAttr( ns ))
    attrs.push( datatypeAttr( ns )) if data.typeName
    if !parent.is_a?( SOAPArray )
      attrs.push( datatypeAttr( ns )) if data.typeName	# Added in rewriting...
    else
      if parent.position
	attrs.push( positionAttr( parent.position, ns ))
      end
      # Add always.
      attrs.push( datatypeAttr( ns )) if data.typeName
    end

    childTypeName = contentTypeName().gsub( /\[,*\]/, ArrayEncodePostfix ) << ArrayEncodePostfix

    children = []
    traverse do | child, *rank |
      unless @sparse
	@position = nil
      else
	@position = rank
      end
      children << child.encode( ns.clone, childTypeName, EncodingNamespace, self )
    end

    # Element.new( name, attrs, children )
    Node.initializeWithChildren( name, attrs, children )
  end


  ###
  ## decode interface.
  #
  class SOAPTemporalObject
    attr_accessor :parent
    attr_accessor :position
    attr_accessor :id
    attr_accessor :root

    def initialize
      @parent = nil
      @position = nil
      @id = nil
      @root = nil
    end
  end

  class SOAPUnknown < SOAPTemporalObject
    def initialize( handler, ns, name, data, typeNamespace, typeName )
      super()
      @handler = handler
      @ns = ns
      @name = name
      @data = data
      @typeNamespace = typeNamespace
      @typeName = typeName
    end

    def toStruct
      o = SOAPStruct.decode( @ns, @name, @typeNamespace, @typeName )
      o.id = @id
      o.root = @root
      o.parent = @parent
      o.position = @position
      @handler.decodeParent( @parent, o )
      o
    end

    def toString
      o = SOAPString.decode( @ns, @name )
      o.id = @id
      o.root = @root
      o.parent = @parent
      o.position = @position
      @handler.decodeParent( @parent, o )
      o
    end

    def toNil
      o = SOAPNil.decode( @ns, @name )
      o.id = @id
      o.root = @root
      o.parent = @parent
      o.position = @position
      @handler.decodeParent( @parent, o )
      o
    end
  end

  def decodeTag( ns, name, attrs, parent )
    # ToDo: check if @textBuf is empty...
    @textBuf = ''
    isNil, type, arrayType, reference, id, root, offset, position = decodeAttrs( ns, attrs )
    o = nil
    if isNil
      o = SOAPNil.decode( ns, name )

    elsif arrayType
      typeNamespace, typeNameString = ns.parse( arrayType )
      o = SOAPArray.decode( ns, name, typeNamespace, typeNameString )
      if offset
	o.offset = decodeArrayPosition( offset )
	o.sparse = true
      else
	o.sparse = false
      end
      # ToDo: xsi:type should be checked here...

    elsif reference
      o = SOAPReference.decode( ns, name, reference )
      @referencePool << o

    else
      typeNamespace = typeNameString = nil
      if type
	typeNamespace, typeNameString = ns.parse( type )
      elsif parent.node.is_a?( SOAPArray )
	typeNamespace, typeNameString = parent.node.typeNamespace, parent.node.typeName
      else
	# Since it's in dynamic(without any type) encoding process,
	# assumes entity as its type itself.
	#   <SOAP-ENC:Array ...> => type Array in SOAP-ENC.
	#   <Country xmlns="foo"> => type Country in foo.
	typeNamespace, typeNameString = ns.parse( name )
      end

      if typeNamespace == XSD::Namespace
	o = decodeTagAsXSD( ns, typeNameString, name )
	unless o
      	  # Not supported...
	  raise FormatDecodeError.new( "Type xsd:#{ typeNameString } have not supported." )
	end

      elsif typeNamespace == EncodingNamespace
	o = decodeTagAsSOAPENC( ns, typeNameString, name )
	unless o
	  # Not supported...
	  raise FormatDecodeError.new( "Type SOAP-ENC:#{ typeNameString } have not supported." )
	end

      else
	# Unknown type... Struct or String
	o = SOAPUnknown.new( self, ns, name, attrs, typeNamespace, typeNameString )

      end
    end

    o.parent = parent
    o.id = id 
    o.root = root
    o.position = position

    unless o.is_a?( SOAPTemporalObject )
      @idPool << o if o.id
      decodeParent( parent, o )
    end

    o
  end

  def decodeTagEnd( ns, node )
    o = node.node
    if o.is_a?( SOAPUnknown )
      newNode = if /\A\s*\z/ =~ @textBuf
	o.toStruct
      else
	o.toString
      end
      if newNode.id
	@idPool << newNode
      end
      node.replaceNode( newNode )
      o = node.node
    end

    decodeTextBuf( o )
    @textBuf = ''
  end

  def decodeText( ns, text )
    # @textBuf is set at decodeTagEnd.
    @textBuf << text
  end

  def decodePrologue
    @referencePool.clear
    @idPool.clear
  end

  def decodeEpilogue
    decodeResolveId
  end

  def decodeParent( parent, node )
    case parent.node
    when SOAPUnknown
      newParent = parent.node.toStruct
      node.parent = newParent
      # ID entiry was delayed.
      if newParent.id
	@idPool << newParent
      end
      parent.replaceNode( newParent )
      decodeParent( parent, node )

    when SOAPReference
      raise FormatDecodeError.new( "Reference node must not have a child." )

    when SOAPStruct
      parent.node.add( node.name, node )

    when SOAPArray
      if node.position
	parent.node[ *( decodeArrayPosition( node.position )) ] = node
	parent.node.sparse = true
      else
	parent.node.add( node )
      end

    when SOAPBasetype
      raise FormatDecodeError.new( "SOAP base type must not have a child." )

    else
      # SOAPUnknown does not have parent.
      # raise FormatDecodeError.new( "Illegal parent: #{ parent }." )
    end
  end

private

  def encodeBaseData()
    attrs = []
    addNSDeclAttr( attrs, ns )
    if parentEncodingStyle != EncodingNamespace
      addEncodingAttr( attrs, ns )
    end
    if parentArray && parentArray.typeNamespace == @typeNamespace &&
        parentArray.baseTypeName == @typeName
      # No need to add.
    else
      attrs.push( datatypeAttr( ns )) if @typeName
    end

    if parentArray && parentArray.position
      attrs.push( positionAttr( parentArray.position, ns ))
    end

    if ( self.to_s.empty? )
      # Element.new( name, attrs )
      Node.initializeWithChildren( name, attrs )
    else
      # Element.new( name, attrs, Text.new( self.to_s ))
      Node.initializeWithChildren( name, attrs, Text.new( self.to_s ))
    end
  end


  XSDBaseTypeMap = {
    XSD::DecimalLiteral => SOAPDecimal,
    XSD::IntegerLiteral => SOAPInteger,
    XSD::LongLiteral => SOAPLong,
    XSD::IntLiteral => SOAPInt,
    XSD::FloatLiteral => SOAPFloat,
    XSD::DoubleLiteral => SOAPDouble,
    XSD::BooleanLiteral => SOAPBoolean,
    XSD::StringLiteral => SOAPString,
    XSD::DateTimeLiteral => SOAPDateTime,
    XSD::DateLiteral => SOAPDate,
    XSD::TimeLiteral => SOAPTime,
    XSD::HexBinaryLiteral => SOAPHexBinary,
    XSD::Base64BinaryLiteral => SOAPBase64,
  }

  SOAPBaseTypeMap = {
    SOAP::Base64Literal => SOAPBase64,
  }

  def decodeTagAsXSD( ns, typeNameString, name )
    if typeNameString == XSD::AnyTypeLiteral
      SOAPUnknown.new( self, ns, name, XSD::Namespace, typeNameString )
    elsif XSDBaseTypeMap.has_key?( typeNameString )
      XSDBaseTypeMap[ typeNameString ].decode( ns, name )
    else
      nil
    end
  end

  def decodeTagAsSOAPENC( ns, typeNameString, name )
    if XSDBaseTypeMap.has_key?( typeNameString )
      XSDBaseTypeMap[ typeNameString ].decode( ns, name )
    elsif SOAPBaseTypeMap.has_key?( typeNameString )
      SOAPBaseTypeMap[ typeNameString ].decode( ns, name )
    else
      nil
    end
  end

  def decodeTextBuf( node )
    case node
    when XSDHexBinary, XSDBase64Binary
      node.setEncoded( @textBuf )
    when XSDString
      encoded = Charset.encodingFromXML( @textBuf )
      node.set( encoded )
    when SOAPNil
      # Nothing to do.
    when SOAPBasetype
      node.set( @textBuf ) unless @textBuf.empty?
    else
      # Nothing to do...
    end
  end

  def decodeAttrs( ns, attrs )
    isNil = false
    type = nil
    arrayType = nil
    reference = nil
    id = nil
    root = nil
    offset = nil
    position = nil

    attrs.each do | key, value |
      if ( ns.compare( XSD::InstanceNamespace, XSD::NilLiteral, key ))
	# isNil = (( value == 'true' ) || ( value == '1' ))
	if value == XSD::NilValue
	  isNil = true
	else
	  raise FormatDecodeError.new( "Cannot accept attribute value: #{ value } as the value of xsi:#{ XSD::NilLiteral } (expected 'true')." )
	end
      elsif ( ns.compare( XSD::InstanceNamespace, XSD::AttrType, key ))
	type = value
      elsif ( ns.compare( EncodingNamespace, AttrArrayType, key ))
	arrayType = value
      elsif ( key == 'href' )
	reference = value
      elsif ( key == 'id' )
	id = value
      elsif ( ns.compare( EncodingNamespace, AttrRoot, key ))
	if value == '1'
	  root = 1
	elsif value == '0'
	  root = 0
	else
	  raise FormatDecodeError.new( "Illegal root attribute value: #{ value }." )
	end
      elsif ( ns.compare( EncodingNamespace, AttrOffset, key ))
	offset = value
      elsif ( ns.compare( EncodingNamespace, AttrPosition, key ))
	position = value
      end
    end

    return isNil, type, arrayType, reference, id, root, offset, position
  end

  def decodeArrayPosition( position )
    /^\[(.+)\]$/ =~ position
    $1.split( ',' ).collect { |s| s.to_i }
  end

  def decodeResolveId
    count = @referencePool.length	# To avoid infinite loop
    while !@referencePool.empty? && count > 0
      @referencePool = @referencePool.find_all { | ref |
	count -= 1
	o = @idPool.find { | item |
	  ( '#' << item.id == ref.refId )
	}
	unless o
	  raise FormatDecodeError.new( "Unresolved reference: #{ ref.refId }." )
	end
	if o.is_a?( SOAPReference )
	  true
	else
	  ref.__setobj__( o )
	  false
	end
      }
    end
  end
end

SOAPEncodingStyleHandlerDynamic.new


end
