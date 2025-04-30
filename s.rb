require 'sinatra'
require 'json'
require 'sinatra/cross_origin'
require 'open-uri'
require 'fileutils'

REPO_URL = "https://github.com/egirlst/api"
REPO_RAW_URL = "https://raw.githubusercontent.com/egirlst/api/main"
CHECK_INTERVAL = 300  # Check for updates every 5 minutes

set :port, 7000
set :bind, '0.0.0.0'
set :environment, :production
set :server, %w[thin mongrel webrick]
set :protection, except: [:json_csrf]

def initialize_git_repo
  unless File.directory?('.git')
    system('git init')
    system("git remote add origin #{REPO_URL}.git")
  end
end

def check_for_updates
  puts "Checking for updates from GitHub..."
  system('git fetch origin')
  local_head = `git rev-parse HEAD`.strip
  remote_head = `git rev-parse origin/main`.strip
  
  if local_head != remote_head
    puts "Updates found, pulling changes..."
    system('git pull origin main')
    puts "Repository updated to #{remote_head}"
    return true
  else
    puts "No updates found."
    return false
  end
end

def start_update_thread
  Thread.new do
    loop do
      begin
        check_for_updates
      rescue => e
        puts "Error checking for updates: #{e.message}"
      end
      sleep CHECK_INTERVAL
    end
  end
end

configure do
  enable :cross_origin
  enable :static
  set :allow_origin, "*"
  set :allow_methods, [:get, :post, :options]
  set :allow_credentials, true
  set :max_age, "1728000"
  set :expose_headers, ['Content-Type']
  
  initialize_git_repo
  start_update_thread
end

before do
  response.headers['Access-Control-Allow-Origin'] = '*'
  content_type :json
end

def load_commands
  all_commands = []
  
  Dir.glob('cmds/*').select { |f| File.directory?(f) }.each do |category_dir|
    category_name = File.basename(category_dir)
    
    Dir.glob("#{category_dir}/*.json").each do |cmd_file|
      begin
        cmd_data = JSON.parse(File.read(cmd_file))
        cmd_data["category"] = category_name  # Add category to each command
        all_commands << cmd_data
      rescue => e
        puts "Error loading #{cmd_file}: #{e.message}"
      end
    end
  end
  
  all_commands
end

get '/cmds' do
  commands = load_commands
  commands.to_json
end

get '/cmds/:category' do
  category = params[:category]
  commands = load_commands
  
  filtered_commands = commands.select { |cmd| cmd["category"] == category }
  
  if filtered_commands.any?
    filtered_commands.to_json
  else
    status 404
    { error: "Category '#{category}' not found" }.to_json
  end
end

get '/cmds/:category/:command' do
  category = params[:category]
  command_name = params[:command]
  commands = load_commands
  
  command = commands.find { |cmd| cmd["category"] == category && cmd["name"] == command_name }
  
  if command
    command.to_json
  else
    status 404
    { error: "Command '#{command_name}' not found in category '#{category}'" }.to_json
  end
end

get '/cmds/' do
  commands = load_commands
  commands.to_json
end

post '/update' do
  content_type :json
  result = check_for_updates
  
  if result
    { success: true, message: "Repository updated successfully" }.to_json
  else
    { success: false, message: "No updates available" }.to_json
  end
end


get '/' do
  content_type :html
  <<-HTML
    <!DOCTYPE html>
    <html>
      <head>
        <title>Commands API</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 20px; }
          h1 { color: #333; }
          pre { background-color: #f4f4f4; padding: 10px; border-radius: 5px; }
        </style>
      </head>
      <body>
        <h1>Commands API</h1>
        <p>This API serves command data from JSON files.</p>
        <h2>Available Endpoints:</h2>
        <ul>
          <li><code>/cmds</code> - List all commands in a single array</li>
          <li><code>/cmds/{category}</code> - List commands from a specific category</li>
          <li><code>/cmds/{category}/{command}</code> - Get details for a specific command</li>
          <li><code>/update</code> - Force a check for GitHub updates</li>
        </ul>
        <h2>Example Command Structure:</h2>
        <pre>#{JSON.pretty_generate(JSON.parse('{"name":"convert","category":"donor","aliases":[],"help":"Convert image to different format","syntax":"convert [format] (url)","example":"convert png","cooldown":false,"permissions":false,"donor":true,"donor_tier":1,"parameters":["format","url"]}'))}</pre>
      </body>
    </html>
  HTML
end

options "*" do
  response.headers["Allow"] = "GET, POST, OPTIONS"
  response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
  response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type, Accept"
  200
end

puts "Server is running at http://localhost:7000"
puts "Auto-update is enabled and will check GitHub every #{CHECK_INTERVAL} seconds"
