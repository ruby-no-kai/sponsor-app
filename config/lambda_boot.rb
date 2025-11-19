require 'aws-sdk-ssm'
ssm = Aws::SSM::Client.new
r = /^SSM_SECRET__/
params = ENV.keys.grep(r).map do |k|
  [ENV[k], k.sub(r, '')]
end.to_h
params.keys.each_slice(10) do |names|
  ssm.get_parameters(
    names:,
    with_decryption: true,
  ).parameters.each do |pa|
    ENV[params.fetch(pa.arn)] = pa.value
  end
end
