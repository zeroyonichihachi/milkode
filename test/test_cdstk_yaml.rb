# -*- coding: utf-8 -*-
#
# @file 
# @brief
# @author ongaeshi
# @date   2011/02/20

require 'test_helper'
require 'milkode/cdstk/cdstk_yaml.rb'
require 'fileutils'

class TestCdstkYaml < Test::Unit::TestCase
  include Milkode

  def setup
    @prev_dir = Dir.pwd
    @tmp_dir = Pathname(File.dirname(__FILE__)) + "tmp"
    FileUtils.rm_rf(@tmp_dir.to_s)
    FileUtils.mkdir_p(@tmp_dir.to_s)
    FileUtils.cd(@tmp_dir.to_s)
  end

  def test_000
    # create
    yaml = CdstkYaml.create
    assert_equal yaml.contents, []
    assert_equal yaml.version, '0.2'
    assert_raise(CdstkYaml::YAMLAlreadyExist) { CdstkYaml.create }

    # load
    yaml = CdstkYaml.load
    assert_equal yaml.contents, []
    assert_equal yaml.version, '0.2'

    # load fail
    FileUtils.mkdir 'loadtest'
    FileUtils.cd 'loadtest' do
      assert_raise(CdstkYaml::YAMLNotExist) { CdstkYaml.load }
    end

    # add
    yaml.add(['dir1'])
    yaml.add(['dir2', 'dir3'])
    assert_equal ['dir1', 'dir2', 'dir3'], yaml.directorys

    # remove
    yaml.add(['dir2', 'dir4', 'dir5'])
    yaml.remove(CdstkYaml::Query.new ['dir5'])
    yaml.remove(CdstkYaml::Query.new ['dir2', 'dir3'])
    assert_equal ['dir1', 'dir4'], yaml.directorys

    # save
    yaml.save
    r = YAML.load(open('milkode.yaml').read)
    assert_equal '0.2', r['version']
    assert_equal([{"directory"=>"dir1", "ignore"=>[]}, {"directory"=>"dir4", "ignore"=>[]}], r['contents'])
  end

  def test_001
    FileUtils.mkdir 'otherpath'
    yaml = CdstkYaml.create('otherpath')
    yaml.save
    
    # save
    r = YAML.load(open('otherpath/milkode.yaml').read)
    assert_equal '0.2', r['version']
    assert_equal([], r['contents'])
  end

  def test_query
    d = 'directory'
    
    contents = [{d => 'key'}, {d => 'keyword'}, {d => 'not'}]

    query = CdstkYaml::Query.new(['key'])
    assert_equal [{d => 'key'}, {d => 'keyword'}], query.select_any?(contents)

    query = CdstkYaml::Query.new(['word'])
    assert_equal [{d => 'keyword'}], query.select_any?(contents)

    contents = [{d => 'a/dir'}, {d => 'b/dia'}]
    query = CdstkYaml::Query.new(['a'])
    assert_equal [{d => 'b/dia'}], query.select_any?(contents) # ディレクトリ名は含めない
  end

  def test_list
    src = <<EOF
version: 0.1
contents: 
- directory: /a/dir1
- directory: /b/dir4
EOF

    yaml = CdstkYaml.new('dummy.yaml', YAML.load(src)) # 自動で0.2にアップグレードされる
    assert_equal [{"directory"=>"/a/dir1", "ignore"=>[]}, {"directory"=>"/b/dir4", "ignore"=>[]}], yaml.list
    assert_equal [{"directory"=>"/b/dir4", "ignore"=>[]}], yaml.list(CdstkYaml::Query.new(['4']))
    assert_equal [], yaml.list(CdstkYaml::Query.new(['a']))
    assert_equal [{"directory"=>"/a/dir1", "ignore"=>[]}, {"directory"=>"/b/dir4", "ignore"=>[]}], yaml.list(nil)
  end

  def test_remove
    src = <<EOF
version: 0.1
contents: 
- directory: /a/dir1
- directory: /b/dir4
EOF

    yaml = CdstkYaml.new('dummy.yaml', YAML.load(src))

    yaml.remove(CdstkYaml::Query.new(['dir4']))
    assert_equal [{"directory"=>"/a/dir1", "ignore"=>[]}], yaml.list

    yaml.remove(CdstkYaml::Query.new(['dir1']))
    assert_equal [], yaml.list

    # ---

    yaml = CdstkYaml.new('dummy.yaml', YAML.load(src))

    yaml.remove(CdstkYaml::Query.new(['dir1']))
    assert_equal [{"directory"=>"/b/dir4", "ignore"=>[]}], yaml.list

    yaml.remove(CdstkYaml::Query.new([]))
    assert_equal [{"directory"=>"/b/dir4", "ignore"=>[]}], yaml.list

  end

  def test_exist
    src = <<EOF
version: 0.1
contents: 
- directory: /a/dir1
- directory: /b/dir12
- directory: /b/dir4
EOF

    yaml = CdstkYaml.new('dummy.yaml', YAML.load(src))

    assert_not_nil yaml.exist?('dir1')
    assert_not_nil yaml.exist?('dir12')
    assert_nil yaml.exist?('dir123')
    assert_nil yaml.exist?('dir')
  end

  def test_package_root
    src = <<EOF
version: 0.1
contents: 
- directory: /a/dir1
- directory: /path/to/dir
- directory: /a/b/c
EOF

    yaml = CdstkYaml.new('dummy.yaml', YAML.load(src))

    assert_equal nil           , yaml.package_root_dir('/not_dir')
    assert_equal "/a/dir1"     , yaml.package_root_dir('/a/dir1/dir3')
    assert_equal nil           , yaml.package_root_dir('/hoge/a/dir1/dir3')
    assert_equal '/path/to/dir', yaml.package_root_dir('/path/to/dir')
  end

  def test_find_content
    src = <<EOF
version: '0.2'
contents: 
- directory: /a/dir1
  ignore: []
- directory: /path/to/dir
  ignore: []
- directory: /a/b/c
  ignore: []
EOF

    yaml = CdstkYaml.new('dummy.yaml', YAML.load(src))
    assert_equal '/a/dir1'           , yaml.find_content('/a/dir1')['directory']
    assert_equal nil                 , yaml.find_content('/a/dir2')
    assert_equal '/path/to/dir'      , yaml.find_content('/path/to/dir')['directory']
    assert_equal '/a/b/c'            , yaml.find_content('/a/b/c')['directory']
  end

  def test_ignore
    src = <<EOF
version: '0.2'
contents: 
- directory: /a/dir1
  ignore: []
- directory: /path/to/dir
  ignore: ['*.bak', '/rdoc']
- directory: /a/b/c
  ignore: []
EOF

    yaml = CdstkYaml.new('dummy.yaml', YAML.load(src))
    assert_equal [], yaml.ignore('/a/dir1')
    assert_equal ['*.bak', '/rdoc'], yaml.ignore('/path/to/dir')
  end
  
  def teardown
    FileUtils.cd(@prev_dir)
    FileUtils.rm_rf(@tmp_dir.to_s)
  end
end
