# Puppet master installer
class profile::puppetserver::install {

  $pe_version                        = '2017.3.1'
  $package_source                    = "/tmp/puppet-enterprise-${pe_version}-el-7-x86_64.tar.gz"
  $package_source_url                = "https://s3.amazonaws.com/pe-builds/released/${pe_version}/puppet-enterprise-${pe_version}-el-7-x86_64.tar.gz"
  $stage_pe_installer_dir            = '/tmp/pe_installer'
  $package_name                      = 'pe-puppetserver'
  $service_name                      = 'pe-puppetserver'
  $puppet_master_host                = $::fqdn
  $console_admin_password            = 'puppet'
  $set_console_admin_password_script = '/opt/puppetlabs/server/data/enterprise/modules/pe_install/files/set_console_admin_password.rb'
  $r10k_remote                       = 'git@github.com:hiscox/control-repo.git'
  $r10k_private_key                  = '/etc/puppetlabs/r10k/r10k_private_key.pem'
  $r10k_token                        = '/etc/puppetlabs/puppetserver/.puppetlabs/code_manager_service_user_token'
  $r10k_proxy                        = 'http://proxy-northeurope.azure.hiscox.com:8080'
  $puppet_conf_file                  = '/etc/puppetlabs/puppet/puppet.conf'
  $hiera_config                      = '/etc/puppetlabs/code/environments/production/hiera.yaml'
  $puppetserver_conf_file            = '/etc/puppetlabs/puppetserver/conf.d/puppetserver.conf'
  $ssldir_path                       = '/etc/puppetlabs/puppetserver/ssl'
  $config_file                       = '/tmp/pe_conf'
  $install_pe_puppetserver           = '/tmp/pe_install.sh'
  $install_pe_puppetserver_sh        = @(EOF)
    #!/bin/bash
    console_admin_password=$1
    ( sleep 20 ;\ 
      yum remove -y puppet ;\
      rm -rf /etc/puppetlabs/puppet/ssl ;\
      rm -f /etc/puppetlabs/puppetserver/ssl/ca/signed/$(hostname -f).pem ;\
      <%= $stage_pe_installer_dir %>/puppet-enterprise-installer -c <%= $config_file %> ;\
      /opt/puppetlabs/bin/ruby <%= $set_console_admin_password_script %> $console_admin_password ;\
      chown pe-puppet:pe-puppet <%= $r10k_private_key %> ;\
      puppet module install npwalker-pe_code_manager_webhook ;\
      puppet module install pltraining-rbac ;\
      puppet module install abrader-gms ;\      
      chown -R pe-puppet:pe-puppet /etc/puppetlabs/code/ ;\
      puppet apply -e "include pe_code_manager_webhook::code_manager" ;\
      echo 'code_manager_mv_old_code=true' > /opt/puppetlabs/facter/facts.d/code_manager_mv_old_code.txt; puppet agent -t ;\
      yum install -y jq ;\
      /usr/bin/jq '.token' <%= $r10k_token %> -r > <%= $r10k_token %>.raw ;\
      /opt/puppetlabs/bin/puppet-code deploy --all --wait -t <%= $r10k_token %>.raw ;\
    ) & 
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
    ensure          => present,
    require         => File[$stage_pe_installer_dir],
    source          => $package_source_url,
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
    "puppet_enterprise::profile::master::code_manager_auto_configure": true,
    "puppet_enterprise::profile::master::r10k_remote": "<%= $r10k_remote %>",
    "puppet_enterprise::profile::master::r10k_private_key": "<%= $r10k_private_key %>",
    "puppet_enterprise::profile::master::r10k_proxy": "<%= $r10k_proxy %>",
    }
  | EOF

  file { $config_file:
    ensure  => file,
    content => inline_epp($conf_content)
  }

  exec { "${install_pe_puppetserver} ${console_admin_password}":
    require => [
      File[$install_pe_puppetserver],
      Archive[$package_source],
    ],
    unless  => '/usr/bin/rpm -q pe-puppetserver',
    notify  => [
      Exec['start_staging_puppetserver_on_next_puppet_run'],
    ],
    timeout => 6000,
  }

  ini_setting { "ssldir in ${puppet_conf_file}":
    ensure            => present,
    path              => $puppet_conf_file,
    section           => 'master',
    setting           => 'ssldir',
    key_val_separator => '=',
    value             => $ssldir_path,
  }

  # If we assume puppetserver has just been installed, we also assume this is a brand new puppetserver,
  # so we set a custom fact 'staging_puppetserver', used in 'roles::puppetserver' to stage new repos to git & setup r10k...
  exec { 'start_staging_puppetserver_on_next_puppet_run':
    path        => '/bin',
    command     => 'echo staging_puppetserver=true > /opt/puppetlabs/facter/facts.d/staging_puppetserver.txt',
    refreshonly => true,
  }

  # TODO: required for agents to specify their own puppet environmnet
  # node_group { 'Agent-specified environment':
  #   ensure               => 'present',
  #   environment          => 'agent-specified',
  #   override_environment => 'true',
  #   parent               => 'Production environment',
  #   rule                 => ['and', ['!=', ['fact', 'agent_specified_environment'], 'production']],
  # }

  # node_group { 'Agent-specified environment': ensure => 'present', environment => 'agent-specified', override_environment => 'true', parent => 'Production environment', rule => ['and', ['!=', ['fact', 'agent_specified_environment'], 'production']],}

}
