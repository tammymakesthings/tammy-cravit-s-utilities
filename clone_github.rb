#!/usr/bin/env ruby
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
require 'optparse'

::Version = [1, 1, 0]

############################################################################
# Helper functions for interacting with the Github REST API
############################################################################

def RESTGetRequest(url)
  uri = URI(url)

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  request = Net::HTTP::Get.new(uri.request_uri)
  request['Accept'] = "application/vnd.github.v3+json"
  response = http.request(request)

  json_data = JSON.parse(response.body)
  return json_data
end

def check_github_user_exists(username)
  user_data = RESTGetRequest("https://api.github.com/users/#{username}")
  if user_data.keys.include?("message") and user_data["message"] == "Not Found" then
    return false
  end
  return true
end

def fetch_repo_list(username)
  return RESTGetRequest("https://api.github.com/users/#{username}/repos")
end

############################################################################
# Main script starts here
############################################################################

# Print out the app banner. Uses TcravitRubyLib's Banner helper.
puts TcravitRubyLib::Banner(name: "clone_github.rb",
                            description: "Clone all github repos",
                            version: ::Version.join('.'),
                            date: "2018-01-31",
                            author: "Tammy Cravit")
puts ""

options = {}

# Supply defaults for command line options
options[:github_user] = "tammymakesthings"
options[:project_dir] = File.join(ENV["HOME"], "projects")

# Parse and validate command line options
OptionParser.new do |opts|
  opts.banner = "Usage: clone_github.rb [options]"
  opts.on("-u", "--github-user USER", "Specify Github username") do |u|
    if check_github_user_exists(u)
      options[:github_user] = u
    else
      puts "Error: Github user \"#{u}\" does not exist!"
      exit
    end
  end
  opts.on("-p", "--project-dir DIR", "Specify local projects directory") do |pd|
    if Dir.exists?(pd) then
      options[:project_dir] = pd
    else
      puts "Error: Project directory \"#{pd}\" must be an existing directory!"
      exit
    end
  end
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

# Now let's do this thing
puts "- Github User: #{options[:github_user]}"
puts "- Project Dir: #{options[:project_dir]}"
puts ""

puts "* Iterating Repos for #{options[:github_user]}..."
repo_data = fetch_repo_list(options[:github_user])

num_cloned = 0
num_checked = 0

puts "* Checking/cloning Repos:"
repo_data.each do |r|
  repo_name = r["name"]
  num_checked = num_checked + 1

  # If a directory exists for the named repo and it has a .git subdirectory,
  # assume we've already cloned the repo. We could check if the .git directory
  # has a remote origin corresponding to the repo name, but this is overkill
  # for our purposes.
  if (Dir.exist?(File.join(options[:project_dir], repo_name))) and (Dir.exist?(File.join(options[:project_dir], repo_name, ".git"))) then
    puts "    - Found repo clone for #{repo_name} - skipping"
  else
    puts "    - Cloning #{repo_name}"
    Git.clone "git@github.com:#{options[:github_user]}/#{repo_name}.git", File.join(options[:project_dir], repo_name)
    num_cloned = num_cloned + 1
  end
end

puts "* Done. Cloned #{num_cloned} of #{num_checked} repos."
exit 0
