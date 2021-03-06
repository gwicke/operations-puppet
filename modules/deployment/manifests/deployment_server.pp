class deployment::deployment_server(
    $deployment_conffile='/etc/git-deploy/git-deploy.conf',
    $deployment_ignorefile='/etc/git-deploy/gitignore',
    $deployment_ignores=['.deploy'],
    $deployment_restrict_umask='002',
    $deployment_block_file='/etc/ROLLOUTS_BLOCKED',
    $deployment_support_email='',
    $deployment_repo_name_detection='dot-git-parent-dir',
    $deployment_announce_email='',
    $deployment_send_mail_on_sync=false,
    $deployment_send_mail_on_revert=false,
    $deployment_log_directory='/var/log/git-deploy',
    $deployment_log_timing_data=false,
    $deployment_git_deploy_dir='/var/lib/git-deploy',
    $deployment_per_repo_config={},
    $deployer_groups=[]
    ) {
    if ! defined(Package['git-deploy']){
        package { 'git-deploy':
            ensure => present;
        }
    }
    if ! defined(Package['git-core']){
        package { 'git-core':
            ensure => present;
        }
    }
    if ! defined(Package['python-redis']){
        package { 'python-redis':
            ensure => present;
        }
    }

    exec { 'eventual_consistency_deployment_server_init':
        path    => ['/usr/bin'],
        command => 'salt-call deploy.deployment_server_init',
        require => Package['salt-minion'];
    }

    $deployment_global_hook_dir = "${deployment_git_deploy_dir}/hooks"
    $deployment_dependencies_dir = "${deployment_git_deploy_dir}/dependencies"
    file { $deployment_global_hook_dir:
        ensure => directory,
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
    }

    file { $deployment_dependencies_dir:
        ensure => directory,
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
    }

    file { "${$deployment_global_hook_dir}/sync":
        ensure  => directory,
        mode    => '0555',
        owner   => 'root',
        group   => 'root',
        require => [File[$deployment_global_hook_dir]],
    }

    file { "${$deployment_global_hook_dir}/sync/deploylib.py":
        source  => 'puppet:///deployment/git-deploy/hooks/deploylib.py',
        mode    => '0555',
        owner   => 'root',
        group   => 'root',
        require => [File["${$deployment_global_hook_dir}/sync"]],
    }

    file { "${$deployment_global_hook_dir}/sync/shared.py":
        source  => 'puppet:///deployment/git-deploy/hooks/shared.py',
        mode    => '0555',
        owner   => 'root',
        group   => 'root',
        require => [File["${$deployment_global_hook_dir}/sync"]],
    }

    file { "${$deployment_global_hook_dir}/sync/depends.py":
        source  => 'puppet:///deployment/git-deploy/hooks/depends.py',
        mode    => '0555',
        owner   => 'root',
        group   => 'root',
        require => [File["${$deployment_global_hook_dir}/sync"]],
    }

    file { "${$deployment_dependencies_dir}/l10n":
        source  => 'puppet:///deployment/git-deploy/dependencies/l10nupdate-quick',
        mode    => '0555',
        owner   => 'root',
        group   => 'root',
        require => [File[$deployment_dependencies_dir]],
    }

    file { '/etc/gitconfig':
        content => template('deployment/git-deploy/gitconfig.erb'),
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        require => [Package['git-core']],
    }

    file { $deployment_conffile:
        content => template('deployment/git-deploy/git-deploy.conf.erb'),
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
    }

    file { $deployment_ignorefile:
        content => template('deployment/git-deploy/gitignore.erb'),
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
    }

    file { '/usr/local/bin/deploy-info':
        owner   => 'root',
        group   => 'root',
        mode    => '0555',
        source  => 'puppet:///deployment/git-deploy/utils/deploy-info',
        require => [Package['python-redis']],
    }

    file { '/usr/local/bin/service-restart':
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
        source => 'puppet:///deployment/git-deploy/utils/service-restart',
    }

    file { '/usr/local/bin/submodule-update-server-info':
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
        source => 'puppet:///deployment/git-deploy/utils/submodule-update-server-info',
    }

    salt::grain { 'deployment_server':
        grain   => 'deployment_server',
        value   => true,
        replace => true,
    }

    salt::grain { 'deployment_global_hook_dir':
        grain   => 'deployment_global_hook_dir',
        value   => $deployment_global_hook_dir,
        replace => true,
    }

    salt::grain { 'deployment_repo_user':
        grain   => 'deployment_repo_user',
        value   => 'sartoris',
        replace => true,
    }

    generic::systemuser { 'sartoris':
        name   => 'sartoris',
        shell  => '/bin/false',
        home   => '/nonexistent',
        groups => $deployer_groups,
    }
}
