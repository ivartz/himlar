#!/bin/bash

#CODE_PATH=/etc/puppetlabs/code
#PUPPET_ENV="${HIMLAR_PUPPET_ENV:-production}"
#ENV_PATH=environments/$PUPPET_ENV

set_certname()
{
  # Set default certname
  certname="vagrant-base-dev.himlar.local"
  # Use certname from puppet.conf if it is present
  grep -q certname /etc/puppetlabs/puppet/puppet.conf && certname="$(/opt/puppetlabs/puppet/bin/puppet config print certname)"
  # Override with certname from env var if present
  certname="${HIMLAR_CERTNAME:-$certname}"
}

bootstraprun()
{
  # Run bootstrap if bootstrap file is present
  # If the run exits with 0, remove the marker file
  if [[ -f "/opt/himlar/bootstrap" ]]; then
    FACTER_RUNMODE=bootstrap puppetrun
    if [[ $? -eq 0 ]]; then
      echo "puppetrun.sh: $certname bootstrap finished"
      rm -fv /opt/himlar/bootstrap
    fi
  fi
}

puppetrun()
{
  CODE_PATH=/etc/puppetlabs/code
  PUPPET_ENV="${HIMLAR_PUPPET_ENV:-production}"
  ENV_PATH=environments/$PUPPET_ENV

  echo "puppet run for environment ${PUPPET_ENV}"
  # Load custom facts from module lib dirs (facter does not scan modulepaths)
  export FACTERLIB="/opt/himlar/modules/named_interfaces/lib/facter:${CODE_PATH}/$ENV_PATH/modules/named_interfaces/lib/facter"
  /opt/puppetlabs/puppet/bin/puppet apply --verbose --show_diff \
    --certname $certname \
    --write-catalog-summary \
    --environment ${PUPPET_ENV} \
    --hiera_config $CODE_PATH/$ENV_PATH/hiera.yaml \
    --basemodulepath /opt/himlar/modules:$CODE_PATH/$ENV_PATH/modules:$CODE_PATH/modules \
    ${p_args[*]} \
    $CODE_PATH/$ENV_PATH/manifests/site.pp
}

# Source command line options as env vars
while [[ $# -gt 0 ]]; do
  case $1 in
    HIMLAR_*=*|FACTER_*=*)
      export $1
      shift
      ;;
    *)
      # Passing through to Puppet
      p_args+=("$1")
      shift
      ;;
  esac
done

# Seed named_interfaces fact for vagrant (structured external facts are broken in facter 4.10,
# the custom fact in modules/named_interfaces reads this file directly via Ruby YAML)
if [[ $HIMLAR_VAGRANT == "true" ]] && [[ ! -f /etc/facter/facts.d/named_interfaces.yaml ]]; then
  mkdir -p /etc/facter/facts.d
  printf 'vagrant:\n  - eth0\nmgmt:\n  - eth1\ntrp:\n  - eth2\nlive:\n  - eth2\npublic:\n  - eth3\n' > /etc/facter/facts.d/named_interfaces.yaml
fi

# Set certname
set_certname

# Do bootstrap run if needed
if [[ ! $FACTER_is_installer == "true" ]]; then
    bootstraprun
fi

# Run Puppet
puppetrun
