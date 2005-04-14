# WSDL4R - Creating class definition from WSDL
# Copyright (C) 2002, 2003, 2004  NAKAMURA, Hiroshi <nahi@ruby-lang.org>.

# This program is copyrighted free software by NAKAMURA, Hiroshi.  You can
# redistribute it and/or modify it under the same terms of Ruby's license;
# either the dual license version in 2003, or any later version.


require 'wsdl/data'
require 'wsdl/soap/classDefCreatorSupport'
require 'xsd/codegen'


module WSDL
module SOAP


class ClassDefCreator
  include ClassDefCreatorSupport

  def initialize(definitions)
    @elements = definitions.collect_elements
    @simpletypes = definitions.collect_simpletypes
    @complextypes = definitions.collect_complextypes
    @faulttypes = definitions.collect_faulttypes if definitions.respond_to?(:collect_faulttypes)
  end

  def dump(type = nil)
    result = ''
    if type
      result = dump_classdef(type.name, type)
    else
      str = dump_element
      unless str.empty?
        result << "\n" unless result.empty?
        result << str
      end
      str = dump_complextype
      unless str.empty?
        result << "\n" unless result.empty?
        result << str
      end
      str = dump_simpletype
      unless str.empty?
        result << "\n" unless result.empty?
        result << str
      end
    end
    result
  end

private

  def dump_element
    @elements.collect { |ele|
      if ele.local_complextype
        dump_classdef(ele.name, ele.local_complextype)
      elsif ele.local_simpletype
        dump_simpletypedef(ele.name, ele.local_simpletype)
      else
        ''
      end
    }.join("\n")
  end

  def dump_simpletype
    @simpletypes.collect { |type|
      dump_simpletypedef(type.name, type)
    }.join("\n")
  end

  def dump_complextype
    @complextypes.collect { |type|
      case type.compoundtype
      when :TYPE_STRUCT
        dump_classdef(type.name, type)
      when :TYPE_ARRAY
        dump_arraydef(type)
      when :TYPE_SIMPLE
        dump_simpleclassdef(type)
      when :TYPE_MAP
        # mapped as a general Hash
      else
        raise RuntimeError.new(
          "unknown kind of complexContent: #{type.compoundtype}")
      end
    }.join("\n")
  end

  def dump_simpletypedef(qname, simpletype)
    if simpletype.restriction.enumeration.empty?
      STDERR.puts("#{qname}: simpleType which is not enum type not supported")
      return ''
    end
    c = XSD::CodeGen::ModuleDef.new(create_class_name(qname))
    c.comment = "#{qname.namespace}"
    const = {}
    simpletype.restriction.enumeration.each do |value|
      constname = safeconstname(value)
      const[constname] ||= 0
      if (const[constname] += 1) > 1
        constname += "_#{const[constname]}"
      end
      c.def_const(constname, value.dump)
    end
    c.dump
  end

  def dump_simpleclassdef(type_or_element)
    qname = type_or_element.name
    base = create_class_name(type_or_element.simplecontent.base)
    c = XSD::CodeGen::ClassDef.new(create_class_name(qname), base)
    c.comment = "#{qname.namespace}"
    c.dump
  end

  def dump_classdef(qname, typedef)
    if @faulttypes and @faulttypes.index(qname)
      c = XSD::CodeGen::ClassDef.new(create_class_name(qname),
        '::StandardError')
    else
      c = XSD::CodeGen::ClassDef.new(create_class_name(qname))
    end
    c.comment = "#{qname.namespace}"
    c.def_classvar('schema_type', qname.name.dump)
    c.def_classvar('schema_ns', qname.namespace.dump)
    schema_element = []
    init_lines = ''
    params = []
    typedef.each_element do |element|
      name = element.name.name
      if element.type == XSD::AnyTypeName
        type = nil
      elsif basetype = element_basetype(element)
        type = basetype.name
      elsif element.type
        type = create_class_name(element.type)
      else
        type = nil      # means anyType.
        # do we define a class for local complexType from it's name?
        #   type = create_class_name(element.name)
        # <element>
        #   <complexType>
        #     <seq...>
        #   </complexType>
        # </element>
      end
      attrname = safemethodname?(name) ? name : safemethodname(name)
      varname = safevarname(name)
      c.def_attr(attrname, true, varname)
      init_lines << "@#{varname} = #{varname}\n"
      if element.map_as_array?
        params << "#{varname} = []"
        type << '[]' if type
      else
        params << "#{varname} = nil"
      end
      qname = (varname == name) ? nil : element.name
      schema_element << [varname, qname, type]
    end
    unless typedef.attributes.empty?
      define_attribute(c, typedef.attributes)
      init_lines << "@__soap_attribute = {}\n"
    end
    c.def_classvar('schema_element',
      '{' +
        schema_element.collect { |varname, name, type|
          if name
            varname.dump + ' => [' + ndq(type) + ', ' + dqname(name) + ']'
          else
            varname.dump + ' => ' + ndq(type)
          end
        }.join(', ') +
      '}'
    )
    c.def_method('initialize', *params) do
      init_lines
    end
    c.dump
  end

  def element_basetype(ele)
    if type = basetype_class(ele.type)
      type
    elsif ele.local_simpletype
      basetype_class(ele.local_simpletype.base)
    else
      nil
    end
  end

  def attribute_basetype(attr)
    if type = basetype_class(attr.type)
      type
    elsif attr.local_simpletype
      basetype_class(attr.local_simpletype.base)
    else
      nil
    end
  end

  def basetype_class(type)
    if simpletype = @simpletypes[type]
      basetype_mapped_class(simpletype.base)
    else
      basetype_mapped_class(type)
    end
  end

  def define_attribute(c, attributes)
    schema_attribute = []
    attributes.each do |attribute|
      name = attribute.name.name
      if basetype = attribute_basetype(attribute)
        type = basetype.name
      else
        type = nil
      end
      varname = safevarname('attr_' + name)
      c.def_method(varname) do <<-__EOD__
          (@__soap_attribute ||= {})[#{name.dump}]
        __EOD__
      end
      c.def_method(varname + '=', 'value') do <<-__EOD__
          (@__soap_attribute ||= {})[#{name.dump}] = value
        __EOD__
      end
      schema_attribute << [name, type]
    end
    c.def_classvar('schema_attribute',
      '{' +
        schema_attribute.collect { |name, type|
          name.dump + ' => ' + ndq(type)
        }.join(', ') +
      '}'
    )
  end

  def dump_arraydef(complextype)
    qname = complextype.name
    c = XSD::CodeGen::ClassDef.new(create_class_name(qname), '::Array')
    c.comment = "#{qname.namespace}"
    type = complextype.child_type
    c.def_classvar('schema_type', type.name.dump)
    c.def_classvar('schema_ns', type.namespace.dump)
    c.dump
  end
end


end
end
