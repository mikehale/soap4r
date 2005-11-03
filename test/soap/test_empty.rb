require 'test/unit'
require 'soap/rpc/standaloneServer'
require 'soap/rpc/driver'


module SOAP


class TestEmpty < Test::Unit::TestCase
  Port = 17171

  class NopServer < SOAP::RPC::StandaloneServer
    def initialize(*arg)
      super
      add_document_method(self, 'urn:empty:nop',  'nop', [], [])
      add_document_method(self, 'urn:empty:nop',  'nop_nil', nil, nil)
    end

    def nop
      [1, 2, 3] # ignored
    end

    def nop_nil
      [1, 2, 3] # ignored
    end
  end

  def setup
    @server = NopServer.new(self.class.name, nil, '0.0.0.0', Port)
    @server.level = Logger::Severity::ERROR
    @t = Thread.new {
      @server.start
    }
    @endpoint = "http://localhost:#{Port}/"
    @client = SOAP::RPC::Driver.new(@endpoint)
    @client.add_document_method('nop', 'urn:empty:nop', [], [])
    @client.add_document_method('nop_nil', 'urn:empty:nop', nil, nil)
  end

  def teardown
    @server.shutdown
    @t.kill
    @t.join
    @client.reset_stream
  end

  EMPTY_XML = %q[<?xml version="1.0" encoding="utf-8" ?>
<env:Envelope xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    xmlns:env="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <env:Body>
  </env:Body>
</env:Envelope>]

  def test_nop
    @client.wiredump_dev = str = ''
    @client.nop
    assert_equal(EMPTY_XML, parse_requestxml(str))
    assert_equal(EMPTY_XML, parse_responsexml(str))
  end

  def test_nop_nil
    @client.wiredump_dev = str = ''
    @client.nop_nil
    assert_equal(EMPTY_XML, parse_requestxml(str))
    assert_equal(EMPTY_XML, parse_responsexml(str))
  end

  def parse_requestxml(str)
    str.split(/\r?\n\r?\n/)[3]
  end

  def parse_responsexml(str)
    str.split(/\r?\n\r?\n/)[6]
  end
end


end
