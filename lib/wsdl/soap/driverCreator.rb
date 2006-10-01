# WSDL4R - Creating driver code from WSDL.
# Copyright (C) 2002, 2003, 2005, 2006  NAKAMURA, Hiroshi <nahi@ruby-lang.org>.

# This program is copyrighted free software by NAKAMURA, Hiroshi.  You can
# redistribute it and/or modify it under the same terms of Ruby's license;
# either the dual license version in 2003, or any later version.


require 'wsdl/info'
require 'wsdl/soap/mappingRegistryCreator'
require 'wsdl/soap/methodDefCreator'
require 'wsdl/soap/classDefCreatorSupport'
require 'xsd/codegen'


module WSDL
module SOAP


class DriverCreator
  include ClassDefCreatorSupport

  attr_reader :definitions

  def initialize(definitions, modulepath = nil)
    @definitions = definitions
    @modulepath = modulepath
  end

  def dump(porttype = nil)
    result = ''
    if @modulepath
      result << "\n"
      @modulepath.each do |name|
        result << "module #{name}\n"
      end
    end
    if porttype.nil?
      @definitions.porttypes.each do |type|
	result << dump_porttype(type.name)
	result << "\n"
      end
    else
      result << dump_porttype(porttype)
    end
    if @modulepath
      result << "\n"
      @modulepath.each do |name|
        result << "end\n"
      end
    end
    result
  end

private

  def dump_porttype(porttype)
    class_name = create_class_name(porttype)
    result = MethodDefCreator.new(@definitions, @modulepath).dump(porttype)
    methoddef = result[:methoddef]
    binding = @definitions.bindings.find { |item| item.type == porttype }
    if binding.nil? or binding.soapbinding.nil?
      # not bind or not a SOAP binding
      return ''
    end
    address = @definitions.porttype(porttype).locations[0]

    c = XSD::CodeGen::ClassDef.new(class_name, "::SOAP::RPC::Driver")
    c.def_require("soap/rpc/driver")
    c.def_const("DefaultEndpointUrl", ndq(address))
    c.def_code <<-EOD
Methods = [
#{methoddef.gsub(/^/, "  ")}
]
    EOD
    wsdl_name = @definitions.name ? @definitions.name.name : 'default'
    mrname = safeconstname(wsdl_name + 'MappingRegistry')
    c.def_method("initialize", "endpoint_url = nil") do
      %Q[endpoint_url ||= DefaultEndpointUrl\n] +
      %Q[super(endpoint_url, nil)\n] +
      %Q[self.mapping_registry = #{mrname}::EncodedRegistry\n] +
      %Q[self.literal_mapping_registry = #{mrname}::LiteralRegistry\n] +
      %Q[init_methods]
    end
    c.def_privatemethod("init_methods") do
      <<-EOD
        Methods.each do |definitions|
          opt = definitions.last
          if opt[:request_style] == :document
            add_document_operation(*definitions)
          else
            add_rpc_operation(*definitions)
            qname = definitions[0]
            name = definitions[2]
            if qname.name != name and qname.name.capitalize == name.capitalize
              ::SOAP::Mapping.define_singleton_method(self, qname.name) do |*arg|
                __send__(name, *arg)
              end
            end
          end
        end
      EOD
    end
    c.dump
  end
end


end
end
