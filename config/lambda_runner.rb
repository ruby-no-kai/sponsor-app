require 'pp'
require 'json'
require 'open3'

module CommandRunner
  def self.handle(event:, context:)
    raise "No command provided" unless event['run']
    run(event['run'], context:)
  end

  def self.run(cmd, context:)
    puts "RUNCMD #{context.aws_request_id} #{JSON.generate(cmd)}"
    t = Time.now
    cmd = Array(cmd)
    raise "invalid argument" unless cmd[1..].all? { |e| e.is_a?(String) }
    $stdout.sync = true
    buf = ''
    status = Open3.popen2e(*cmd) do |stdin, stdouterr, waiter|
      stdin.close
      while line = stdouterr.gets
        buf << line
        puts line
      end
      waiter.value
    end
    puts "RUNCMD-OK #{context.aws_request_id}"
    {ok: status.success?, duration: Time.now-t, output: buf.bytesize > 5000000 ? buf[..5000000] : buf, status: status.exitstatus, signal: status.termsig}
  end

  #def self.interact(param, context:)
  #  puts "INTERACT #{context.aws_request_id} #{JSON.generate(param)}"
  #  r = eval(param, binding)
  #  puts "RESULT-OK #{context.aws_request_id} #{r.inspect}"
  #  {statusCode: 200, body: "#{r.pretty_inspect}\n"}
  #rescue => e
  #  puts "RESULT-ERROR #{context.aws_request_id} #{e.full_message.gsub(/\n/, " | ")}"
  #  {statusCode: 422, body: "#{e.full_message}\n"}
  #end
end
