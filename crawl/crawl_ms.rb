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

  def search_url
  end

  
end


if __FILE__ == $0
  m = Minshu.new(File.dirname(__FILE__))
  #m.get_text("http://www.nikki.ne.jp/?action=bbs&subaction=es_view&pid=6702&grad_yyyy=2010",:eeee)
end
