# == Class role::wikimetrics
# Installs and hosts wikimetrics.
# NOTE:  This class does not (yet) work in production!
#
# role::wikimetrics requires class passwords::wikimetrics to
# exist and populated with variables.
# passwords::wikimetrics is not a real class checked in to any repository.
# In labs on your self hosted puppetmaster, you must do two
# things to make this exist:
# 1. Edit /var/lib/git/operations/puppet/manifests/passwords.pp
#    and add this class with the variables below.
# 2. Edit /var/lib/git/operations/puppet/manifests/site.pp
#    and add an 'import "passwords.pp" line near the top.
#
# == Globals
# These parameters can be set globally or via wikitech.
# $wikimetrics_web_mode       - Either 'apache' or 'daemon'. If apache, 
#                               wikimetrics will be run in WSGI.  If
#                               daemon, wikimetrics will be managed
#                               as a python daemon process via upstart.
#                               Default: apache
# $wikimetrics_ssl_redirect   - If true, apache will force redirect any
#                               requests made to https:://$server_name...
#                               This does nothing if you are running in
#                               daemon mode.  Default: false
# $wikimetrics_server_name    - Apache ServerName.  This is not used if
#                               $web_mode is daemon.  Default: $::fqdn
# $wikimetrics_server_aliases - comma separated list of Apache ServerAlias-es.
#                               Default: undef
# $wikimetrics_server_port    - port on which to listen for wikimetrics web requests.
#                               If in apache mode, this defaults to 80, else
#                               this defaults to 5000.
#
class role::wikimetrics {
     # wikimetrics does not yet run via puppet in production
    if $::realm == 'production' {
        fail('Cannot include role::wikimetrics in production (yet).')
    }

    include passwords::wikimetrics

    $wikimetrics_path = '/srv/wikimetrics'

    # Wikimetrics Database Creds
    $db_user_wikimetrics   = $::passwords::wikimetrics::db_user_wikimetrics
    $db_pass_wikimetrics   = $::passwords::wikimetrics::db_pass_wikimetrics
    $db_host_wikimetrics   = 'localhost'
    $db_name_wikimetrics   = 'wikimetrics'

    # Use the LabsDB for editor cohort analysis
    $db_user_mediawiki     = $::passwords::wikimetrics::db_user_labsdb
    $db_pass_mediawiki     = $::passwords::wikimetrics::db_pass_labsdb
    $db_host_mediawiki     = '{0}.labsdb'
    $db_name_mediawiki     = '{0}_p'

    # OAuth and Google Auth
    $flask_secret_key      = $::passwords::wikimetrics::flask_secret_key
    $google_client_id      = $::passwords::wikimetrics::google_client_id
    $google_client_email   = $::passwords::wikimetrics::google_client_email
    $google_client_secret  = $::passwords::wikimetrics::google_client_secret
    $meta_mw_consumer_key  = $::passwords::wikimetrics::meta_mw_consumer_key
    $meta_mw_client_secret = $::passwords::wikimetrics::meta_mw_client_secret

    # Run as daemon python process or in Apache WSGI.
    $web_mode = $::wikimetrics_web_mode ? {
        undef   => 'apache',
        default => $::wikimetrics_web_mode,
    }

    # if the global variable $::wikimetrics_server_name is set,
    # use it as the server_name.  This allows
    # configuration via the Labs Instance configuration page.
    $server_name = $::wikimetrics_server_name ? {
        undef   => $::fqdn,
        default => $::wikimetrics_server_name,
    }
    $server_aliases = $::wikimetrics_server_aliases ? {
        undef   => undef,
        default => split($::wikimetrics_server_aliases, ','),
    }

    $server_port = $::wikimetrics_server_port ? {
        # If $::wikimetrics_server_port is not set,
        # default to port 80 for apache web mode,
        # or port 5000 for daemon web mode.
        undef   => $web_mode ? {
            'apache' => 80,
            default  => 5000,
        },
        default => $::wikimetrics_server_port,
    }
    $ssl_redirect = $::wikimetrics_ssl_redirect ? {
        undef   => false,
        default => $::wikimetrics_ssl_redirect,
    }

    # need pip :/
    if !defined(Package['python-pip']) {
        package { 'python-pip':
            ensure => 'installed',
        }
    }
    if !defined(Package['mysql-server']) {
        package { 'mysql-server':
            ensure => 'installed',
        }
    }
    class { '::wikimetrics::database': }

    class { '::wikimetrics':
        path                  => $wikimetrics_path,

        # clone wikimetrics as root user so it can write to /srv
        repository_owner      => 'root',

        server_name           => $server_name,
        server_aliases        => $server_aliases,
        server_port           => $server_port,
        ssl_redirect          => $ssl_redirect,

        flask_secret_key      => $flask_secret_key,
        google_client_id      => $google_client_id,
        google_client_email   => $google_client_email,
        google_client_secret  => $google_client_secret,
        meta_mw_consumer_key  => $meta_mw_consumer_key,
        meta_mw_client_secret => $meta_mw_client_secret,

        db_user_wikimetrics   => $db_user_wikimetrics,
        db_pass_wikimetrics   => $db_pass_wikimetrics,
        db_host_wikimetrics   => $db_host_wikimetrics,
        db_name_wikimetrics   => $db_name_wikimetrics,

        db_user_mediawiki     => $db_user_mediawiki,
        db_pass_mediawiki     => $db_pass_mediawiki,
        db_host_mediawiki     => $db_host_mediawiki,
        db_name_mediawiki     => $db_name_mediawiki,

        # wikimetrics runs on the LabsDB usually,
        # where this table is called 'revision_userindex'.
        # The mediawiki database usually calls this 'revision'.
        revision_tablename    => 'revision_userindex',
        require               => Class['::wikimetrics::database'],
    }

    # Run the wikimetrics/scripts/install script
    # in order to pip install proper dependencies.
    # Note:  This is not in the wikimetrics puppet module
    # because it is an improper way to do things in
    # WMF production.
    exec { 'install_wikimetrics_dependencies':
        command => "${wikimetrics_path}/scripts/install ${wikimetrics_path}",
        creates => '/usr/local/bin/wikimetrics',
        path    => '/usr/local/bin:/usr/bin:/bin',
        user    => 'root',
        require => [Package['python-pip'], Class['::wikimetrics']],
    }

    # The redis module by default sets up redis in /a.  Oh well!
    if !defined(File['/a']) {
        file { '/a':
            ensure => directory,
            before => Class['::wikimetrics::queue']
        }
    }

    # TODO: Support installation of queue, web and database
    # classes on different nodes (maybe?).
    class { '::wikimetrics::queue':
        require => Exec['install_wikimetrics_dependencies'],
    }

    class { '::wikimetrics::web':
        mode    => $web_mode,
        require => Exec['install_wikimetrics_dependencies'],
    }
}
