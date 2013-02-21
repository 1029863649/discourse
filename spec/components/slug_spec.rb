# encoding: utf-8

require 'spec_helper'
require 'slug'

describe Slug do

  it 'replaces spaces with hyphens' do
    Slug.for("hello world").should == 'hello-world'
  end

  it 'changes accented characters' do
    Slug.for('àllo').should == 'allo'
  end

  it 'replaces symbols' do
    Slug.for('evil#trout').should == 'evil-trout'
  end

  it 'handles a.b.c properly' do
    Slug.for("a.b.c").should == "a-b-c"
  end

  it 'handles double dots right' do
    Slug.for("a....b.....c").should == "a-b-c"
  end

  it 'strips trailing punctuation' do
    Slug.for("hello...").should == "hello"
  end

  it 'strips leading punctuation' do
    Slug.for("...hello").should == "hello"
  end

  it 'handles our initial transliteration' do
    from = "àáäâčďèéëěêìíïîľĺňòóöôŕřšťůùúüûýžñç"
    to   = "aaaacdeeeeeiiiillnoooorrstuuuuuyznc"
    Slug.for(from).should == to
  end

  it 'replaces underscores' do
    Slug.for("o_o_o").should == "o-o-o"
  end

  it 'processes cyrillic letters in :ru locale' do
    I18n.locale = :ru
    Slug.for("первый пост").should == "pervyy-post"
    I18n.locale = :en
  end
end

