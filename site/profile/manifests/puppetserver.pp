# Puppet master set up
class profile::puppetserver {

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
    ensure   => '1.8.0',
    name     => 'rest-client',
    provider => 'puppetserver_gem',
    require  => Package[$dev_toolkit],
    notify   => Exec['gemspec_permissions'],
  }

  package { 'hiera-eyaml':
    ensure   => '2.1.0',
    provider => 'puppetserver_gem',
    notify   => Exec['gemspec_permissions'],
  }

  package { 'hiera-http':
    ensure   => '2.0.0',
    provider => 'puppetserver_gem',
    notify   => Exec['gemspec_permissions'],
  }

  package { 'rest-client_agent':
    ensure   => 'installed',
    name     => 'rest-client',
    provider => 'puppet_gem',
    require  => Package[$dev_toolkit],
    notify   => Exec['gemspec_permissions'],
  }

  $ruby_version  = split($facts['ruby']['version'], '[.]')
  $ruby_gems_dir = "${ruby_version[0]}.${ruby_version[1]}.0"

  file { "/opt/puppetlabs/puppet/lib/ruby/gems/${ruby_gems_dir}/specifications":
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => 'u=rwx,go=rx',
  }

  exec { 'gemspec_permissions':
    command     => 'chmod u=rw,go=r *.gemspec',
    cwd         => "/opt/puppetlabs/puppet/lib/ruby/gems/${ruby_gems_dir}/specifications",
    path        => ['/usr/bin', '/usr/sbin',],
    refreshonly => true,
  }

  $autosign_password = lookup('common_data::autosign_password')
  $autosign_jwt_secret = lookup('common_data::autosign_jwt_secret')

  package { 'autosign':
    ensure   => '0.1.2',
    provider => 'gem',
    notify   => Exec['gemspec_permissions'],
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
    notify  => Service['pe-puppetserver'],
  }

}
