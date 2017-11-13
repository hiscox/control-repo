# Puppet master autosign set up
class profile::puppetserver::autosign {
  $proxy_url = 'http://proxy-northeurope.azure.hiscox.com:8080'

  $dev_toolkit = [
    'ruby-devel',
    'gcc',
    'gcc-c++'
  ]

  user { 'pe-puppet':
    ensure => present,
  }

  package { $dev_toolkit:
    ensure => present,
  }

  package { 'rest-client_server':
    ensure          => '1.8.0',
    name            => 'rest-client',
    provider        => 'puppetserver_gem',
    install_options => [{'--http-proxy' => $proxy_url}],
    require         => Package[$dev_toolkit],
    notify          => Exec['gemspec_permissions'],
  }

  package { 'hiera-eyaml':
    ensure          => '2.1.0',
    provider        => 'puppetserver_gem',
    install_options => [{'--http-proxy' => $proxy_url}],
    notify          => Exec['gemspec_permissions'],
  }

  package { 'hiera-http':
    ensure          => '2.0.0',
    provider        => 'puppetserver_gem',
    install_options => [{'--http-proxy' => $proxy_url}],
    notify          => Exec['gemspec_permissions'],
  }

  package { 'rest-client_agent':
    ensure          => 'installed',
    name            => 'rest-client',
    provider        => 'puppet_gem',
    install_options => [{'--http-proxy' => $proxy_url}],
    require         => Package[$dev_toolkit],
    notify          => Exec['gemspec_permissions'],
  }

  file { '/opt/puppetlabs/puppet/lib/ruby/gems/2.1.0/specifications':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => 'u=rwx,go=rx',
  }

  exec { 'gemspec_permissions':
    command     => 'chmod u=rw,go=r *.gemspec',
    cwd         => '/opt/puppetlabs/puppet/lib/ruby/gems/2.1.0/specifications',
    path        => ['/usr/bin', '/usr/sbin',],
    refreshonly => true,
  }

  # Autosign config
  $autosign_password = lookup('common_data::autosign_password')
  $autosign_jwt_secret = lookup('common_data::autosign_jwt_secret')
  package { 'autosign':
    ensure          => '0.1.2',
    provider        => 'gem',
    install_options => [{'--http-proxy' => $proxy_url}],
    notify          => Exec['gemspec_permissions'],
  }
  file { '/var/autosign':
    ensure => directory,
    owner  => 'pe-puppet',
    mode   => '0750',
  }
  file { '/var/log/autosign.log':
    ensure => file,
    owner  => 'pe-puppet',
    mode   => '0644',
  }
  file { '/etc/autosign.conf':
    ensure  => file,
    owner   => 'pe-puppet',
    mode    => '0440',
    content => template("${module_name}/autosign.conf.erb"),
  }
  ini_setting { 'policy_based_autosigning':
    setting => 'autosign',
    path    => '/etc/puppetlabs/puppet/puppet.conf',
    section => 'master',
    value   => '/usr/local/bin/autosign-validator',
    require => Package['autosign'],
  }
  # End
}
