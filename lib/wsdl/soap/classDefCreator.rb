# WSDL4R - Creating class definition from WSDL
# Copyright (C) 2002-2006  NAKAMURA, Hiroshi <nahi@ruby-lang.org>.

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
  include XSD::CodeGen

  def initialize(definitions, modulepath = nil)
    @definitions = definitions
    @modulepath = modulepath
    @elements = definitions.collect_elements
    @elements.uniq!
    @attributes = definitions.collect_attributes
    @attributes.uniq!
    @simpletypes = definitions.collect_simpletypes
    @simpletypes.uniq!
    @complextypes = definitions.collect_complextypes
    @complextypes.uniq!
    @faulttypes = nil
    if definitions.respond_to?(:collect_faulttypes)
      @faulttypes = definitions.collect_faulttypes
    end
  end

  def dump(type = nil)
    result = "require 'xsd/qname'\n"
    if @modulepath
      result << "\n"
      result << @modulepath.collect { |ele| "module #{ele}" }.join("; ")
      result << "\n\n"
    end
    if type
      result << dump_classdef(type.name, type)
    else
      str = dump_element
      unless str.empty?
        result << "\n" unless result.empty?
        result << str
      end
      str = dump_attribute
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
    if @modulepath
      result << "\n\n"
      result << @modulepath.collect { |ele| "end" }.join("; ")
      result << "\n"
    end
    result
  end

private

  def dump_element
    @elements.collect { |ele|
      if ele.local_complextype
        qualified = (ele.elementform == 'qualified')
        dump_complextypedef(ele.name, ele.local_complextype, qualified)
      elsif ele.local_simpletype
        qualified = (ele.elementform == 'qualified')
        dump_simpletypedef(ele.name, ele.local_simpletype, qualified)
      else
        nil
      end
    }.compact.join("\n")
  end

  def dump_attribute
    @attributes.collect { |attr|
      if attr.local_simpletype
        dump_simpletypedef(attr.name, attr.local_simpletype)
      end
    }.compact.join("\n")
  end

  def dump_simpletype
    @simpletypes.collect { |type|
      dump_simpletypedef(type.name, type)
    }.compact.join("\n")
  end

  def dump_complextype
    @complextypes.collect { |type|
      dump_complextypedef(type.name, type)
    }.compact.join("\n")
  end

  def dump_simpletypedef(qname, simpletype, qualified = false)
    if simpletype.restriction
      dump_simpletypedef_restriction(qname, simpletype, qualified)
    elsif simpletype.list
      dump_simpletypedef_list(qname, simpletype, qualified)
    else
      raise RuntimeError.new("unknown kind of simpletype: #{simpletype}")
    end
  end

  def dump_simpletypedef_restriction(qname, typedef, qualified)
    restriction = typedef.restriction
    if restriction.enumeration.empty?
      # not supported.  minlength?
      return nil
    end
    classname = create_class_name(qname)
    c = ClassDef.new(classname, '::String')
    c.comment = "#{qname}"
    define_classenum_restriction(c, classname, restriction.enumeration)
    c.dump
  end

  def dump_simpletypedef_list(qname, typedef, qualified)
    list = typedef.list
    c = ClassDef.new(create_class_name(qname), '::Array')
    c.comment = "#{qname}"
    if simpletype = list.local_simpletype
      if simpletype.restriction.nil?
        raise RuntimeError.new(
          "unknown kind of simpletype: #{simpletype}")
      end
      define_stringenum_restriction(c, simpletype.restriction.enumeration)
      c.comment << "\n  contains list of #{create_class_name(qname)}::*"
    elsif list.itemtype
      c.comment << "\n  contains list of #{create_class_name(list.itemtype)}::*"
    else
      raise RuntimeError.new("unknown kind of list: #{list}")
    end
    c.dump
  end

  def define_stringenum_restriction(c, enumeration)
    const = {}
    enumeration.each do |value|
      constname = safeconstname(value)
      const[constname] ||= 0
      if (const[constname] += 1) > 1
        constname += "_#{const[constname]}"
      end
      c.def_const(constname, ndq(value))
    end
  end

  def define_classenum_restriction(c, classname, enumeration)
    const = {}
    enumeration.each do |value|
      constname = safeconstname(value)
      const[constname] ||= 0
      if (const[constname] += 1) > 1
        constname += "_#{const[constname]}"
      end
      c.def_const(constname, "#{classname}.new(#{ndq(value)})")
    end
  end

  def dump_simpleclassdef(qname, type_or_element)
    c = ClassDef.new(create_class_name(qname), '::String')
    c.comment = "#{qname}"
    init_lines = []
    unless type_or_element.attributes.empty?
      define_attribute(c, type_or_element.attributes)
      init_lines << "@__xmlattr = {}"
    end
    c.def_method('initialize', '*arg') do
      "super\n" + init_lines.join("\n")
    end
    c.dump
  end

  def dump_complextypedef(qname, type, qualified = false)
    case type.compoundtype
    when :TYPE_STRUCT, :TYPE_EMPTY
      dump_classdef(qname, type, qualified)
    when :TYPE_ARRAY
      dump_arraydef(qname, type)
    when :TYPE_SIMPLE
      dump_simpleclassdef(qname, type)
    when :TYPE_MAP
      # mapped as a general Hash
      nil
    else
      raise RuntimeError.new(
        "unknown kind of complexContent: #{type.compoundtype}")
    end
  end

  def dump_classdef(qname, typedef, qualified = false)
    if @faulttypes and @faulttypes.index(qname)
      c = ClassDef.new(create_class_name(qname), '::StandardError')
    else
      c = ClassDef.new(create_class_name(qname))
    end
    c.comment = "#{qname}"
    c.comment << "\nabstract" if typedef.abstract
    init_lines, init_params =
      parse_elements(c, typedef.elements, qname.namespace)
    unless typedef.attributes.empty?
      define_attribute(c, typedef.attributes)
      init_lines << "@__xmlattr = {}"
    end
    c.def_method('initialize', *init_params) do
      init_lines.join("\n")
    end
    c.dump
  end

  def parse_elements(c, elements, base_namespace)
    init_lines = []
    init_params = []
    any = false
    elements.each do |element|
      case element
      when XMLSchema::Any
        # only 1 <any/> is allowed for now.
        raise RuntimeError.new("duplicated 'any'") if any
        any = true
        attrname = '__xmlele_any'
        c.def_attr(attrname, false, attrname)
        c.def_method('set_any', 'elements') do
          '@__xmlele_any = elements'
        end
        init_lines << "@__xmlele_any = nil"
      when XMLSchema::Element
        name = name_element(element).name
        attrname = safemethodname(name)
        varname = safevarname(name)
        c.def_attr(attrname, true, varname)
        init_lines << "@#{varname} = #{varname}"
        if element.map_as_array?
          init_params << "#{varname} = []"
        else
          init_params << "#{varname} = nil"
        end
      when WSDL::XMLSchema::Sequence
        child_init_lines, child_init_params =
          parse_elements(c, element.elements, base_namespace)
        init_lines.concat(child_init_lines)
        init_params.concat(child_init_params)
      when WSDL::XMLSchema::Choice
        child_init_lines, child_init_params =
          parse_elements(c, element.elements, base_namespace)
        init_lines.concat(child_init_lines)
        init_params.concat(child_init_params)
      else
        raise RuntimeError.new("unknown type: #{element}")
      end
    end
    [init_lines, init_params]
  end

  def element_basetype(ele)
    if klass = basetype_class(ele.type)
      klass
    elsif ele.local_simpletype
      basetype_class(ele.local_simpletype.base)
    else
      nil
    end
  end

  def attribute_basetype(attr)
    if klass = basetype_class(attr.type)
      klass
    elsif attr.local_simpletype
      basetype_class(attr.local_simpletype.base)
    else
      nil
    end
  end

  def basetype_class(type)
    return nil if type.nil?
    if simpletype = @simpletypes[type]
      basetype_mapped_class(simpletype.base)
    else
      basetype_mapped_class(type)
    end
  end

  def define_attribute(c, attributes)
    attributes.each do |attribute|
      name = name_attribute(attribute)
      methodname = safemethodname('xmlattr_' + name.name)
      c.def_method(methodname) do <<-__EOD__
          (@__xmlattr ||= {})[#{dqname(name)}]
        __EOD__
      end
      c.def_method(methodname + '=', 'value') do <<-__EOD__
          (@__xmlattr ||= {})[#{dqname(name)}] = value
        __EOD__
      end
    end
  end

  def name_element(element)
    return element.name if element.name 
    return element.ref if element.ref
    raise RuntimeError.new("cannot define name of #{element}")
  end

  def name_attribute(attribute)
    return attribute.name if attribute.name 
    return attribute.ref if attribute.ref
    raise RuntimeError.new("cannot define name of #{attribute}")
  end

  def dump_arraydef(qname, complextype)
    c = ClassDef.new(create_class_name(qname), '::Array')
    c.comment = "#{qname}"
    c.dump
  end
end


end
end
