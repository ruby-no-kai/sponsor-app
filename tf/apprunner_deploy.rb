ENV['BUNDLE_GEMFILE'] ||= File.join(__dir__, '..', 'deploy', 'Gemfile')
require 'bundler/setup'
require 'json'
require 'aws-sdk-ecs'

@ecs = Aws::ECS::Client.new(region: 'us-west-2')

service = @ecs.describe_services(cluster: 'rk-usw2-fargate', services: %w(sponsor-app-worker)).services[0]
taskdef = @ecs.describe_task_definition(task_definition: service.task_definition).task_definition
app = taskdef.container_definitions.find { _1.name == 'app' }

puts JSON.pretty_generate({
  image_identifier: app.image,
  runtime_environment_variables: JSON.generate(app.environment.map { [_1.name, _1.value ] }.to_h),
  runtime_environment_secrets: JSON.generate(app.secrets.map { [_1.name, _1.value_from ] }.to_h),
})
