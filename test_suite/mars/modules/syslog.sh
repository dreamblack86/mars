#!/bin/bash
# Copyright 2010-2014 Frank Liepold /  1&1 Internet AG
#
# Email: frank.liepold@1und1.de
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

#####################################################################

function syslog_run
{
    local primary_host=${global_host_list[0]}
    local secondary_host=${global_host_list[1]}
    local res=${resource_name_list[0]}
    local writer_pid writer_script write_count
    local logfile length_logfile time_waited
    local logfile_sav=$global_mars_directory/logfile.sav.$$
    local nr_msg_orig i

    lib_wait_for_initial_end_of_sync $primary_host $secondary_host $res \
                                  $resource_maxtime_initial_sync \
                                  $resource_time_constant_initial_sync \
                                  "time_waited"
    lib_vmsg "  ${FUNCNAME[0]}: sync time: $time_waited"

    mount_mount_data_device $primary_host $res

    # 2 loops to test recovery window
    for i in 1 2; do
        resource_clear_data_device $primary_host $res

        lib_rw_start_writing_data_device $primary_host "writer_pid" \
                                         "writer_script"  2 2 $res ""

        marsadm_pause_cmd "apply" $secondary_host $res

        lib_wait_until_action_stops "replay" $secondary_host $res \
                                      $apply_fetch_maxtime_apply \
                                      $apply_fetch_time_constant_apply \
                                      "time_waited" 0 ""
        lib_vmsg "  ${FUNCNAME[0]}: apply time: $time_waited"

        marsview_wait_for_state $secondary_host $res "disk" "Outdated\[.*A.*\]" \
                                $marsview_wait_for_state_time
        marsview_wait_for_state $secondary_host $res "repl" '-SF--' \
                                $marsview_wait_for_state_time || lib_exit 1

        lib_rw_stop_writing_data_device $primary_host $writer_script \
                                        "write_count"
        main_error_recovery_functions["lib_rw_stop_scripts"]=

        lib_wait_until_fetch_stops "apply_fetch" $secondary_host $primary_host \
                                   $res "logfile" "length_logfile" \
                                   "time_waited" 0 ""
        lib_vmsg "  ${FUNCNAME[0]}: fetch time: $time_waited"

        file_handling_check_equality_of_file_lengths $logfile $primary_host \
                                                     $secondary_host \
                                                     $length_logfile

        syslog_set_logging_parameters $secondary_host

        lib_vmsg "  copying $secondary_host:$logfile to $logfile_sav"
        lib_remote_idfile $secondary_host \
                          "rm -f $logfile_sav && cp $logfile $logfile_sav" || \
                                                                    lib_exit 1

        file_destroy_dd_on_logfile $secondary_host $logfile $length_logfile

        nr_msg_orig=$(syslog_count_or_check_messages $secondary_host \
                      $syslog_flood_limit 1) || lib_exit 1

        marsadm_do_cmd $secondary_host "resume-replay" $res || lib_exit 1

        syslog_count_or_check_messages $secondary_host \
                                     $(( $nr_msg_orig + $syslog_flood_limit )) 0

        # stopp generation of new error messages
        marsadm_pause_cmd "apply" $secondary_host $res

        lib_wait_until_action_stops "replay" $secondary_host $res \
                                      $apply_fetch_maxtime_apply \
                                      $apply_fetch_time_constant_apply \
                                      "time_waited" 0 ""

        lib_vmsg "  restoring $logfile from $logfile_sav"
        lib_remote_idfile $secondary_host \
                          "dd if=$logfile_sav of=$logfile conv=notrunc" || \
                                                                    lib_exit 1

        marsadm_do_cmd $secondary_host "resume-replay" $res || lib_exit 1

        nr_msg_orig=$(syslog_count_or_check_messages $secondary_host \
                      $syslog_flood_limit 1) || lib_exit 1

        lib_vmsg "  sleeping syslog_recovery_s = $syslog_recovery_s seconds"

        syslog_count_or_check_messages $secondary_host $nr_msg_orig 0
    done

}

function syslog_set_logging_parameters
{
    local host=$1 param file value varname filename
    for param in class limit recovery_s; do
        varname='syslog_flood_'$param
        lib_vmsg "  setting $varname on $host"
        eval value='$'$varname
        if [ -z "$value" ]; then
            lib_exit 1 "no value found for variable $varname"
        fi
        filename='syslog_flood_'$param'_file'
        eval file='$'$filename
        lib_remote_idfile $host "ls -l $file" || lib_exit 1
        lib_remote_idfile $host "echo $value > $file" || lib_exit 1
    done
}

# we cannot use lib_err_wait_for_error_messages, because we need a grep -v egrep
# because sometimes all commands are logged in /var/log/syslog ...
# If only_count==1 then the number of messages found is printed to stdout.
function syslog_count_or_check_messages
{
    [ $# -eq 3 ] || lib_exit 1 "wrong number $# of arguments (args = $*)"
    local host=$1 nr_msg_req=$2 only_count=$3
    local waited=0 maxwait=$syslog_msg_wait_time
    while true; do
        local nr_msg_act
        nr_msg_act="$(lib_remote_idfile $host \
                     "egrep '$syslog_err_msg_pattern' $syslog_logfile")" || \
                                                                    lib_exit 1
        nr_msg_act=$(echo "$nr_msg_act" | grep -vw egrep | wc -l)
        if [ $only_count -eq 1 ]; then
            echo $nr_msg_act
            return
        fi
        if [ $nr_msg_act -eq $nr_msg_req ]; then
            break
        fi
        sleep 1
        let waited+=1
        lib_vmsg "  waited $waited for $nr_msg_req (act. found = $nr_msg_act)"
        if [ $waited -eq $maxwait ]; then 
            lib_exit 1 "maxwait $maxwait exceeded"
        fi
    done
}
