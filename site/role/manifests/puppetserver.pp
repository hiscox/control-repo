# Puppet master role
class role::puppetserver {

  contain profile::puppetserver
  Class['profile::puppetserver']

}
