# This class handels the installation for RHEL machines
class sssd::rhel () inherits sssd {
    # Variables for the execution of authselect and authconfig
    $authselect_exec = '/bin/authselect'
    $authconfig_exec = '/usr/sbin/authconfig'

    case $::facts['os']['release']['major'] {
        '9': {
            # In rhel9 no parameters are required for the select command, only the option "sssd" must be specified
            $auth_select_cmd = "${authselect_exec} select ${authselect_profile} --force"
            $auth_check_cmd = "/usr/bin/test \"$(${authselect_exec} current --raw)\" = \"${authselect_profile} with-mkhomedir\""
            # In rhel9, mkhomedir is used in a separate command
            $auth_mkhomedir_cmd = "${authselect_exec} enable-feature with-mkhomedir"
            # Flag file which is used to execute the $auth_mkhomedir_cmd
            $auth_flag_file = "true"
        }
        '8': {
            # This if statement checks if the variable $ensure is set to present
            # It will join the authselect_profile (sssd) with the specific flags
            if $ensure == 'present' {
                $authselect_options = join(
                    concat(
                        [$authselect_profile],
                        $mkhomedir ? {
                            true  => $enable_mkhomedir_flags,
                            false => $disable_mkhomedir_flags,
                        }
                    ),
                    ' '
                )
            } else {
                $authselect_options = $authselect_profile
            }
            # $auth_select_cmd is assembled with the options
            $auth_select_cmd = "${authselect_exec} select ${authselect_options} --force"
            # same for $auth_check_cmd
            $auth_check_cmd = "${authselect_exec} current --raw | grep -q '^${authselect_options}$'"
        }
        default: {
            # authconfig is used for Rhel7
            $auth_select_cmd = "${authconfig_exec} ${authconfig_flags} --update"
            $auth_test_cmd   = "${authconfig_exec} ${authconfig_flags} --test"
            $auth_check_cmd  = "/usr/bin/test \"$(${authconfig_test_cmd})\" = \"$(${authconfig_exec} --test)\""
        }
    }

    exec { 'auth-select':
        command => $auth_select_cmd,
        unless  => $auth_check_cmd,
        require => File['sssd.conf'],
    }

    if $auth_flag_file == 'true' {
        exec { 'authselect-enable-mkhomedir':
            command => $auth_mkhomedir_cmd,
            unless  => $auth_check_cmd,
            require => Exec['auth-select'],
        }
    }
}
