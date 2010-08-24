#! ruby -Ku
# -*- coding: utf-8 -*-
require 'kconv'
require 'open-uri'
require 'yaml'
require 'logger'
require 'rubygems'
require 'mechanize'
require 'hpricot'

class Minshu
  def initialize()
    
    @category_es = Hash.new{|h,k|h[k] = ""}
    @category_url = Hash.new
    
    @agent = Mechanize.new
    @agent.user_agent_alias = "Mechanize"

    #設定読み込み
    config = YAML.load_file("./config.yaml")
    @id = config["ID"]
    @pass = config["PASS"]
    @retry_limit = config["LIMIT"] || 5

    #e.g. 2010-09-01-12-00.log
    @log = Logger.new("./data/logs/#{Time.now.strftime("%Y-%m-%d-%H-%M")}.log")
    
    _login
  end

  #エラーが起こった時のlog出力
  #ついでにリトライ制限判定
  def _raise_error(e, method_name, try)
    @log.fatal("Failed to #{method_name}.")
    @log.fatal(e.inspect)
    if try > @retry_limit
      @log.fatal("Too many errors!")
      exit()
    else
      sleep(20)
    end
  end

  def _login(try = 1)
    begin
      @page = @agent.get("https://www.nikki.ne.jp/a/login/")
      @page.encoding = "UTF-8"
      
      #フォームに入力
      login_form = @page.forms[3]
      login_form['u'] = @id
      login_form['p'] = @pass

      #フォームのボタンを押す感じ
      @page = @agent.submit(login_form)
      sleep(2)
      
      #リダイレクトを追ってくれない
      #かつ「自動的に移動しないときはこちら」のようなリンクも存在しないので
      @page = @agent.get("https://www.nikki.ne.jp/a/login/")
      @page.encoding = "UTF-8"
      @log.info("Successfully Login.")
    rescue Mechanize::ResponseCodeError , Timeout::Error , SocketError => e
      _raise_error(e, __method__, try)
      _login(try + 1)
    end
  end

  def get_text(target_url, category, try = 1)
    begin
      @page = @agent.get(target_url)
      @page.encoding = "UTF-8"
      
      year = target_url.scan(/&grad_yyyy=(\d+)$/)[0][0]
      
      (Hpricot(@page.body)/"div#es").each do |elem|
        #elem.inner_html.toutf8.scan(/(by\s#{year}年卒業\s<!--.*?--><\/font>(.+?)<hr size=\"1\" color=\"#cccccc\"){1,}/).each do |txt|
        elem.inner_html.toutf8.scan(/(by\s#{year}年卒業\s<!--.*?--><\/font>(.+?)<hr size="1" color="#cccccc"){1,}/).each do |txt|
          @category_es[category] += txt[1].gsub(/<br \/>/, "").gsub(/\t/, "").gsub(/\n/, "") + "\n"
        end
      end
    rescue Timeout::Error => e
      _raise_error(e, "get_text", try)
      get_text(target_url, __method__, try+1)
    end
  end

  def _get_category_url(try = 1)
    begin
      large_category = ["10","20","30","40","50"]
      
      large_category.each do |i|
        doc = Hpricot(open("http://www.nikki.ne.jp/bbs/#{i}/").read)
        (doc/"li.onCategory"/"ul.smallCategory"/"li"/:a).each do |c|
          url = c["href"]
          category = c.inner_text.toutf8
          @category_url[category] = "http://www.nikki.ne.jp" + url
        end
        sleep(5)
      end
    rescue Timeout::Error => e
      _raise_error(e, __method__, try)
      _get_category_url(try + 1)
    end
  end

  def _get_each_company_url(url, try = 1)
    begin
      ret = [ ]
      doc = Hpricot(open(url).read)
      
      (doc/"ol.high"/:li/:a).each do |e|
        ret.push e["href"] if e["href"] =~ /bbs/
      end
      
      (doc/"ol.low"/:li/:a).each do |e|
        ret.push e["href"] if e["href"] =~ /bbs/
      end
      return ret
    rescue Timeout::Error => e
      _raise_error(e, __method__, try)
      _get_each_company_url(url, try + 1)
    end
  end

  def _scan_url(url)
    comp_id = url.scan(/\/bbs\/(\d+)\/$/)
    return "http://www.nikki.ne.jp/?action=bbs&subaction=es_view&pid=#{comp_id}&grad_yyyy="
  end

  def get_entry_sheet
    _get_category_url
    @category_url.each do |category, url|
      _get_each_company_url(url).each do |u|
        base_url = _scan_url(u)
        ["2005", "2006", "2007", "2008", "2009", "2010"].each do |year|
          target_url = base_url + year
          puts "#{category} - #{year} - #{target_url}"
          get_text(target_url, category)
          sleep(7)
        end
      end
      _save_data(category)
    end
  end

  def _save_data(category)
    f = open("./data/es_about_#{category.delete("/")}.txt","w")
    f.puts @category_es[category]
    f.close
  end
  
end


if __FILE__ == $0
  m = Minshu.new()
  #m.get_text("http://www.nikki.ne.jp/?action=bbs&subaction=es_view&pid=6702&grad_yyyy=2010",:eeee)
  #m._get_category_url
  #m._get_each_company_url("http://www.nikki.ne.jp/bbs/12/")
  #m.get_entry_sheet
end
