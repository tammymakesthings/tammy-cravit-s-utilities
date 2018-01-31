#!/home/tammy/.rvm/rubies/ruby-2.5.0/bin/ruby
############################################################################
# Clone all of your github repos into a project directory
# 
# Version 1.00, Wed Jan 31 12:27:53 EST 2018, tammy.cravit
############################################################################

require 'net/http'
require 'uri'
require 'json'
require 'fileutils'
require 'tcravit_ruby_lib'
require 'git'

puts "****************************************************************************"
puts "* Clone all of your github repos into a project directory                  *"
puts "*                                                                          *"
puts "* Version 1.00, Wed Jan 31 12:27:53 EST 2018, tammy.cravit                 *"
puts "****************************************************************************"
puts ""

GITHUB_USER_NAME = "tammycravit"

project_dir = File.join(ENV["HOME"], "projects")
unless Dir.exist?(project_dir) 
	project_dir = Dir.pwd
end

puts "- Github User: #{GITHUB_USER_NAME}"
puts "- Project Dir: #{project_dir}"
puts ""

puts "* Iterating Repos for #{GITHUB_USER_NAME}..."
uri = URI("https://api.github.com/users/#{GITHUB_USER_NAME}/repos")

http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Get.new(uri.request_uri)
request['Accept'] = "application/vnd.github.v3+json"
response = http.request(request)

repo_data = JSON.parse(response.body)

puts "* Checking/cloning Repos:"
repo_data.each do |r|
	repo_name = r["name"]

	if (Dir.exist?(File.join(project_dir, repo_name))) and (Dir.exist?(File.join(project_dir, repo_name, ".git"))) then
		puts "    - Found repo clone for #{repo_name} - skipping"
	else
		puts "    - Cloning #{repo_name}"
		Git.clone "git@github.com:#{GITHUB_USER_NAME}/#{repo_name}.git", File.join(project_dir, repo_name)
	end
end