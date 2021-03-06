# == Class: role::performance
#
# This role provisions <http://performance.wikimedia.org>, a static site with
# web performance dashboards.
#
class role::performance {
    include ::apache

    file { '/var/www/performance':
        ensure  => directory,
        owner   => 'www-data',
        group   => 'www-data',
        mode    => '0444',
        purge   => true,
        recurse => true,
        force   => true,
        source => 'puppet:///files/performance',
    }

    file { '/etc/apache2/sites-available/performance':
        content => template('apache/sites/performance.wikimedia.org.erb'),
        require => Package['httpd'],
    }

    file { '/etc/apache2/sites-enabled/performance':
        ensure => link,
        target => '/etc/apache2/sites-available/performance',
        notify => Service['httpd'],
    }
}
