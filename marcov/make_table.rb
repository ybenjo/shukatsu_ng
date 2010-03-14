# -*- coding: utf-8 -*-
require 'rubygems'
require 'MeCab'

class Marcov_table
  def initialize(file,n)
    @text = []
    open(file).each do |l|
      @text.push l.chomp!
    end
    @tagger = MeCab::Tagger.new(ARGV.join(" "))
    @table = Hash.new{|h,k|h[k] = Hash.new{|i,j|i[j] = 0}}
    @n = n
  end

  def _split(str)
    split_str = @tagger.parseToNode(str)
    words = []
    1.upto(@n-1) do |i|
      words.push ":head#{i}"
    end
    while split_str do 
      words.push split_str.surface unless split_str.surface == ""
      split_str = split_str.next
    end
    words.push ":eos"
    return words
  end

  def set_table(words)
    words.each_cons(@n) do |e|
      @table[e[0..-2]][e[-1]] += 1
    end
  end

  def calc
    @text.each do |str|
      set_table(_split(str))
    end
  end

  def _calc_prob(word)
    list = @table[word]
    prob = Hash.new{|h,k|h[k] = 0.0}
    total = list.values.inject(0.0){|s,v|s += v}
    sum = 0.0
    list.each_pair do |k,v|
      prob[k] = [sum, sum + v / total]
      sum += v / total
    end
    return prob
  end

  def _get_next_word(word)
    prob = _calc_prob(word)
    r = rand()
    ret = ""
    prob.each_pair do |w,count|
      ret = w if count[0] <= r && count[1] > r
    end
    return ret
  end

  def make_sentence
    sentence = ""

    w = []
    1.upto(@n-1) do |i|
      w.push ":head#{i}"
    end
    
    next_word = ""
    e = ""

    while w[0].to_s != ":eos"
      sentence = sentence + w[0].to_s
      ret =  _get_next_word(w)
      w = w[1..-1]
      w.push ret
    end
    puts sentence.gsub(/\:head\d/,"")
  end
end


a = Marcov_table.new("../crawl/data/ALL.txt",5)
a.calc

3.times do
  a.make_sentence
  puts "-------------------"
end
