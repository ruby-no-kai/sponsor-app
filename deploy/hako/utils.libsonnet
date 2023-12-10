{
  vpcId:: 'vpc-0a4e5da322884146d',  // rk-usw2
  publicSubnets:: ['subnet-0f124e0efa57ca9ed', 'subnet-0543f95bcbcb848db'],  // c, d
  iamRole(name):: std.format('arn:aws:iam::005216166247:role/%s', name),

  ecrRepository(name):: std.format('005216166247.dkr.ecr.us-west-2.amazonaws.com/%s', name),

  ecsSchedulerBase:: {
    type: 'ecs',
    region: 'us-west-2',
    cluster: error 'cluster must be specified',
    // role: 'aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS',
    execution_role_arn: $.iamRole('EcsExecSponsorApp'),
    desired_count: 1,
    tags: {
      Project: 'sponsor-app',
    },
  },
  ecsSchedulerFargate:: $.ecsSchedulerBase {
    cluster: 'rk-usw2-fargate',
    cpu: '256',
    memory: '512',
    requires_compatibilities: ['FARGATE'],
    capacity_provider_strategy: [
      { capacity_provider: 'FARGATE_SPOT', weight: 1 },
    ],
    network_mode: 'awsvpc',
    network_configuration: {
      awsvpc_configuration: {
        subnets: $.publicSubnets,
        security_groups: [
          'sg-00e4325624f55b1f4',  // default
        ],
        assign_public_ip: 'ENABLED',
      },
    },
  },

  makeSecretParameterStore(path)::
    function(variableName) {
      name: variableName,
      value_from: std.format('arn:aws:ssm:us-west-2:005216166247:parameter/%s/%s', [path, variableName]),
    },

  awsLogs(name):: {
    log_driver: 'awslogs',
    options: {
      'awslogs-group': std.format('/ecs/%s', [std.extVar('appId')]),
      'awslogs-region': 'us-west-2',
      'awslogs-stream-prefix': 'ecs',
    },
  },
  createLogGroups():: {
    type: 'create_aws_cloud_watch_logs_log_group',
  },
}
