# Class: toollabs::master
#
# This role sets up a grid master in the Tool Labs model.
#
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
class toollabs::master inherits toollabs {
    include gridengine::master,
        toollabs::infrastructure,
        toollabs::exec_environ,
        toollabs::gridnode

    #
    # These things are done on toollabs::master because they
    # need to be done exactly once per project (they live on the
    # shared filesystem), and there can only be exactly one
    # gridmaster in this setup.  They could have been done on
    # any singleton instance.
    #

    file { $repo:
        ensure  => directory,
        owner   => 'local-admin',
        group   => 'local-admin',
        mode    => '0755',
        require => File[$sysdir],
    }

    file { "${repo}/update-repo.sh":
        ensure  => file,
        owner   => 'local-admin',
        group   => 'local-admin',
        mode    => '0550',
        require => File[$repo],
        source  => 'puppet:///modules/toollabs/update-repo.sh',
    }

    if $::site != 'eqiad' {
        cron { 'push-accounting-to-shared':
            ensure  => present,
            command => 'cp -f /var/lib/gridengine/default/common/accounting /data/project/.system/accounting.tmp && mv -f /data/project/.system/accounting.tmp /data/project/.system/accounting',
            user    => 'root',
            minute  => '*/5',
        }
    }
}

