=begin
SOAP4R - Charset encoding handler.
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


module SOAP


module Charset
  public

  ###
  ## Maps
  #
  EncodingConvertMap = {}
  def setEncodingConvertMap
    trueProc = Proc.new { |str| true }
    begin
      require 'nkf'
      EncodingConvertMap[ [ 'EUC' , 'SJIS' ] ] = [
	trueProc,
	Proc.new { |str| NKF.nkf( '-sXm0', str ) }
      ]
      EncodingConvertMap[ [ 'SJIS', 'EUC'  ] ] = [
	trueProc,
	Proc.new { |str| NKF.nkf( '-eXm0', str ) }
      ]
    rescue LoadError
    end
  
    begin
      require 'nkf'
      require 'uconv'
      EncodingConvertMap[ [ 'UTF8', 'EUC'  ] ] = [
	trueProc,
	Uconv.method( :u8toeuc )
      ]
      EncodingConvertMap[ [ 'UTF8', 'SJIS' ] ] = [
	trueProc,
	Uconv.method( :u8tosjis )
      ]

      # Original regexps: http://www.din.or.jp/~ohzaki/perl.htm
      # ascii_euc = '[\x00-\x7F]'
      ascii_euc = '[\x9\xa\xd\x20-\x7F]'	# XML 1.0 restricted.
      twoBytes_euc = '(?:[\x8E\xA1-\xFE][\xA1-\xFE])'
      threeBytes_euc = '(?:\x8F[\xA1-\xFE][\xA1-\xFE])'
      character_euc = "(?:#{ ascii_euc }|#{ twoBytes_euc }|#{ threeBytes_euc })"
      # oneByte_sjis = '[\x00-\x7F\xA1-\xDF]'
      oneByte_sjis = '[\x9\xa\xd\x20-\x7F\xA1-\xDF]'	# XML 1.0 restricted.
      twoBytes_sjis = '(?:[\x81-\x9F\xE0-\xFC][\x40-\x7E\x80-\xFC])'
      character_sjis = "(?:#{ oneByte_sjis }|#{ twoBytes_sjis })"

      eucRegexp = Regexp.new( "\A#{ character_euc }*\z", nil, "NONE" )
      sjisRegexp = Regexp.new( "\A#{ character_sjis }*\z", nil, "NONE" )

      EncodingConvertMap[ [ 'EUC' , 'UTF8' ] ] = [
	Proc.new { |str| eucRegexp =~ str },
	Uconv.method( :euctou8 )
      ]
      EncodingConvertMap[ [ 'SJIS', 'UTF8' ] ] = [
	Proc.new { |str| sjisRegexp =~ str },
	Uconv.method( :sjistou8 )
      ]
    rescue LoadError
    end

    # ToDo: Iconv support
  end
  module_function :setEncodingConvertMap
  self.setEncodingConvertMap

  CharsetMap = {
    'NONE' => 'us-ascii',
    'EUC' => 'euc-jp',
    'SJIS' => 'shift_jis',
    'UTF8' => 'utf-8',
  }


  ###
  ## handlers
  #
  Encoding = [ $KCODE, $KCODE ]
  def setEncoding( encoding = $KCODE )
    Encoding[ 0 ] = encoding
  end
  module_function :setEncoding

  def getEncoding
    Encoding[ 0 ]
  end
  module_function :getEncoding

  def setXMLInstanceEncoding( streamEncoding = $KCODE )
    Encoding[ 1 ] = streamEncoding
  end
  module_function :setXMLInstanceEncoding

  def getXMLInstanceEncoding
    Encoding[ 1 ]
  end
  module_function :getXMLInstanceEncoding

  def encodingToXML( str )
    codeConv( str, getEncoding, getXMLInstanceEncoding )
  end
  module_function :encodingToXML

  def encodingFromXML( str )
    codeConv( str, getXMLInstanceEncoding, getEncoding )
  end
  module_function :encodingFromXML

  def codeConv( str, encFrom, encTo )
    retStr = str
    if encFrom == 'NONE' or encTo == 'NONE'
      return retStr
    end
    if m = EncodingConvertMap[ [ encFrom, encTo ] ]
      guard, convert = m
      if guard.call( str )
	retStr = convert.call( str )
      end
    end
    retStr
  end
  module_function :codeConv

  def getXMLInstanceEncodingLabel
    getCharsetLabel( getXMLInstanceEncoding )
  end
  module_function :getXMLInstanceEncodingLabel

  def getCharsetLabel( encoding )
    CharsetMap[ encoding ]
  end
  module_function :getCharsetLabel

  def getCharsetStr( label )
    CharsetMap.index( label ) || 'NONE'
  end
  module_function :getCharsetStr
end


end
