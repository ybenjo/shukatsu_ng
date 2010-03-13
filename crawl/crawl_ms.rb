#! ruby -Ku
# -*- coding: utf-8 -*-

require 'kconv'
require 'rubygems'
require 'mechanize'
require 'hpricot'

class Minshu
  def initialize(path)
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

  def get
  end
  
end

if __FILE__ == $0
  m = Minshu.new(File.dirname(__FILE__))
end
