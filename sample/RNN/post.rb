#!/usr/bin/env ruby -Ke


# RNN��SOAP�����ӥ������Ѥ��륵��ץ�Ǥ����ƥ��ȵ������Ф��륳���Ȥ�
# ��Ƥ��ޤ����¹Ԥ������ˡ�
# http://cvs.sourceforge.jp/cgi-bin/viewcvs.cgi/*checkout*/rnn/rnn/doc/articles/xmlrpc.txt
# �����
# http://rwiki.jin.gr.jp/cgi-bin/rw-cgi.rb?cmd=view;name=RNN%A4%C8SOAP4R%A4%C7%CD%B7%A4%DC%A4%A6
# �򻲾Ȥ��Ƥ���������


require 'soap/wsdlDriver'
wsdl = 'http://cvs.sourceforge.jp/cgi-bin/viewcvs.cgi/*checkout*/rnn/rnn/app/rnn-hash.wsdl'
rnn = SOAP::WSDLDriverFactory.new(wsdl).createDriver
rnn.generateEncodeType = true
#rnn.setWireDumpDev(STDERR)


test_article_id = 1
POST_COMMENT_DIRECT = 0

subject = "SOAP4R�ˤ��ƥ��� by ̵̾������"
text =<<__EOS__
�ƥ�����ƤǤ���
__EOS__

p rnn.post_comment(test_article_id, POST_COMMENT_DIRECT, subject, text)
