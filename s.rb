require 'sinatra'
require 'json'
require 'sinatra/cross_origin'

set :port, 7000
set :bind, '0.0.0.0'

configure do
  enable :cross_origin
end

before do
  response.headers['Access-Control-Allow-Origin'] = '*'
  content_type :json
end

def load_commands
  commands = {}
  
  Dir.glob('cmds/*').select { |f| File.directory?(f) }.each do |category_dir|
    category_name = File.basename(category_dir)
    commands[category_name] = []
    
    Dir.glob("#{category_dir}/*.json").each do |cmd_file|
      begin
        cmd_data = JSON.parse(File.read(cmd_file))
        commands[category_name] << cmd_data
      rescue => e
        puts "Error loading #{cmd_file}: #{e.message}"
      end
    end
  end
  
  commands
end

get '/cmds' do
  commands = load_commands
  commands.to_json
end

get '/cmds/:category' do
  category = params[:category]
  commands = load_commands
  
  if commands.key?(category)
    commands[category].to_json
  else
    status 404
    { error: "Category '#{category}' not found" }.to_json
  end
end

get '/cmds/:category/:command' do
  category = params[:category]
  command_name = params[:command]
  commands = load_commands
  
  if commands.key?(category)
    command = commands[category].find { |cmd| cmd["name"] == command_name }
    if command
      command.to_json
    else
      status 404
      { error: "Command '#{command_name}' not found in category '#{category}'" }.to_json
    end
  else
    status 404
    { error: "Category '#{category}' not found" }.to_json
  end
end

get '/cmds/' do
  commands = load_commands
  commands.to_json
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
          <li><code>/cmds</code> - List all commands from all categories</li>
          <li><code>/cmds/{category}</code> - List all commands in a specific category</li>
          <li><code>/cmds/{category}/{command}</code> - Get details for a specific command</li>
        </ul>
        <h2>Example Command Structure:</h2>
        <pre>#{JSON.pretty_generate(JSON.parse('{"name":"convert","aliases":[],"help":"Convert image to different format","syntax":"convert [format] (url)","example":"convert png","cooldown":false,"permissions":false,"donor":true,"donor_tier":1,"parameters":["format","url"]}'))}</pre>
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