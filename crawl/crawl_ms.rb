#! ruby -Ku
# -*- coding: utf-8 -*-

require 'kconv'
require 'rubygems'
require 'mechanize'
require 'hpricot'
require 'open-uri'

class Minshu
  def initialize(path)

    @c_es = Hash.new{|h,k|h[k] = ""}
    @c_url = Hash.new{ }
    
    @agent = WWW::Mechanize.new
    # @agent.user_agent_alias = 'Mac Safari'
    
    @page = @agent.get("https://www.nikki.ne.jp/a/login/")
    @page.encoding = "UTF-8"
    
    open("#{path}/config") do |f|
      @id = f.gets.chomp
      @pass = f.gets.chomp
    end
    _login
  end

  def _login
    login_form = @page.forms[3]
    login_form['u'] = @id.toutf8
    login_form['p'] = @pass.toutf8
    @page = @agent.submit(login_form)
    #リダイレクトを待つのがわからないので
    @page = @agent.get("https://www.nikki.ne.jp/a/login/")
    @page.encoding = "UTF-8"
  end

  def get_text(target_url, category)
    # doc = Hpricot(open(target_url).read)
    @page = @agent.get(target_url)
    @page.encoding = "UTF-8"

    year = target_url.scan(/&grad_yyyy=(\d+)$/)[0][0]
        
    (Hpricot(@page.body)/"div#es").each do |elem|
      elem.inner_html.toutf8.scan(/(by\s#{year}年卒業\s<!--.*?--><\/font>(.+?)<hr size=\"1\" color=\"#cccccc\"){1,}/).each do |txt|
        @c_es[category] += txt[1].delete("<br />")
      end
    end
  end

  def _get_category_url
    large_category = ["10","20","30","40","50"]
    
    large_category.each do |i|
      doc = Hpricot(open("http://www.nikki.ne.jp/bbs/#{i}/").read)
      (doc/"li.onCategory"/"ul.smallCategory"/"li"/:a).each do |c|
        url = c["href"]
        category = c.inner_text.toutf8
        @c_url[category] = "http://www.nikki.ne.jp" + url
      end
    end
  end

  def _get_each_company_url(url)
    ret = [ ]
    doc = Hpricot(open(url).read)
    
    (doc/"ol.high"/:li/:a).each do |e|
      ret.push e["href"] if e["href"] =~ /bbs/
    end

    (doc/"ol.low"/:li/:a).each do |e|
      ret.push e["href"] if e["href"] =~ /bbs/
    end
    
    p ret
  end

  
end


if __FILE__ == $0
  m = Minshu.new(File.dirname(__FILE__))
  #m.get_text("http://www.nikki.ne.jp/?action=bbs&subaction=es_view&pid=6702&grad_yyyy=2010",:eeee)
  #m._get_category_url
  #m._get_each_company_url("http://www.nikki.ne.jp/bbs/12/")
end
