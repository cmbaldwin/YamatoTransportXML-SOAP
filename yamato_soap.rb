## Yamato SOAP
# A simple example client for retrieving data from Yamato transport's XMP/SOAP API service.
# ヤマト運輸のXMP/SOAP APIサービスからデータを取得するための簡単なサンプルクライアント
##
# This uses the ヤマト運輸　XML荷物検索データ交換
# PDF with rules can be found here: https://webinter-consistent2.kuronekoyamato.co.jp/consistent2web/XML-InterFace_for_Corporation.pdf
# For our online shop (built in Solidus) we export orders via CSV and then import them into Yamato's system.
# This shipping slip data contains a column 'search key' which is a unique number for each order, we use this for the 'order_number' method.
# slip_number, order_number and shipping_phone return a Nokogiri::XML object.
# ♪ ヤマトSOAP
# ヤマト運輸のXML荷物検索データ交換専用のSOAPクライアントです。
# ルールのPDFはこちら: https://webinter-consistent2.kuronekoyamato.co.jp/consistent2web/XML-InterFace_for_Corporation.pdf
# オンラインショップ（Solidusで構築）では、注文をCSVでエクスポートし、ヤマトのシステムにインポートしています。
# この配送伝票データには'検索キー'(例：受注番号)という列があり, これは各注文に対してユニークな番号なので, 'order_number' メソッドにこれを利用します.
# slip_number、order_number、shipping_phoneはNokogiri::XMLオブジェクトを返す。

class YamatoSOAP
  require 'net/http'

  attr_reader :doc, :res, :params

  def initialize
    @url = URI.parse('https://inter-consistent2.kuronekoyamato.co.jp/consistent2/cts')
    @request = Net::HTTP::Post.new(@url)
    request_headers
    @doc = ''
    @res = ''
  end

  def request_headers
    @request.add_field('Content-Type', 'application/soap+xml; charset=UTF-8')
    @request.add_field('SOAPAction', 'ClientReception')
    @request.add_field('urn', 'ClientReception')
    @request.add_field('Method-Name', 'provideXMLTraceService')
  end

  def parse_response(response)
    return unless response

    nested_xml = response.xpath('//provideXMLTraceServiceReturn')
    xml = Nokogiri::XML(nested_xml.text)

    return "Error: #{xml.text}" if xml.text.include?('エラー')

    xml
  end

  def slip_number(slip_number)
    @request.body = slip_number_body(slip_number)
    @res = make_request
    parse_response(@res)
  end

  def order_number(order)
    @request.body = order_number_body(order)
    @res = make_request
    parse_response(@res)
  end

  def shipping_phone(phone)
    @request.body = shipping_phone_body(phone)
    @res = make_request
    parse_response(@res)
  end

  def make_request
    @res = Net::HTTP.start(@url.hostname, @url.port, { use_ssl: true }) { |http| http.request(@request) }
    @doc = Nokogiri::XML(@res.body)
    @doc
  end

  def header
    "<soapenv:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:ct=\"http://ct\">
    <soapenv:Header/>
    <soapenv:Body>
    <ct:provideXMLTraceService soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">
    <requestXML xsi:type=\"xsd:string\">&lt;?xml version=&quot;1.0&quot; encoding=&quot;UTF-8&quot;?&gt;"
  end

  def shop_login
    "&lt;基本情報&gt;
    &lt;IPアドレス&gt;#{ENV['IP']}&lt;/IPアドレス&gt;
    &lt;顧客コード&gt;#{ENV['YAMATO_ID']}&lt;/顧客コード&gt;
    &lt;顧客コード枝番&gt;&lt;/顧客コード枝番&gt;
    &lt;パスワード&gt;#{ENV['YAMATO_PASS']}&lt;/パスワード&gt;
    &lt;/基本情報&gt;"
  end

  def search_options(search_type, display_flag)
    "&lt;検索オプション&gt;
    &lt;検索区分&gt;#{search_type}&lt;/検索区分&gt;
    &lt;届け先情報表示フラグ&gt;#{display_flag}&lt;/届け先情報表示フラグ&gt;
    &lt;/検索オプション&gt;"
  end

  def footer
    "</requestXML>
    </ct:provideXMLTraceService>
    </soapenv:Body>
    </soapenv:Envelope>"
  end

  def slip_number_body(slip_number)
    "#{header}
    &lt;問合せ要求&gt;
    #{shop_login}
    #{search_options('01', '1')}
    &lt;検索条件&gt;
    &lt;伝票番号&gt;#{slip_number}&lt;/伝票番号&gt;
    &lt;/検索条件&gt;
    &lt;/問合せ要求&gt;
    #{footer}"
  end

  def order_number_body(order)
    "#{header}
    &lt;問合せ要求&gt;
    #{shop_login}
    #{search_options('02', '1')}
    &lt;検索条件&gt;
    &lt;検索キータイトル&gt;受注番号&lt;/検索キータイトル&gt;
    &lt;検索キー&gt;#{order.number}&lt;/検索キー&gt;
    &lt;/検索条件&gt;
    &lt;/問合せ要求&gt;
    #{footer}"
  end

  def shipping_phone_body(phone)
    "#{header}
    &lt;問合せ要求&gt;
    #{shop_login}
    #{search_options('02', '1')}
    &lt;検索条件&gt;
    &lt;お届け先電話番号&gt;#{phone}&lt;/お届け先電話番号&gt;
    &lt;/検索条件&gt;
    &lt;/問合せ要求&gt;
    #{footer}"
  end
end
