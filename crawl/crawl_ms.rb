require 'rubygems'
require 'mechanize'
require 'hpricot'

agent = WWW::Mechanize.new
login_page = agent.get("https://www.nikki.ne.jp/a/login/")
