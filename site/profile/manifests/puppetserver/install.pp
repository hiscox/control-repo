# Puppet master installer
class profile::puppetserver::install {

  $package_source                    = '/tmp/puppet-enterprise-2017.3.0-el-7-x86_64.tar.gz'
  $package_source_url                = 'https://s3.amazonaws.com/pe-builds/released/2017.3.1/puppet-enterprise-2017.3.1-el-7-x86_64.tar.gz'
  $stage_pe_installer_dir            = '/tmp/pe_installer'
  $package_name                      = 'pe-puppetserver'
  $service_name                      = 'pe-puppetserver'
  $puppet_master_host                = $::fqdn
  $console_admin_password            = 'puppet'
  $set_console_admin_password_script = '/opt/puppetlabs/server/data/enterprise/modules/pe_install/files/set_console_admin_password.rb'
  $r10k_remote                       = ''
  $r10k_private_key                  = '/etc/puppetlabs/r10k/r10k_private_key.pem'
  $puppet_conf_file                  = '/etc/puppetlabs/puppet/puppet.conf'
  $hiera_config                      = '/etc/puppetlabs/code/environments/production/hiera.yaml'
  $accept_tcp_ports                  = ['8140','443','61613','8142','4433']
  $puppetserver_conf_file            = '/etc/puppetlabs/puppetserver/conf.d/puppetserver.conf' 
  $ssldir_path                       = '/etc/puppetlabs/puppetserver/ssl'
  $config_file                       = '/tmp/pe_conf'
  $install_pe_puppetserver           = '/tmp/pe_install.sh'
  $install_pe_puppetserver_sh        = @(EOF)
    #!/bin/bash
    if /usr/bin/rpm -q pe-puppetserver ; then exit 0 ; fi
    (<%= $stage_pe_installer_dir %>/puppet-enterprise-installer -c <%= $config_file %>) & 
    exit 0
  | EOF

  file { $stage_pe_installer_dir:
    ensure => directory,
  }

  file { $install_pe_puppetserver:
    ensure  => file,
    mode    => '0755',
    content => inline_epp($install_pe_puppetserver_sh),
  }

  archive { $package_source:
    require         => File[$stage_pe_installer_dir],
    source          => $package_source_url,
    ensure          => present,
    extract         => true,
    extract_command => 'tar xfz %s --strip-components=1',
    extract_path    => $stage_pe_installer_dir,
    cleanup         => true,
    creates         => '/tmp/pe_installer/puppet-enterprise-installer',
  }

  $conf_content = @(EOF)
    {
    "console_admin_password": "<%= $console_admin_password %>",
    "puppet_enterprise::puppet_master_host": "<%= $puppet_master_host %>",
    }
  | EOF

  file { $config_file:
    ensure  => file,
    content => inline_epp($conf_content)
  }

  exec { $install_pe_puppetserver:
    require => [
      File[$install_pe_puppetserver],
      Archive[$package_source],
    ],
    unless  => '/usr/bin/rpm -q pe-puppetserver',
    notify  => [
      Exec['start_staging_puppetserver_on_next_puppet_run'],
      Exec['set console admin password'],
    ],
    timeout => 6000,
  }

  exec { 'set console admin password':
    refreshonly => true, 
    command     => "ruby ${set_console_admin_password_script} ${console_admin_password}",
    path        => "/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:/opt/puppet/bin",
  }

  # If we assume puppetserver has just been installed, we also assume this is a brand new puppetserver,
  # so we set a custom fact 'staging_puppetserver', used in 'roles::puppetserver' to stage new repos to git & setup r10k...
  exec { 'start_staging_puppetserver_on_next_puppet_run':
    path        => '/bin',
    command     => 'echo staging_puppetserver=true > /opt/puppetlabs/facter/facts.d/staging_puppetserver.txt',
    refreshonly => true,
  }

}
