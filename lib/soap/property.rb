# soap/property.rb: SOAP4R - Property implementation.
# Copyright (C) 2003  NAKAMURA, Hiroshi <nahi@ruby-lang.org>.

# This program is copyrighted free software by NAKAMURA, Hiroshi.  You can
# redistribute it and/or modify it under the same terms of Ruby's license;
# either the dual license version in 2003, or any later version.


module SOAP


class Property
  include Enumerable

  # Property file format:
  #   line separator is \r?\n.  1 line per a property.
  #   line which begins with '#' is comment line.  empty line is ignored.
  #   key/value separator is ':', '=', or \s.
  #   '\' as escape character.  but line separator cannot be escaped.
  #   \s at the head/tail of key/value are trimmed.
  def self.load(stream)
    prop = new
    stream.each_with_index do |line, lineno|
      line.sub!(/\r?\n\z/, '')
      next if /^(#.*|)$/ =~ line
      if /^\s*([^=:\s\\]+(?:\\.[^=:\s\\]*)*)\s*[=:\s]\s*(.*)$/ =~ line
	key, value = $1, $2
	key = eval("\"#{key}\"")
	value = eval("\"#{value.strip}\"")
	prop[key] = value
      else
	raise TypeError.new("property format error at line #{lineno + 1}: `#{line}'")
      end
    end
    prop
  end

  def self.open(filename)
    File.open(filename) do |f|
      load(f)
    end
  end

  def self.loadproperty(propname)
    $:.each do |path|
      if File.file?(file = File.join(path, propname))
	return open(file)
      end
    end
    nil
  end

  def initialize
    @store = Hash.new
    @hook = Hash.new
    @self_hook = Array.new
    @locked = false
  end

  # name: a Symbol, String or an Array
  def [](name)
    referent(name_to_a(name))
  end

  # name: a Symbol, String or an Array
  # value: an Object
  def []=(name, value)
    hooks = assign(name_to_a(name), value)
    normalized_name = normalize_name(name)
    hooks.each do |hook|
      hook.call(normalized_name, value)
    end
    value
  end

  # value: an Object
  # key is generated by property
  def <<(value)
    self[generate_new_key] = value
  end

  # name: a Symbol, String or an Array.  nil means hook to the root.
  # hook: block which will be called with 2 args, name and value
  def add_hook(name = nil, &hook)
    if name.nil?
      assign_self_hook(hook)
    else
      assign_hook(name_to_a(name), hook)
    end
  end

  def each
    @store.each do |key, value|
      yield(key, value)
    end
  end

  def empty?
    @store.empty?
  end

  def keys
    @store.keys
  end

  def values
    @store.values
  end

  def lock(cascade = false)
    if cascade
      each_key do |key|
	key.lock(cascade)
      end
    end
    @locked = true
    self
  end

  def unlock(cascade = false)
    @locked = false
    if cascade
      each_key do |key|
	key.unlock(cascade)
      end
    end
    self
  end

  def locked?
    @locked
  end

protected

  def referent(ary)
    key, rest = location_pair(ary)
    if rest.empty?
      local_referent(key)
    else
      deref_key(key).referent(rest)
    end
  end

  def assign(ary, value)
    key, rest = location_pair(ary)
    if rest.empty?
      local_assign(key, value)
      local_hook(key)
    else
      local_hook(key) + deref_key(key).assign(rest, value)
    end
  end

  def assign_hook(ary, hook)
    key, rest = location_pair(ary)
    if rest.empty?
      local_assign_hook(key, hook)
    else
      deref_key(key).assign_hook(rest, hook)
    end
  end

  def assign_self_hook(hook)
    check_lock(nil)
    @self_hook << hook
  end

private

  def each_key
    self.each do |key, value|
      if propkey?(value)
	yield(value)
      end
    end
  end

  def deref_key(key)
    check_lock(key)
    ref = @store[key] ||= self.class.new
    unless propkey?(ref)
      raise ArgumentError.new("key `#{key}' already defined as a value")
    end
    ref
  end

  def local_referent(key)
    check_lock(key)
    if propkey?(@store[key]) and @store[key].locked?
      raise TypeError.new("cannot split any key from locked property")
    end
    @store[key]
  end

  def local_assign(key, value)
    check_lock(key)
    if @locked
      if propkey?(value)
	raise TypeError.new("cannot add any key to locked property")
      elsif propkey?(@store[key])
	raise TypeError.new("cannot override any key in locked property")
      end
    end
    @store[key] = value
  end

  def local_assign_hook(key, hook)
    check_lock(key)
    @store[key] ||= nil
    (@hook[key] ||= []) << hook
  end

  NO_HOOK = [].freeze
  def local_hook(key)
    @self_hook + (@hook[key] || NO_HOOK)
  end

  def check_lock(key)
    if @locked and (key.nil? or !@store.key?(key))
      raise TypeError.new("cannot add any key to locked property")
    end
  end

  def propkey?(value)
    value.is_a?(::SOAP::Property)
  end

  def name_to_a(name)
    case name
    when Symbol
      [name]
    when String
      name.scan(/[^.\\]+(?:\\.[^.\\])*/)	# split with unescaped '.'
    when Array
      name
    else
      raise ArgumentError.new("Unknown name #{name}(#{name.class})")
    end
  end

  def location_pair(ary)
    name, *rest = *ary
    key = to_key(name)
    return key, rest
  end

  def normalize_name(name)
    name_to_a(name).collect { |key| to_key(key) }.join('.')
  end

  def to_key(name)
    name.to_s.downcase
  end

  def generate_new_key
    if @store.empty?
      "0"
    else
      (key_max + 1).to_s
    end
  end

  def key_max
    (@store.keys.max { |l, r| l.to_s.to_i <=> r.to_s.to_i }).to_s.to_i
  end
end


end
