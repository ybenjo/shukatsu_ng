#! ruby -Ku
# -*- coding: utf-8 -*-
require 'kconv'
require 'open-uri'
require 'yaml'
require 'logger'
require 'rubygems'
require 'mechanize'
require 'nokogiri'
require 'hpricot'

class Minshu
  #コンストラクタ
  def initialize()
    
    @category_es = Hash.new{|h,k|h[k] = Array.new}
    @category_url = Hash.new
    @retry_count = 0
    
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
  def _raise_error(e, method_name)
    @retry_count += 1
    @log.error("Failed to #{method_name}.")
    @log.error(e.inspect)
    if @retry_count > @retry_limit
      @log.error("Too many errors!")
      exit()
    else
      sleep(30)
    end
  end

  def _login
    begin
      @page = @agent.get("https://www.nikki.ne.jp/a/login/")
      @page.encoding = "UTF-8"
      
      #フォームに入力
      login_form = @page.forms[3]
      login_form['u'] = @id
      login_form['p'] = @pass

      #フォームのボタンを押す感じ
      @page = @agent.submit(login_form)
    rescue Mechanize::ResponseCodeError , Timeout::Error , SocketError => e
      _raise_error(e, __method__)
      _login
    end
  end

  def _get_category_url
    begin
      large_category = ["10","20","30","40","50"]
      
      large_category.each do |i|
        doc = Hpricot(open("http://www.nikki.ne.jp/bbs/#{i}/").read)
        (doc/"li.onCategory"/:a).each do |c|
          url = c["href"]
          category = c.inner_text.toutf8
          puts "#{category} - #{url}"
          @category_url[category] = "http://www.nikki.ne.jp" + url
        end
        sleep(5)
      end
    rescue Timeout::Error => e
      _raise_error(e, __method__)
      _get_category_url
    end
  end

  def _get_each_company_id(url)
    begin
      company_id = [ ]
      doc = Hpricot(open(url).read)

      (doc/"ol.high"/:a).each do |e|
        if e["href"] =~ /\/bbs\/(\d+)\/$/
          company_id.push $1
        end
      end
      
      (doc/"ol.low"/:a).each do |e|
        if e["href"] =~ /\/bbs\/(\d+)\/$/
          company_id.push $1
        end
      end
      return company_id
    rescue Timeout::Error => e
      _raise_error(e, __method__)
      _get_each_company_url(url)
    end
  end

  def get_text(id, year, category)
    begin
      url = "http://www.nikki.ne.jp/?action=bbs&subaction=es_view&pid=#{id}&grad_yyyy=#{year}"
      @page = @agent.get(url)
      @page.encoding = "UTF-8"
      
      (Hpricot(@page.body)/"div#es").each do |elem|
        elem.inner_html.toutf8.gsub("\n", "").scan(/(by #{year}年卒業 (<!--.*?-->)?<\/font><br \/><br \/>(.*?)<br \/><br \/><hr size="1"){1,}/).each do |txt|
          @category_es[category].push  txt[2].gsub(/<br \/>/, "").gsub(/\t/, "")
        end
      end
    rescue Timeout::Error => e
      _raise_error(e,  __method__)
      get_text(comp_id, year, category)
    end
  end


  def get_entry_sheet
    _get_category_url
    @category_url.each do |category, url|
      _get_each_company_id(url).each do |id|
        ["2005", "2006", "2007", "2008", "2009", "2010"].each do |year|
          puts "#{category} - #{year} - #{id}"
          get_text(id, year, category)
          sleep(7)
        end
      end
      _save_data(category)
    end
  end

  def _save_data(category)
    open("./data/es_about_#{category.delete("/")}.txt","w"){|f|
      f.puts @category_es[category]
    }
  end
  
end


if __FILE__ == $0
  m = Minshu.new()
  #m._get_category_url
  #m._get_each_company_id("http://www.nikki.ne.jp/bbs/12/")
  #m.get_entry_sheet
end
