# Puppet master set up
class profile::puppetserver {

  $proxy_url = lookup('common_data::proxy_url')

  user { 'pe-puppet':
    ensure => present,
  }

  package { 'rest-client_server':
    ensure          => '1.8.0',
    name            => 'rest-client',
    provider        => 'puppetserver_gem',
    install_options => [{'--http-proxy' => $proxy_url}],
    require         => Package[$dev_toolkit],
    notify          => Class['hiscox_profile::gemspec'],
  }

  package { 'hiera-eyaml':
    ensure          => '2.1.0',
    provider        => 'puppetserver_gem',
    install_options => [{'--http-proxy' => $proxy_url}],
    notify          => Class['hiscox_profile::gemspec'],
  }

  package { 'hiera-http':
    ensure          => '2.0.0',
    provider        => 'puppetserver_gem',
    install_options => [{'--http-proxy' => $proxy_url}],
    notify          => Class['hiscox_profile::gemspec'],
  }

  package { 'rest-client_agent':
    ensure          => 'installed',
    name            => 'rest-client',
    provider        => 'puppet_gem',
    install_options => [{'--http-proxy' => $proxy_url}],
    require         => Package[$dev_toolkit],
    notify          => Class['hiscox_profile::gemspec'],
  }

  $autosign_password   = lookup('puppet_data::autosign_password')
  $autosign_jwt_secret = lookup('puppet_data::autosign_jwt_secret')

  package { 'autosign':
    ensure          => '0.1.2',
    provider        => 'gem',
    install_options => [{'--http-proxy' => $proxy_url}],
    notify          => Class['hiscox_profile::gemspec'],
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
