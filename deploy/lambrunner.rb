#!/usr/bin/env ruby
require 'aws-sdk-lambda'
require 'base64'

function_name, command = ARGV[0], ARGV[1..]
abort "Usage: #$0 <function_name> <command1> [<command2> ...]" if function_name.nil? || command.empty?

@lambda = Aws::Lambda::Client.new

invocation = @lambda.invoke(
  function_name:,
  payload: JSON.generate(run: command),
  invocation_type: 'RequestResponse',
  log_type: 'Tail',
)

if invocation.function_error
  puts invocation.payload.read
  puts Base64.decode64(invocation.log_result)
  exit 1
else
  j = JSON.parse(invocation.payload.read)
  puts j['output']

  case 
  when j['status'].is_a?(Integer)
    exit j['status']
  when j['ok'] == false
    exit 1
  else
    raise "Unknown response status"
  end
end

