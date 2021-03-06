# Configuration files for apache running on application servers
# note: it uses $cluster for the apache2.conf
#
# requires applicationserver::packages to be in place
class applicationserver::config::apache(
    $maxclients='40'
) {

    Class['applicationserver::apache_packages'] -> Class['applicationserver::config::apache']
    Class['applicationserver::config::apache'] -> Class['applicationserver::config::base']

    file { '/etc/apache2/apache2.conf':
        owner   => root,
        group   => root,
        mode    => '0444',
        content => template('applicationserver/apache/apache2.conf.erb'),
    }
    file { '/etc/apache2/envvars':
        owner  => root,
        group  => root,
        mode   => '0444',
        source => 'puppet:///modules/applicationserver/apache/envvars.appserver',
    }
    file { '/etc/cluster':
        owner   => root,
        group   => root,
        mode    => '0444',
        content => $::site,
    }

    if $::realm == 'production' {
        file { '/usr/local/apache':
            ensure => directory,
        }
        exec { 'sync apache wmf config':
            require => File['/usr/local/apache'],
            path    => '/bin:/sbin:/usr/bin:/usr/sbin',
            command => 'rsync -av 10.0.5.8::httpdconf/ /usr/local/apache/conf',
            creates => '/usr/local/apache/conf',
            notify  => Service[apache]
        }
    } else {  # labs
        # bug 38996 - Apache service does not run on start, need a fake
        # sync to start it up though don't bother restarting it is already
        # running.
        exec { 'Fake sync apache wmf config on beta':
            command => '/bin/true',
            unless  => '/bin/ps -C apache2 > /dev/null',
            notify  => Service[apache],
        }
    }

}
