#!/usr/bin/env ruby

require 'parseconfig'
require 'git'
require 'pathname'            # for #children
require 'tcravit_ruby_lib'    # for on_execute

class GitPullAll

  def self.update_all_subdirs(start_in)
    GitPullAll.new.update_all_subdirs(start_in)
  end

  def update_all_subdirs(start_in)
    puts "*** Looking for git repos in #{start_in}..."
    find_git_repos_in(start_in).each do |d|
      update_git_repo(d)
    end
  end

  protected

  def find_git_repos_in(start_in)
    Pathname(start_in).children.select(&:directory?).select do |c|
      contains_git_repo?(c) && has_remote_origin?(c)
    end
  end

  def update_git_repo(the_dir)
    g = Git.open(the_dir)
    puts g.pull
  end

  def contains_git_repo?(the_dir)
    Dir.exists?(File.expand_path(File.join(the_dir, '.git')))
  end

  def has_remote_origin?(the_dir)
    git_config = File.expand_path(File.join(the_dir, '.git', 'config'))
    return false unless File.exists?(git_config)
    cfg = ParseConfig.new(git_config)
    return cfg.get_groups.include?('remote "origin"')
  end
end

on_execute do
  the_dir = ARGV[1] || ENV['PROJECTS_DIR'] || File.expand_path(Dir.pwd)
  GitPullAll.update_all_subdirs(the_dir)
end
